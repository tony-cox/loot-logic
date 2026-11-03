local _, ns, h = ...

local Stub = h.Stub

local function Raises(fn)
    local ok, message = pcall(fn)
    h.Equal(ok, false, "the call raised")
    return message
end

local function Contains(text, part, label)
    h.True(string.find(text, part, 1, true), label .. " (in: " .. text .. ")")
end

return {
    ["advancing the clock moves GetServerTime, GetTime and date together"] = function()
        local startServer = GetServerTime()
        local startTime = GetTime()
        h.Equal(date("%Y-%m-%d %H:%M:%S", startServer), "2024-01-01 00:00:00", "start date")
        Stub.Advance(3661)
        h.Equal(GetServerTime(), startServer + 3661, "server time")
        h.Equal(GetTime(), startTime + 3661, "session time")
        h.Equal(date("%H:%M:%S"), "01:01:01", "date with no time argument")
        h.Equal(time(), GetServerTime(), "time()")
    end,

    ["time of a date table is the UTC epoch of it"] = function()
        local stamp = time({ year = 2024, month = 3, day = 1, hour = 6, min = 30, sec = 5 })
        h.Equal(date("%Y-%m-%d %H:%M:%S", stamp), "2024-03-01 06:30:05", "round trip")
        h.Equal(time({ year = 2024, month = 1, day = 1, hour = 0 }), GetServerTime(), "start")
    end,

    ["time(date(*t)) round-trips under a zone offset"] = function()
        Stub.SetTimeOffset(-5 * 3600)
        local stamp = GetServerTime()
        h.Equal(date("%H:%M", stamp), "19:00", "local clock reading")
        h.Equal(time(date("*t", stamp)), stamp, "round trip")
    end,

    ["date with a leading ! formats in UTC and ignores the offset"] = function()
        Stub.SetTimeOffset(-5 * 3600)
        h.Equal(date("!%H:%M", GetServerTime()), "00:00", "UTC text")
        h.Equal(date("!*t", GetServerTime()).hour, 0, "UTC table")
        h.Equal(date("*t", GetServerTime()).hour, 19, "offset table")
    end,

    ["ten advances of 0.1 seconds reach exactly one second"] = function()
        local ran = 0
        C_Timer.After(1, function()
            ran = ran + 1
        end)
        for _ = 1, 10 do
            Stub.Advance(0.1)
        end
        h.Equal(GetServerTime() - 1704067200, 1, "server seconds")
        h.Equal(GetTime(), 1001, "session time")
        h.Equal(ran, 1, "timer ran")
    end,

    ["a zero-delay timer made inside a callback runs on the next Advance"] = function()
        local steps = 0
        local function Step()
            steps = steps + 1
            C_Timer.After(0, Step)
        end
        C_Timer.After(0, Step)
        Stub.Advance(0)
        h.Equal(steps, 1, "one step after the first Advance")
        Stub.Advance(0)
        h.Equal(steps, 2, "one more step after the second")
        Stub.Advance(1)
        h.Equal(steps, 3, "one step per Advance however long it is")
    end,

    ["time normalises a month past 12 into the next year"] = function()
        local march = time({ year = 2025, month = 3, day = 1, hour = 0 })
        h.Equal(time({ year = 2024, month = 15, day = 1, hour = 0 }), march, "month 15")
        local february = time({ year = 2023, month = 2, day = 1, hour = 0 })
        h.Equal(time({ year = 2024, month = -10, day = 1, hour = 0 }), february, "month -10")
    end,

    ["a chat list read earlier still sees lines after ClearChat"] = function()
        local lines = Stub.ChatLines()
        Stub.ClearChat()
        print("x")
        h.DeepEqual(lines, { "x" }, "list read before the clear")
        h.DeepEqual(Stub.ChatLines(), { "x" }, "list read after")
    end,

    ["strsplit treats each delimiter character as a separator"] = function()
        h.DeepEqual({ strsplit(" ,", "a b,c") }, { "a", "b", "c" }, "two separators")
    end,

    ["a C_Timer.After callback runs when the clock passes its time and not before"] = function()
        local ran = {}
        C_Timer.After(5, function()
            ran[#ran + 1] = "five"
        end)
        C_Timer.After(0, function()
            ran[#ran + 1] = "zero"
        end)
        h.DeepEqual(ran, {}, "nothing before the clock moves")
        Stub.Advance(0)
        h.DeepEqual(ran, { "zero" }, "the zero timer after Advance(0)")
        Stub.Advance(4.9)
        h.DeepEqual(ran, { "zero" }, "five not yet due")
        Stub.Advance(0.1)
        h.DeepEqual(ran, { "zero", "five" }, "five once due")
        Stub.Advance(10)
        h.DeepEqual(ran, { "zero", "five" }, "each timer runs once")
    end,

    ["a timer started by a timer runs inside the same advance when it is due"] = function()
        local ran = {}
        C_Timer.After(1, function()
            ran[#ran + 1] = GetServerTime() - 1704067200
            C_Timer.After(2, function()
                ran[#ran + 1] = GetServerTime() - 1704067200
            end)
        end)
        Stub.Advance(10)
        h.DeepEqual(ran, { 1, 3 }, "clock reading inside each callback")
    end,

    ["a cancelled NewTimer never runs and a live one does"] = function()
        local ran = {}
        local cancelled = C_Timer.NewTimer(2, function()
            ran[#ran + 1] = "cancelled"
        end)
        C_Timer.NewTimer(2, function()
            ran[#ran + 1] = "kept"
        end)
        cancelled:Cancel()
        h.True(cancelled:IsCancelled(), "cancelled flag")
        Stub.Advance(5)
        h.DeepEqual(ran, { "kept" }, "only the live timer ran")
    end,

    ["date formats in UTC and follows the offset setter"] = function()
        Stub.Advance(13 * 3600 + 5 * 60 + 9)
        h.Equal(date("%H:%M:%S", GetServerTime()), "13:05:09", "UTC")
        Stub.SetTimeOffset(-5 * 3600)
        h.Equal(date("%H:%M:%S", GetServerTime()), "08:05:09", "offset minus five hours")
        Stub.SetTimeOffset(0)
        h.Equal(date("%H:%M:%S", GetServerTime()), "13:05:09", "offset cleared")
    end,

    ["a global set in one case is absent in the next (part 1 sets it)"] = function()
        _G.LeakProbe = "set"
        h.Equal(_G.LeakProbe, "set", "set in this case")
    end,

    ["a global set in one case is absent in the next (part 2 reads it)"] = function()
        h.Nil(_G.LeakProbe, "global from the case before")
    end,

    ["event frames receive fired events with their arguments"] = function()
        local seen = {}
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:SetScript("OnEvent", function(_, event, ...)
            seen[#seen + 1] = { event, ... }
        end)
        Stub.FireEvent("PLAYER_LOGIN")
        Stub.FireEvent("PLAYER_LEVEL_UP", 12)
        Stub.FireEvent("PLAYER_LOGIN", "x", "y")
        h.DeepEqual(seen, { { "PLAYER_LOGIN" }, { "PLAYER_LOGIN", "x", "y" } }, "events seen")
    end,

    ["chat output is captured from print and AddMessage"] = function()
        print("one", 2)
        DEFAULT_CHAT_FRAME:AddMessage("three")
        h.DeepEqual(Stub.ChatLines(), { "one 2", "three" }, "captured lines")
        Stub.ClearChat()
        h.DeepEqual(Stub.ChatLines(), {}, "cleared")
    end,

    ["strsplit, strtrim and wipe behave as the client's"] = function()
        h.DeepEqual({ strsplit("-", "a-b-c") }, { "a", "b", "c" }, "strsplit all")
        h.DeepEqual({ strsplit("-", "a-b-c", 2) }, { "a", "b-c" }, "strsplit limited")
        h.Equal(strtrim("  hi \n"), "hi", "strtrim whitespace")
        h.Equal(strtrim("xxhixx", "x"), "hi", "strtrim chars")
        local target = { 1, 2, key = 3 }
        h.Equal(wipe(target), target, "wipe returns the table")
        h.Nil(next(target), "wipe empties it")
    end,

    ["the addon files are loaded into one shared ns"] = function()
        h.True(ns.L, "ns.L from Locale/enUS.lua")
        h.True(ns.Init, "ns.Init from Core/Init.lua")
    end,

    ["h.Fixture loads the table of a fixture file, a new one each call"] = function()
        local first = h.Fixture("harnessSample")
        h.DeepEqual(first, { value = 1 }, "fixture content")
        h.True(h.Fixture("harnessSample") ~= first, "separate tables")
    end,

    ["a nil label still gives the expected and actual values"] = function()
        local message = Raises(function()
            h.Equal(1, 2)
        end)
        Contains(message, "expected 2, got 1", "values")
    end,

    ["h.Fixture raises for a missing fixture and names it"] = function()
        local message = Raises(function()
            h.Fixture("noSuchFixture")
        end)
        Contains(message, "noSuchFixture", "the message names the fixture")
    end,

    ["h.DeepEqual raises with the label, expected and actual on a mismatch"] = function()
        h.DeepEqual({ 1, { a = "x" } }, { 1, { a = "x" } }, "equal tables pass")
        local message = Raises(function()
            h.DeepEqual({ 1, { a = "x" } }, { 1, { a = "y" } }, "my label")
        end)
        Contains(message, "my label", "label")
        Contains(message, 'expected { [1] = 1, [2] = { ["a"] = "y" } }', "expected value")
        Contains(message, 'got { [1] = 1, [2] = { ["a"] = "x" } }', "actual value")
        Raises(function()
            h.DeepEqual({ 1 }, { 1, 2 }, "missing key")
        end)
        Raises(function()
            h.DeepEqual({ 1, 2 }, { 1 }, "extra key")
        end)
    end,

    ["h.Equal, h.True and h.Nil raise with the label"] = function()
        Contains(
            Raises(function()
                h.Equal(1, 2, "equal label")
            end),
            "equal label: expected 2, got 1",
            "Equal"
        )
        Contains(
            Raises(function()
                h.True(false, "true label")
            end),
            "true label: expected true, got false",
            "True"
        )
        Contains(
            Raises(function()
                h.Nil(5, "nil label")
            end),
            "nil label: expected nil, got 5",
            "Nil"
        )
        h.Equal(1, 1, "equal passes")
        h.True(1, "true passes")
        h.Nil(nil, "nil passes")
    end,

    ["DeepEqual compares stored fields and ignores metatable fallbacks"] = function()
        local fallback = setmetatable({}, {
            __index = function(_, key)
                return key
            end,
        })
        Raises(function()
            h.DeepEqual(fallback, { noSuchKey = "noSuchKey" }, "fallback")
        end)
        Raises(function()
            h.DeepEqual({ noSuchKey = "noSuchKey" }, fallback, "fallback reversed")
        end)
        h.DeepEqual(fallback, {}, "both hold nothing")
    end,
}
