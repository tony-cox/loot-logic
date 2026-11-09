--[[
The M1 chat lines at login (docs/ux.md 2.1, "Chat lines at login"): added,
first-run and no-price, printed together 5 seconds after PLAYER_LOGIN in that
order. Every decision is made when the lines print, not at login. Writes
nothing to the saved data and never calls Prices.Best or Classify.
]]

local _, ns = ...

local LoginLines = {}
ns.LoginLines = LoginLines

local L = ns.L
local Log = ns.Log
local DB = ns.DB
local Events = ns.Events
local Roster = ns.Roster
local Loadouts = ns.Loadouts
local Specs = ns.Specs
local Prices = ns.Prices

local DELAY_SECONDS = 5

-- The "added" line for a character registered at this login, or nil. The
-- class name is the first value of UnitClass (from memory, no live check;
-- Loadouts.lua reads it the same way) and the faction is the one stored at
-- login (live check L3).
local function AddedLine()
    local key = Roster.HereKey()
    if not key or not Roster.WasAddedThisSession(key) then
        return nil
    end
    local entry = Roster.Entry(key)
    if not entry then
        return nil
    end
    local name = Roster.DisplayName(key)
    local className = UnitClass("player")
    local spec = Loadouts.AssumedSpec(entry.class)
    if spec and Loadouts.HasWeights(spec) then
        return string.format(
            L.loginAdded,
            name,
            className,
            entry.level,
            entry.faction,
            Specs[spec].label
        )
    end
    return string.format(
        L.loginAddedNoTable,
        name,
        className,
        entry.level,
        entry.faction,
        className
    )
end

local function AnyPriceAvailable()
    for _, row in ipairs(Prices.Status()) do
        if row.available then
            return true
        end
    end
    return false
end

-- Gathers the three decisions first, then prints. Prices.Status can print the
-- provider error line, which then comes before the group.
local function PrintLines()
    local lines = {}
    local added = AddedLine()
    if added then
        lines[#lines + 1] = added
    end
    if not DB.Data().ui.firstRunDone then
        lines[#lines + 1] = L.loginFirstRun
        if not AnyPriceAvailable() then
            lines[#lines + 1] = L.loginNoPrice
        end
    end
    for _, line in ipairs(lines) do
        Log.Chat(line)
    end
end

-- The handler reads nothing: C_Timer.After only (live check L63 found that
-- Cancel does not stop a NewTimer callback), and no cancel is needed.
Events.Register("PLAYER_LOGIN", function()
    C_Timer.After(DELAY_SECONDS, function()
        Log.Guard("events", PrintLines)
    end)
end)
