--[[
The addon version and the constants the other files share.
]]

local addonName, ns = ...

local Init = {}
ns.Init = Init

--- The schema number this code writes (spec 6: 1 in M0 and M1).
Init.schemaVersion = 1

--- The addon's version, read from the TOC's Version line. An unpackaged copy
--- returns the unreplaced "@project-version@".
-- Unverified: C_AddOns.GetAddOnMetadata exists on the Forever client (live
-- check L63; fallback: the global GetAddOnMetadata).
-- @treturn string|nil version
function Init.Version()
    return C_AddOns.GetAddOnMetadata(addonName, "Version")
end
