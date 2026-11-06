--[[
Command parsing for /ll and /lootlogic (technical findings 14). This stage
handles "probe" and "debug"; the help list and the other commands of spec 13
arrive with later stages.
]]

local addonName, ns = ...

local Slash = {}
ns.Slash = Slash

local L = ns.L
local Log = ns.Log
local DB = ns.DB
local Events = ns.Events
local Util = ns.Util
local Probe = ns.Probe
local API = ns.API
local Detail = ns.Detail

local debugEventsRegistered = false

local function NoOp() end

-- Registers the events that only the debug log reads, so Events.lua writes
-- their "event" lines (technical findings 15, Debug log). Each registration
-- runs under pcall: PLAYERBANKSLOTS_CHANGED may not exist on Forever (from
-- memory; live check L40 notes whether it fires), and an unknown name may
-- raise (API guess). MERCHANT_SHOW and AUCTION_HOUSE_SHOW are from memory
-- (live check L38) and are skipped when ui.autoOpenContents is on, as the
-- findings say. A second call does nothing: Events has no unregister, and the
-- registrations are harmless while debug is off, because the event line is
-- written only while it is on.
local function RegisterDebugEvents()
    if debugEventsRegistered then
        return
    end
    debugEventsRegistered = true
    local names = { "PLAYERBANKSLOTS_CHANGED" }
    if not DB.Data().ui.autoOpenContents then
        names[#names + 1] = "MERCHANT_SHOW"
        names[#names + 1] = "AUCTION_HOUSE_SHOW"
    end
    for _, name in ipairs(names) do
        local ok, message = Util.Pcall(Events.Register, name, NoOp)
        if not ok then
            Log.Error("events", name .. ": " .. message)
        end
    end
end

-- /ll debug on|off (spec 13). rest is what follows the word "debug".
local function RunDebug(rest)
    local argument = string.match(rest, "^(%S+)$")
    argument = argument and string.lower(argument)
    if argument ~= "on" and argument ~= "off" then
        Log.Chat(L.debugUsage)
        return
    end
    if DB.IsReadOnly() then
        Log.Chat(L.debugReadOnly)
        return
    end
    local saved = DB.Data().debug
    local wanted = argument == "on"
    local already = saved.enabled == wanted
    saved.enabled = wanted
    if wanted then
        RegisterDebugEvents()
    end
    if already then
        Log.Chat(wanted and L.debugAlreadyOn or L.debugAlreadyOff)
    elseif wanted then
        Log.Chat(string.format(L.debugOn, tostring(saved.maxLog)))
    else
        Log.Chat(L.debugOff)
    end
end

local function InstanceArgument(argument)
    local id, suffix = string.match(argument, "^(%d+):([%-]?%d+)$")
    if id then
        return tonumber(id), tonumber(suffix)
    end
    id = string.match(argument, "^(%d+)$")
    if id then
        return tonumber(id), nil
    end
end

local function BagMatch(itemID, suffix)
    for bag = 0, 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local link = C_Container.GetContainerItemLink(bag, slot)
            local foundID, foundSuffix = Util.ParseLink(link or "")
            if foundID == itemID and (suffix == nil or suffix == foundSuffix) then
                return bag, slot
            end
        end
    end
end

local function Hovered()
    local tooltip = _G.GameTooltip
    if not tooltip then
        return nil
    end
    local info
    if type(tooltip.GetPrimaryTooltipInfo) == "function" then
        local ok, value = pcall(tooltip.GetPrimaryTooltipInfo, tooltip)
        if ok then
            info = value
        end
    end
    if info and info.getterName == "GetBagItem" then
        local args = info.getterArgs or {}
        if type(args[1]) == "number" and type(args[2]) == "number" then
            return { bag = args[1], slot = args[2] }
        end
    end
    local link = info and (info.hyperlink or (info.getterArgs or {})[1])
    if type(link) ~= "string" and type(tooltip.GetItem) == "function" then
        local ok, _, itemLink = pcall(tooltip.GetItem, tooltip)
        if ok then
            link = itemLink
        end
    end
    if type(link) == "string" and Util.ParseLink(link) then
        return { link = link, fromInbox = info and info.getterName == "GetInboxItem" }
    end
end

local function ItemLink(itemID, suffix)
    local itemString = string.format("item:%d:0:0:0:0:0:%d", itemID, suffix or 0)
    local ok, _, link = pcall(C_Item.GetItemInfo, itemString)
    if ok and type(link) == "string" then
        return link
    end
end

local function HyperlinkArgument(argument)
    local raw = argument
    if string.match(raw, "^|c%x%x%x%x%x%x%x%x") then
        if string.sub(raw, -2) ~= "|r" then
            return nil
        end
        raw = string.sub(raw, 11, -3)
    end
    if string.sub(raw, 1, 7) ~= "|Hitem:" or string.sub(raw, -3) ~= "]|h" then
        return nil
    end
    local separatorStart, separatorEnd = string.find(raw, "|h%[", 1)
    if not separatorStart or separatorStart <= 8 then
        return nil
    end
    local fields = string.sub(raw, 8, separatorStart - 1)
    if string.find(fields, "|", 1, true) or not Util.ParseLink("item:" .. fields) then
        return nil
    end
    local name = string.sub(raw, separatorEnd + 1, #raw - 3)
    if string.find(name, "|", 1, true) then
        return nil
    end
    return argument
end

local function RunWhy(rest)
    local argument = string.match(strtrim(rest), "^(.*)$")
    if argument == "" then
        local context = Hovered()
        if not context then
            Log.Chat(L.detailNoHover)
            return
        end
        local result
        if context.bag then
            result = API.ClassifyBagSlot(context.bag, context.slot)
        else
            result = API.ClassifyLink(context.link, context.fromInbox)
        end
        if result then
            local lines = Detail.Lines(result)
            for _, line in ipairs(lines) do
                Log.Chat(string.gsub(line, "^" .. L.chatPrefix .. " ", ""))
            end
        end
        return
    end
    local link = HyperlinkArgument(argument)
    local context, id, suffix
    if link then
        context = { link = link }
    else
        id, suffix = InstanceArgument(argument)
        if not id then
            Log.Chat(L.detailUsage)
            return
        end
        local bag, slot = BagMatch(id, suffix)
        if bag then
            context = { bag = bag, slot = slot }
        else
            if type(C_Item.DoesItemExistByID) == "function" then
                local ok, exists = pcall(C_Item.DoesItemExistByID, id)
                if ok and exists == false then
                    Log.Chat(L.detailNotFound)
                    return
                end
            end
            link = ItemLink(id, suffix)
            if not link then
                return
            end
            context = { link = link }
        end
    end
    local result
    if context.bag then
        result = API.ClassifyBagSlot(context.bag, context.slot)
    else
        result = API.ClassifyLink(context.link, context.fromInbox)
    end
    if result then
        for _, line in ipairs(Detail.Lines(result)) do
            Log.Chat(string.gsub(line, "^" .. L.chatPrefix .. " ", ""))
        end
    end
end

--- Runs the command typed after /ll. The command word is case-insensitive;
--- words after "probe" are ignored (spec 13, errors rule 2). "debug" takes on
--- or off; "why" explains the hovered or given item. Other commands print
--- one placeholder line for now.
-- @param message string the typed text after the slash command
function Slash.Run(message)
    local word, rest = string.match(strtrim(message), "^(%S+)%s*(.*)$")
    word = word and string.lower(word)
    if word == "probe" then
        Probe.Run()
        return
    end
    if word == "debug" then
        RunDebug(rest)
        return
    end
    if word == "why" then
        RunWhy(rest)
        return
    end
    Log.Chat(L.slashPlaceholder)
end

-- Debug saved on from an earlier session registers the debug-only events
-- (RegisterDebugEvents) at load. DB.lua's
-- handler for the same event is registered first, so the saved data is
-- loaded by now.
Events.Register("ADDON_LOADED", function(_, name)
    if name == addonName and Log.IsDebugOn() then
        RegisterDebugEvents()
    end
end)
