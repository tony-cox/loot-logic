--[[
The saved data: the defaults tree (spec 6), schema migrations and the deep-fill
(technical findings 14, Saved data).

The client loads LootLogicDB from the TOC's SavedVariables line before it
fires ADDON_LOADED for this addon (from memory; technical findings 15 lists
the timing). This file registers the first handler of that event, because it
loads right after Events.lua and no earlier file registers one.
]]

local addonName, ns = ...

local DB = {}
ns.DB = DB

local Events = ns.Events
local Init = ns.Init
local L = ns.L
local Log = ns.Log
local Util = ns.Util

--- The defaults tree of spec 6. Keys whose default is nil (ui.wantsFor,
--- ui.point, debug.probe) are absent. A table with a first element is a list:
--- the deep-fill keeps a saved list whole.
DB.defaults = {
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
            -- Off in the M0 code; M1 changes it to on, M2 back to off with its
            -- migration (spec 6).
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
    debug = {
        enabled = false,
        log = {},
        maxLog = 300,
    },
}

--- migrations[n] upgrades the saved data from schema n-1 to n. It is called
--- with a copy of the data and changes that copy in place; it does not touch
--- LootLogicDB. It fails by raising an error; what it returns is ignored. M0
--- ships none (spec 6). Tests add entries and raise ns.Init.schemaVersion to
--- run the framework; a missing entry is skipped.
DB.migrations = {}

local readOnly = false
local noticePrinted = false
local readCopy

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

-- Fills saved from defaults without overwriting a saved value of the right
-- type. Tables merge key by key; a list default is one value; unknown keys
-- stay.
local function Fill(saved, defaults)
    for key, default in pairs(defaults) do
        local current = saved[key]
        if type(current) ~= type(default) then
            saved[key] = DeepCopy(default)
        elseif type(default) == "table" and default[1] == nil then
            Fill(current, default)
        end
    end
end

-- Puts the session in the read-only state: LootLogicDB stays as it is, and
-- DB.Data() hands out a default-filled copy built now.
local function EnterReadOnly(notice)
    readOnly = true
    Log.LockDebug(true)
    readCopy = DeepCopy(LootLogicDB)
    Fill(readCopy, DB.defaults)
    if not noticePrinted then
        noticePrinted = true
        Log.Chat(notice)
    end
end

--- A new copy of the defaults tree.
-- @treturn table
function DB.NewDefaults()
    return DeepCopy(DB.defaults)
end

--- True for the session when the saved schema was newer than the code's at
--- load, or a migration failed: LootLogicDB is left unchanged and the capture
--- functions of Snapshot.lua write nothing (spec 6, Notes: Migrations).
-- @treturn boolean
function DB.IsReadOnly()
    return readOnly
end

--- The saved data for code outside DB.lua to read: LootLogicDB, or in a
--- read-only session a copy of it deep-filled with the defaults, built once at
--- load and never assigned to the global (technical findings 14, Saved data).
-- @treturn table
function DB.Data()
    if readOnly then
        return readCopy
    end
    return LootLogicDB
end

--- Creates LootLogicDB when nil or not a table, runs the migrations from the
--- saved schema + 1 up to ns.Init.schemaVersion in order, then deep-fills the
--- defaults. A new table runs no migration. When the saved schema is newer, or
--- a migration fails, it changes nothing more, sets the read-only state and
--- prints a notice once. Runs from the ADDON_LOADED handler; tests may call
--- it.
function DB.Load()
    readOnly = false
    readCopy = nil
    Log.LockDebug(false)
    local target = Init.schemaVersion
    if type(LootLogicDB) ~= "table" then
        LootLogicDB = DB.NewDefaults()
        LootLogicDB.schema = target
        return
    end
    local db = LootLogicDB
    local saved = db.schema
    if type(saved) == "number" and saved > target then
        EnterReadOnly(L.dataNewer)
        return
    end
    -- A damaged schema (not a number, negative, fractional or NaN) is 0.
    if type(saved) ~= "number" or saved < 0 or saved ~= math.floor(saved) then
        saved = 0
    end
    for number = saved + 1, target do
        local migrate = DB.migrations[number]
        if migrate then
            local work = DeepCopy(db)
            -- A migration can fail on saved data from an older version that it
            -- does not expect (hand-edited or damaged).
            local ok, message = Util.Pcall(migrate, work)
            if not ok then
                EnterReadOnly(L.dataNotUpgraded)
                Log.Error("db", string.format("migration %d: %s", number, message))
                return
            end
            -- The table stays the same one: empty it, then copy the result in.
            for key in pairs(db) do
                db[key] = nil
            end
            for key, value in pairs(work) do
                db[key] = value
            end
        end
        db.schema = number
    end
    Fill(db, DB.defaults)
    db.schema = target
end

Events.Register("ADDON_LOADED", function(_, name)
    if name == addonName then
        DB.Load()
    end
end)
