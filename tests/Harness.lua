--[[
Builds the h table that run.py passes to every Test*.lua file: the fixture
loader, the assertions and the stub's control table (technical findings 17.1,
Test file contract). Called by run.py as chunk(Stub, testsDirectory).
]]

local Stub, testsDirectory = ...

local h = { Stub = Stub }

local MAX_DEPTH = 6

local function Describe(value, depth)
    depth = depth or 0
    if type(value) == "string" then
        return string.format("%q", value)
    end
    if type(value) ~= "table" then
        return tostring(value)
    end
    if depth >= MAX_DEPTH then
        return "{...}"
    end
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(first, second)
        return tostring(first) < tostring(second)
    end)
    local parts = {}
    for _, key in ipairs(keys) do
        local name = Describe(key, depth + 1)
        parts[#parts + 1] = string.format("[%s] = %s", name, Describe(value[key], depth + 1))
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function Fail(label, expected, actual)
    local message = string.format(
        "%s: expected %s, got %s",
        tostring(label),
        Describe(expected),
        Describe(actual)
    )
    error(message, 3)
end

local function SameValue(first, second, seen)
    if first == second then
        return true
    end
    if type(first) ~= "table" or type(second) ~= "table" then
        return false
    end
    if seen[first] == second then
        return true
    end
    seen[first] = second
    for key, value in pairs(first) do
        if not SameValue(value, second[key], seen) then
            return false
        end
    end
    for key in pairs(second) do
        if first[key] == nil then
            return false
        end
    end
    return true
end

--- Raises unless actual == expected.
-- @param actual any
-- @param expected any
-- @param label string names the check in the message
function h.Equal(actual, expected, label)
    if actual ~= expected then
        Fail(label, expected, actual)
    end
end

--- Raises unless the two values are equal, comparing tables by content.
-- @param actual any
-- @param expected any
-- @param label string names the check in the message
function h.DeepEqual(actual, expected, label)
    if not SameValue(actual, expected, {}) then
        Fail(label, expected, actual)
    end
end

--- Raises unless value is truthy.
-- @param value any
-- @param label string names the check in the message
function h.True(value, label)
    if not value then
        Fail(label, true, value)
    end
end

--- Raises unless value is nil.
-- @param value any
-- @param label string names the check in the message
function h.Nil(value, label)
    if value ~= nil then
        Fail(label, nil, value)
    end
end

--- Loads tests/fixtures/<name>.lua, a file that returns a table.
-- @param name string the file name without folder and extension
-- @treturn table the table the file returned
function h.Fixture(name)
    local path = testsDirectory .. "/fixtures/" .. name .. ".lua"
    local chunk, message = loadfile(path)
    if not chunk then
        error("fixture " .. name .. ": " .. tostring(message), 2)
    end
    return chunk()
end

return h
