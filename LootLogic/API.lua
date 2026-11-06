--[[
The public classification API and result palette (spec 12.4, technical
findings 14 and docs/ux.md 7).
]]

local _, ns = ...

local API = {}
ns.API = API

local Classify = ns.Classify
local DB = ns.DB
local Generations = ns.Generations
local Detail = ns.Detail
local L = ns.L
local Log = ns.Log
local Roster = ns.Roster

local WHITE = { r = 1, g = 1, b = 1 }
local UNKNOWN_ICON_PATH = "Interface\\Icons\\INV_Misc_QuestionMark"

local ICONS = {
    equip = "Interface\\Icons\\INV_Sword_04",
    ah = "Interface\\Icons\\INV_Misc_Coin_01",
    vendor = "Interface\\Icons\\INV_Misc_Coin_02",
    vendorah = UNKNOWN_ICON_PATH,
    stays = UNKNOWN_ICON_PATH,
}

local COLORS = {
    default = {
        equip = GREEN_FONT_COLOR,
        ah = GOLD_FONT_COLOR,
        vendor = GRAY_FONT_COLOR,
        vendorah = ORANGE_FONT_COLOR,
    },
    colorblind = {
        equip = BLUE_FONT_COLOR,
        ah = YELLOW_FONT_COLOR,
        vendor = GRAY_FONT_COLOR,
        vendorah = MAGENTA_FONT_COLOR,
    },
}

local LABELS = {
    equip = "categoryEquip",
    ah = "categoryAH",
    vendor = "categoryVendor",
    vendorah = "categoryVendorAH",
    stays = "categoryStays",
}

local SHORT = {
    equip = "E",
    ah = "A",
    vendor = "V",
    vendorah = "?",
    stays = "",
}

local callbacks = {}
local pendingName
local scheduled = false

local function CopyColor(source, fallback)
    if source then
        return { r = source.r, g = source.g, b = source.b }
    end
    return { r = fallback.r, g = fallback.g, b = fallback.b }
end

local function Palette()
    local choice = DB.Data().settings.display.palette
    local colorblind = choice == "colorblind"
    if choice == "auto" and GetCVarBool then
        colorblind = GetCVarBool("colorblindMode")
    end
    if colorblind then
        return COLORS.colorblind
    end
    return COLORS.default
end

local function Category(category)
    local key = string.match(category, "^char:(.+)$")
    if key then
        return Roster.DisplayName(key) or key, "character", key
    end
    if category == "none" then
        return L[LABELS.stays], "stays"
    end
    return L[LABELS[category]], category
end

local function ClassColor(key)
    local entry = Roster.Entry(key)
    local color = entry and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    return CopyColor(color, WHITE)
end

local function Icon(category, key)
    if key then
        local entry = Roster.Entry(key)
        local class = entry and entry.class
        if class and GetFileIDFromPath then
            local classPath = "Interface\\Icons\\ClassIcon_" .. class
            local classIcon = GetFileIDFromPath(classPath)
            if classIcon then
                return classIcon
            end
        end
    end
    local path = ICONS[category] or UNKNOWN_ICON_PATH
    if GetFileIDFromPath then
        return GetFileIDFromPath(path) or GetFileIDFromPath(UNKNOWN_ICON_PATH) or 134400
    end
    return 134400
end

local function Color(category, reasonCode, key)
    if reasonCode == "error" then
        return CopyColor(RED_FONT_COLOR, WHITE)
    end
    if reasonCode == "nobody" then
        return CopyColor(GRAY_FONT_COLOR, WHITE)
    end
    if key then
        return ClassColor(key)
    end
    if category == "none" then
        return CopyColor(NORMAL_FONT_COLOR, WHITE)
    end
    return CopyColor(Palette()[category], WHITE)
end

local function Characters(text)
    local characters = {}
    text = string.gsub(text, "%s+", "")
    for character in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        characters[#characters + 1] = character
    end
    return characters
end

local function CharacterShorts()
    local names = {}
    local groups = {}
    for _, key in ipairs(Roster.EligibleKeys()) do
        local label = Roster.DisplayName(key) or key
        local chars = Characters(label)
        names[key] = { label = label, chars = chars }
        local initial = string.lower(chars[1] or "")
        groups[initial] = groups[initial] or {}
        groups[initial][#groups[initial] + 1] = key
    end
    local shorts = {}
    for _, keys in pairs(groups) do
        for _, key in ipairs(keys) do
            local own = names[key].chars
            local short = own[1] or ""
            if #keys > 1 then
                local position
                for candidate = 2, #own do
                    local differs = true
                    for _, otherKey in ipairs(keys) do
                        if otherKey ~= key then
                            local other = names[otherKey].chars
                            if
                                string.lower(own[candidate]) == string.lower(other[candidate] or "")
                            then
                                differs = false
                                break
                            end
                        end
                    end
                    if differs then
                        position = candidate
                        break
                    end
                end
                short = short .. (own[position or 2] or own[1] or "")
            end
            shorts[key] = short
        end
    end
    return shorts
end

local function Short(category, key)
    if key then
        return CharacterShorts()[key] or ""
    end
    return SHORT[category] or SHORT.stays
end

local function Line(label, result)
    local text
    if result.reasonCode == "nobody" or result.reasonCode == "error" then
        text = result.reasonText
    elseif result.category == "none" then
        text = label .. " (" .. result.reasonText .. ")"
    else
        text = label .. " (" .. result.reasonText .. ")"
    end
    return L.chatPrefix .. " " .. text
end

local function Decorate(result)
    if not result then
        return nil
    end
    local label, category, key = Category(result.category)
    result.label = label
    result.color = Color(result.category, result.reasonCode, key)
    result.icon = Icon(category, key)
    result.short = Short(category, key, label)
    result.line = Line(label, result)
    return result
end

--- Classifies one bag slot and decorates its result for display.
-- @param bag number
-- @param slot number
-- @treturn table|nil result, nil while pending, empty or a closed bank
function API.ClassifyBagSlot(bag, slot)
    local result = Decorate(Classify.BagSlot(bag, slot))
    if result and result.reasonCode ~= "error" then
        Log.Guard("engine", Detail.Attach, result, { bag = bag, slot = slot })
    end
    return result
end

--- Classifies a hyperlink without a bag slot and decorates its result.
-- @param link string
-- @param fromInbox boolean|nil true for an inbox attachment
-- @treturn table|nil result, nil while pending or when the link has no item
function API.ClassifyLink(link, fromInbox)
    local mail
    if fromInbox then
        mail = "inbox"
    end
    local result = Decorate(Classify.Link(link, mail))
    if result and result.reasonCode ~= "error" then
        Log.Guard("engine", Detail.Attach, result, { link = link, fromInbox = fromInbox == true })
    end
    return result
end

--- The active category rows in display order. The Contents totals are added
--- with the M2 consumer.
-- @treturn table list of category rows
function API.GetActiveCategories()
    local rows = {}
    for _, key in ipairs(Roster.EligibleKeys()) do
        local label = Roster.DisplayName(key) or key
        rows[#rows + 1] = {
            id = "char:" .. key,
            label = label,
            color = ClassColor(key),
            icon = Icon("character", key),
        }
    end
    local palette = Palette()
    for _, category in ipairs({ "ah", "vendor", "vendorah", "equip" }) do
        rows[#rows + 1] = {
            id = category,
            label = L[LABELS[category]],
            color = CopyColor(palette[category], WHITE),
            icon = Icon(category),
        }
    end
    rows[#rows + 1] = {
        id = "none",
        label = L.categoryNoCategory,
        color = CopyColor(NORMAL_FONT_COLOR, WHITE),
        icon = Icon("stays"),
    }
    return rows
end

--- The number of generation bumps since this session began.
-- @treturn number
function API.GetGeneration()
    return Generations.Total()
end

--- Registers a listener for classification-affecting changes.
-- @param event string currently "CHANGED"
-- @param fn function called with (generation, firstNameThisFrame)
function API.RegisterCallback(event, fn)
    if event ~= "CHANGED" then
        return
    end
    callbacks[#callbacks + 1] = fn
end

Generations.OnBump(function(name)
    if not pendingName then
        pendingName = name
    end
    if scheduled then
        return
    end
    scheduled = true
    C_Timer.After(0, function()
        local generation = Generations.Total()
        local changedName = pendingName
        pendingName = nil
        scheduled = false
        for index = 1, #callbacks do
            Log.Guard("events", callbacks[index], generation, changedName)
        end
    end)
end)
