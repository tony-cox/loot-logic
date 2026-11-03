local _, ns, h = ...

local Events = ns.Events
local Log = ns.Log

local function DebugOn()
    LootLogicDB = { debug = { enabled = true, log = {}, maxLog = 300 } }
end

return {
    ["handlers of one event run in registration order"] = function()
        local order = {}
        Events.Register("PLAYER_LOGIN", function()
            order[#order + 1] = "first"
        end)
        Events.Register("PLAYER_LOGIN", function()
            order[#order + 1] = "second"
        end)
        Events.Register("PLAYER_LOGIN", function()
            order[#order + 1] = "third"
        end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.DeepEqual(order, { "first", "second", "third" }, "run order")
    end,

    ["a handler gets the event name and its arguments"] = function()
        local received
        Events.Register("ADDON_LOADED", function(...)
            received = { select("#", ...), ... }
        end)
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic", 7)
        h.DeepEqual(received, { 3, "ADDON_LOADED", "LootLogic", 7 }, "arguments")
    end,

    ["handlers of other events do not run"] = function()
        local ran = false
        Events.Register("BAG_UPDATE_DELAYED", function()
            ran = true
        end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(ran, false, "other event")
    end,

    ["a handler registered at run time runs on the next dispatch"] = function()
        local order = {}
        Events.Register("PLAYER_LOGIN", function()
            order[#order + 1] = "early"
            Events.Register("PLAYER_LOGIN", function()
                order[#order + 1] = "late"
            end)
        end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.DeepEqual(order, { "early" }, "the new handler waits")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.DeepEqual(order, { "early", "early", "late" }, "the new handler runs next time")
    end,

    ["an event first registered at run time is delivered"] = function()
        local seen = 0
        Events.Register("MAIL_SHOW", function()
            seen = seen + 1
        end)
        h.Stub.FireEvent("MAIL_SHOW")
        h.Equal(seen, 1, "calls")
    end,

    ["a failing handler adds an Errors entry and the next handler runs"] = function()
        local ran = false
        Events.Register("PLAYER_LOGIN", function()
            error("boom", 0)
        end)
        Events.Register("PLAYER_LOGIN", function()
            ran = true
        end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(ran, true, "next handler ran")
        h.Equal(#Log.Errors(), 1, "entries")
        h.Equal(Log.Errors()[1].area, "events", "area")
        h.Equal(Log.Errors()[1].message, "PLAYER_LOGIN: boom", "message")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["the event line is written before the handlers run"] = function()
        DebugOn()
        local seenByHandler
        Events.Register("PLAYER_LEVEL_UP", function()
            seenByHandler = LootLogicDB.debug.log[#LootLogicDB.debug.log]
        end)
        h.Stub.FireEvent("PLAYER_LEVEL_UP", 12)
        h.Equal(seenByHandler, "[00:00:00] event: PLAYER_LEVEL_UP: 12", "line a handler reads")
    end,

    ["the event line separates arguments with a comma and a space"] = function()
        DebugOn()
        Events.Register("ADDON_LOADED", function() end)
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic", true, nil, 4)
        h.DeepEqual(
            LootLogicDB.debug.log,
            { "[00:00:00] event: ADDON_LOADED: LootLogic, true, nil, 4" },
            "log"
        )
    end,

    ["the event line writes a table as <table> and a secret as <secret>"] = function()
        DebugOn()
        Events.Register("UNIT_AURA", function() end)
        h.Stub.FireEvent("UNIT_AURA", {}, h.Stub.MakeSecret(), "x")
        h.DeepEqual(
            LootLogicDB.debug.log,
            { "[00:00:00] event: UNIT_AURA: <table>, <secret>, x" },
            "log"
        )
    end,

    ["an event with no arguments gives just its name"] = function()
        DebugOn()
        Events.Register("PLAYER_LOGIN", function() end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.DeepEqual(LootLogicDB.debug.log, { "[00:00:00] event: PLAYER_LOGIN" }, "log")
    end,

    ["no event line for the two item-data events"] = function()
        DebugOn()
        local ran = 0
        local function Count()
            ran = ran + 1
        end
        Events.Register("GET_ITEM_INFO_RECEIVED", Count)
        Events.Register("ITEM_DATA_LOAD_RESULT", Count)
        h.Stub.FireEvent("GET_ITEM_INFO_RECEIVED", 100, true)
        h.Stub.FireEvent("ITEM_DATA_LOAD_RESULT", 100, true)
        h.Equal(ran, 2, "handlers still ran")
        h.DeepEqual(LootLogicDB.debug.log, {}, "no line written")
    end,

    ["no event line for ADDON_LOADED under a newer saved schema"] = function()
        LootLogicDB = {
            schema = ns.Init.schemaVersion + 1,
            debug = { enabled = true, log = { "kept" }, maxLog = 1 },
        }
        Events.Register("ADDON_LOADED", function() end)
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.DeepEqual(LootLogicDB.debug.log, { "kept" }, "log unchanged")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["no event line and no table with debug off"] = function()
        LootLogicDB = nil
        Events.Register("PLAYER_LOGIN", function() end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Nil(LootLogicDB, "no table created")
    end,
}
