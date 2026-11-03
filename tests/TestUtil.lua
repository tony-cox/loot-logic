local _, ns, h = ...

local Util = ns.Util

local PLAIN = "|cff0070dd|Hitem:12345:0:0:0:0:0:0:0:60:0:0:0|h[Ring]|h|r"
local SUFFIX = "|cff0070dd|Hitem:12345:0:0:0:0:0:123:0:60:0:0:0|h[Ring of X]|h|r"
local NEGATIVE = "|cff0070dd|Hitem:12345:0:0:0:0:0:-17:0:60|h[Ring of Y]|h|r"
local TOKEN_FORM = "|cnIQ4:|Hitem:12345:0:0:0:0:0:123:0:60|h[Ring of X]|h|r"

return {
    ["instance key: no suffix gives suffix 0"] = function()
        h.Equal(Util.InstanceKey(PLAIN), "12345:0", "plain link")
        h.Equal(Util.InstanceKey("item:12345"), "12345:0", "short item string")
    end,

    ["instance key: the suffix is the seventh field"] = function()
        h.Equal(Util.InstanceKey(SUFFIX), "12345:123", "suffix link")
    end,

    ["instance key: a negative suffix keeps its sign"] = function()
        h.Equal(Util.InstanceKey(NEGATIVE), "12345:-17", "negative suffix")
        local itemID, suffix = Util.ParseLink(NEGATIVE)
        h.Equal(itemID, 12345, "item ID")
        h.Equal(suffix, -17, "suffix")
    end,

    ["instance key: both colour forms read the same"] = function()
        h.Equal(Util.InstanceKey(TOKEN_FORM), "12345:123", "colour token form")
        h.Equal(Util.InstanceKey(SUFFIX), "12345:123", "hex form")
    end,

    ["instance key: text with no item gives nil"] = function()
        h.Nil(Util.InstanceKey("not a link"), "no item")
        h.Nil(Util.InstanceKey("item:"), "no ID")
    end,

    ["secret guard: reports a value the stub marks secret"] = function()
        local secret = h.Stub.MakeSecret()
        h.Equal(Util.IsSecret(secret), true, "secret value")
        h.Equal(Util.IsSecret({}), false, "plain table")
        h.Equal(Util.IsSecret("text"), false, "plain string")
        h.Equal(Util.IsSecret(nil), false, "nil")
    end,

    ["pcall wrapper: success returns true and the values"] = function()
        local ok, first, second = Util.Pcall(function(a, b)
            return a + 1, b + 1
        end, 1, 2)
        h.Equal(ok, true, "ok")
        h.Equal(first, 2, "first")
        h.Equal(second, 3, "second")
    end,

    ["pcall wrapper: keeps the count of values with a nil in the middle"] = function()
        local count = select(
            "#",
            Util.Pcall(function()
                return 1, nil
            end)
        )
        h.Equal(count, 3, "true, 1, nil")
    end,

    ["pcall wrapper: an error returns false and the text"] = function()
        local ok, message = Util.Pcall(function()
            error("boom", 0)
        end)
        h.Equal(ok, false, "ok")
        h.Equal(message, "boom", "message")
        local okTable, textTable = Util.Pcall(function()
            error({}, 0)
        end)
        h.Equal(okTable, false, "ok for a table error")
        h.Equal(type(textTable), "string", "message is text")
    end,

    ["pcall wrapper: an error object whose tostring fails still gives false and text"] = function()
        local ok, text = Util.Pcall(function()
            error(
                setmetatable({}, {
                    __tostring = function()
                        error("no text", 0)
                    end,
                }),
                0
            )
        end)
        h.Equal(ok, false, "ok")
        h.Equal(type(text), "string", "message is text")
    end,

    ["debounce: runs once after the last call"] = function()
        local calls = {}
        local fire = Util.Debounce(1, function(value)
            calls[#calls + 1] = value
        end)
        fire("a")
        h.Stub.Advance(0.5)
        fire("b")
        h.Stub.Advance(0.5)
        h.Equal(#calls, 0, "nothing yet, the second call restarted the wait")
        h.Stub.Advance(0.5)
        h.DeepEqual(calls, { "b" }, "one run with the last arguments")
        h.Stub.Advance(10)
        h.Equal(#calls, 1, "no further run")
    end,

    ["debounce: a call after a run starts a new wait"] = function()
        local count = 0
        local fire = Util.Debounce(1, function()
            count = count + 1
        end)
        fire()
        h.Stub.Advance(1)
        fire()
        h.Stub.Advance(1)
        h.Equal(count, 2, "two runs")
    end,

    ["format pattern: a placeholder is a number wildcard, a percent sign is literal"] = function()
        local pattern = Util.FormatPattern("Raises hit by %s%% (%d+).")
        h.Equal(pattern, "^Raises hit by [%d%.,]+%% %([%d%.,]+%+%)%.$", "the pattern")
        h.True(string.find("Raises hit by 1.5% (20+).", pattern), "matches with numbers")
        h.Nil(string.find("Raises hit by lots% (20+).", pattern), "a word is not a number")
        h.Nil(string.find("Equip: Raises hit by 1.5% (20+).", pattern), "anchored at the start")
    end,

    ["format pattern: numbered and precision placeholders are wildcards"] = function()
        h.True(string.find("by 12 and 3.50", Util.FormatPattern("by %1$d and %2$.2f")), "numbered")
    end,

    ["format pattern: with capture a placeholder captures any text"] = function()
        local pattern = Util.FormatPattern("Classes: %s", true)
        h.Equal(pattern, "^Classes: (.+)$", "the pattern")
        h.Equal(string.match("Classes: Warrior, Paladin", pattern), "Warrior, Paladin", "text")
    end,

    ["money: parts, no padding, zero parts dropped"] = function()
        h.Equal(Util.FormatMoney(0), "0c", "zero")
        h.Equal(Util.FormatMoney(35), "35c", "copper only")
        h.Equal(Util.FormatMoney(500), "5s", "silver only")
        h.Equal(Util.FormatMoney(10200), "1g 2s", "gold and silver")
        h.Equal(Util.FormatMoney(40100 + 900), "4g 10s", "silver 10 of 4g")
        h.Equal(Util.FormatMoney(10001), "1g 1c", "gold and copper")
        h.Equal(Util.FormatMoney(10000), "1g", "gold only")
        h.Equal(Util.FormatMoney(123456), "12g 34s 56c", "all three")
    end,
}
