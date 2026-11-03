local _, ns, h = ...

local Stats = ns.Stats

local function Link(itemID)
    return string.format("|cffffffff|Hitem:%d:0:0:0:0:0:0:0:60|h[Test]|h|r", itemID)
end

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    LootLogicDB.debug.enabled = true
end

local function Lines()
    return LootLogicDB.debug.log
end

local function CountLines(text)
    local count = 0
    for _, line in ipairs(Lines()) do
        if string.find(line, text, 1, true) then
            count = count + 1
        end
    end
    return count
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = DeepCopy(inner)
    end
    return copy
end

-- A tooltip with the given lines for an item.
local function Tooltip(itemID, lines)
    h.Stub.SetTooltipLines(Link(itemID), lines)
    return Link(itemID)
end

local function EquipStat()
    return ITEM_SPELL_TRIGGER_ONEQUIP
        .. " "
        .. string.format(TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE, "1.5")
end

return {
    ["Stats: the game's keys map to the canonical keys"] = function()
        local link = Link(100)
        h.Stub.SetItem(100, {
            stats = {
                ITEM_MOD_CRIT_RATING_SHORT = 20,
                ITEM_MOD_STAMINA_SHORT = 12,
                ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40.5,
                ITEM_MOD_SPELL_POWER_SHORT = 25,
            },
        })
        h.DeepEqual(
            Stats.Get(link),
            { CRIT = 20, STA = 12, DPS = 40.5, SP = 25 },
            "canonical keys and values"
        )
    end,

    ["Stats: an item with no stats gives an empty table"] = function()
        h.Stub.SetItem(101, {})
        h.DeepEqual(Stats.Get(Link(101)), {}, "empty")
    end,

    ["Stats: a link is read once per session"] = function()
        local link = Link(102)
        h.Stub.SetItem(102, { stats = { ITEM_MOD_HIT_RATING_SHORT = 5 } })
        h.DeepEqual(Stats.Get(link), { HIT = 5 }, "first read")
        h.Stub.SetItem(102, { stats = { ITEM_MOD_HIT_RATING_SHORT = 9 } })
        h.DeepEqual(Stats.Get(link), { HIT = 5 }, "remembered")
    end,

    ["Stats: another roll of the item is a different link with its own stats"] = function()
        local first = "|Hitem:103:0:0:0:0:0:0:0:60|h[Test]|h"
        h.Stub.SetItem(103, { stats = { ITEM_MOD_STAMINA_SHORT = 7 } })
        h.DeepEqual(Stats.Get(first), { STA = 7 }, "first link")
        h.Stub.SetItem(103, { stats = { ITEM_MOD_STAMINA_SHORT = 8 } })
        local second = "|Hitem:103:0:0:0:0:0:-5:0:60|h[Test]|h"
        h.DeepEqual(Stats.Get(second), { STA = 8 }, "second link")
    end,

    ["Stats: an item that is not loaded gives nil and nothing is remembered"] = function()
        local link = Link(104)
        h.Stub.SetItemPending(104, { stats = { ITEM_MOD_AGILITY_SHORT = 3 } })
        h.Nil(Stats.Get(link), "pending")
        h.Stub.LoadItem(104)
        h.DeepEqual(Stats.Get(link), { AGI = 3 }, "after the data arrived")
    end,

    ["Stats: a secret value gives nil and nothing is remembered"] = function()
        local link = Link(105)
        h.Stub.SetItem(105, { stats = { ITEM_MOD_CRIT_RATING_SHORT = h.Stub.MakeSecret() } })
        h.Nil(Stats.Get(link), "secret")
        h.Stub.SetItem(105, { stats = { ITEM_MOD_CRIT_RATING_SHORT = 4 } })
        h.DeepEqual(Stats.Get(link), { CRIT = 4 }, "read again")
    end,

    ["Stats: an unknown key is ignored and logged once per key and session"] = function()
        Boot()
        h.Stub.SetItem(110, {
            stats = { ITEM_MOD_NEW_THING_SHORT = 3, ITEM_MOD_CRIT_RATING_SHORT = 1 },
        })
        h.Stub.SetItem(111, {
            stats = { ITEM_MOD_NEW_THING_SHORT = 4, ITEM_MOD_OTHER_THING_SHORT = 2 },
        })
        h.DeepEqual(Stats.Get(Link(110)), { CRIT = 1 }, "the unknown key is left out")
        h.DeepEqual(Stats.Get(Link(111)), {}, "second link")
        h.Equal(CountLines("stats: unknown stat key ITEM_MOD_NEW_THING_SHORT, ignored"), 1, "once")
        h.Equal(
            CountLines("stats: unknown stat key ITEM_MOD_OTHER_THING_SHORT, ignored"),
            1,
            "other"
        )
    end,

    ["Stats: an unknown key seen with debug off is logged when seen with debug on"] = function()
        Boot()
        LootLogicDB.debug.enabled = false
        h.Stub.SetItem(112, { stats = { ITEM_MOD_NEW_THING_SHORT = 3 } })
        h.Stub.SetItem(113, { stats = { ITEM_MOD_NEW_THING_SHORT = 3 } })
        Stats.Get(Link(112))
        LootLogicDB.debug.enabled = true
        Stats.Get(Link(113))
        h.Equal(CountLines("ITEM_MOD_NEW_THING_SHORT"), 1, "logged once, with debug on")
    end,

    ["Stats: reading stats stores nothing in the saved data"] = function()
        Boot()
        local before = DeepCopy(LootLogicDB)
        h.Stub.SetItem(114, { stats = { ITEM_MOD_CRIT_RATING_SHORT = 1 } })
        Stats.Get(Link(114))
        h.Stub.SetTooltipLines(Link(114), { "Use: something" })
        Stats.HasUnscoredEffect(Link(114))
        h.DeepEqual(LootLogicDB, before, "saved data unchanged")
    end,

    ["Stats: a Use line is an effect that is not scored"] = function()
        local link = Tooltip(200, { "Test Item", "Use: Restores 100 health.", EquipStat() })
        h.Equal(Stats.HasUnscoredEffect(link), true, "Use:")
    end,

    ["Stats: a Chance on hit line is an effect that is not scored"] = function()
        local link = Tooltip(201, { "Test Item", "Chance on hit: Deals 50 fire damage." })
        h.Equal(Stats.HasUnscoredEffect(link), true, "Chance on hit:")
    end,

    ["Stats: an Equip line that is not a stat is an effect that is not scored"] = function()
        local link = Tooltip(202, { "Equip: Gives you a chance to evade an attack." })
        h.Equal(Stats.HasUnscoredEffect(link), true, "non-stat Equip:")
    end,

    ["Stats: when every Equip line is a stat there is no effect"] = function()
        local link = Tooltip(203, {
            "Test Item",
            EquipStat(),
            ITEM_SPELL_TRIGGER_ONEQUIP
                .. " "
                .. string.format(TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE, 25),
            ITEM_SPELL_TRIGGER_ONEQUIP
                .. " "
                .. string.format(TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE, "2"),
        })
        h.Equal(Stats.HasUnscoredEffect(link), false, "stat lines only")
    end,

    ["Stats: a set bonus line is not an effect"] = function()
        local link = Tooltip(204, {
            "Test Item",
            EquipStat(),
            string.format(ITEM_SET_BONUS, "(2) Improves your chance to hit by 1%."),
        })
        h.Equal(Stats.HasUnscoredEffect(link), false, "Set:")
    end,

    ["Stats: a stat line and a use effect together count as an effect"] = function()
        local link = Tooltip(205, { EquipStat(), "Use: Heals you." })
        h.Equal(Stats.HasUnscoredEffect(link), true, "mixed")
    end,

    ["Stats: a tooltip with no Equip or effect lines has no effect"] = function()
        local link = Tooltip(206, { "Test Item", "Binds when picked up", "Requires Level 60" })
        h.Equal(Stats.HasUnscoredEffect(link), false, "plain")
    end,

    ["Stats: a stat format that carries the Equip prefix itself matches too"] = function()
        h.Stub.SetString(
            "TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE",
            "Equip: Increases your critical strike chance by %s%%."
        )
        local link = Tooltip(207, { "Equip: Increases your critical strike chance by 12.5%." })
        h.Equal(Stats.HasUnscoredEffect(link), false, "format with the prefix")
    end,

    ["Stats: no stat format strings leaves only Use and Chance on hit as effects"] = function()
        h.Stub.SetString("TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE", nil)
        h.Stub.SetString("TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE", nil)
        h.Stub.SetString("TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE", nil)
        local equip = Tooltip(208, { "Equip: Gives you a chance to evade an attack." })
        h.Equal(Stats.HasUnscoredEffect(equip), false, "an Equip line cannot be told")
        local use = Tooltip(209, { "Use: Heals you." })
        h.Equal(Stats.HasUnscoredEffect(use), true, "Use: still counts")
    end,

    ["Stats: with the effect prefixes missing too the suffix is dropped"] = function()
        h.Stub.SetString("TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE", nil)
        h.Stub.SetString("ITEM_SPELL_TRIGGER_ONEQUIP", nil)
        h.Stub.SetString("ITEM_SPELL_TRIGGER_ONUSE", nil)
        h.Stub.SetString("ITEM_SPELL_TRIGGER_ONPROC", nil)
        local link = Tooltip(210, { "Use: Heals you.", "Chance on hit: Burns." })
        h.Equal(Stats.HasUnscoredEffect(link), false, "never an effect")
    end,

    ["Stats: no tooltip yet gives nil and nothing is remembered"] = function()
        local link = Link(211)
        h.Nil(Stats.HasUnscoredEffect(link), "no tooltip")
        h.Stub.SetTooltipLines(link, { "Use: Heals you." })
        h.Equal(Stats.HasUnscoredEffect(link), true, "once the tooltip exists")
    end,

    ["Stats: a secret tooltip line gives nil and nothing is remembered"] = function()
        local link = Link(212)
        h.Stub.SetTooltipLines(link, { h.Stub.MakeSecret() })
        h.Nil(Stats.HasUnscoredEffect(link), "secret")
        h.Stub.SetTooltipLines(link, { "Test Item" })
        h.Equal(Stats.HasUnscoredEffect(link), false, "read again")
    end,

    ["Stats: the effect answer is kept with the stats for the session"] = function()
        local link = Tooltip(213, { "Use: Heals you." })
        h.Stub.SetItem(213, { stats = { ITEM_MOD_STAMINA_SHORT = 2 } })
        h.Equal(Stats.HasUnscoredEffect(link), true, "effect")
        h.DeepEqual(Stats.Get(link), { STA = 2 }, "stats alongside it")
        h.Stub.SetTooltipLines(link, { "Test Item" })
        h.Equal(Stats.HasUnscoredEffect(link), true, "remembered")
        h.Equal(h.Stub.TooltipCalls(), 1, "tooltip read once")
    end,
}
