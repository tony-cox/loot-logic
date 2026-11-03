local _, ns, h = ...

local Roster = ns.Roster

-- Registers characters with these first and last names (and an optional
-- override as the third value) and returns their display names in the same
-- order. The faction is mixed on purpose: eligibility plays no part.
local function Names(list)
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    local keys = {}
    for index, row in ipairs(list) do
        local key = row[1] .. " " .. row[2] .. "-Region"
        local faction = "Horde"
        if index % 2 == 0 then
            faction = "Alliance"
        end
        keys[index] = key
        LootLogicDB.characters[key] = {
            first = row[1],
            last = row[2],
            region = "Region",
            faction = faction,
            displayName = row[3],
        }
        LootLogicDB.order[index] = key
    end
    local names = {}
    for index, key in ipairs(keys) do
        names[index] = Roster.DisplayName(key)
    end
    return names
end

return {
    ["DisplayNames: a first name used once is the display name"] = function()
        h.DeepEqual(Names({ { "Zugar", "Sou" }, { "Boneset", "Hallowine" } }), {
            "Zugar",
            "Boneset",
        }, "names")
    end,

    ["DisplayNames: a character with no last name is its first name"] = function()
        h.DeepEqual(Names({ { "Zugar", "" } }), { "Zugar" }, "names")
    end,

    ["DisplayNames: Zugar Sou and Zugar Sun become Zugar o and Zugar u"] = function()
        h.DeepEqual(Names({ { "Zugar", "Sou" }, { "Zugar", "Sun" } }), {
            "Zugar o",
            "Zugar u",
        }, "names")
    end,

    ["DisplayNames: the surnames Tan and Tna give a and n"] = function()
        h.DeepEqual(Names({ { "Zugar", "Tan" }, { "Zugar", "Tna" } }), {
            "Zugar a",
            "Zugar n",
        }, "names")
    end,

    ["DisplayNames: the surnames Sou and Sunny give o and u"] = function()
        h.DeepEqual(Names({ { "Zugar", "Sou" }, { "Zugar", "Sunny" } }), {
            "Zugar o",
            "Zugar u",
        }, "names")
    end,

    ["DisplayNames: a surname that starts another gets the first name alone"] = function()
        h.DeepEqual(
            Names({ { "Chamoomile", "Rocketship" }, { "Chamoomile", "Rocketships" } }),
            { "Chamoomile", "Chamoomile s" },
            "names"
        )
    end,

    ["DisplayNames: the letter is compared ignoring case and kept as written"] = function()
        h.DeepEqual(Names({ { "Zugar", "sOu" }, { "Zugar", "sun" } }), {
            "Zugar O",
            "Zugar u",
        }, "names")
    end,

    ["DisplayNames: Tan, Tna and Tnn all get their full names"] = function()
        h.DeepEqual(Names({ { "Zugar", "Tan" }, { "Zugar", "Tna" }, { "Zugar", "Tnn" } }), {
            "Zugar Tan",
            "Zugar Tna",
            "Zugar Tnn",
        }, "names")
    end,

    ["DisplayNames: letters that differ only in case give full names"] = function()
        h.DeepEqual(Names({ { "Zugar", "Axx" }, { "Zugar", "Bay" }, { "Zugar", "Bbz" } }), {
            "Zugar Axx",
            "Zugar Bay",
            "Zugar Bbz",
        }, "names")
    end,

    ["DisplayNames: equal surnames ignoring case give full names"] = function()
        h.DeepEqual(Names({ { "Zugar", "Soul" }, { "Zugar", "SOUL" } }), {
            "Zugar Soul",
            "Zugar SOUL",
        }, "names")
    end,

    ["DisplayNames: surnames that start a longer one share the first name alone"] = function()
        h.DeepEqual(Names({ { "Zugar", "Ab" }, { "Zugar", "Abc" }, { "Zugar", "Abcd" } }), {
            "Zugar Ab",
            "Zugar Abc",
            "Zugar Abcd",
        }, "names")
    end,

    ["DisplayNames: the full-name fall-back covers the whole group only"] = function()
        h.DeepEqual(
            Names({
                { "Zugar", "Soul" },
                { "Zugar", "SOUL" },
                { "Boneset", "A" },
                { "Tana", "B" },
            }),
            { "Zugar Soul", "Zugar SOUL", "Boneset", "Tana" },
            "names"
        )
    end,

    ["DisplayNames: other first names do not affect a group"] = function()
        h.DeepEqual(
            Names({ { "Zugar", "Sou" }, { "Boneset", "Sun" }, { "Zugar", "Sun" } }),
            { "Zugar o", "Boneset", "Zugar u" },
            "names"
        )
    end,

    ["DisplayNames: an override is the display name and does not change the others"] = function()
        h.DeepEqual(Names({ { "Zugar", "Sou", "Zed" }, { "Zugar", "Sun" } }), {
            "Zed",
            "Zugar u",
        }, "names")
    end,

    ["DisplayNames: an override on a lone character replaces its first name"] = function()
        h.DeepEqual(Names({ { "Zugar", "Sou", "Zed" } }), { "Zed" }, "names")
    end,

    ["DisplayNames: an empty or non-string override is ignored"] = function()
        h.DeepEqual(Names({ { "Zugar", "Sou", "" }, { "Boneset", "Sun", 5 } }), {
            "Zugar",
            "Boneset",
        }, "names")
    end,

    ["DisplayNames: an automatic name equal to another override becomes the full name"] = function()
        h.DeepEqual(Names({ { "Foo", "Bar" }, { "Zugar", "Sou", "Foo" } }), {
            "Foo Bar",
            "Foo",
        }, "names")
    end,

    ["DisplayNames: a letter name equal to an override becomes the full name"] = function()
        h.DeepEqual(
            Names({
                { "Zugar", "Sou" },
                { "Zugar", "Sun" },
                { "Boneset", "Hallowine", "Zugar o" },
            }),
            { "Zugar Sou", "Zugar u", "Zugar o" },
            "names"
        )
    end,

    ["DisplayNames: a full name equal to an override gets the first free number"] = function()
        h.DeepEqual(
            Names({
                { "Foo", "Bar" },
                { "Zugar", "Sou", "Foo" },
                { "Boneset", "Hallowine", "Foo Bar" },
            }),
            { "Foo Bar 2", "Foo", "Foo Bar" },
            "names"
        )
    end,

    ["DisplayNames: a number already taken is skipped"] = function()
        h.DeepEqual(
            Names({
                { "Foo", "Bar" },
                { "Zugar", "Sou", "Foo" },
                { "Boneset", "Hallowine", "Foo Bar" },
                { "Tana", "Tan", "Foo Bar 2" },
            }),
            { "Foo Bar 3", "Foo", "Foo Bar", "Foo Bar 2" },
            "names"
        )
    end,

    ["DisplayNames: a name does not depend on eligibility"] = function()
        Names({ { "Zugar", "Sou" }, { "Zugar", "Sun" } })
        local before = Roster.DisplayNames()
        LootLogicDB.characters["Zugar Sun-Region"].faction = "Neutral"
        LootLogicDB.characters["Zugar Sun-Region"].region = "Elsewhere"
        h.DeepEqual(Roster.DisplayNames(), before, "names")
    end,

    ["DisplayNames: registering a second character renames the first"] = function()
        Names({ { "Zugar", "Sou" } })
        h.Equal(Roster.DisplayName("Zugar Sou-Region"), "Zugar", "before")
        LootLogicDB.characters["Zugar Sun-Region"] = { first = "Zugar", last = "Sun" }
        LootLogicDB.order[2] = "Zugar Sun-Region"
        h.Equal(Roster.DisplayName("Zugar Sou-Region"), "Zugar o", "after")
    end,

    ["DisplayNames: a letter is a whole UTF-8 character"] = function()
        h.DeepEqual(Names({ { "Zugar", "\195\160b" }, { "Zugar", "\195\169b" } }), {
            "Zugar \195\160",
            "Zugar \195\169",
        }, "names")
    end,

    ["DisplayNames: an entry without a first name is named by its key"] = function()
        Names({ { "Zugar", "Sou" } })
        LootLogicDB.characters.Broken = { last = "X" }
        LootLogicDB.characters.Worse = "text"
        local names = Roster.DisplayNames()
        h.Equal(names.Broken, "Broken", "broken")
        h.Equal(names.Worse, "Worse", "worse")
        h.Equal(names["Zugar Sou-Region"], "Zugar", "good entry")
    end,

    ["DisplayNames: an unknown key has no name"] = function()
        Names({ { "Zugar", "Sou" } })
        h.Nil(Roster.DisplayName("Nobody Known-Region"), "name")
    end,
}
