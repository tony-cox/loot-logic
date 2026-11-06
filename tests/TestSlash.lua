local _, ns, h = ...

local L = ns.L
local Stub = h.Stub

local PREFIX = L.chatPrefix .. " "

local function Load()
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.ClearChat()
end

local function HasLine(text)
    for _, line in ipairs(Stub.ChatLines()) do
        if line == PREFIX .. text then
            return true
        end
    end
    return false
end

local function HasL2Line()
    for _, line in ipairs(Stub.ChatLines()) do
        if string.find(line, "^" .. PREFIX .. "L2 PASS ") then
            return true
        end
    end
    return false
end

local function RunsSaved()
    return LootLogicDB.debug.probe
end

local function ExpectProbe(message)
    Load()
    ns.Slash.Run(message)
    Stub.Advance(11)
    h.True(HasL2Line(), "the L2 line for '" .. message .. "'")
    h.True(HasLine(L.probeDone), "probe done for '" .. message .. "'")
end

local function ExpectPlaceholder(message)
    Load()
    ns.Slash.Run(message)
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.slashPlaceholder }, "chat for '" .. message .. "'")
    h.Nil(RunsSaved(), "nothing saved for '" .. message .. "'")
    h.Equal(#Stub.ChatLines(), 1, "nothing run for '" .. message .. "'")
end

local function LogCount(text)
    local count = 0
    for _, line in ipairs(LootLogicDB.debug.log or {}) do
        if string.find(line, "] " .. text, 1, true) then
            count = count + 1
        end
    end
    return count
end

local function DebugOnLine()
    return string.format(L.debugOn, "300")
end

local function ExpectOnWith(message)
    Load()
    ns.Slash.Run(message)
    h.Equal(LootLogicDB.debug.enabled, true, "enabled for '" .. message .. "'")
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. DebugOnLine() }, "chat for '" .. message .. "'")
end

local function ExpectUsage(message)
    Load()
    LootLogicDB.debug.enabled = true
    ns.Slash.Run(message)
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugUsage }, "chat for '" .. message .. "'")
    h.Equal(LootLogicDB.debug.enabled, true, "unchanged for '" .. message .. "'")
end

local function WhyBoot()
    Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = "WARRIOR",
        level = 60,
    })
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.FireEvent("PLAYER_LOGIN")
end

local function WhyItem(itemID, suffix)
    local link = "item:" .. itemID
    if suffix then
        link = link .. ":0:0:0:0:0:" .. suffix
    end
    local item = {
        itemID = itemID,
        name = "Why Item",
        link = link,
        quality = 1,
        itemLevel = 1,
        reqLevel = 0,
        sellPrice = 100,
        bindType = 0,
        classID = 7,
        subclassID = 5,
    }
    Stub.SetItem(itemID, item)
    Stub.SetTooltipLines(link, {})
    return link
end

return {
    ["Slash: probe runs the probe"] = function()
        ExpectProbe("probe")
    end,

    ["Slash: PROBE runs the probe (case-insensitive)"] = function()
        ExpectProbe("PROBE")
    end,

    ["Slash: a padded Probe runs the probe"] = function()
        ExpectProbe("  Probe  ")
    end,

    ["Slash: words after probe are ignored"] = function()
        ExpectProbe("probe extra words")
    end,

    ["Slash: bare /ll prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("")
    end,

    ["Slash: help prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("help")
    end,

    ["Slash: an unknown word prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("foo")
    end,

    ["Slash: a word that only starts with probe is not the probe command"] = function()
        ExpectPlaceholder("probes")
    end,

    ["Slash: an unknown word during a probe prints the placeholder"] = function()
        Load()
        ns.Slash.Run("probe")
        Stub.ClearChat()
        ns.Slash.Run("foo")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.slashPlaceholder }, "chat")
        Stub.Advance(11)
    end,

    ["Slash: debug on sets debug.enabled and prints the on line"] = function()
        ExpectOnWith("debug on")
    end,

    ["Slash: DEBUG ON and a padded debug  on work (case-insensitive)"] = function()
        ExpectOnWith("DEBUG ON")
        ExpectOnWith(" debug  on ")
    end,

    ["Slash: debug off clears debug.enabled, prints the off line, keeps the log"] = function()
        Load()
        LootLogicDB.debug.enabled = true
        LootLogicDB.debug.log = { "[00:00:00] old: line" }
        ns.Slash.Run("debug off")
        h.Equal(LootLogicDB.debug.enabled, false, "enabled")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugOff }, "chat")
        h.DeepEqual(LootLogicDB.debug.log, { "[00:00:00] old: line" }, "log kept")
    end,

    ["Slash: debug on while on prints the already-on line and registers once"] = function()
        Load()
        local original = ns.Events.Register
        local merchantRegistrations = 0
        ns.Events.Register = function(event, handler)
            if event == "MERCHANT_SHOW" then
                merchantRegistrations = merchantRegistrations + 1
            end
            return original(event, handler)
        end
        ns.Slash.Run("debug on")
        ns.Slash.Run("debug on")
        ns.Events.Register = original
        h.DeepEqual(
            Stub.ChatLines(),
            { PREFIX .. DebugOnLine(), PREFIX .. L.debugAlreadyOn },
            "chat"
        )
        h.Equal(LootLogicDB.debug.enabled, true, "still on")
        h.Equal(merchantRegistrations, 1, "registered once")
    end,

    ["Slash: debug on after a hand-set enabled prints already-on and registers"] = function()
        Load()
        LootLogicDB.debug.enabled = true
        ns.Slash.Run("debug on")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugAlreadyOn }, "chat")
        Stub.FireEvent("MERCHANT_SHOW")
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant logged")
    end,

    ["Slash: debug on reports a changed maxLog"] = function()
        Load()
        LootLogicDB.debug.maxLog = 50
        ns.Slash.Run("debug on")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. string.format(L.debugOn, "50") }, "chat")
    end,

    ["Slash: debug off while off prints the already-off line and changes nothing"] = function()
        Load()
        ns.Slash.Run("debug off")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugAlreadyOff }, "chat")
        h.Equal(LootLogicDB.debug.enabled, false, "still off")
    end,

    ["Slash: debug on then off then off prints off and then the already-off line"] = function()
        Load()
        ns.Slash.Run("debug on")
        Stub.ClearChat()
        ns.Slash.Run("debug off")
        ns.Slash.Run("debug off")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugOff, PREFIX .. L.debugAlreadyOff }, "chat")
    end,

    ["Slash: a bare debug prints the usage and changes nothing"] = function()
        ExpectUsage("debug")
    end,

    ["Slash: a bad debug word prints the usage and changes nothing"] = function()
        ExpectUsage("debug maybe")
    end,

    ["Slash: extra words after debug on print the usage and change nothing"] = function()
        ExpectUsage("debug on now")
    end,

    ["Slash: a read-only session refuses debug on and off and stays unchanged"] = function()
        for _, word in ipairs({ "on", "off" }) do
            LootLogicDB = h.Fixture("dbNewer")
            Stub.FireEvent("ADDON_LOADED", "LootLogic")
            Stub.ClearChat()
            ns.Slash.Run("debug " .. word)
            h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugReadOnly }, "chat for " .. word)
            h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data for " .. word)
            Stub.FireEvent("MERCHANT_SHOW")
            h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "no event line for " .. word)
        end
    end,

    ["Slash: events are logged after debug on and not after debug off"] = function()
        Load()
        ns.Slash.Run("debug on")
        Stub.ClearChat()
        Stub.FireEvent("BANKFRAME_OPENED")
        h.Equal(LogCount("event: BANKFRAME_OPENED"), 1, "log line")
        local entry
        for _, line in ipairs(LootLogicDB.debug.log) do
            if string.find(line, "] event: BANKFRAME_OPENED", 1, true) then
                entry = line
            end
        end
        h.True(entry, "the event line is in the log")
        local echoed = false
        for _, line in ipairs(Stub.ChatLines()) do
            if line == L.debugPrefix .. " " .. entry then
                echoed = true
            end
        end
        h.True(echoed, "the event line is echoed to chat")
        ns.Slash.Run("debug off")
        local before = #LootLogicDB.debug.log
        Stub.FireEvent("BANKFRAME_CLOSED")
        h.Equal(#LootLogicDB.debug.log, before, "no line after off")
    end,

    ["Slash: debug on stays on, events registered, when ADDON_LOADED runs again"] = function()
        Load()
        ns.Slash.Run("debug on")
        -- A reload keeps the saved table and loads the addon again; the
        -- registered handlers stand in for the fresh session's.
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Equal(LootLogicDB.debug.enabled, true, "still on")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 4)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED: 4"), 1, "bank slots")
    end,

    ["Slash: saved debug on registers the debug-only events at ADDON_LOADED"] = function()
        LootLogicDB = nil
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        LootLogicDB.debug.enabled = true
        -- ADDON_LOADED for another addon registers nothing.
        Stub.FireEvent("ADDON_LOADED", "SomethingElse")
        Stub.FireEvent("MERCHANT_SHOW")
        h.Equal(LogCount("event: MERCHANT_SHOW"), 0, "not registered yet")
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 1)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(LogCount("event: AUCTION_HOUSE_SHOW"), 1, "auction house")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED: 1"), 1, "bank slots")
    end,

    ["Slash: saved debug off registers nothing at ADDON_LOADED"] = function()
        Load()
        -- Turned on directly, not through the command, so only a registration
        -- made at load could write the lines.
        LootLogicDB.debug.enabled = true
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 1)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 0, "merchant")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED"), 0, "bank slots")
    end,

    ["Slash: autoOpenContents on skips MERCHANT_SHOW and AUCTION_HOUSE_SHOW"] = function()
        Load()
        LootLogicDB.ui.autoOpenContents = true
        ns.Slash.Run("debug on")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 2)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 0, "merchant skipped")
        h.Equal(LogCount("event: AUCTION_HOUSE_SHOW"), 0, "auction house skipped")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED: 2"), 1, "bank slots logged")
    end,

    ["Slash: an event the client refuses is an Errors entry and the others register"] = function()
        Load()
        Stub.SetUnknownEvents({ "PLAYERBANKSLOTS_CHANGED" })
        ns.Slash.Run("debug on")
        local errors = ns.Log.Errors()
        h.Equal(#errors, 1, "one error")
        h.Equal(errors[1].area, "events", "area")
        h.True(string.find(errors[1].message, "PLAYERBANKSLOTS_CHANGED", 1, true), "names it")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(LogCount("event: AUCTION_HOUSE_SHOW"), 1, "auction house")
        h.Equal(LogCount("error: events: PLAYERBANKSLOTS_CHANGED"), 1, "error line")
    end,

    ["Slash: why prints shared lines for an explicit link and a bare item ID"] = function()
        WhyBoot()
        WhyItem(199001)
        local hyperlink = "|cffa335ee|Hitem:199001:0:0:0:0:0:0|h[Why Item]|h|r"
        Stub.SetTooltipLines(hyperlink, {})
        ns.Slash.Run("why " .. hyperlink)
        h.Equal(#Stub.ChatLines(), 1, "link line count")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "explicit link result"
        )
        Stub.ClearChat()
        ns.Slash.Run("why 199001")
        h.Equal(#Stub.ChatLines(), 1, "ID line count")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "constructed link result"
        )
        WhyItem(199006)
        local uncolored = "|Hitem:199006:0:0:0:0:0:0|h[Why Item]|h"
        Stub.SetTooltipLines(uncolored, {})
        Stub.ClearChat()
        ns.Slash.Run("why " .. uncolored)
        h.Equal(#Stub.ChatLines(), 1, "uncolored hyperlink accepted")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "uncolored link result"
        )
    end,

    ["Slash: why matches a bag item and preserves suffix identity"] = function()
        WhyBoot()
        local link = WhyItem(199002, -17)
        LootLogicDB.characters["Local Test-Realm"].asks = {
            types = {},
            items = { [199002] = "include" },
        }
        Stub.SetBagSize(0, 2)
        Stub.SetBagItem(0, 1, { itemID = 199002, link = link, count = 1, quality = 1 })
        ns.Slash.Run("why 199002:-17")
        h.Equal(#Stub.ChatLines(), 2, "category and wants explanation")
        h.True(
            string.find(Stub.ChatLines()[1], "wanted by you", 1, true) ~= nil,
            "exact matching bag result"
        )
    end,

    ["Slash: why rejects extra text and reports missing IDs and hover"] = function()
        WhyBoot()
        WhyItem(199003)
        WhyItem(199005)
        local link = "|cffa335ee|Hitem:199003:0:0:0:0:0:0|h[Why Item]|h|r"
        local secondLink = "|Hitem:199005:0:0:0:0:0:0|h[Why Item]|h"
        Stub.SetTooltipLines(link, {})
        Stub.SetTooltipLines(secondLink, {})
        for _, argument in ipairs({
            "199003 extra",
            "prefix " .. link,
            link .. " extra",
            link .. " " .. link,
            link .. " " .. secondLink,
        }) do
            Stub.ClearChat()
            ns.Slash.Run("why " .. argument)
            h.DeepEqual(
                Stub.ChatLines(),
                { PREFIX .. L.detailUsage },
                "rejected argument: " .. argument
            )
        end
        Stub.SetItemExists(199004, false)
        Stub.ClearChat()
        ns.Slash.Run("why 199004")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.detailNotFound }, "missing item")
        Stub.ClearChat()
        ns.Slash.Run("why")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.detailNoHover }, "no hovered item")
    end,
    ["Slash: why uses hovered bag, link and inbox contexts"] = function()
        WhyBoot()
        local bagItem = WhyItem(199010)
        LootLogicDB.characters["Local Test-Realm"].asks = {
            types = {},
            items = { [199010] = "include" },
        }
        Stub.SetBagSize(0, 1)
        Stub.SetBagItem(0, 1, { itemID = 199010, link = bagItem, count = 1, quality = 1 })
        local tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "GetBagItem", getterArgs = { 0, 1 } },
            nil,
            bagItem
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        ns.Slash.Run("why")
        h.True(
            string.find(Stub.ChatLines()[1], "wanted by you", 1, true) ~= nil,
            "hovered bag item"
        )
        local linkItem = WhyItem(199011)
        Stub.ClearChat()
        tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "SetHyperlink", getterArgs = { linkItem }, hyperlink = linkItem },
            nil,
            linkItem
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        ns.Slash.Run("why")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "hovered link"
        )
        h.Stub.SetInbox({ { items = { { link = linkItem, count = 1 } } } })
        Stub.ClearChat()
        tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "GetInboxItem", getterArgs = { 1, 1 } },
            nil,
            linkItem
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        local original = ns.API.ClassifyLink
        local inboxSeen = false
        ns.API.ClassifyLink = function(link, fromInbox)
            inboxSeen = inboxSeen or fromInbox == true
            return original(link, fromInbox)
        end
        ns.Slash.Run("why")
        ns.API.ClassifyLink = original
        h.True(inboxSeen, "hovered inbox retains inbox origin")
    end,
    ["Slash: why accepts token colors and falls back from malformed hover links"] = function()
        WhyBoot()
        local item = WhyItem(199099)
        local link = "|cnIQ4:|Hitem:199099:0:0:0:0:0:0|h[Why Item]|h|r"
        Stub.SetTooltipLines(link, {})
        ns.Slash.Run("why " .. link)
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "token link accepted"
        )
        Stub.ClearChat()
        Stub.SetGlobal(
            "GameTooltip",
            Stub.MakeTooltip("GameTooltip", { hyperlink = "bad" }, nil, item)
        )
        ns.Slash.Run("why")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "valid GetItem fallback"
        )
    end,
    ["Slash: why preserves pending matching-bag results without link fallback"] = function()
        WhyBoot()
        local link = WhyItem(199012)
        Stub.SetBagSize(0, 1)
        Stub.SetBagItem(0, 1, { itemID = 199012, link = link, count = 1, quality = 1 })
        Stub.SetItemPending(199012, { itemID = 199012, name = "Why Item", link = link })
        local original = ns.API.ClassifyLink
        local linkCalls = 0
        ns.API.ClassifyLink = function(...)
            linkCalls = linkCalls + 1
            return original(...)
        end
        ns.Slash.Run("why 199012")
        ns.API.ClassifyLink = original
        h.Equal(#Stub.ChatLines(), 0, "pending bag has no classification")
        h.Equal(linkCalls, 0, "no link-only fallback")
    end,
    ["Slash: zero suffix selects the first stack and ID lookup failures are tolerated"] = function()
        WhyBoot()
        local link = WhyItem(199013, -17)
        local zeroLink = "item:199013:0:0:0:0:0:0"
        Stub.SetTooltipLines(zeroLink, {})
        local here = LootLogicDB.characters["Local Test-Realm"]
        here.asks = { types = {}, items = {} }
        LootLogicDB.characters["Alt Test-Realm"] = {
            first = "Alt",
            last = "Test",
            class = "PRIEST",
            level = 60,
            faction = here.faction,
            region = here.region,
            loadouts = {},
            asks = { types = {}, items = { [199013] = "include" } },
        }
        LootLogicDB.order = { "Alt Test-Realm", "Local Test-Realm" }
        Stub.SetBagSize(0, 2)
        Stub.SetBagItem(0, 1, {
            itemID = 199013,
            link = zeroLink,
            count = 1,
            quality = 1,
            bound = true,
        })
        Stub.SetBagItem(0, 2, { itemID = 199013, link = link, count = 1, quality = 1 })
        ns.Slash.Run("why 199013:0")
        h.True(
            string.find(Stub.ChatLines()[1], "Alt", 1, true) == nil,
            "zero suffix uses bound first stack"
        )
        Stub.ClearChat()
        ns.Slash.Run("why 199013:-17")
        h.True(
            string.find(Stub.ChatLines()[1], "Alt", 1, true) ~= nil,
            "negative suffix uses its matching stack"
        )
        WhyItem(199014)
        WhyItem(199015)
        Stub.SetExistsApi("off")
        Stub.ClearChat()
        ns.Slash.Run("why 199014")
        h.Equal(#Stub.ChatLines(), 1, "missing lookup API does not block a loaded item")
        Stub.SetExistsApi("raise")
        Stub.ClearChat()
        ns.Slash.Run("why 199015")
        h.Equal(#Stub.ChatLines(), 1, "failing lookup API does not block a loaded item")
    end,
}
