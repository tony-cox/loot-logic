local _, ns, h = ...

local L = ns.L
local Stub = h.Stub
local Probe = ns.Probe

local PREFIX = L.chatPrefix .. " "
local EXPECTED_AUTOMATIC = {
    2,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    15,
    19,
    21,
    22,
    24,
    31,
    33,
    48,
    52,
    58,
    61,
    62,
}

local function Load()
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.ClearChat()
end

-- Runs the probe and moves the clock past both waits.
local function RunToEnd()
    Probe.Run()
    Stub.Advance(11)
end

-- The status and value of the result line of a check, or nil.
local function Result(id)
    local pattern = "^" .. PREFIX .. "L" .. id .. " (%u+) (.*)$"
    for _, line in ipairs(Stub.ChatLines()) do
        local status, value = string.match(line, pattern)
        if status then
            return status, value
        end
    end
    return nil
end

local function IndexOf(predicate)
    for index, line in ipairs(Stub.ChatLines()) do
        if predicate(line) then
            return index
        end
    end
    return nil
end

local function Count(predicate)
    local count = 0
    for _, line in ipairs(Stub.ChatLines()) do
        if predicate(line) then
            count = count + 1
        end
    end
    return count
end

local function IsDone(line)
    return line == PREFIX .. L.probeDone
end

local function Runs()
    return LootLogicDB.debug.probe
end

local function SingleKey()
    local keys = {}
    for key in pairs(Runs()) do
        keys[#keys + 1] = key
    end
    h.Equal(#keys, 1, "one saved run")
    return keys[1]
end

-- Items: the first candidate cached, the second pending (L58 picks 17182).
local function SetCandidates()
    Stub.SetItem(19019, {})
    Stub.SetItemPending(17182, {})
end

return {
    ["Probe: L2 passes with the stub's two names"] = function()
        Load()
        RunToEnd()
        local status, value = Result(2)
        h.Equal(status, "PASS", "status")
        h.Equal(value, "Zugar, Soulsour", "value")
    end,

    ["Probe: L2 fails with an empty last name"] = function()
        Load()
        Stub.SetPlayer({ last = "" })
        RunToEnd()
        h.Equal((Result(2)), "FAIL", "status")
    end,

    ["Probe: L62 passes under Lua 5.1 without table.unpack"] = function()
        Load()
        RunToEnd()
        local status, value = Result(62)
        h.Equal(status, "PASS", "status")
        h.True(
            string.find(value, "^Lua 5%.1, false, true, true, true, "),
            "measured line " .. value
        )
    end,

    ["Probe: L62 fails when table.unpack exists"] = function()
        Load()
        rawset(table, "unpack", unpack)
        RunToEnd()
        local status, value = Result(62)
        h.Equal(status, "FAIL", "status")
        h.True(string.find(value, "^Lua 5%.1, true"), "measured line " .. value)
    end,

    ["Probe: L63 prints nothing before 1.5 s, then passes"] = function()
        Load()
        Probe.Run()
        Stub.Advance(1.4)
        h.Nil(Result(63), "no line at 1.4 s")
        Stub.Advance(0.2)
        h.Equal((Result(63)), "PASS", "status at 1.6 s")
    end,

    ["Probe: L63 fails naming the timer when the cancelled timer fires"] = function()
        Load()
        Stub.SetCancelStops(false)
        RunToEnd()
        local status, value = Result(63)
        h.Equal(status, "FAIL", "status")
        h.True(string.find(value, L.probeTimerFired, 1, true), "names the timer: " .. value)
    end,

    ["Probe: L63 fails without NewTimer and still prints after the wait"] = function()
        Load()
        Stub.SetNewTimer(false)
        Probe.Run()
        Stub.Advance(1.4)
        h.Nil(Result(63), "no line at 1.4 s")
        Stub.Advance(0.2)
        local status, value = Result(63)
        h.Equal(status, "FAIL", "status")
        h.True(string.find(value, "C_Timer.NewTimer", 1, true), "names NewTimer: " .. value)
    end,

    ["Probe: L63 fails naming a missing add-on version"] = function()
        Load()
        Stub.SetAddOnMetadata("LootLogic", "Version", false)
        RunToEnd()
        local status, value = Result(63)
        h.Equal(status, "FAIL", "status")
        h.True(string.find(value, "GetAddOnMetadata", 1, true), "names the part: " .. value)
    end,

    ["Probe: a check that raises is FAIL with its error and the next still prints"] = function()
        Load()
        Stub.SetGlobal("C_PlayerInfo", {
            CanUseItem = function()
                error("boom", 0)
            end,
        })
        RunToEnd()
        local status, value = Result(5)
        h.Equal(status, "FAIL", "L5 status")
        h.Equal(value, "boom", "L5 value")
        h.Equal((Result(6)), "FAIL", "L6 still printed")
        h.Equal((Result(62)), "PASS", "L62 still printed")
    end,

    ["Probe: the run is saved under the server time with the build and the results"] = function()
        Load()
        SetCandidates()
        local key = tostring(GetServerTime())
        Probe.Run()
        local run = Runs()[key]
        h.Equal(run.build, "1.60.1.12345", "build")
        h.Equal(run.results.L2.status, "PASS", "L2 status")
        h.Equal(run.results.L2.value, "Zugar, Soulsour", "L2 value")
        h.Nil(run.results.L63, "L63 absent before its line prints")
        h.Nil(run.results.L28, "L28 absent while it waits")
    end,

    ["Probe: a missing GetServerTime saves the run as unknown and goes on"] = function()
        Load()
        Stub.SetGlobal("GetServerTime", nil)
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoServerTime, "one notice first")
        h.Equal(Runs().unknown.build, "1.60.1.12345", "saved under unknown")
        h.Equal(Runs().unknown.results.L2.status, "PASS", "checks ran")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoServerTime
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: a GetServerTime that raises saves the run as unknown"] = function()
        Load()
        Stub.SetGlobal("GetServerTime", function()
            error("boom", 0)
        end)
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoServerTime, "one notice first")
        h.Equal(Runs().unknown.results.L2.status, "PASS", "checks ran")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoServerTime
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: a GetServerTime that gives nil saves the run as unknown"] = function()
        Load()
        Stub.SetGlobal("GetServerTime", function()
            return nil
        end)
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoServerTime, "one notice first")
        h.Equal(type(Runs().unknown), "table", "saved as unknown")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoServerTime
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: a GetServerTime that gives no number saves the run as unknown"] = function()
        Load()
        Stub.SetGlobal("GetServerTime", function()
            return "1793750400"
        end)
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoServerTime, "one notice first")
        h.Equal(type(Runs().unknown), "table", "saved as unknown")
        h.Nil(Runs()["1793750400"], "not saved under the text")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoServerTime
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: a second unknown run takes -2"] = function()
        Load()
        Stub.SetGlobal("GetServerTime", nil)
        Probe.Run()
        Stub.Advance(11)
        Probe.Run()
        h.Equal(type(Runs().unknown), "table", "first")
        h.Equal(type(Runs()["unknown-2"]), "table", "second")
    end,

    ["Probe: a missing GetBuildInfo saves the build as unknown and goes on"] = function()
        Load()
        Stub.SetGlobal("GetBuildInfo", nil)
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoBuild, "one notice first")
        h.Equal(Runs()[key].build, "unknown", "build")
        h.Equal(Runs()[key].results.L2.status, "PASS", "checks ran")
    end,

    ["Probe: a GetBuildInfo that raises is recorded as unknown"] = function()
        Load()
        Stub.SetGlobal("GetBuildInfo", function()
            error("boom", 0)
        end)
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Equal(Runs()[key].build, "unknown", "build")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoBuild, "notice")
    end,

    ["Probe: a GetBuildInfo with no build text is recorded as unknown"] = function()
        Load()
        Stub.SetGlobal("GetBuildInfo", function()
            return "1.60.1", nil
        end)
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoBuild, "one notice first")
        h.Equal(Runs()[key].build, "unknown", "build")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoBuild
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: a GetBuildInfo with an empty build text is recorded as unknown"] = function()
        Load()
        Stub.SetGlobal("GetBuildInfo", function()
            return "1.60.1", ""
        end)
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoBuild, "one notice first")
        h.Equal(Runs()[key].build, "unknown", "build")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoBuild
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: a GetBuildInfo with an empty version text is recorded as unknown"] = function()
        Load()
        Stub.SetGlobal("GetBuildInfo", function()
            return "", "70532"
        end)
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoBuild, "one notice first")
        h.Equal(Runs()[key].build, "unknown", "build")
    end,

    ["Probe: a GetBuildInfo with a number build is recorded as unknown"] = function()
        Load()
        Stub.SetGlobal("GetBuildInfo", function()
            return "1.60.1", 70532
        end)
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.probeNoBuild, "one notice first")
        h.Equal(Runs()[key].build, "unknown", "build")
        h.Equal(
            Count(function(line)
                return line == PREFIX .. L.probeNoBuild
            end),
            1,
            "notice once"
        )
    end,

    ["Probe: the L63 entry is saved when its line prints"] = function()
        Load()
        local key = tostring(GetServerTime())
        Probe.Run()
        h.Nil(Runs()[key].results.L63, "absent at the start")
        Stub.Advance(1.6)
        h.Equal(Runs()[key].results.L63.status, "PASS", "present after the line")
        h.Equal(type(Runs()[key].results.L63.value), "string", "value is text")
    end,

    ["Probe: a run after probe done adds a second entry and keeps the first"] = function()
        Load()
        local first = tostring(GetServerTime())
        RunToEnd()
        local second = tostring(GetServerTime())
        h.True(first ~= second, "the clock moved")
        RunToEnd()
        h.Equal(type(Runs()[first]), "table", "first kept")
        h.Equal(type(Runs()[second]), "table", "second added")
        local count = 0
        for key in pairs(Runs()) do
            h.Equal(type(key), "string", "every key is text")
            count = count + 1
        end
        h.Equal(count, 2, "two runs")
    end,

    ["Probe: a run in the second of a saved run takes -2, then -3"] = function()
        Load()
        local base = tostring(GetServerTime())
        LootLogicDB.debug.probe = { [base] = { results = {} } }
        Probe.Run()
        h.Equal(type(Runs()[base .. "-2"]), "table", "-2 added")
        Stub.Advance(0.1)
        h.Nil(Runs()[base].build, "original not overwritten")
        Stub.Advance(11)
        -- The clock has moved on, so seed the new second as well.
        local later = tostring(GetServerTime())
        Runs()[later] = { results = {} }
        Runs()[later .. "-2"] = { results = {} }
        Probe.Run()
        h.Equal(type(Runs()[later .. "-3"]), "table", "-3 added")
        h.Nil(Runs()[later .. "-2"].build, "-2 not overwritten")
    end,

    ["Probe: a second run before probe done is refused and saves nothing"] = function()
        Load()
        Probe.Run()
        local checkLines = Count(function(line)
            return string.find(line, "^" .. PREFIX .. "L2 ") ~= nil
        end)
        h.Equal(checkLines, 1, "one L2 line")
        Stub.Advance(0.5)
        Stub.ClearChat()
        Probe.Run()
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.probeBusy }, "only the refusal line")
        SingleKey()
        Stub.Advance(11)
        Stub.ClearChat()
        Probe.Run()
        h.True(Result(2) ~= nil, "a run after probe done runs")
        h.Equal(Count(IsDone), 0, "its own wait has not ended")
    end,

    ["Probe: a read-only session runs every check and leaves LootLogicDB unchanged"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        Stub.ClearChat()
        RunToEnd()
        for _, id in ipairs(EXPECTED_AUTOMATIC) do
            h.True(Result(id) ~= nil, "L" .. id .. " printed")
        end
        h.Equal((Result(63)), "PASS", "L63")
        h.Equal(Count(IsDone), 1, "probe done once")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        local runs = ns.DB.Data().debug.probe
        local count = 0
        for _ in pairs(runs) do
            count = count + 1
        end
        h.Equal(count, 1, "the run lives in the session copy")
    end,

    ["Probe: every line starts with LootLogic:"] = function()
        Load()
        RunToEnd()
        h.True(#Stub.ChatLines() > 60, "many lines")
        for _, line in ipairs(Stub.ChatLines()) do
            h.Equal(string.sub(line, 1, #PREFIX), PREFIX, "prefix of " .. line)
        end
    end,

    ["Probe: the order is the automatic lines, the manual list, L28, L63, probe done"] = function()
        Load()
        RunToEnd()
        local lines = Stub.ChatLines()
        local autoIndex = {}
        local lastAuto = 0
        local firstManual
        local lastManual = 0
        for index, line in ipairs(lines) do
            local id = string.match(line, "^" .. PREFIX .. "L(%d+) %u+ ")
            if id then
                autoIndex[tonumber(id)] = index
            end
            if string.find(line, " manual", 1, true) then
                firstManual = firstManual or index
                lastManual = index
            end
        end
        local previous = 0
        for _, id in ipairs(EXPECTED_AUTOMATIC) do
            h.True(autoIndex[id] > previous, "L" .. id .. " in number order")
            previous = autoIndex[id]
            lastAuto = autoIndex[id]
        end
        -- L61 prints its names under its line, before L62.
        h.True(autoIndex[62] - autoIndex[61] > 1, "L61 names sit under its line")
        h.True(firstManual > lastAuto, "the manual list follows the automatic lines")
        h.True(autoIndex[28] > lastManual, "L28 follows the manual list")
        h.True(autoIndex[63] > autoIndex[28], "L63 follows L28")
        h.Equal(Count(IsDone), 1, "probe done once")
        h.Equal(IndexOf(IsDone), #lines, "probe done last")
        h.Equal(lines[#lines - 1], lines[autoIndex[63]], "L63 just before probe done")
    end,

    ["Probe: the manual list has 42 lines, 24 marked for M1, L5 among them"] = function()
        Load()
        RunToEnd()
        local total = 0
        local marked = 0
        local l5Marked = false
        for _, line in ipairs(Stub.ChatLines()) do
            local id = string.match(line, "^" .. PREFIX .. "L(%d+) manual")
            if id then
                total = total + 1
                if string.find(line, "manual (M1):", 1, true) then
                    marked = marked + 1
                    if id == "5" then
                        l5Marked = true
                    end
                end
            end
        end
        h.Equal(total, 42, "manual lines")
        h.Equal(marked, 24, "marked for M1")
        h.True(l5Marked, "L5 above-level line is marked")
        local l1 = PREFIX .. string.format(L.probeManualLineM1, 1, L.probeAssumptionL1)
        h.True(
            IndexOf(function(line)
                return line == l1
            end),
            "L1 line with its assumption"
        )
        local l16 = PREFIX .. string.format(L.probeManualLine, 16, L.probeAssumptionL16)
        h.True(
            IndexOf(function(line)
                return line == l16
            end),
            "L16 line unmarked"
        )
    end,

    ["Probe: the first cached and the second pending candidate select 17182"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        local status, value = Result(58)
        h.Equal(status, "PASS", "L58 status")
        h.Equal(value, "item 17182 true false nil", "L58 value")
    end,

    ["Probe: with no candidate L58 and L28 are SKIP and L28 does not wait"] = function()
        Load()
        Probe.Run()
        local status, value = Result(58)
        h.Equal(status, "SKIP", "L58 status")
        for _, itemID in ipairs({ 19019, 17182, 13262, 18608, 17204 }) do
            h.True(
                string.find(value, tostring(itemID) .. " false false nil", 1, true),
                "lists " .. itemID
            )
        end
        h.Equal((Result(28)), "SKIP", "L28 printed right after the list")
        h.Equal(Count(IsDone), 0, "probe done waits for L63")
        Stub.Advance(1.6)
        h.Equal(Count(IsDone), 1, "probe done after L63")
    end,

    ["Probe: the event at 3 s gives L28 PASS with the time"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.Advance(3)
        h.Nil(Result(28), "no L28 line before the event")
        h.Equal(Count(IsDone), 0, "not done yet")
        Stub.LoadItem(17182)
        local status, value = Result(28)
        h.Equal(status, "PASS", "status")
        h.Equal(value, "item 17182 loaded in 3.0 s, success true", "value")
        h.Equal(Count(IsDone), 1, "probe done once, L63 had printed")
        h.Equal(IndexOf(IsDone), #Stub.ChatLines(), "last")
        Stub.Advance(11)
        h.Equal(Count(IsDone), 1, "still once")
    end,

    ["Probe: an early event waits for L63 before probe done"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.Advance(0.5)
        Stub.LoadItem(17182)
        h.Equal((Result(28)), "PASS", "L28 printed")
        h.Equal(Count(IsDone), 0, "probe done follows the later line")
        Stub.Advance(1.2)
        h.Equal(Count(IsDone), 1, "probe done after L63")
        h.Equal(IndexOf(IsDone), #Stub.ChatLines(), "last")
    end,

    ["Probe: no event gives nothing at 9.9 s and FAIL at 10 s"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.Advance(9.9)
        h.Nil(Result(28), "nothing at 9.9 s")
        h.Equal(Count(IsDone), 0, "not done")
        Stub.Advance(0.1)
        local status, value = Result(28)
        h.Equal(status, "FAIL", "status")
        h.Equal(value, L.probeNoEvent, "value")
        h.Equal(Count(IsDone), 1, "probe done after the later line")
    end,

    ["Probe: another item or GET_ITEM_INFO_RECEIVED alone does not pass L28"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.FireEvent("ITEM_DATA_LOAD_RESULT", 99, true)
        Stub.FireEvent("GET_ITEM_INFO_RECEIVED", 17182, true)
        h.Nil(Result(28), "no L28 line")
        Stub.Advance(10)
        h.Equal((Result(28)), "FAIL", "FAIL at 10 s")
    end,

    ["Probe: an event after 10 s but before the overdue callback fails L28"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.JumpClock(10.5)
        Stub.FireEvent("ITEM_DATA_LOAD_RESULT", 17182, true)
        local status, value = Result(28)
        h.Equal(status, "FAIL", "status")
        h.Equal(value, L.probeNoEvent, "value")
        Stub.Advance(0)
        h.Equal((Result(28)), "FAIL", "still FAIL after the callback")
        h.Equal(Count(IsDone), 1, "probe done once, after the overdue callbacks")
    end,

    ["Probe: an event at exactly 10 s still passes L28"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.JumpClock(10)
        Stub.FireEvent("ITEM_DATA_LOAD_RESULT", 17182, true)
        h.Equal((Result(28)), "PASS", "status")
    end,

    ["Probe: the success argument does not matter for L28"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.FireEvent("ITEM_DATA_LOAD_RESULT", 17182, false)
        local status, value = Result(28)
        h.Equal(status, "PASS", "status")
        h.True(string.find(value, "success false", 1, true), "success printed: " .. value)
    end,

    ["Probe: the L28 entry is saved when its line prints"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        local key = SingleKey()
        h.Nil(Runs()[key].results.L28, "absent before")
        Stub.Advance(2)
        Stub.LoadItem(17182)
        h.Equal(Runs()[key].results.L28.status, "PASS", "present after")
    end,

    ["Probe: the L28 wait still ends at 10 s without NewTimer"] = function()
        Load()
        SetCandidates()
        Stub.SetNewTimer(false)
        Probe.Run()
        Stub.Advance(9.9)
        h.Nil(Result(28), "nothing at 9.9 s")
        Stub.Advance(0.1)
        h.Equal((Result(28)), "FAIL", "FAIL at 10 s")
    end,

    ["Probe: L58 fails when the missing ID answers true"] = function()
        Load()
        SetCandidates()
        Stub.SetItemExists(-1, true)
        Probe.Run()
        h.Equal((Result(58)), "FAIL", "status")
    end,

    ["Probe: L58 fails with call missing and L28 is SKIP"] = function()
        Load()
        SetCandidates()
        Stub.SetExistsApi("off")
        Probe.Run()
        local status, value = Result(58)
        h.Equal(status, "FAIL", "L58 status")
        h.Equal(value, L.probeCallMissing, "L58 value")
        local l28Status, l28Value = Result(28)
        h.Equal(l28Status, "SKIP", "L28")
        h.Equal(l28Value, L.probeNoCandidateApi, "L28 reason")
    end,

    ["Probe: L58 fails with the raised error's text and L28 is SKIP"] = function()
        Load()
        SetCandidates()
        Stub.SetExistsApi("raise")
        Probe.Run()
        local status, value = Result(58)
        h.Equal(status, "FAIL", "L58 status")
        h.Equal(value, "DoesItemExistByID failed", "L58 value")
        local l28Status, l28Value = Result(28)
        h.Equal(l28Status, "SKIP", "L28")
        h.Equal(l28Value, L.probeCandidateError, "L28 reason")
        h.Equal((Result(61)) ~= nil, true, "later checks still run")
        Stub.Advance(1.6)
        h.Equal(Count(IsDone), 1, "probe done after L63")
    end,

    ["Probe: a run during the L28 wait is refused, one after probe done runs"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        Stub.Advance(2)
        h.True(Result(63) ~= nil, "L63 has printed")
        Stub.ClearChat()
        Probe.Run()
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.probeBusy }, "refused")
        Stub.Advance(8)
        h.Equal(Count(IsDone), 1, "probe done after the L28 FAIL")
        Stub.ClearChat()
        Probe.Run()
        h.True(Result(2) ~= nil, "runs again")
    end,

    ["Probe: an event received during the request is kept and passes L28 at once"] = function()
        Load()
        SetCandidates()
        Stub.SetLoadOnRequest(17182)
        Probe.Run()
        local status, value = Result(28)
        h.Equal(status, "PASS", "status")
        h.Equal(value, "item 17182 loaded in 0.0 s, success true", "value")
        local manualEnd = IndexOf(function(line)
            return string.find(line, "^" .. PREFIX .. "L60 manual") ~= nil
        end)
        local l28 = IndexOf(function(line)
            return string.find(line, "^" .. PREFIX .. "L28 ") ~= nil
        end)
        local l63 = IndexOf(function(line)
            return string.find(line, "^" .. PREFIX .. "L63 ") ~= nil
        end)
        h.True(l28 > manualEnd, "L28 after the manual list")
        h.Nil(l63, "L63 still waits")
    end,

    ["Probe: a failing C_Timer.After keeps L58 and fails L28 with the error"] = function()
        Load()
        SetCandidates()
        Stub.SetGlobal("C_Timer", {
            NewTimer = C_Timer.NewTimer,
        })
        Probe.Run()
        local status58 = Result(58)
        h.Equal(status58, "PASS", "L58 keeps its own verdict")
        local status28, value28 = Result(28)
        h.Equal(status28, "FAIL", "L28")
        h.True(string.find(value28, "After", 1, true) ~= nil, "error text: " .. value28)
        h.Equal((Result(63)), "FAIL", "L63")
        h.Equal(Count(IsDone), 1, "probe done once")
        h.Equal(IndexOf(IsDone), #Stub.ChatLines(), "last")
        Stub.ClearChat()
        Probe.Run()
        h.True(Result(2) ~= nil, "a following run is not refused")
    end,

    ["Probe: an event after the request counts for L28"] = function()
        Load()
        SetCandidates()
        Probe.Run()
        h.True(Stub.ItemRequests(17182) >= 1, "17182 was requested")
        Stub.LoadItem(17182)
        h.Equal((Result(28)), "PASS", "the event counted")
    end,
}
