--[[
The single category line on an item tooltip (spec 13, technical findings
12.2, and live checks L11 and L60).
]]

local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local API = ns.API
local DB = ns.DB
local Events = ns.Events
local Util = ns.Util

local itemRefTooltipHooked = false
local itemRefHyperlinkHooked = false
local itemRefClickHooked = false

local function IsUsableLink(link)
    return type(link) == "string" and link ~= "" and Util.ParseLink(link) ~= nil
end

local function IsCharacterEquipment(tooltip, info)
    if info and info.getterName == "GetInventoryItem" then
        return true
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

local function Classify(info)
    local getterName = info.getterName
    local args = info.getterArgs or {}
    if getterName == "GetBagItem" then
        if type(args[1]) == "number" and type(args[2]) == "number" then
            return API.ClassifyBagSlot(args[1], args[2]), true
        end
        if IsUsableLink(info.hyperlink) then
            return API.ClassifyLink(info.hyperlink), true
        end
        return nil, false
    end
    if getterName == "GetInboxItem" then
        local link = info.hyperlink
        if not IsUsableLink(link) and type(args[1]) == "number" and type(args[2]) == "number" then
            link = GetInboxItemLink(args[1], args[2])
        end
        if IsUsableLink(link) then
            return API.ClassifyLink(link, true), true
        end
        return nil, false
    end
    local link = info.hyperlink
    if not IsUsableLink(link) and type(args[1]) == "string" then
        link = args[1]
    end
    if IsUsableLink(link) then
        return API.ClassifyLink(link), true
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

local function AddLine(tooltip, info)
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
    local result, hasInput
    if info then
        result, hasInput = Classify(info)
    end
    if not result and not hasInput then
        local link = ItemLink(tooltip)
        if link then
            result = API.ClassifyLink(link, info and info.getterName == "GetInboxItem")
        end
    end
    if not result then
        return
    end
    if result.reasonCode == "nobody" and not display.tooltipNoWant then
        return
    end
    if HasLine(tooltip, result.line) then
        return
    end
    local color = result.color
    tooltip:AddLine(result.line, color.r, color.g, color.b)
    tooltip:Show()
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    local info = tooltip:GetPrimaryTooltipInfo()
    AddLine(tooltip, info)
end)

-- Forever's ItemRefTooltip does not run TooltipDataProcessor post-calls when
-- a chat link opens it (live check L60). The global SetItemRef hook showed the
-- line in the live test; retry registration as client frames become available.
local function HookItemRefTooltip()
    local itemRefTooltip = _G.ItemRefTooltip
    local function AddItemRefLine(tooltip, link)
        if not IsUsableLink(link) then
            link = ItemLink(tooltip)
        end
        if IsUsableLink(link) then
            AddLine(tooltip, {
                getterName = "SetHyperlink",
                getterArgs = { link },
                hyperlink = link,
            })
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
            if tooltip and type(tooltip.IsShown) == "function" and tooltip:IsShown() then
                AddItemRefLine(tooltip, link)
            end
        end)
        itemRefClickHooked = ok
    end
end

HookItemRefTooltip()
Events.Register("ADDON_LOADED", HookItemRefTooltip)
Events.Register("PLAYER_LOGIN", HookItemRefTooltip)
