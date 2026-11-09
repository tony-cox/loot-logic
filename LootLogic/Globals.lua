--[[
The only file that creates globals, apart from the frame names UI files
create (style guide 3): wiring only. The client
creates LootLogicDB from the TOC and Core/DB.lua fills it.
]]

local _, ns = ...

LootLogic = {
    API = ns.API,
    Slash = ns.Slash,
}

SLASH_LOOTLOGIC1 = "/ll"
SLASH_LOOTLOGIC2 = "/lootlogic"
-- From memory (API guess), no live check; docs/TESTING.md M1 step 1 types the
-- command in game. Fallback: /run LootLogic.Slash.Run("probe").
SlashCmdList.LOOTLOGIC = ns.Slash.Run

-- The TOC names this function for the addon compartment (D137; technical
-- findings 14). The client passes the addon name and the mouse button (API
-- guess; live check L50), which it ignores. In M1, which has no window, the
-- click does what bare /ll does.
function LootLogicOnCompartmentClick()
    ns.Slash.Run("")
end
