--[[
Command parsing and setup commands for /ll and /lootlogic (spec 13, technical
findings 14). M2 window commands and templates are handled by later modules.
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
local Cache = ns.Cache
local Classify = ns.Classify
local Snapshot = ns.Snapshot
local Tooltip = ns.Tooltip
local Roster = ns.Roster
local Loadouts = ns.Loadouts
local Asks = ns.Asks
local Sets = ns.Sets
local Specs = ns.Specs

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
    local id, suffix = string.match(argument, "^(%-?%d+):([%-]?%d+)$")
    if id then
        return tonumber(id), tonumber(suffix)
    end
    id = string.match(argument, "^(%-?%d+)$")
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
    if
        (type(link) ~= "string" or not Util.ParseLink(link))
        and type(tooltip.GetItem) == "function"
    then
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
    local prefix = string.match(raw, "^(|c%x%x%x%x%x%x%x%x)") or string.match(raw, "^(|cn[%w_]+:)")
    if prefix then
        if string.sub(raw, -2) ~= "|r" then
            return nil
        end
        raw = string.sub(raw, #prefix + 1, -3)
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

local function RunHelp(rest)
    if strtrim(rest) ~= "" then
        Log.Chat(L.helpUsage)
        return
    end
    Log.Chat(L.helpHeader)
    for _, key in ipairs({
        "helpWhy", "helpProtect", "helpLoadout", "helpOrder", "helpWant",
        "helpGear", "helpRefresh", "helpProbe", "helpPerf", "helpDebug",
        "helpReset", "helpHelp",
    }) do
        Log.Chat(L[key])
    end
    Log.Chat(L.helpMultiPC)
end

local function RunPerf(rest)
    if strtrim(rest) ~= "" then
        Log.Chat(L.perfUsage)
        return
    end
    local pass = Classify.LastPass()
    if not pass then
        Log.Chat(L.perfNone)
        return
    end
    Log.Chat(string.format(L.perfLine, pass.scope, pass.count, pass.ms))
end

local function RunRefresh(rest)
    if strtrim(rest) ~= "" then
        Log.Chat(L.refreshUsage)
        return
    end
    if DB.IsReadOnly() then
        Log.Chat(L.debugReadOnly)
        return
    end
    Cache.Clear()
    Classify.Pass("bags")
    if Snapshot.IsBankOpen() then
        Classify.Pass("bank")
    end
    Tooltip.RefreshShown()
    Log.Chat(L.refreshDone)
end

local function Tokens(text)
    local result = {}
    local quoted = {}
    local position = 1
    while position <= #text do
        local _, finish = string.find(string.sub(text, position), "^%s+")
        if finish then
            position = position + finish
        else
            local rest = string.sub(text, position)
            local color = string.match(rest, "^(|c%x%x%x%x%x%x%x%x)")
                or string.match(rest, "^(|cn[%w_]+:)")
            local linkStart = position + (color and #color or 0)
            if string.sub(text, linkStart, linkStart + 1) == "|H" then
                local _, ending = string.find(text, "|h%[[^\n]-%]|h", linkStart)
                if ending then
                    if color and string.sub(text, ending + 1, ending + 2) == "|r" then
                        ending = ending + 2
                    end
                    result[#result + 1] = string.sub(text, position, ending)
                    position = ending + 1
                else
                    return nil
                end
            elseif string.sub(text, position, position) == '"' then
                local ending = string.find(text, '"', position + 1, true)
                if not ending then return nil end
                result[#result + 1] = string.sub(text, position + 1, ending - 1)
                quoted[#result] = true
                position = ending + 1
            else
                local _, ending = string.find(string.sub(text, position), "^%S+")
                if not ending then return nil end
                result[#result + 1] = string.sub(text, position, position + ending - 1)
                position = position + ending
            end
        end
    end
    return result, quoted
end

local function OneEditAway(first, second)
    first, second = string.lower(first), string.lower(second)
    local left, right = #first, #second
    if math.abs(left - right) > 1 or first == second then return false end
    if left == right then
        local differences = {}
        for index = 1, left do
            if string.sub(first, index, index) ~= string.sub(second, index, index) then
                differences[#differences + 1] = index
            end
        end
        return #differences == 1
            or (#differences == 2
                and differences[2] == differences[1] + 1
                and string.sub(first, differences[1], differences[1])
                    == string.sub(second, differences[2], differences[2])
                and string.sub(first, differences[2], differences[2])
                    == string.sub(second, differences[1], differences[1]))
    end
    local shorter, longer = first, second
    if left > right then shorter, longer = second, first end
    local shortIndex, longIndex, skipped = 1, 1, false
    while shortIndex <= #shorter and longIndex <= #longer do
        if string.sub(shorter, shortIndex, shortIndex)
            == string.sub(longer, longIndex, longIndex)
        then
            shortIndex = shortIndex + 1
            longIndex = longIndex + 1
        elseif skipped then
            return false
        else
            skipped = true
            longIndex = longIndex + 1
        end
    end
    return true
end

local function UniqueNearMatch(input, candidates)
    local found
    local seen = {}
    for _, candidate in ipairs(candidates) do
        local key = string.lower(candidate)
        if not seen[key] and OneEditAway(input, candidate) then
            if found then return nil end
            found = candidate
            seen[key] = true
        end
    end
    return found
end

local function ResolveName(tokens)
    local names = {}
    for key, name in pairs(Roster.DisplayNames()) do
        names[#names + 1] = { key = key, name = name, display = true }
        names[#names + 1] = { key = key, name = Roster.FullName(key), display = false }
    end
    local best, matches
    for count = 1, #tokens do
        local candidate = table.concat(tokens, " ", 1, count)
        local found = {}
        for _, row in ipairs(names) do
            if row.name and string.lower(row.name) == string.lower(candidate) then
                found[#found + 1] = row
            end
        end
        if #found > 0 then best, matches = count, found end
    end
    if not best then return nil, 0 end
    local display = {}
    for _, row in ipairs(matches) do
        if row.display then display[#display + 1] = row end
    end
    if #display > 0 then matches = display end
    local byKey = {}
    for _, row in ipairs(matches) do byKey[row.key] = true end
    local keys = {}
    for key in pairs(byKey) do keys[#keys + 1] = key end
    table.sort(keys)
    return #keys == 1 and keys[1] or nil, best, keys
end

local function NameError(tokens, count, matches)
    local input = table.concat(tokens, " ", 1, math.max(1, count))
    if matches and #matches > 1 then
        local names = Roster.DisplayNames()
        local choices = {}
        for _, key in ipairs(matches) do choices[#choices + 1] = names[key] or key end
        return string.format(L.ambiguousCharacter, input, table.concat(choices, " or "))
    end
    local candidates = {}
    for _, name in pairs(Roster.DisplayNames()) do candidates[#candidates + 1] = name end
    for _, key in ipairs(Roster.Keys()) do candidates[#candidates + 1] = Roster.FullName(key) end
    local near = UniqueNearMatch(input, candidates)
    if near then return string.format(L.unknownCharacterSuggested, input, near, input) end
    if count == 0 and #tokens > 0 then
        local firstMatches = {}
        for _, key in ipairs(Roster.Keys()) do
            local entry = Roster.Entry(key)
            if entry and string.lower(entry.first or "") == string.lower(tokens[1]) then
                firstMatches[#firstMatches + 1] = key
            end
        end
        if #firstMatches > 1 then
            local names = Roster.DisplayNames()
            local choices = {}
            for _, key in ipairs(firstMatches) do choices[#choices + 1] = names[key] or key end
            return string.format(L.ambiguousCharacter, tokens[1], table.concat(choices, " or "))
        end
    end
    return string.format(L.unknownCharacter, input, input)
end

local function CharacterTarget(args, quoted, usage)
    local count = #args
    local option
    for index, token in ipairs(args) do
        if not quoted[index]
            and (string.lower(token) == "--character" or string.lower(token) == "--all")
        then
            if option then
                Log.Chat(usage)
                return nil, "error"
            end
            option = index
        end
    end
    if not option then
        return { Roster.HereKey() }, "current"
    end
    local word = string.lower(args[option])
    if word == "--all" then
        if option ~= count or option ~= 1 then
            Log.Chat(usage)
            return nil, "error"
        end
        return Roster.Keys(), "all"
    end
    if option + 1 ~= count or not args[option + 1] then
        Log.Chat(usage)
        return nil, "error"
    end
    local name = args[option + 1]
    local key, matched, matches = ResolveName({ name })
    if not key then
        Log.Chat(NameError({ name }, matched, matches))
        return nil, "error"
    end
    for index = #args, option, -1 do
        args[index] = nil
        quoted[index] = nil
    end
    return { key }, "character"
end

local function TypeCatalogue()
    if
        type(C_Item) ~= "table"
        or type(C_Item.GetItemClassInfo) ~= "function"
        or type(C_Item.GetItemSubClassInfo) ~= "function"
    then
        return nil
    end
    local classes, types = {}, {}
    for class = 0, 20 do
        local classOk, name = pcall(C_Item.GetItemClassInfo, class)
        if not classOk then return nil end
        if name then
            classes[#classes + 1] = { id = class, name = name }
            for sub = 0, 20 do
                local subclassOk, subName = pcall(C_Item.GetItemSubClassInfo, class, sub)
                if not subclassOk then return nil end
                if subName then
                    types[#types + 1] = {
                        key = class .. ":" .. sub,
                        name = name .. ": " .. subName,
                        short = subName,
                        class = class,
                        subclass = sub,
                    }
                end
            end
        end
    end
    return classes, types
end

local function ItemLabel(itemID)
    local name = C_Item.GetItemInfo(itemID)
    if name then return " [" .. name .. "]" end
    return ""
end

local function LoadoutLines(key, targeted)
    local display = Roster.DisplayName(key)
    local lines = { string.format(L.loadoutListHeader, display) }
    local loadouts = Loadouts.List(key)
    if #loadouts == 0 then
        lines[#lines + 1] = L.loadoutListNone
        return lines
    end
    for _, loadout in ipairs(loadouts) do
        local spec = Specs[loadout.spec]
        local specName = spec and spec.label or L.loadoutListNoSpec
        local status = loadout.worn and L.loadoutListWorn or L.loadoutListStowed
        if loadout.assumed then
            status = status .. L.loadoutListAssumed
        end
        local armor
        if loadout.armor then
            armor = loadout.armor == "best" and L.loadoutListBestArmor
                or L.loadoutListAnyArmor
        else
            armor = string.format(
                L.loadoutListDefaultArmor,
                DB.Data().settings.gear.bestArmorOnly and L.loadoutListBestOnly
                    or L.loadoutListAnyArmor
            )
        end
        lines[#lines + 1] = string.format(
            L.loadoutListEntry,
            loadout.name,
            specName,
            status,
            armor
        )
        if loadout.assumed and spec then
            local characterOption = targeted
                and string.format(L.loadoutListCharacterOption, display)
                or ""
            lines[#lines + 1] = string.format(
                L.loadoutListKeep,
                loadout.name,
                spec.label,
                characterOption
            )
        end
    end
    return lines
end

local function WantTypeName(key)
    local classID = string.match(key, "^(%d+):%d+$")
    local classAll = string.match(key, "^(%d+):%*$")
    local classes, types = TypeCatalogue()
    if not classes then return key end
    local className
    for _, row in ipairs(classes) do
        if tostring(row.id) == (classID or classAll) then
            className = row.name
            break
        end
    end
    if classAll then return className or key end
    for _, row in ipairs(types) do
        if row.key == key then return row.name end
    end
    return key
end

local function WantLines(key)
    local entry = Roster.Entry(key)
    local asks = entry and entry.asks or {}
    local lines = { string.format(L.wantListHeader, Roster.DisplayName(key)) }
    local typeEntries, itemEntries = {}, {}
    for typeKey, flag in pairs(asks.types or {}) do
        if flag then
            typeEntries[#typeEntries + 1] = { key = typeKey, flag = flag }
        end
    end
    for itemID, mode in pairs(asks.items or {}) do
        if mode == "include" or mode == "exclude" then
            itemEntries[#itemEntries + 1] = { id = itemID, mode = mode }
        end
    end
    table.sort(typeEntries, function(first, second)
        local firstClass, firstSub = string.match(first.key, "^(%d+):(%d+)$")
        local secondClass, secondSub = string.match(second.key, "^(%d+):(%d+)$")
        firstClass = tonumber(firstClass) or tonumber(string.match(first.key, "^(%d+):%*$")) or 0
        secondClass = tonumber(secondClass)
            or tonumber(string.match(second.key, "^(%d+):%*$"))
            or 0
        if firstClass ~= secondClass then return firstClass < secondClass end
        return (tonumber(firstSub) or -1) < (tonumber(secondSub) or -1)
    end)
    table.sort(itemEntries, function(first, second) return first.id < second.id end)
    for _, item in ipairs(typeEntries) do
        local quality = type(item.flag) == "table" and item.flag.minQuality or nil
        local qualityName = quality and tostring(quality) or L.wantListAnyQuality
        lines[#lines + 1] = string.format(
            L.wantListType,
            WantTypeName(item.key),
            qualityName
        )
    end
    for _, item in ipairs(itemEntries) do
        lines[#lines + 1] = string.format(
            item.mode == "include" and L.wantListInclude or L.wantListExclude,
            item.id,
            ItemLabel(item.id)
        )
    end
    if #typeEntries == 0 and #itemEntries == 0 then lines[#lines + 1] = L.wantListNone end
    return lines
end

local function PrintCharacterListings(keys, build)
    for _, key in ipairs(keys) do
        local lines = build(key, key ~= Roster.HereKey())
        for _, line in ipairs(lines) do Log.Chat(line) end
    end
end

local function ValidateItem(id)
    if type(C_Item.DoesItemExistByID) == "function" then
        local ok, exists = pcall(C_Item.DoesItemExistByID, id)
        if ok and exists == false then return false end
    end
    return true
end

local function IneligibleReason(key)
    if key == Roster.HereKey() or Roster.IsEligible(key) then return nil end
    local entry = Roster.Entry(key)
    if entry.faction ~= UnitFactionGroup("player") then return L.ineligibleFaction end
    return L.ineligibleRegion
end

local function ParseItemOrType(value, allowInstance)
    local link = HyperlinkArgument(value)
    if link then
        local id, suffix = Util.ParseLink(link)
        return "item", id, suffix, link
    end
    local id, suffix = string.match(value, "^(%d+):([%-]?%d+)$")
    if id then
        if allowInstance then
            id, suffix = tonumber(id), tonumber(suffix)
            return "item", id, suffix
        end
        local wanted = id .. ":" .. suffix
        local _, catalog = TypeCatalogue()
        if not catalog then return nil, {}, nil, nil, "catalogue" end
        for _, row in ipairs(catalog) do
            if row.key == wanted then
                return "type", wanted, nil, nil, nil, nil, row.name
            end
        end
        return nil, {}, nil, nil, wanted
    end
    id = string.match(value, "^(%-?%d+)$")
    if id then return "item", tonumber(id) end
    local whole = string.match(value, "^(%d+):%*$")
    if whole then
        local classes = TypeCatalogue()
        if not classes then return nil, {}, nil, nil, "catalogue" end
        for _, row in ipairs(classes) do
            if tostring(row.id) == whole then
                return "type", whole .. ":*", nil, nil, nil, nil, row.name
            end
        end
        return nil, {}, nil, nil, whole .. ":*"
    end
    local classes, types = TypeCatalogue()
    if not classes then return nil, {}, nil, nil, "catalogue" end
    local lower = string.lower(value)
    for _, row in ipairs(classes) do
        if string.lower(row.name) == lower then
            return "type", row.id .. ":*", nil, nil, nil, nil, row.name
        end
    end
    for _, row in ipairs(types) do
        if string.lower(row.name) == lower then
            return "type", row.key, nil, nil, nil, nil, row.name
        end
    end
    local found = {}
    for _, row in ipairs(types) do
        if string.lower(row.short) == lower then found[#found + 1] = row end
    end
    if #found == 1 then
        return "type", found[1].key, nil, nil, nil, nil, found[1].name
    end
    local classText, subclassText = string.match(value, "^([^:]+):%s*(.+)$")
    if classText then
        local classRow
        for _, row in ipairs(classes) do
            if string.lower(row.name) == string.lower(classText) then
                classRow = row
                break
            end
        end
        if classRow then
            return nil, found, classes, types, nil, {
                class = classRow,
                subclassText = subclassText,
            }
        end
        return nil, found, classes, types, nil, { classText = classText }
    end
    return nil, found, classes, types
end

local function RunWant(rest)
    local args, quoted = Tokens(rest)
    if not args then Log.Chat(L.wantUsage); return end
    local keys, targetMode = CharacterTarget(args, quoted, L.wantUsage)
    if not keys then return end
    if targetMode == "all" or #args == 0 then
        PrintCharacterListings(keys, WantLines)
        return
    end
    local key = keys[1]
    local setting = "on"
    local last = string.lower(args[#args])
    if last == "on" or last == "off" or last == "clear" then
        setting = last
        table.remove(args)
    end
    local value = table.concat(args, " ")
    if string.match(value, "^%s*$") then
        Log.Chat(L.wantUsage)
        return
    end
    local kind, parsed, classes, types, missingType, typeError, typeName =
        ParseItemOrType(value, false)
    if not kind then
        if missingType then
            if missingType == "catalogue" then
                Log.Chat(L.typeCatalogueUnavailable)
                return
            end
            Log.Chat(string.format(L.itemTypeMissing, missingType))
            return
        end
        if #parsed > 1 then
            local choices = {}
            for _, row in ipairs(parsed) do
                choices[#choices + 1] = string.format("%s (%s)", row.name, row.key)
            end
            Log.Chat(string.format(L.ambiguousType, value, table.concat(choices, " and ")))
            return
        end
        if typeError then
            local names = {}
            if typeError.class then
                for _, row in ipairs(types) do
                    if row.class == typeError.class.id then
                        names[#names + 1] = row.short
                    end
                end
                local near = UniqueNearMatch(typeError.subclassText, names)
                local suffix = near and string.format(L.typeSuggestion, near) or ""
                Log.Chat(string.format(
                    L.noSubclass,
                    typeError.class.name,
                    typeError.subclassText,
                    typeError.class.name,
                    table.concat(names, ", "),
                    suffix
                ))
            else
                for _, row in ipairs(classes) do names[#names + 1] = row.name end
                local near = UniqueNearMatch(typeError.classText, names)
                local suffix = near and string.format(L.typeSuggestion, near) or ""
                Log.Chat(string.format(
                    L.noClass,
                    typeError.classText,
                    table.concat(names, ", "),
                    suffix
                ))
            end
            return
        end
        local candidates = {}
        for _, row in ipairs(classes or {}) do candidates[#candidates + 1] = row.name end
        for _, row in ipairs(types or {}) do
            candidates[#candidates + 1] = row.name
            candidates[#candidates + 1] = row.short
        end
        local near = UniqueNearMatch(value, candidates)
        if near then
            Log.Chat(string.format(L.noTypeSuggested, value, near))
            return
        end
        Log.Chat(string.format(L.noType, value))
        return
    end
    if kind == "type" then
        if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
        local status = Asks.SetType(key, parsed, setting)
        local name = Roster.DisplayName(key)
        local ineligible = IneligibleReason(key)
        if ineligible then
            Log.Chat(string.format(L.wantIneligible, name, ineligible))
        else
            local reply = L.wantTypeAbsent
            if status == "changed" and setting == "on" then reply = L.wantTypeChanged end
            if status == "unchanged" and setting == "on" then reply = L.wantTypeUnchanged end
            if status == "changed" and setting ~= "on" then reply = L.wantTypeRemoved end
            Log.Chat(string.format(
                reply,
                name,
                typeName
            ))
        end
    else
        if not ValidateItem(parsed) then
            Log.Chat(string.format(L.itemNotExist, parsed))
            return
        end
        if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
        local mode = setting == "on" and "include" or setting == "off" and "exclude" or "clear"
        local status = Asks.SetItem(key, parsed, mode)
        local name = Roster.DisplayName(key)
        local label = ItemLabel(parsed)
        local ineligible = IneligibleReason(key)
        if ineligible then
            Log.Chat(string.format(L.wantIneligible, name, ineligible))
        elseif mode == "include" then
            Log.Chat(string.format(
                status == "changed" and L.wantItemChanged or L.wantItemUnchanged,
                name,
                parsed,
                label
            ))
        elseif mode == "exclude" then
            Log.Chat(string.format(
                status == "changed" and L.wantItemExcluded or L.wantItemExcludeUnchanged,
                name,
                parsed,
                label
            ))
        else
            Log.Chat(string.format(
                status == "changed" and L.wantItemCleared or L.wantItemClearUnchanged,
                status == "changed" and parsed or name,
                status == "changed" and label or parsed,
                status == "changed" and name or label
            ))
        end
    end
end

local function RunOrder(rest)
    local args = Tokens(rest)
    if not args then
        Log.Chat(L.orderUsage)
        return
    end
    if #args == 0 then
        local names = Roster.DisplayNames()
        local ordered = {}
        for _, key in ipairs(Roster.Keys()) do ordered[#ordered + 1] = names[key] or key end
        Log.Chat(string.format(L.orderList, table.concat(ordered, ", ")))
        return
    end
    local keys, at = {}, 1
    while at <= #args do
        local remaining = { unpack(args, at) }
        local key, count, matches = ResolveName(remaining)
        if not key then
            Log.Chat(NameError(remaining, count, matches))
            return
        end
        keys[#keys + 1] = key
        at = at + count
    end
    if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
    local status = Roster.SetOrder(keys)
    local names = Roster.DisplayNames()
    local ordered = {}
    for _, key in ipairs(Roster.Keys()) do ordered[#ordered + 1] = names[key] or key end
    Log.Chat(string.format(status == "changed" and L.orderChanged or L.orderUnchanged,
        table.concat(ordered, ", ")))
end

local function RunGear(rest)
    local args = Tokens(rest)
    if not args or #args < 2 then Log.Chat(L.gearUsage); return end
    local key, count, matches = ResolveName(args)
    if not key then
        Log.Chat(NameError(args, count, matches))
        return
    end
    local setting = string.lower(args[count + 1] or "")
    if (setting ~= "on" and setting ~= "off") or count + 1 ~= #args then
        Log.Chat(L.gearUsage)
        return
    end
    if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
    local status = Roster.SetReceivesGear(key, setting == "on")
    local name = Roster.DisplayName(key)
    if status == "changed" then
        Log.Chat(string.format(setting == "on" and L.gearOn or L.gearOff, name))
    else
        Log.Chat(string.format(L.gearUnchanged, name, setting))
    end
end

local function LoadoutChoices(key)
    local choices = {}
    for _, loadout in ipairs(Loadouts.List(key)) do
        if type(loadout.name) == "string" then choices[#choices + 1] = loadout.name end
    end
    table.sort(choices)
    return #choices > 0 and table.concat(choices, ", ") or L.loadoutChoiceNone
end

local function LoadoutMissing(key, name)
    local choices = Loadouts.List(key)
    local candidates = {}
    for _, loadout in ipairs(choices) do
        if type(loadout.name) == "string" then candidates[#candidates + 1] = loadout.name end
    end
    local near = UniqueNearMatch(name, candidates)
    local suggestion = near and string.format(L.argumentSuggestion, near) or ""
    return string.format(L.noLoadoutNamed, Roster.DisplayName(key), name, LoadoutChoices(key))
        .. suggestion
end

local function ClassName(token)
    local male = _G.LOCALIZED_CLASS_NAMES_MALE
    local female = _G.LOCALIZED_CLASS_NAMES_FEMALE
    return (male and male[token]) or (female and female[token]) or token
end

local function RunLoadout(rest)
    local args, quoted = Tokens(rest)
    if not args then Log.Chat(string.format(L.loadoutUsage, L.helpLoadoutExample)); return end
    local keys, targetMode = CharacterTarget(args, quoted, string.format(
        L.loadoutUsage,
        L.helpLoadoutExample
    ))
    if not keys then return end
    if targetMode == "all" or #args == 0 then
        PrintCharacterListings(
            keys,
            LoadoutLines
        )
        return
    end
    local key = keys[1]
    local entry = Roster.Entry(key)
    local tail = args
    local tailQuoted = quoted
    if #tail == 0 then
        Log.Chat(string.format(L.loadoutUsage, L.helpLoadoutExample))
        return
    end
    local action = string.lower(tail[#tail] or "")
    local status
    local reason
    local loadoutName
    local specLabel
    local armorAction
    local makeWorn = false
    local operation
    local wasAssumed = false
    if action == "remove" and not tailQuoted[#tail] then
        operation = "remove"
        table.remove(tail)
        table.remove(tailQuoted)
        local name = table.concat(tail, " ")
        if name == "" then
            Log.Chat(string.format(L.loadoutUsage, L.helpLoadoutExample))
            return
        end
        loadoutName = name
    elseif action == "armor" and not tailQuoted[#tail] and #tail > 1 then
        Log.Chat(L.loadoutArmorUsage)
        return
    elseif
        string.lower(tail[#tail - 1] or "") == "armor"
        and not tailQuoted[#tail - 1]
        and not tailQuoted[#tail]
    then
        operation = "armor"
        armorAction = action
        local armor
        if action ~= "default" then
            armor = action
        end
        if action ~= "default" and action ~= "best" and action ~= "any" then
            Log.Chat(L.loadoutArmorUsage)
            return
        end
        table.remove(tail)
        table.remove(tail)
        table.remove(tailQuoted)
        table.remove(tailQuoted)
        loadoutName = table.concat(tail, " ")
        if loadoutName == "" then
            Log.Chat(L.loadoutArmorUsage)
            return
        end
        if not Loadouts.Find(key, loadoutName) then
            Log.Chat(LoadoutMissing(key, loadoutName))
            return
        end
        if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
        status, reason = Loadouts.SetArmor(key, loadoutName, armor)
    else
        operation = "set"
        makeWorn = string.lower(tail[#tail]) == "worn" and not tailQuoted[#tail]
        if makeWorn then
            table.remove(tail)
            table.remove(tailQuoted)
        end
        if #tail < 2 then
            Log.Chat(string.format(L.loadoutUsage, L.helpLoadoutExample))
            return
        end
        local choices = {}
        for id, spec in pairs(Specs) do
            if spec.class == entry.class and Loadouts.HasWeights(id) then
                choices[#choices + 1] = { id = id, label = spec.label }
            end
        end
        table.sort(choices, function(first, second)
            return string.lower(first.label) < string.lower(second.label)
        end)
        if #choices == 0 then
            Log.Chat(string.format(L.loadoutNoSpecs, ClassName(entry.class)))
            return
        end
        local foundSpec, specStart
        for index = 2, #tail do
            local candidate = string.lower(table.concat(tail, " ", index))
            for _, spec in ipairs(choices) do
                if string.lower(spec.label) == candidate or string.lower(spec.id) == candidate
                then
                    foundSpec, specStart = spec.id, index
                    break
                end
            end
            if foundSpec then break end
        end
        if not foundSpec or not specStart or specStart == 1 then
            local labels = {}
            for _, spec in ipairs(choices) do labels[#labels + 1] = spec.label end
            local candidates = {}
            for _, spec in ipairs(choices) do
                candidates[#candidates + 1] = spec.label
                candidates[#candidates + 1] = spec.id
            end
            local near = UniqueNearMatch(tail[#tail], candidates)
            local suggestion = near and string.format(L.argumentSuggestion, near) or ""
            Log.Chat(string.format(
                L.loadoutSpecs,
                tostring(tail[#tail]),
                ClassName(entry.class),
                table.concat(labels, ", ")
            ) .. suggestion)
            return
        end
        local name = table.concat(tail, " ", 1, specStart - 1)
        if string.match(name, "^%s*$") then
            Log.Chat(string.format(L.loadoutUsage, L.helpLoadoutExample))
            return
        end
        loadoutName = name
        specLabel = Specs[foundSpec].label
        local existing = Loadouts.Find(key, name)
        wasAssumed = existing and existing.assumed == true or false
        if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
        status, reason = Loadouts.Set(key, name, foundSpec, makeWorn)
    end
    if operation == "remove" then
        if not Loadouts.Find(key, loadoutName) then
            Log.Chat(LoadoutMissing(key, loadoutName))
            return
        end
        if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
        status, reason = Loadouts.Remove(key, loadoutName)
    end
    if reason == "readonly" or status == "readonly" then Log.Chat(L.debugReadOnly)
    elseif reason == "worn" then
        Log.Chat(string.format(L.loadoutWornNamed, Roster.DisplayName(key), loadoutName))
    elseif reason == "noloadout" then
        Log.Chat(LoadoutMissing(key, loadoutName))
    elseif status == "unchanged" then
        if specLabel then
            Log.Chat(string.format(
                L.loadoutUnchanged,
                Roster.DisplayName(key),
                loadoutName,
                specLabel
            ))
        else
            Log.Chat(string.format(
                L.loadoutArmorUnchanged,
                Roster.DisplayName(key),
                loadoutName,
                armorAction
            ))
        end
    elseif status == "removed" then
        Log.Chat(string.format(L.loadoutRemoved, Roster.DisplayName(key), loadoutName))
    elseif status == "changed" and armorAction then
        Log.Chat(string.format(
            L.loadoutArmorChanged,
            Roster.DisplayName(key),
            loadoutName,
            armorAction
        ))
    elseif status then
        Log.Chat(string.format(
            L.loadoutChanged,
            Roster.DisplayName(key),
            loadoutName,
            specLabel,
            makeWorn and L.wantWornSuffix or wasAssumed and L.loadoutPickedSuffix or ""
        ))
    else
        Log.Chat(L.loadoutFailed)
    end
end

local function RunProtect(rest)
    local args = Tokens(rest)
    if not args then
        Log.Chat(L.protectUsage)
        return
    end
    local global = string.lower(args[1] or "") == "global"
    if global then table.remove(args, 1) end
    local itemText = table.concat(args, " ")
    local context, kind, id, suffix
    if itemText == "" then
        if #args == 0 then
            context = Hovered()
            if context then
                local link = context.link
                if context.bag then
                    link = C_Container.GetContainerItemLink(context.bag, context.slot)
                end
                if link then id, suffix = Util.ParseLink(link) end
            end
        else
            Log.Chat(L.protectUsage)
            return
        end
    else
        kind, id, suffix = ParseItemOrType(itemText, true)
        if kind ~= "item" then id = nil end
    end
    if not id then
        if itemText ~= "" and #args > 0 then Log.Chat(L.protectUsage)
        else Log.Chat(L.detailNoHover) end
        return
    end
    if not ValidateItem(id) then Log.Chat(string.format(L.itemNotExist, id)); return end
    if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
    local result, reason
    if global then result, reason = Sets.ToggleProtectGlobal(id, suffix)
    else result, reason = Sets.ToggleProtect(Roster.HereKey(), id, suffix) end
    if reason == "everyroll" then
        Log.Chat(string.format(L.everyRoll,
            id, global and L.globalArgumentPrefix or "", id))
    else
        local subject = global and L.protectGlobalName or Roster.DisplayName(Roster.HereKey())
        local instance = suffix and suffix ~= 0 and (id .. ":" .. suffix) or tostring(id)
        if result == "added" then
            Log.Chat(string.format(L.protectAdded, subject, instance))
        elseif result == "removed" then
            Log.Chat(string.format(L.protectRemoved, subject, instance))
        else
            Log.Chat(L.protectUnchanged)
        end
    end
end

local pendingReset

local function ReplaceTable(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = value end
end

local function ResetApply(target)
    local data = DB.Data()
    local defaults = DB.NewDefaults()
    if target.kind == "settings" then
        local firstRunDone = data.ui.firstRunDone
        ReplaceTable(data.settings, defaults.settings)
        ReplaceTable(data.ui, defaults.ui)
        data.ui.firstRunDone = firstRunDone
        ns.Generations.Bump("settings")
    elseif target.kind == "character" then
        local entry = data.characters[target.key]
        local className
        if Roster.IsHere(target.key) then
            className = UnitClass("player")
        else
            local maleNames = _G.LOCALIZED_CLASS_NAMES_MALE
            local femaleNames = _G.LOCALIZED_CLASS_NAMES_FEMALE
            className = (maleNames and maleNames[entry.class])
                or (femaleNames and femaleNames[entry.class])
        end
        entry.loadouts = { Loadouts.NewDefault(entry.class, className) }
        entry.asks = { types = {}, items = {} }
        entry.protect = {}
        entry.receivesGear = nil
        ns.Generations.Bump("loadouts")
        ns.Generations.Bump("asks")
        ns.Generations.Bump("roster")
    else
        local firstRunDone = data.ui.firstRunDone
        ReplaceTable(data, defaults)
        data.ui.firstRunDone = firstRunDone
        Roster.RegisterNow()
        local key = Roster.HereKey()
        local entry = key and data.characters[key]
        if entry then
            local className = UnitClass("player")
            entry.loadouts = { Loadouts.NewDefault(entry.class, className) }
        end
        Log.Guard("events", Snapshot.TakeAll)
        if Snapshot.IsBankOpen() then Log.Guard("events", Snapshot.TakeBank) end
        Log.Guard("events", Sets.RefreshEquipmentSets, true)
        Log.Guard("events", Sets.RefreshOutfitter)
        for _, generation in ipairs({
            "asks", "gearHere", "gearOthers", "loadouts", "prices", "settings",
        }) do
            ns.Generations.Bump(generation)
        end
    end
    Cache.Clear()
    Classify.Pass("bags")
    if Snapshot.IsBankOpen() then Classify.Pass("bank") end
    Tooltip.RefreshShown()
end

local function RunReset(rest)
    local args, quoted = Tokens(rest)
    if not args then Log.Chat(L.resetUsage); return end
    if DB.IsReadOnly() then Log.Chat(L.debugReadOnly); return end
    if #args == 1 and string.lower(args[1]) == "confirm" and not quoted[1] then
        if not pendingReset or GetTime() - pendingReset.at > 30 then
            pendingReset = nil
            Log.Chat(L.resetNothing)
            return
        end
        local target = pendingReset.target
        pendingReset = nil
        ResetApply(target)
        Log.Chat(L.resetDone)
        return
    end
    local target
    if #args == 0 then
        target = { kind = "settings" }
    elseif #args == 1 and string.lower(args[1]) == "all" and not quoted[1] then
        target = { kind = "all" }
    else
        local key, count, matches = ResolveName(args)
        if key and count ~= #args then
            Log.Chat(L.resetUsage)
            return
        end
        if not key then
            Log.Chat(NameError(args, count, matches))
            return
        end
        target = { kind = "character", key = key }
        local entry = Roster.Entry(key)
        if not Loadouts.AssumedSpec(entry.class) and not Roster.IsHere(key) then
            local maleNames = _G.LOCALIZED_CLASS_NAMES_MALE
            local femaleNames = _G.LOCALIZED_CLASS_NAMES_FEMALE
            if not (maleNames and maleNames[entry.class])
                and not (femaleNames and femaleNames[entry.class])
            then
                Log.Chat(L.resetClassNameMissing)
                return
            end
        end
    end
    pendingReset = { target = target, at = GetTime() }
    if target.kind == "settings" then
        Log.Chat(L.resetPreviewSettings)
    elseif target.kind == "character" then
        Log.Chat(string.format(L.resetPreviewCharacter, Roster.DisplayName(target.key)))
    else
        Log.Chat(L.resetPreviewAll)
    end
end

--- Runs the command typed after /ll. The command word is case-insensitive;
--- words after "probe" are ignored (spec 13, errors rule 2).
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
    if word == "help" or not word then
        RunHelp(rest or "")
        return
    end
    if word == "perf" then
        RunPerf(rest)
        return
    end
    if word == "refresh" then
        RunRefresh(rest)
        return
    end
    if word == "want" then RunWant(rest); return end
    if word == "order" then RunOrder(rest); return end
    if word == "gear" then RunGear(rest); return end
    if word == "loadout" then RunLoadout(rest); return end
    if word == "protect" then RunProtect(rest); return end
    if word == "reset" then RunReset(rest); return end
    local near = UniqueNearMatch(word, {
        "why", "protect", "loadout", "order", "want", "gear", "help", "refresh",
        "probe", "perf", "debug", "reset",
    })
    if near then
        Log.Chat(string.format(L.slashUnknownSuggested, word, near))
    else
        Log.Chat(string.format(L.slashUnknown, word))
    end
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
