--[[
The debug lines that the live checks L38 and L40 read, with debug turned on
through /ll debug on (M1 stage 2; technical findings 15, Debug log, and 18).
The lines of L13, L23 and L32 are asserted by the M0 tests of the files that
write them.
]]
local _, ns, h = ...

local Stub = h.Stub

-- A fresh database, logged in, debug on through the command.
local function StartWithDebug()
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.FireEvent("PLAYER_LOGIN")
    ns.Slash.Run("debug on")
    LootLogicDB.debug.log = {}
end

-- How many log lines end the "<area>: " part with the given text.
local function Count(text)
    local count = 0
    for _, line in ipairs(LootLogicDB.debug.log) do
        if string.find(line, "^%[%d%d:%d%d:%d%d%] " .. text:gsub("%p", "%%%0") .. "$") then
            count = count + 1
        end
    end
    return count
end

return {
    ["DebugChecks L38: MERCHANT_SHOW, AUCTION_HOUSE_SHOW and MAIL_SHOW log once each"] = function()
        StartWithDebug()
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        Stub.FireEvent("MAIL_SHOW")
        h.Equal(Count("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(Count("event: AUCTION_HOUSE_SHOW"), 1, "auction house")
        h.Equal(Count("event: MAIL_SHOW"), 1, "mail")
    end,

    ["DebugChecks L40: the bank events and the login arguments are logged"] = function()
        StartWithDebug()
        Stub.OpenBank()
        Stub.FireEvent("BAG_UPDATE_DELAYED")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 3)
        Stub.CloseBank()
        Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Equal(Count("event: BANKFRAME_OPENED"), 1, "opened")
        h.Equal(Count("event: BAG_UPDATE_DELAYED"), 1, "bag update")
        h.Equal(Count("event: PLAYERBANKSLOTS_CHANGED: 3"), 1, "bank slots")
        h.Equal(Count("event: BANKFRAME_CLOSED"), 1, "closed")
        h.Equal(Count("event: PLAYER_ENTERING_WORLD: true, false"), 1, "entering world")
        local text = table.concat(LootLogicDB.debug.log, "\n")
        h.True(string.find(text, "snapshot: bank:", 1, true), "bank snapshot line")
    end,
}
