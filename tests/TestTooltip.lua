local _, ns, h = ...

local API = ns.API
local Detail = ns.Detail

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
            _G["ItemRefTooltipTextLeft" .. #self.lines] = {
                GetText = function()
                    return text
                end,
            }
        end
        _G.ItemRefTooltip = popup
        _G.IsModifiedClick = function()
            return false
        end
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

    ["click hook checks the displayed item and falls back without its link"] = function()
        Boot()
        local displayed = Define()
        local clicked = Define()
        Include(clicked)
        local popup = h.Stub.MakeTooltip("ItemRefTooltip", nil, nil, displayed.link)
        popup.shown = true
        popup.IsShown = function(self)
            return self.shown
        end
        _G.ItemRefTooltip = popup
        local modified = false
        _G.IsModifiedClick = function()
            return modified
        end
        _G.SetItemRef = function() end
        h.Stub.FireEvent("PLAYER_LOGIN")

        _G.SetItemRef(clicked.link)
        h.Equal(#popup.lines, 0, "different displayed item stays unchanged")
        popup.itemLink = nil
        modified = true
        _G.SetItemRef(clicked.link)
        h.Equal(#popup.lines, 0, "modified click without displayed link is ignored")
        modified = false
        _G.SetItemRef(clicked.link)
        h.Equal(#popup.lines, 1, "clicked link fallback")
        popup.lines = {}
        _G.IsModifiedClick = nil
        _G.SetItemRef(clicked.link)
        h.Equal(#popup.lines, 0, "unknown modifier state does not use fallback")
        popup.itemLink = clicked.link .. ":"
        _G.SetItemRef(clicked.link)
        h.Equal(#popup.lines, 1, "equivalent item fields match")
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

    ["Shift adds and removes shared detail on the stationary bag tooltip"] = function()
        Boot()
        local item = Define()
        Bag(item)
        Include(item)
        h.Stub.SetShiftDown(false)
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetBagItem",
            getterArgs = { 0, 1 },
        })
        h.Equal(#tooltip.lines, 1, "category before Shift")
        h.Stub.SetShiftDown(true)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        local result = API.ClassifyBagSlot(0, 1)
        local expected = Detail.Lines(result)
        h.Equal(#tooltip.lines, #expected, "all shared detail lines shown")
        h.Equal(tooltip.lines[2].text, expected[2], "same wants line")
        h.Stub.SetShiftDown(false)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
        h.Equal(#tooltip.lines, 1, "release rebuilds category only")
    end,

    ["Shift refresh retains the classified link for incomplete tooltip payloads"] = function()
        Boot()
        local item = Define()
        Include(item)
        h.Stub.SetShiftDown(false)
        local tooltips = {
            Tooltip("GameTooltip", {
                getterName = "GetHyperlink",
                getterArgs = { item.link },
            }),
            Tooltip("GameTooltip", nil, nil, item.link),
            Tooltip("GameTooltip", {
                getterName = "GetHyperlink",
                getterArgs = { "invalid" },
                hyperlink = "invalid",
            }, nil, item.link),
        }
        h.Stub.SetShiftDown(true)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        for _, tooltip in ipairs(tooltips) do
            h.True(#tooltip.lines > 1, "detail appears for the classified link")
            h.True(
                tooltip.info and tooltip.info.getterArgs[1] == item.link,
                "refresh uses the resolved link"
            )
        end
        h.Stub.SetShiftDown(false)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
        for _, tooltip in ipairs(tooltips) do
            h.Equal(#tooltip.lines, 1, "detail clears after Shift release")
        end
    end,

    ["Shift refresh uses valid link fallbacks for malformed bag and inbox getters"] = function()
        Boot()
        local item = Define()
        Include(item)
        local originalClassifyLink = API.ClassifyLink
        local cases = {
            {
                getterName = "GetBagItem",
                getterArgs = { "bad" },
                hyperlink = item.link,
            },
            {
                getterName = "GetBagItem",
                getterArgs = {},
            },
            {
                getterName = "GetInboxItem",
                getterArgs = { "bad" },
                hyperlink = "bad",
            },
            {
                getterName = "GetInboxItem",
                getterArgs = {},
                hyperlink = item.link,
            },
        }
        h.Stub.SetShiftDown(false)
        for _, info in ipairs(cases) do
            local tooltip = h.Stub.MakeTooltip("GameTooltip", info, nil, item.link)
            local badBagCalls, badInboxCalls, inboxSeen = 0, 0, false
            local setBagItem, setInboxItem = tooltip.SetBagItem, tooltip.SetInboxItem
            tooltip.SetBagItem = function(self, ...)
                badBagCalls = badBagCalls + 1
                return setBagItem(self, ...)
            end
            tooltip.SetInboxItem = function(self, ...)
                badInboxCalls = badInboxCalls + 1
                return setInboxItem(self, ...)
            end
            local classifyLink = API.ClassifyLink
            API.ClassifyLink = function(link, fromInbox)
                inboxSeen = inboxSeen or fromInbox == true
                return classifyLink(link, fromInbox)
            end
            h.Stub.FireTooltip(tooltip)
            h.Stub.SetShiftDown(true)
            h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
            h.True(#tooltip.lines > 1, "Shift adds detail from the fallback link")
            h.Stub.SetShiftDown(false)
            h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
            API.ClassifyLink = classifyLink
            h.Equal(badBagCalls, 0, "malformed bag getter is not reused")
            h.Equal(badInboxCalls, 0, "malformed inbox getter is not reused")
            if info.getterName == "GetInboxItem" then
                h.True(inboxSeen, "inbox fallback remains classified as inbox")
            end
        end
        API.ClassifyLink = originalClassifyLink
    end,

    ["modifier refresh clears tracking after a tooltip becomes excluded or pending"] = function()
        Boot()
        local first = Define()
        local second = Define()
        Include(first)
        Include(second)
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { first.link },
            hyperlink = first.link,
        }, nil, first.link)
        tooltip:ClearLines()
        tooltip.info = {
            getterName = "GetInventoryItem",
            getterArgs = { "player", 1 },
            hyperlink = first.link,
        }
        h.Stub.FireTooltip(tooltip)
        h.Stub.SetShiftDown(true)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "RSHIFT", 1)
        h.Equal(#tooltip.lines, 0, "equipped transition does not restore prior item")
        tooltip.info = {
            getterName = "GetHyperlink",
            getterArgs = { second.link },
            hyperlink = second.link,
        }
        h.Stub.SetItemPending(second.itemID, second)
        h.Stub.FireTooltip(tooltip)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        h.Equal(#tooltip.lines, 0, "pending transition remains empty")
        h.Stub.SetShiftDown(false)
    end,

    ["Shift inbox rebuild retains inbox classification without a hyperlink field"] = function()
        Boot()
        local item = Define()
        Include(item)
        h.Stub.SetInbox({ { items = { { link = item.link, count = 1 } } } })
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetInboxItem",
            getterArgs = { 1, 1 },
        })
        local original = API.ClassifyLink
        local inboxSeen = false
        h.Stub.SetShiftDown(true)
        API.ClassifyLink = function(link, fromInbox)
            inboxSeen = inboxSeen or fromInbox == true
            return original(link, fromInbox)
        end
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        API.ClassifyLink = original
        h.True(inboxSeen, "inbox flag preserved on refresh")
        h.True(#tooltip.lines >= 2, "inbox detail rebuilt")
        h.Stub.SetShiftDown(false)
    end,

    ["Shift release keeps detail while the other key remains down"] = function()
        Boot()
        local item = Define()
        Bag(item)
        Include(item)
        h.Stub.SetShiftDown(false)
        local tooltip = Tooltip("GameTooltip", { getterName = "GetBagItem", getterArgs = { 0, 1 } })
        h.Stub.SetShiftDown(true)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        local detailed = #tooltip.lines
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "RSHIFT", 1)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
        h.Equal(#tooltip.lines, detailed, "other Shift keeps detail visible")
        h.Stub.SetShiftDown(false)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "RSHIFT", 0)
        h.Equal(#tooltip.lines, 1, "last Shift release removes detail")
    end,

    ["Shift ignores unrelated modifiers, hidden tooltips, and refreshes popups"] = function()
        Boot()
        local item = Define()
        Include(item)
        h.Stub.SetShiftDown(false)
        local tooltip = Tooltip("GameTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
            hyperlink = item.link,
        }, nil, item.link)
        h.Stub.SetShiftDown(true)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LCTRL", 1)
        h.Equal(#tooltip.lines, 1, "unrelated modifier has no effect")
        tooltip.shown = false
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        h.Equal(tooltip.shown, false, "hidden tooltip stays hidden")
        h.Stub.SetShiftDown(false)
        local popup = Tooltip("ItemRefTooltip", {
            getterName = "GetHyperlink",
            getterArgs = { item.link },
            hyperlink = item.link,
        }, nil, item.link)
        popup.shown = true
        h.Stub.SetShiftDown(true)
        h.Stub.FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        h.True(#popup.lines >= 2, "shown item-link popup gets detail")
        h.Stub.SetShiftDown(false)
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

    ["other unit inventory is classified while unknown inventory owner is excluded"] = function()
        Boot()
        local item = Define()
        Include(item)
        local other = Tooltip("GameTooltip", {
            getterName = "GetInventoryItem",
            getterArgs = { "target", 1 },
            hyperlink = item.link,
        })
        local unknown = Tooltip("GameTooltip", {
            getterName = "GetInventoryItem",
            getterArgs = {},
            hyperlink = item.link,
        })
        h.Equal(#other.lines, 1, "other unit gets a line")
        h.Equal(#unknown.lines, 0, "unknown unit is excluded")
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
