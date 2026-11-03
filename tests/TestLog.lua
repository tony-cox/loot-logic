local _, ns, h = ...

local Log = ns.Log
local L = ns.L

local function DebugOn(maxLog)
    LootLogicDB = { debug = { enabled = true, log = {}, maxLog = maxLog or 300 } }
end

return {
    ["Chat prints one prefixed line"] = function()
        Log.Chat("hello")
        h.DeepEqual(h.Stub.ChatLines(), { L.chatPrefix .. " hello" }, "chat lines")
    end,

    ["errors: dedupe against the newest entry only"] = function()
        Log.Error("engine", "A")
        Log.Error("engine", "B")
        Log.Error("engine", "A")
        h.Equal(#Log.Errors(), 3, "three entries")
        h.Equal(Log.Errors()[1].message, "A", "first")
        h.Equal(Log.Errors()[2].message, "B", "second")
        h.Equal(Log.Errors()[3].message, "A", "third")
        h.Equal(Log.Errors()[3].count, 1, "count of the third")
    end,

    ["errors: an entry has time, area, message and count"] = function()
        h.Stub.Advance(5)
        Log.Error("provider:ahdb", "bad data")
        h.DeepEqual(Log.Errors(), {
            { time = GetServerTime(), area = "provider:ahdb", message = "bad data", count = 1 },
        }, "entry")
    end,

    ["errors: a repeat adds to count, and errorCount counts every error"] = function()
        Log.Error("engine", "A")
        Log.Error("engine", "A")
        Log.Error("engine", "A")
        Log.Error("events", "A")
        h.Equal(#Log.Errors(), 2, "two entries")
        h.Equal(Log.Errors()[1].count, 3, "count of the repeated entry")
        h.Equal(Log.errorCount, 4, "errorCount")
    end,

    ["errors: the 21st distinct error drops the oldest"] = function()
        for index = 1, 21 do
            Log.Error("engine", "error " .. tostring(index))
        end
        h.Equal(#Log.Errors(), 20, "list length")
        h.Equal(Log.Errors()[1].message, "error 2", "oldest kept")
        h.Equal(Log.Errors()[20].message, "error 21", "newest")
        h.Equal(Log.errorCount, 21, "errorCount")
    end,

    ["errors: Log.Error prints no chat line and writes the error debug line"] = function()
        DebugOn()
        h.Stub.ClearChat()
        Log.Error("events", "bad")
        local expected = "[00:00:00] error: events: bad"
        h.DeepEqual(LootLogicDB.debug.log, { expected }, "debug.log")
        h.DeepEqual(h.Stub.ChatLines(), { L.debugPrefix .. " " .. expected }, "only the echo")
    end,

    ["errors: with debug off Log.Error prints nothing"] = function()
        Log.Error("events", "bad")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["guard: returns all of fn's values"] = function()
        local a, b, c = Log.Guard("engine", function(x, y)
            return x, y, nil
        end, 1, 2)
        h.Equal(a, 1, "first")
        h.Equal(b, 2, "second")
        h.Nil(c, "third")
        local count = select(
            "#",
            Log.Guard("engine", function()
                return 1, 2, 3
            end)
        )
        h.Equal(count, 3, "number of values")
        h.Equal(#Log.Errors(), 0, "no entry on success")
    end,

    ["guard: returns nil on an error and records the entry"] = function()
        local result = Log.Guard("engine", function()
            error("boom", 0)
        end)
        h.Nil(result, "result")
        h.Equal(#Log.Errors(), 1, "entries")
        h.Equal(Log.Errors()[1].area, "engine", "area")
        h.Equal(Log.Errors()[1].message, "boom", "message")
        h.Equal(Log.errorCount, 1, "errorCount")
    end,

    ["guard: the engine line prints once however many items fail"] = function()
        for index = 1, 5 do
            Log.Guard("engine", function()
                error("fail " .. tostring(index), 0)
            end)
        end
        h.DeepEqual(h.Stub.ChatLines(), { L.chatPrefix .. " " .. L.errorEngine }, "lines")
        h.Equal(Log.errorCount, 5, "errorCount")
    end,

    ["guard: another area prints no engine line"] = function()
        Log.Guard("provider:x", function()
            error("boom", 0)
        end)
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
        h.Equal(Log.Errors()[1].area, "provider:x", "area")
    end,

    ["debug: nothing is written when LootLogicDB is nil"] = function()
        LootLogicDB = nil
        Log.Debug("snapshot", "x")
        h.Nil(LootLogicDB, "no table created")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["debug: nothing is written when there is no debug table"] = function()
        LootLogicDB = {}
        Log.Debug("snapshot", "x")
        h.DeepEqual(LootLogicDB, {}, "no table created")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["debug: nothing is written when debug is not enabled"] = function()
        LootLogicDB = { debug = { enabled = false, log = {}, maxLog = 300 } }
        Log.Debug("snapshot", "x")
        h.DeepEqual(
            LootLogicDB,
            { debug = { enabled = false, log = {}, maxLog = 300 } },
            "unchanged"
        )
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["debug: nothing is written when the saved schema is newer"] = function()
        LootLogicDB = {
            schema = ns.Init.schemaVersion + 1,
            debug = { enabled = true, log = {}, maxLog = 300 },
        }
        Log.Debug("snapshot", "x")
        Log.Error("engine", "boom")
        h.DeepEqual(LootLogicDB.debug.log, {}, "log unchanged")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
        LootLogicDB.schema = ns.Init.schemaVersion
        Log.Debug("snapshot", "y")
        h.Equal(#LootLogicDB.debug.log, 1, "written when the schema equals the code's")
    end,

    ["debug: a newer saved schema keeps a log that is not a table"] = function()
        LootLogicDB = {
            schema = ns.Init.schemaVersion + 1,
            debug = { enabled = true, log = "packed newer log", maxLog = 1 },
        }
        Log.Debug("snapshot", "x")
        h.Equal(LootLogicDB.debug.log, "packed newer log", "log untouched")
    end,

    ["guard: keeps the count of values with a nil in the middle"] = function()
        local count = select(
            "#",
            Log.Guard("engine", function()
                return 1, nil
            end)
        )
        h.Equal(count, 2, "number of values")
    end,

    ["debug: line format at a stub time, echoed and kept"] = function()
        DebugOn()
        h.Stub.Advance(3723)
        Log.Debug("snapshot", "gear: 19 links")
        local expected = "[01:02:03] snapshot: gear: 19 links"
        h.DeepEqual(LootLogicDB.debug.log, { expected }, "debug.log")
        h.DeepEqual(h.Stub.ChatLines(), { L.debugPrefix .. " " .. expected }, "chat")
    end,

    ["debug: the log is trimmed to maxLog"] = function()
        DebugOn(3)
        for index = 1, 5 do
            Log.Debug("a", "line " .. tostring(index))
        end
        h.DeepEqual(LootLogicDB.debug.log, {
            "[00:00:00] a: line 3",
            "[00:00:00] a: line 4",
            "[00:00:00] a: line 5",
        }, "last three lines")
    end,
}
