local _, ns, h = ...

local DB = ns.DB
local L = ns.L

local function Load()
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
end

return {
    ["an empty first load gets the whole defaults tree"] = function()
        LootLogicDB = nil
        Load()
        h.DeepEqual(LootLogicDB, DB.NewDefaults(), "saved data")
        h.Equal(LootLogicDB.schema, 1, "schema")
        h.Equal(DB.IsReadOnly(), false, "read-only")
    end,

    ["the defaults are the whole spec 6 tree"] = function()
        h.DeepEqual(DB.defaults, {
            schema = 1,
            settings = {
                ah = {
                    ahCutPct = 5,
                    minGainCopper = 100,
                    minGainPct = 10,
                    maxPriceAgeDays = 7,
                    requireLastScan = false,
                    providerOrder = { "ahdb", "auctionator" },
                },
                gear = {
                    lookAheadLevels = 5,
                    hereWinsInLookAhead = true,
                    minUpgradePct = 1,
                    bestArmorOnly = true,
                    itemLevelFallback = true,
                },
                staleDays = 14,
                notify = {
                    staleSnapshot = true,
                    scanSummary = true,
                    mailRecorded = false,
                    mailUpgrade = true,
                },
                classOverride = {},
                display = {
                    tooltip = true,
                    overlay = true,
                    tooltipNoWant = true,
                    badge = {
                        enabled = true,
                        position = "TOPRIGHT",
                        size = 12,
                        smallFallback = 26,
                    },
                    palette = "auto",
                },
                adapters = {
                    betterbags = { enabled = true },
                    bagbrother = { enabled = true },
                    arkinventory = { enabled = true },
                    ellesmere = { enabled = true },
                    blizzard = { enabled = true },
                },
            },
            ui = {
                firstRunDone = false,
                lastTab = "contents",
                scale = 1,
                checklistHidden = false,
                minimap = { hide = false, angle = 215 },
                ack = {},
                autoOpenContents = false,
            },
            order = {},
            characters = {},
            protectGlobal = {},
            debug = { enabled = false, log = {}, maxLog = 300 },
        }, "defaults")
    end,

    ["NewDefaults returns a copy that does not alias the defaults"] = function()
        local copy = DB.NewDefaults()
        copy.settings.ah.providerOrder[1] = "changed"
        copy.settings.ah.ahCutPct = 99
        h.Equal(DB.defaults.settings.ah.providerOrder[1], "ahdb", "list untouched")
        h.Equal(DB.defaults.settings.ah.ahCutPct, 5, "value untouched")
    end,

    ["a first load does not alias the defaults"] = function()
        LootLogicDB = { schema = 1, settings = { ah = "oops" } }
        Load()
        LootLogicDB.settings.ah.providerOrder[1] = "changed"
        LootLogicDB.ui.minimap.angle = 1
        h.Equal(DB.defaults.settings.ah.providerOrder[1], "ahdb", "list untouched")
        h.Equal(DB.defaults.ui.minimap.angle, 215, "nested value untouched")
    end,

    ["the read-only copy does not alias the defaults"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        Load()
        DB.Data().settings.ah.providerOrder[1] = "changed"
        DB.Data().ui.minimap.angle = 1
        h.Equal(DB.defaults.settings.ah.providerOrder[1], "ahdb", "list untouched")
        h.Equal(DB.defaults.ui.minimap.angle, 215, "nested value untouched")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
    end,

    ["deep-fill keeps every saved value and fills only missing keys"] = function()
        LootLogicDB = {
            schema = 1,
            settings = {
                ah = { ahCutPct = 15, requireLastScan = true },
                display = { badge = { size = 20 }, palette = "colorblind" },
                staleDays = 3,
            },
            ui = { lastTab = "status", minimap = { angle = 10 } },
            characters = { ["A B-US"] = { level = 5 } },
            order = { "A B-US" },
        }
        Load()
        local expected = DB.NewDefaults()
        expected.settings.ah.ahCutPct = 15
        expected.settings.ah.requireLastScan = true
        expected.settings.display.badge.size = 20
        expected.settings.display.palette = "colorblind"
        expected.settings.staleDays = 3
        expected.ui.lastTab = "status"
        expected.ui.minimap.angle = 10
        expected.characters = { ["A B-US"] = { level = 5 } }
        expected.order = { "A B-US" }
        h.DeepEqual(LootLogicDB, expected, "saved data")
    end,

    ["deep-fill keeps a saved false over a true default"] = function()
        LootLogicDB = { schema = 1, settings = { gear = { bestArmorOnly = false } } }
        Load()
        h.Equal(LootLogicDB.settings.gear.bestArmorOnly, false, "bestArmorOnly")
        h.Equal(LootLogicDB.settings.gear.lookAheadLevels, 5, "filled sibling")
    end,

    ["a saved list is kept whole, not merged by index"] = function()
        LootLogicDB = { schema = 1, settings = { ah = { providerOrder = { "auctionator" } } } }
        Load()
        h.DeepEqual(LootLogicDB.settings.ah.providerOrder, { "auctionator" }, "providerOrder")
    end,

    ["a missing list is filled with the default list"] = function()
        LootLogicDB = { schema = 1, settings = { ah = {} } }
        Load()
        h.DeepEqual(
            LootLogicDB.settings.ah.providerOrder,
            { "ahdb", "auctionator" },
            "providerOrder"
        )
    end,

    ["a saved value of the wrong type is replaced by the default"] = function()
        LootLogicDB = {
            schema = 1,
            settings = { ah = "oops", staleDays = "many", display = { tooltip = 1 } },
            ui = { minimap = false },
            characters = 5,
        }
        Load()
        local defaults = DB.NewDefaults()
        h.DeepEqual(LootLogicDB.settings.ah, defaults.settings.ah, "table replaced")
        h.Equal(LootLogicDB.settings.staleDays, 14, "number replaced")
        h.Equal(LootLogicDB.settings.display.tooltip, true, "boolean replaced")
        h.DeepEqual(LootLogicDB.ui.minimap, defaults.ui.minimap, "minimap replaced")
        h.DeepEqual(LootLogicDB.characters, {}, "characters replaced")
    end,

    ["unknown keys are kept"] = function()
        LootLogicDB = { schema = 1, futureKey = { 1 }, settings = { ah = { extra = "x" } } }
        Load()
        h.DeepEqual(LootLogicDB.futureKey, { 1 }, "top level")
        h.Equal(LootLogicDB.settings.ah.extra, "x", "nested")
    end,

    ["a second load changes nothing"] = function()
        LootLogicDB = nil
        Load()
        local first = DB.NewDefaults()
        Load()
        h.DeepEqual(LootLogicDB, first, "saved data")
    end,

    ["another addon's ADDON_LOADED does nothing"] = function()
        LootLogicDB = nil
        h.Stub.FireEvent("ADDON_LOADED", "SomethingElse")
        h.Nil(LootLogicDB, "saved data")
    end,

    ["the handler runs before any handler registered later"] = function()
        LootLogicDB = nil
        local seen
        ns.Events.Register("ADDON_LOADED", function()
            if LootLogicDB then
                seen = LootLogicDB.schema
            end
        end)
        Load()
        h.Equal(seen, 1, "schema seen by a later handler")
    end,

    ["two injected migrations run in order and set the schema"] = function()
        local calls = {}
        DB.migrations[2] = function(db)
            calls[#calls + 1] = "2 at schema " .. tostring(db.schema)
            db.two = true
        end
        DB.migrations[3] = function(db)
            calls[#calls + 1] = "3 saw two=" .. tostring(db.two)
            db.three = true
        end
        ns.Init.schemaVersion = 3
        LootLogicDB = { schema = 1 }
        Load()
        h.DeepEqual(calls, { "2 at schema 1", "3 saw two=true" }, "calls")
        h.Equal(LootLogicDB.schema, 3, "schema")
        h.Equal(LootLogicDB.three, true, "migration effect kept")
        h.Equal(LootLogicDB.settings.staleDays, 14, "defaults filled after")
        h.Equal(DB.IsReadOnly(), false, "read-only")
    end,

    ["migrations start after the saved schema"] = function()
        local calls = {}
        DB.migrations[2] = function()
            calls[#calls + 1] = 2
        end
        DB.migrations[3] = function()
            calls[#calls + 1] = 3
        end
        ns.Init.schemaVersion = 3
        LootLogicDB = { schema = 2 }
        Load()
        h.DeepEqual(calls, { 3 }, "calls")
        h.Equal(LootLogicDB.schema, 3, "schema")
    end,

    ["a negative or fractional saved schema is treated as 0 and still loads"] = function()
        local calls = {}
        DB.migrations[1] = function()
            calls[#calls + 1] = 1
        end
        DB.migrations[2] = function()
            calls[#calls + 1] = 2
        end
        ns.Init.schemaVersion = 2
        for _, damaged in ipairs({ -1e20, -1, 0.5, 1.5 }) do
            calls = {}
            LootLogicDB = { schema = damaged }
            Load()
            h.DeepEqual(calls, { 1, 2 }, "calls for " .. tostring(damaged))
            h.Equal(LootLogicDB.schema, 2, "schema for " .. tostring(damaged))
            h.Equal(DB.IsReadOnly(), false, "read-only for " .. tostring(damaged))
        end
    end,

    ["a migration sees the data before the defaults are filled"] = function()
        local sawSettings = "unset"
        DB.migrations[2] = function(db)
            sawSettings = db.settings
        end
        ns.Init.schemaVersion = 2
        LootLogicDB = { schema = 1 }
        Load()
        h.Nil(sawSettings, "settings during the migration")
    end,

    ["a failing migration leaves the data unchanged, read-only, with one notice"] = function()
        DB.migrations[2] = function(db)
            db.two = true
            db.settings = nil
        end
        DB.migrations[3] = function(db)
            db.three = true
            error("boom")
        end
        ns.Init.schemaVersion = 3
        LootLogicDB = { schema = 1, settings = { staleDays = 3 }, other = "x" }
        h.Stub.ClearChat()
        Load()
        Load()
        h.DeepEqual(LootLogicDB, { schema = 2, two = true, other = "x" }, "data after step 2")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        h.Equal(ns.Log.Errors()[1].area, "db", "area")
        h.DeepEqual(h.Stub.ChatLines(), { L.chatPrefix .. " " .. L.dataNotUpgraded }, "chat")
        h.Equal(DB.Data().settings.ah.maxPriceAgeDays, 7, "Data is filled")
        h.Nil(LootLogicDB.settings, "global not filled")
    end,

    ["a failed migration turns debug off and writes nothing"] = function()
        DB.migrations[2] = function()
            error("boom", 0)
        end
        ns.Init.schemaVersion = 2
        LootLogicDB = { schema = 1, debug = { enabled = true, log = { "old" }, maxLog = 50 } }
        Load()
        -- Only the event line of this ADDON_LOADED, written before DB's handler
        -- ran; the db error line is not.
        local logAfterLoad = { "old", "[00:00:00] event: ADDON_LOADED: LootLogic" }
        h.DeepEqual(LootLogicDB.debug.log, logAfterLoad, "only the event line")
        ns.Log.Error("db", "later")
        ns.Events.Register("PLAYER_LOGIN", function() end)
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(ns.Log.IsDebugOn(), false, "debug")
        h.DeepEqual(LootLogicDB.debug.log, logAfterLoad, "debug.log")
        h.Equal(#ns.Log.Errors(), 2, "errors still recorded")
    end,

    ["a failing migration leaves the saved table as it was"] = function()
        DB.migrations[2] = function(db)
            db.renamed = db.old
            db.old = nil
            error("boom", 0)
        end
        ns.Init.schemaVersion = 2
        LootLogicDB = { schema = 1, old = "value" }
        Load()
        h.DeepEqual(LootLogicDB, { schema = 1, old = "value" }, "saved data")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        h.Equal(ns.Log.Errors()[1].message, "migration 2: boom", "message")
    end,

    ["a migration that succeeds replaces the data in the same table"] = function()
        local before = { schema = 1 }
        LootLogicDB = before
        DB.migrations[2] = function(db)
            db.two = true
        end
        ns.Init.schemaVersion = 2
        Load()
        h.True(LootLogicDB == before, "same table")
        h.Equal(before.two, true, "migration effect")
    end,

    ["a first load runs no migration and gets the code's schema"] = function()
        local called = false
        DB.migrations[2] = function()
            called = true
        end
        ns.Init.schemaVersion = 2
        LootLogicDB = nil
        Load()
        h.Equal(called, false, "migration called")
        h.Equal(LootLogicDB.schema, 2, "schema")
        h.Equal(LootLogicDB.settings.staleDays, 14, "defaults filled")
        h.Equal(DB.IsReadOnly(), false, "read-only")
    end,

    ["a saved LootLogicDB that is not a table is replaced by the defaults"] = function()
        for _, bad in ipairs({ "x", 5, true }) do
            LootLogicDB = bad
            Load()
            h.DeepEqual(LootLogicDB, DB.NewDefaults(), "replaced " .. tostring(bad))
        end
    end,

    ["a newer saved schema leaves the data unchanged and read-only"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        Load()
        h.Equal(DB.IsReadOnly(), true, "read-only")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
    end,

    ["a newer saved schema prints the notice once"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.ClearChat()
        Load()
        Load()
        h.DeepEqual(h.Stub.ChatLines(), { L.chatPrefix .. " " .. L.dataNewer }, "chat lines")
    end,

    ["a newer saved schema stays unchanged through ADDON_LOADED and PLAYER_LOGIN"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        ns.Events.Register("PLAYER_LOGIN", function() end)
        h.Stub.ClearChat()
        Load()
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        h.Equal(ns.Log.IsDebugOn(), false, "debug")
        for _, line in ipairs(h.Stub.ChatLines()) do
            h.Equal(string.find(line, L.debugPrefix, 1, true), nil, "no debug line: " .. line)
        end
    end,

    ["Data returns a default-filled copy under a newer schema"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        Load()
        h.Equal(DB.Data().settings.ah.maxPriceAgeDays, 7, "filled default")
        h.Equal(DB.Data().ui.lastTab, "status", "stored value kept")
        h.True(DB.Data() ~= LootLogicDB, "a copy")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        h.True(DB.Data() == DB.Data(), "built once")
    end,

    ["Data returns LootLogicDB when the session is not read-only"] = function()
        LootLogicDB = nil
        Load()
        h.True(DB.Data() == LootLogicDB, "same table")
    end,

    ["a newer saved schema runs no migration"] = function()
        local called = false
        DB.migrations[2] = function()
            called = true
        end
        ns.Init.schemaVersion = 2
        LootLogicDB = { schema = 5 }
        Load()
        h.Equal(called, false, "migration called")
        h.DeepEqual(LootLogicDB, { schema = 5 }, "saved data")
    end,

    ["the read-only state is per load: an older saved schema clears it"] = function()
        LootLogicDB = { schema = 99 }
        Load()
        h.Equal(DB.IsReadOnly(), true, "first")
        LootLogicDB = { schema = 1, debug = { enabled = true, log = {}, maxLog = 300 } }
        Load()
        h.Equal(DB.IsReadOnly(), false, "second")
        h.Equal(ns.Log.IsDebugOn(), true, "debug follows the read-only state")
    end,

    ["M0 ships no migration"] = function()
        h.Nil(next(DB.migrations), "migrations")
    end,
}
