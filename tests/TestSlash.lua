local _, ns, h = ...

local L = ns.L
local Stub = h.Stub

local PREFIX = L.chatPrefix .. " "

local function Load()
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.ClearChat()
end

local function HasLine(text)
    for _, line in ipairs(Stub.ChatLines()) do
        if line == PREFIX .. text then
            return true
        end
    end
    return false
end

local function HasL2Line()
    for _, line in ipairs(Stub.ChatLines()) do
        if string.find(line, "^" .. PREFIX .. "L2 PASS ") then
            return true
        end
    end
    return false
end

local function RunsSaved()
    return LootLogicDB.debug.probe
end

local function ExpectProbe(message)
    Load()
    ns.Slash.Run(message)
    Stub.Advance(11)
    h.True(HasL2Line(), "the L2 line for '" .. message .. "'")
    h.True(HasLine(L.probeDone), "probe done for '" .. message .. "'")
end

local function ExpectPlaceholder(message)
    Load()
    ns.Slash.Run(message)
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.slashPlaceholder }, "chat for '" .. message .. "'")
    h.Nil(RunsSaved(), "nothing saved for '" .. message .. "'")
    h.Equal(#Stub.ChatLines(), 1, "nothing run for '" .. message .. "'")
end

return {
    ["Slash: probe runs the probe"] = function()
        ExpectProbe("probe")
    end,

    ["Slash: PROBE runs the probe (case-insensitive)"] = function()
        ExpectProbe("PROBE")
    end,

    ["Slash: a padded Probe runs the probe"] = function()
        ExpectProbe("  Probe  ")
    end,

    ["Slash: words after probe are ignored"] = function()
        ExpectProbe("probe extra words")
    end,

    ["Slash: bare /ll prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("")
    end,

    ["Slash: help prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("help")
    end,

    ["Slash: an unknown word prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("foo")
    end,

    ["Slash: a word that only starts with probe is not the probe command"] = function()
        ExpectPlaceholder("probes")
    end,

    ["Slash: an unknown word during a probe prints the placeholder"] = function()
        Load()
        ns.Slash.Run("probe")
        Stub.ClearChat()
        ns.Slash.Run("foo")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.slashPlaceholder }, "chat")
        Stub.Advance(11)
    end,
}
