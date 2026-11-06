--[[
Loadouts: a name plus a spec per entry of a character's loadouts list, with
exactly one worn (spec 6, 8.2, 9.2 and 13). Every change bumps the loadouts
generation. A read-only session writes nothing and refuses (spec 6, Notes:
Migrations). Names of characters come from Roster.lua; typed text is parsed in
M1.
]]

local _, ns = ...

local Loadouts = {}
ns.Loadouts = Loadouts

local DB = ns.DB
local Events = ns.Events
local Generations = ns.Generations
local Roster = ns.Roster
local Specs = ns.Specs
local WeightTables = ns.WeightTables

-- The saved entry of an editable character, or nil and the reason for a
-- refusal. Creates nothing.
local function Editable(key)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    local entry = DB.Data().characters[key]
    if not entry then
        return nil, "unknown"
    end
    return entry
end

local function MakeWorn(list, chosen)
    for _, loadout in ipairs(list) do
        loadout.worn = nil
    end
    chosen.worn = true
end

local function HasWorn(list)
    for _, loadout in ipairs(list) do
        if loadout.worn then
            return true
        end
    end
    return false
end

--- The class's assumed spec: the spec row carrying assumed = true (from M0 on
--- the four rows of the M1 tables, spec 8.2), or nil for any other class.
-- @param class string class token, such as "MAGE"
-- @treturn string|nil spec id
function Loadouts.AssumedSpec(class)
    for id, row in pairs(Specs) do
        if row.class == class and row.assumed then
            return id
        end
    end
    return nil
end

--- True when the spec has a shipped weight table, so a loadout may use it
--- (spec 8.2: a spec without a table is not offered).
-- @param spec string spec id
-- @treturn boolean
function Loadouts.HasWeights(spec)
    if WeightTables[spec] then
        return true
    end
    return false
end

--- A new default loadout for a character of the class: worn, assumed, with the
--- class's assumed spec and named after the spec's label, or after the class
--- name when the class has no assumed spec (spec 6, New characters).
-- @param class string class token
-- @param className string the client's name of the class, such as "Mage"
-- @treturn table loadout
function Loadouts.NewDefault(class, className)
    local spec = Loadouts.AssumedSpec(class)
    if spec then
        return { name = Specs[spec].label, spec = spec, worn = true, assumed = true }
    end
    return { name = className, worn = true, assumed = true }
end

--- The loadouts of a character, in order (the saved list).
-- @param key string character key
-- @treturn table list, empty for an unknown character
function Loadouts.List(key)
    local entry = DB.Data().characters[key]
    if not entry or type(entry.loadouts) ~= "table" then
        return {}
    end
    return entry.loadouts
end

--- The loadout with the name, ignoring case, and its index.
-- @param key string character key
-- @param name string
-- @treturn table|nil loadout
-- @treturn number|nil index
function Loadouts.Find(key, name)
    local lowered = string.lower(name)
    for index, loadout in ipairs(Loadouts.List(key)) do
        if type(loadout.name) == "string" and string.lower(loadout.name) == lowered then
            return loadout, index
        end
    end
    return nil
end

--- The worn loadout of a character, or nil.
-- @param key string character key
-- @treturn table|nil
function Loadouts.Worn(key)
    for _, loadout in ipairs(Loadouts.List(key)) do
        if loadout.worn then
            return loadout
        end
    end
    return nil
end

--- Adds a loadout, or edits the one with that name (ignoring case). Setting a
--- spec clears the assumed flag, also when the spec is the same; only a picked
--- spec set again, with no change to worn, is "unchanged". worn = true makes it
--- the worn loadout and clears the others; a loadout added to a list that has
--- no worn one becomes the worn one (spec 6: exactly one is worn). Only a spec
--- with a weight table is accepted (spec 8.2). A spec of another class is also
--- refused: the model does that as a guard, and no rule of the spec states it
--- (M1's parser only offers specs of the character's class). Bumps loadouts on
--- a change.
-- @param key string character key
-- @param name string loadout name
-- @param spec string spec id
-- @param worn boolean|nil true to make it the worn loadout
-- @treturn string|nil "added", "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly", "unknown", "noweights" or "wrongclass"
function Loadouts.Set(key, name, spec, worn)
    local entry, reason = Editable(key)
    if not entry then
        return nil, reason
    end
    if not Loadouts.HasWeights(spec) then
        return nil, "noweights"
    end
    if Specs[spec].class ~= entry.class then
        return nil, "wrongclass"
    end
    if type(entry.loadouts) ~= "table" then
        entry.loadouts = {}
    end
    local list = entry.loadouts
    local loadout = Loadouts.Find(key, name)
    local result
    if not loadout then
        loadout = { name = name, spec = spec, assumed = false }
        if not HasWorn(list) then
            loadout.worn = true
        end
        list[#list + 1] = loadout
        result = "added"
    elseif loadout.spec == spec and not loadout.assumed and not (worn and not loadout.worn) then
        return "unchanged"
    else
        loadout.spec = spec
        loadout.assumed = false
        result = "changed"
    end
    if worn then
        MakeWorn(list, loadout)
    end
    Generations.Bump("loadouts")
    return result
end

--- Makes the named loadout the worn one, clearing the others.
-- @param key string character key
-- @param name string loadout name
-- @treturn string|nil "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly", "unknown" or "noloadout"
function Loadouts.SetWorn(key, name)
    local entry, reason = Editable(key)
    if not entry then
        return nil, reason
    end
    local loadout = Loadouts.Find(key, name)
    if not loadout then
        return nil, "noloadout"
    end
    if loadout.worn then
        return "unchanged"
    end
    MakeWorn(entry.loadouts, loadout)
    Generations.Bump("loadouts")
    return "changed"
end

--- Removes the named loadout. The worn loadout is never removed.
-- @param key string character key
-- @param name string loadout name
-- @treturn string|nil "removed"; nil after a refusal
-- @treturn string|nil "readonly", "unknown", "noloadout" or "worn"
function Loadouts.Remove(key, name)
    local entry, reason = Editable(key)
    if not entry then
        return nil, reason
    end
    local loadout, index = Loadouts.Find(key, name)
    if not loadout then
        return nil, "noloadout"
    end
    if loadout.worn then
        return nil, "worn"
    end
    table.remove(entry.loadouts, index)
    Generations.Bump("loadouts")
    return "removed"
end

--- Sets the loadout's armour rule: "best", "any", or nil to follow the
--- bestArmorOnly setting (spec 8.3).
-- @param key string character key
-- @param name string loadout name
-- @param armor string|nil
-- @treturn string|nil "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly", "unknown" or "noloadout"
function Loadouts.SetArmor(key, name, armor)
    local entry, reason = Editable(key)
    if not entry then
        return nil, reason
    end
    local loadout = Loadouts.Find(key, name)
    if not loadout then
        return nil, "noloadout"
    end
    if loadout.armor == armor then
        return "unchanged"
    end
    loadout.armor = armor
    Generations.Bump("loadouts")
    return "changed"
end

-- After the roster entry (Roster.lua loads first, so its handler runs first):
-- a character with no loadout gets the default one.
Events.Register("PLAYER_LOGIN", function()
    if DB.IsReadOnly() then
        return
    end
    local key = Roster.HereKey()
    local entry = key and DB.Data().characters[key]
    if not entry then
        return
    end
    if type(entry.loadouts) == "table" and #entry.loadouts > 0 then
        local changed = false
        for index = #entry.loadouts, 1, -1 do
            local spec = Specs[entry.loadouts[index].spec]
            if spec and spec.class ~= entry.class then
                table.remove(entry.loadouts, index)
                changed = true
            end
        end
        if #entry.loadouts > 0 then
            if changed then
                if not HasWorn(entry.loadouts) then
                    MakeWorn(entry.loadouts, entry.loadouts[1])
                end
                Generations.Bump("loadouts")
            end
            return
        end
    end
    -- The client's class name, such as "Mage" (the first value of UnitClass;
    -- from memory, no live check yet).
    local className = UnitClass("player")
    entry.loadouts = { Loadouts.NewDefault(entry.class, className) }
    Generations.Bump("loadouts")
end)
