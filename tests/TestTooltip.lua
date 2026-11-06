local _, ns, h = ...

local API = ns.API

local HERE = "Local Test-Realm"
local OTHER = "Alt Test-Realm"
local nextID = 105000

local function Boot()
    LootLogicDB = nil
    h.Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = "WARRIOR",
        level = 60,
    })
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    local here = LootLogicDB.characters[HERE]
    LootLogicDB.characters[OTHER] = {
        first = "Alt",
        last = "Test",
        class = "PRIEST",
        level = 60,
        faction = here.faction,
        region = here.region,
        loadouts = {},
        asks = { types = {}, items = {} },
    }
    LootLogicDB.order = { OTHER, HERE }
    return here
end

local function Define(fields)
    nextID = nextID + 1
    local item = {
        itemID = nextID,
        name = "Tooltip Item",
        quality = 1,
        itemLevel = 1,
        reqLevel = 0,
        sellPrice = 0,
        bindType = 0,
        classID = 7,
        subclassID = 5,
    }
    for key, value in pairs(fields or {}) do
        item[key] = value
    end
    item.link = "item:" .. item.itemID
    h.Stub.SetItem(item.itemID, item)
    h.Stub.SetTooltipLines(item.link, {})
    return item
end

local function Include(item)
    LootLogicDB.characters[OTHER].asks.items[item.itemID] = "include"
end

local function Tooltip(name, info, owner, itemLink)
    local tooltip = h.Stub.MakeTooltip(name, info, owner, itemLink)
    h.Stub.FireTooltip(tooltip)
    return tooltip
end

local function Bag(item)
    h.Stub.SetBagSize(0, 10)
    h.Stub.SetBagItem(0, 1, {
        itemID = item.itemID,
        link = item.link,
        count = 1,
        quality = item.quality,
    })
end

return {
    ["chat link hooks retry and add only one line when the item script fails"] = function()
        Boot()
        local item = Define()
        Include(item)
        local popup = h.Stub.MakeTooltip("ItemRefTooltip", nil, nil, item.link)
        popup.shown = true
        popup.HookScript = function()
            error("unsupported item script")
        end
        popup.IsShown = function(self)
            return self.shown
        end
        popup.NumLines = function(self)
            return #self.lines
        end
        popup.SetHyperlink = function(self, link)
            self.itemLink = link
        end
        local addLine = popup.AddLine
        popup.AddLine = function(self, text, red, green, blue)
            addLine(self, text, red, green, blue)
            _G["ItemRefTooltipTextLeft" .. #self.lines] = { GetText = function() return text end }
        end
        _G.ItemRefTooltip = popup
        _G.SetItemRef = function(link)
            popup.itemLink = link
        end

        h.Stub.FireEvent("ADDON_LOADED", "OtherAddon")
        h.Stub.FireEvent("PLAYER_LOGIN")
        popup:SetHyperlink(item.link)
        h.Equal(#popup.lines, 1, "hyperlink hook works when item script fails")
        popup.lines = {}
        _G.SetItemRef(item.link)
        h.Equal(#popup.lines, 1, "click hook adds a line")
        h.Equal(
            popup.lines[1].text,
            "LootLogic: Alt (wants Tooltip Item; not in your bags)",
            "popup result"
        )
        popup:SetHyperlink(item.link)
        _G.SetItemRef(item.link)
        h.Equal(#popup.lines, 1, "repeated notifications do not duplicate the line")
    end,

    ["bag getter adds one result line"] = function()
        Boot()
        local item = Define()
        Bag(item)
        Include(item)

        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetBagItem",
            getterArgs = { 0, 1 },
        })

        h.Equal(#tooltip.lines, 1, "one line")
        h.Equal(tooltip.lines[1].text, "LootLogic: Alt (wants Tooltip Item)", "line")
        h.Equal(tooltip.shown, true, "shown")
    end,

    ["bag getter falls back to a link when its slot arguments are malformed"] = function()
        Boot()
        local item = Define()
        Include(item)
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetBagItem",
            getterArgs = { "bad" },
        }, nil, item.link)

        h.Equal(#tooltip.lines, 1, "fallback line")
        h.True(
            string.find(tooltip.lines[1].text, "; not in your bags", 1, true) ~= nil,
            "link-only reason"
        )
    end,

    ["hyperlink getter uses link classification and not a bag slot"] = function()
        Boot()
        local item = Define()
        Include(item)
        local bagCalls = 0
        local oldBagSlot = API.ClassifyBagSlot
        API.ClassifyBagSlot = function(...)
            bagCalls = bagCalls + 1
            return oldBagSlot(...)
        end

        local tooltip = Tooltip("GameTooltip", {
            getterName = "SetHyperlink",
            getterArgs = { item.link },
        })
        API.ClassifyBagSlot = oldBagSlot

        h.Equal(bagCalls, 0, "no bag classification")
        h.Equal(#tooltip.lines, 1, "one link line")
        local notInBags = string.find(tooltip.lines[1].text, "; not in your bags", 1, true)
        h.True(notInBags ~= nil, "link text")
    end,

    ["pending item data adds no line"] = function()
        Boot()
        local item = Define()
        h.Stub.SetItemPending(item.itemID, item)
        local originalLink = API.ClassifyLink
        local linkCalls = 0
        API.ClassifyLink = function(...)
            linkCalls = linkCalls + 1
            return originalLink(...)
        end

        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
            hyperlink = item.link,
        }, nil, item.link)
        API.ClassifyLink = originalLink

        h.Equal(#tooltip.lines, 0, "pending line count")
        h.Equal(linkCalls, 1, "valid pending link does not try fallback")
    end,

    ["pending valid bag slot does not fall back to a link"] = function()
        Boot()
        local item = Define()
        Bag(item)
        h.Stub.SetItemPending(item.itemID, item)
        local originalLink = API.ClassifyLink
        local linkCalls = 0
        API.ClassifyLink = function(...)
            linkCalls = linkCalls + 1
            return originalLink(...)
        end
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetBagItem",
            getterArgs = { 0, 1 },
        }, nil, item.link)
        API.ClassifyLink = originalLink

        h.Equal(#tooltip.lines, 0, "pending bag has no line")
        h.Equal(linkCalls, 0, "pending bag does not try link fallback")
    end,

    ["malformed primary hyperlink falls back to the tooltip item link"] = function()
        Boot()
        local item = Define()
        Include(item)
        local originalLink = API.ClassifyLink
        local classifiedLink
        API.ClassifyLink = function(link, fromInbox)
            classifiedLink = link
            return originalLink(link, fromInbox)
        end
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetHyperlink",
            hyperlink = "bad",
        }, nil, item.link)
        API.ClassifyLink = originalLink

        h.Equal(classifiedLink, item.link, "fallback classified the valid link")
        h.Equal(#tooltip.lines, 1, "fallback line")
    end,

    ["malformed inbox hyperlink falls back and keeps the inbox flag"] = function()
        Boot()
        local item = Define()
        local originalLink = API.ClassifyLink
        local fromInbox
        API.ClassifyLink = function(link, inbox)
            fromInbox = inbox
            return originalLink(link, inbox)
        end
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetInboxItem",
            getterArgs = { "bad" },
            hyperlink = "bad",
        }, nil, item.link)
        API.ClassifyLink = originalLink

        h.Equal(fromInbox, true, "inbox flag")
        h.Equal(#tooltip.lines, 1, "fallback line")
    end,

    ["nil primary info falls back to the tooltip item link"] = function()
        Boot()
        local item = Define()
        Include(item)
        local tooltip = Tooltip("GameTooltip", nil, nil, item.link)

        h.Equal(#tooltip.lines, 1, "link fallback line")
        h.True(
            string.find(tooltip.lines[1].text, "; not in your bags", 1, true) ~= nil,
            "link-only result"
        )
    end,

    ["primary info without a usable link falls back to the tooltip item link"] = function()
        Boot()
        local item = Define()
        Include(item)
        local tooltip = Tooltip("GameTooltip", { getterName = "UnknownGetter" }, nil, item.link)

        h.Equal(#tooltip.lines, 1, "link fallback line")
        h.True(
            string.find(tooltip.lines[1].text, "; not in your bags", 1, true) ~= nil,
            "link-only result"
        )
    end,

    ["inbox getter classifies the attachment as inbox mail"] = function()
        Boot()
        local item = Define()
        Include(item)
        h.Stub.SetInbox({ { items = { { link = item.link, count = 1 } } } })

        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetInboxItem",
            getterArgs = { 1, 1 },
        })

        h.Equal(#tooltip.lines, 1, "inbox line")
        local line = tooltip.lines[1].text
        h.True(string.find(line, "LootLogic: Alt", 1, true) == 1, "inbox verdict")
    end,

    ["inbox getter falls back to its hyperlink and keeps inbox classification"] = function()
        Boot()
        local item = Define()
        local originalLink = API.ClassifyLink
        local fromInbox
        API.ClassifyLink = function(link, inbox)
            fromInbox = inbox
            return originalLink(link, inbox)
        end
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetInboxItem",
            getterArgs = { "bad" },
            hyperlink = item.link,
        })
        API.ClassifyLink = originalLink

        h.Equal(fromInbox, true, "inbox flag")
        h.Equal(#tooltip.lines, 1, "fallback line")
    end,

    ["malformed inbox getter falls back to the tooltip item link"] = function()
        Boot()
        local item = Define()
        local originalLink = API.ClassifyLink
        local fromInbox
        API.ClassifyLink = function(link, inbox)
            fromInbox = inbox
            return originalLink(link, inbox)
        end
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetInboxItem",
            getterArgs = { "bad" },
        }, nil, item.link)
        API.ClassifyLink = originalLink

        h.Equal(fromInbox, true, "inbox flag")
        h.Equal(#tooltip.lines, 1, "fallback line")
    end,

    ["unknown item tooltip frames use the L60 fallback"] = function()
        Boot()
        local item = Define()
        Include(item)
        local tooltip = Tooltip("UnknownItemTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
        })

        h.Equal(#tooltip.lines, 1, "unknown tooltip line")
    end,

    ["Auctionator-priced unwanted bag items get one AH line"] = function()
        Boot()
        local item = Define({ sellPrice = 100 })
        Bag(item)
        h.Stub.SetAuctionator(
            h.Stub.MakeAuctionatorV1({ [item.itemID] = 10000 }, { [item.itemID] = 1 })
        )

        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetBagItem",
            getterArgs = { 0, 1 },
        })

        h.Equal(#tooltip.lines, 1, "one AH line")
        h.True(string.find(tooltip.lines[1].text, "LootLogic: AH (", 1, true) == 1, "AH result")
    end,

    ["nobody line defaults on and can be explicitly disabled"] = function()
        Boot()
        local item = Define()
        local info = { getterName = "GetHyperlink", getterArgs = { item.link } }
        local shown = Tooltip("GameTooltip", info)
        LootLogicDB.settings.display.tooltipNoWant = false
        local hidden = Tooltip("GameTooltip", info)

        h.Equal(#shown.lines, 1, "default line is visible")
        h.Equal(#hidden.lines, 0, "explicitly disabled")
        local nobodyLine = "LootLogic: nobody wants this (not in your bags)"
        h.Equal(shown.lines[1].text, nobodyLine, "nobody text")
    end,

    ["equipped and comparison tooltips are excluded"] = function()
        Boot()
        local item = Define()
        Include(item)
        local equipped = Tooltip("GameTooltip", {
            getterName = "GetInventoryItem",
            getterArgs = { "player", 1 },
        })
        local owner = h.Stub.MakeTooltip("PaperDollItemsFrameHeadSlot")
        local characterSlot = Tooltip("GameTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
        }, owner)
        local comparison = Tooltip("ShoppingTooltip1", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
        })
        local infoMissingOnCharacterPane = Tooltip("GameTooltip", nil, owner, item.link)

        h.Equal(#equipped.lines, 0, "equipped item")
        h.Equal(#characterSlot.lines, 0, "character pane owner")
        h.Equal(#infoMissingOnCharacterPane.lines, 0, "character pane with missing info")
        h.Equal(#comparison.lines, 0, "comparison")
    end,

    ["item link popup is included and error line is kept"] = function()
        Boot()
        local item = Define()
        Include(item)
        local popup = Tooltip("ItemRefTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
        })
        local oldLink = API.ClassifyLink
        API.ClassifyLink = function()
            return {
                reasonCode = "error",
                line = "LootLogic: error on an item, see /ll status.",
                color = RED_FONT_COLOR,
            }
        end
        local errorTooltip = Tooltip("GameTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
        })
        API.ClassifyLink = oldLink

        h.Equal(#popup.lines, 1, "popup line")
        local errorLine = "LootLogic: error on an item, see /ll status."
        h.Equal(errorTooltip.lines[1].text, errorLine, "error line")
        h.DeepEqual(errorTooltip.lines[1].color, RED_FONT_COLOR, "error color")
    end,
}
