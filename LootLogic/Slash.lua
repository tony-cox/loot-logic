--[[
Command parsing for /ll and /lootlogic (technical findings 14). This stage
handles only "probe"; the help list and the other commands of spec 13 arrive
with later stages.
]]

local _, ns = ...

local Slash = {}
ns.Slash = Slash

local L = ns.L
local Log = ns.Log
local Probe = ns.Probe

--- Runs the command typed after /ll. The command word is case-insensitive;
--- words after "probe" are ignored (spec 13, errors rule 2). Anything else
--- prints one placeholder line for now.
-- @param message string the typed text after the slash command
function Slash.Run(message)
    local word = string.match(strtrim(message), "^(%S+)")
    if word and string.lower(word) == "probe" then
        Probe.Run()
        return
    end
    Log.Chat(L.slashPlaceholder)
end
