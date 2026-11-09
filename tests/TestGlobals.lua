local _, ns, h = ...

local Stub = h.Stub

local function ReadFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function Lines()
    local copy = {}
    for index, line in ipairs(Stub.ChatLines()) do
        copy[index] = line
    end
    return copy
end

return {
    ["Globals: the compartment click does what bare /ll does"] = function()
        assert(loadfile("LootLogic/Globals.lua"))("LootLogic", ns)
        h.Equal(type(LootLogicOnCompartmentClick), "function", "global function")
        Stub.SetPlayer({ first = "Local", last = "Test", realm = "Realm", class = "WARLOCK" })
        LootLogicDB = nil
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        Stub.FireEvent("PLAYER_LOGIN")
        Stub.ClearChat()
        ns.Slash.Run("")
        local expected = Lines()
        h.True(#expected > 1, "bare /ll prints the help list and the checklist")
        Stub.ClearChat()
        LootLogicOnCompartmentClick("LootLogic", "LeftButton")
        h.DeepEqual(Lines(), expected, "the compartment click prints the same lines")
    end,

    ["Globals: the TOC names the compartment function and the icon, with LF endings"] = function()
        local toc = ReadFile("LootLogic/LootLogic.toc")
        h.Nil(string.find(toc, "\r", 1, true), "no carriage return")
        h.True(
            string.find(toc, "\n## AddonCompartmentFunc: LootLogicOnCompartmentClick\n", 1, true),
            "compartment line"
        )
        local icon = "\n## IconTexture: Interface\\AddOns\\LootLogic\\Art\\Icon\n"
        h.True(string.find(toc, icon, 1, true), "icon line")
    end,

    ["Globals: Art/Icon.tga is an uncompressed 64 by 64 32-bit TGA"] = function()
        local data = ReadFile("LootLogic/Art/Icon.tga")
        local function Byte(index)
            return string.byte(data, index)
        end
        h.Equal(Byte(2), 0, "no colour map")
        h.Equal(Byte(3), 2, "uncompressed true colour")
        h.Equal(Byte(13) + Byte(14) * 256, 64, "width")
        h.Equal(Byte(15) + Byte(16) * 256, 64, "height")
        h.Equal(Byte(17), 32, "bits per pixel")
        h.Equal(#data, 18 + 64 * 64 * 4, "header plus pixels")
    end,
}
