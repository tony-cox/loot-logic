--[[
The single category line on an item tooltip (spec 13, technical findings
12.2, and live checks L11 and L60).
]]

local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local API = ns.API
local Detail = ns.Detail
local DB = ns.DB
local Events = ns.Events
local L = ns.L
local Util = ns.Util

local itemRefTooltipHooked = false
local itemRefHyperlinkHooked = false
local itemRefClickHooked = false
local tracked = {}
local refreshing = false
local rebuildingContext = {}
local hooked = {}

local function TrackLifecycle(tooltip)
    if hooked[tooltip] or type(tooltip.HookScript) ~= "function" then
        return
    end
    local function ClearTracking()
        if not refreshing then
            tracked[tooltip] = nil
        end
    end
    pcall(tooltip.HookScript, tooltip, "OnHide", ClearTracking)
    pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", ClearTracking)
    hooked[tooltip] = true
end

local function ShiftDown()
    return type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
end

local function IsUsableLink(link)
    return type(link) == "string" and link ~= "" and Util.ParseLink(link) ~= nil
end

local function IsCharacterEquipment(tooltip, info)
    if info and info.getterName == "GetInventoryItem" then
        local unit = info.getterArgs and info.getterArgs[1]
        if type(unit) ~= "string" or unit == "" or unit == "player" then
            return true
        end
    end
    local owner = tooltip:GetOwner()
    local name = owner and owner.GetName and owner:GetName()
    if not name or string.match(name, "Slot$") == nil then
        return false
    end
    return string.match(name, "^Character") ~= nil
        or string.match(name, "^PaperDollItemsFrame") ~= nil
end

local function IsComparison(tooltip)
    local name = tooltip:GetName()
    return name == "ShoppingTooltip1" or name == "ShoppingTooltip2"
end

local function Classify(info, fromInbox)
    local getterName = info.getterName
    local args = info.getterArgs or {}
    if getterName == "GetBagItem" then
        if type(args[1]) == "number" and type(args[2]) == "number" then
            return API.ClassifyBagSlot(args[1], args[2]), true, nil, true
        end
        if IsUsableLink(info.hyperlink) then
            return API.ClassifyLink(info.hyperlink), true, info.hyperlink
        end
        return nil, false
    end
    if getterName == "GetInboxItem" then
        local link = info.hyperlink
        local validArgs = type(args[1]) == "number" and type(args[2]) == "number"
        if not IsUsableLink(link) and validArgs then
            link = GetInboxItemLink(args[1], args[2])
        end
        if IsUsableLink(link) then
            return API.ClassifyLink(link, true), true, link, validArgs
        end
        return nil, false
    end
    local link = info.hyperlink
    if not IsUsableLink(link) and type(args[1]) == "string" then
        link = args[1]
    end
    if IsUsableLink(link) then
        return API.ClassifyLink(link, fromInbox), true, link
    end
    return nil, false
end

local function ItemLink(tooltip)
    if type(tooltip.GetItem) ~= "function" then
        return nil
    end
    -- Unverified API guess (L11): Tooltip:GetItem returns name, then link.
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if ok and type(link) == "string" and link ~= "" then
        return link
    end
end

local function HasLine(tooltip, text)
    local name = tooltip:GetName()
    if not name or type(tooltip.NumLines) ~= "function" then
        return false
    end
    for index = 1, tooltip:NumLines() do
        local left = _G[name .. "TextLeft" .. index]
        if left and type(left.GetText) == "function" and left:GetText() == text then
            return true
        end
    end
    return false
end

local function AddLine(tooltip, info, bagResult, matchesBag, savedContext)
    if IsComparison(tooltip) then
        return
    end
    if IsCharacterEquipment(tooltip, info) then
        return
    end
    local display = DB.Data().settings.display
    if not display.tooltip then
        return
    end
    local result, hasInput, classificationLink = bagResult, matchesBag, nil
    if info and not matchesBag then
        local getterUsed
        result, hasInput, classificationLink, getterUsed =
            Classify(info, savedContext and savedContext.fromInbox)
        if getterUsed then
            savedContext = {
                getterName = info.getterName,
                getterArgs = info.getterArgs,
                fromInbox = info.getterName == "GetInboxItem",
            }
        end
    end
    if not result and not hasInput then
        local link = ItemLink(tooltip)
        if IsUsableLink(link) then
            result = API.ClassifyLink(
                link,
                (savedContext and savedContext.fromInbox)
                    or (info and info.getterName == "GetInboxItem")
            )
            classificationLink = link
        end
    end
    if not result then
        return
    end
    if result.reasonCode == "nobody" and not display.tooltipNoWant then
        return
    end
    if info or savedContext or classificationLink then
        TrackLifecycle(tooltip)
        tracked[tooltip] = {
            info = info,
            bagResult = bagResult,
            matchesBag = matchesBag,
            context = savedContext
                or {
                    info = info,
                    getterName = info
                        and info.getterName
                        and (
                            (info.getterName ~= "GetBagItem" and info.getterName ~= "GetInboxItem")
                            or (savedContext and savedContext.getterName)
                        ),
                    getterArgs = info and info.getterArgs,
                    link = classificationLink,
                    fromInbox = info and info.getterName == "GetInboxItem",
                },
        }
    end
    local line = result.line .. (matchesBag and L.tooltipMatchesBag or "")
    if HasLine(tooltip, line) then
        return
    end
    local color = result.color
    tooltip:AddLine(line, color.r, color.g, color.b)
    if ShiftDown() then
        local detailLines = Detail.Lines(result)
        for index = 2, #detailLines do
            tooltip:AddLine(detailLines[index], color.r, color.g, color.b)
        end
    end
    tooltip:Show()
end

local function MatchingBagSlot(link)
    local key = Util.InstanceKey(link)
    if not key then
        return nil
    end
    for bag = 0, 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local bagLink = C_Container.GetContainerItemLink(bag, slot)
            if bagLink and Util.InstanceKey(bagLink) == key then
                return bag, slot
            end
        end
    end
end

local function AddItemRefLine(tooltip, link)
    tracked[tooltip] = nil
    if not IsUsableLink(link) then
        link = ItemLink(tooltip)
    end
    if IsUsableLink(link) then
        local bag, slot = MatchingBagSlot(link)
        if bag then
            AddLine(
                tooltip,
                nil,
                API.ClassifyBagSlot(bag, slot),
                true,
                { bag = bag, slot = slot, link = link }
            )
        else
            AddLine(tooltip, {
                getterName = "SetHyperlink",
                getterArgs = { link },
                hyperlink = link,
            }, nil, false, { link = link })
        end
        return
    end
    local info
    if type(tooltip.GetPrimaryTooltipInfo) == "function" then
        local ok, primaryInfo = pcall(tooltip.GetPrimaryTooltipInfo, tooltip)
        if ok then
            info = primaryInfo
        end
    end
    AddLine(tooltip, info)
end

local function RefreshShownTooltips(_, key)
    if key and key ~= "LSHIFT" and key ~= "RSHIFT" then
        return
    end
    if refreshing then
        return
    end
    refreshing = true
    for tooltip, state in pairs(tracked) do
        if type(tooltip.IsShown) == "function" and tooltip:IsShown() and state then
            local context = state.context
            local args = context
                    and (context.getterArgs or (context.info and context.info.getterArgs))
                or {}
            local rebuild
            if
                tooltip:GetName() == "ItemRefTooltip"
                and context
                and context.link
                and type(tooltip.SetHyperlink) == "function"
            then
                rebuild = function()
                    tooltip:SetHyperlink(context.link)
                end
            elseif context and context.bag and type(tooltip.SetBagItem) == "function" then
                rebuild = function()
                    tooltip:SetBagItem(context.bag, context.slot)
                end
            elseif
                context
                and context.getterName == "GetInboxItem"
                and type(tooltip.SetInboxItem) == "function"
            then
                -- API guess (L59): setter takes mail and attachment indices.
                rebuild = function()
                    tooltip:SetInboxItem(args[1], args[2])
                end
            elseif
                context
                and context.getterName == "GetBagItem"
                and type(tooltip.SetBagItem) == "function"
            then
                rebuild = function()
                    tooltip:SetBagItem(args[1], args[2])
                end
            elseif context and context.link and type(tooltip.SetHyperlink) == "function" then
                rebuildingContext[tooltip] = context
                rebuild = function()
                    tooltip:SetHyperlink(context.link)
                end
            elseif context and context.hyperlink and type(tooltip.SetHyperlink) == "function" then
                rebuild = function()
                    tooltip:SetHyperlink(context.hyperlink)
                end
            end
            if rebuild then
                if type(tooltip.ClearLines) == "function" then
                    tooltip:ClearLines()
                end
                rebuild()
                rebuildingContext[tooltip] = nil
            end
        else
            tracked[tooltip] = nil
        end
    end
    refreshing = false
end

--- Rebuild the tracked shown tooltip through its existing eligibility guards.
function Tooltip.RefreshShown()
    RefreshShownTooltips(nil)
end

Events.Register("MODIFIER_STATE_CHANGED", RefreshShownTooltips)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    local info = tooltip:GetPrimaryTooltipInfo()
    tracked[tooltip] = nil
    if tooltip:GetName() == "ItemRefTooltip" then
        local link = info and (info.hyperlink or (info.getterArgs or {})[1])
        AddItemRefLine(tooltip, link)
    else
        AddLine(tooltip, info, nil, false, rebuildingContext[tooltip])
    end
end)

-- Forever's ItemRefTooltip does not run TooltipDataProcessor post-calls when
-- a chat link opens it (live check L60). The global SetItemRef hook showed the
-- line in the live test; retry registration as client frames become available.
local function HookItemRefTooltip()
    local itemRefTooltip = _G.ItemRefTooltip

    if
        not itemRefTooltipHooked
        and itemRefTooltip
        and type(itemRefTooltip.HookScript) == "function"
    then
        local ok = pcall(
            itemRefTooltip.HookScript,
            itemRefTooltip,
            "OnTooltipSetItem",
            function(tooltip)
                AddItemRefLine(tooltip, nil)
            end
        )
        itemRefTooltipHooked = ok
    end

    if
        not itemRefHyperlinkHooked
        and itemRefTooltip
        and type(hooksecurefunc) == "function"
        and type(itemRefTooltip.SetHyperlink) == "function"
    then
        local ok = pcall(hooksecurefunc, itemRefTooltip, "SetHyperlink", function(tooltip, link)
            AddItemRefLine(tooltip, link)
        end)
        itemRefHyperlinkHooked = ok
    end

    if
        not itemRefClickHooked
        and type(hooksecurefunc) == "function"
        and type(_G.SetItemRef) == "function"
    then
        local ok = pcall(hooksecurefunc, "SetItemRef", function(link)
            local tooltip = _G.ItemRefTooltip
            if
                IsUsableLink(link)
                and tooltip
                and type(tooltip.IsShown) == "function"
                and tooltip:IsShown()
            then
                local displayedLink = ItemLink(tooltip)
                local modified
                if type(_G.IsModifiedClick) == "function" then
                    local ok, result = pcall(_G.IsModifiedClick)
                    if ok and type(result) == "boolean" then
                        modified = result
                    end
                end
                if modified then
                    return
                end
                if IsUsableLink(displayedLink) then
                    local displayedItem = string.match(displayedLink, "item:([%-%d:]*)")
                    local clickedItem = string.match(link, "item:([%-%d:]*)")
                    displayedItem = string.gsub(displayedItem, ":+$", "")
                    clickedItem = string.gsub(clickedItem, ":+$", "")
                    if displayedItem ~= clickedItem then
                        return
                    end
                elseif modified ~= false then
                    return
                end
                AddItemRefLine(tooltip, link)
            end
        end)
        itemRefClickHooked = ok
    end
end

HookItemRefTooltip()
Events.Register("ADDON_LOADED", HookItemRefTooltip)
Events.Register("PLAYER_LOGIN", HookItemRefTooltip)
