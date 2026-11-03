local _, ns, h = ...

local Generations = ns.Generations

local NAMES = { "asks", "gearHere", "gearOthers", "loadouts", "prices", "roster", "settings" }

return {
    ["Get starts equal for every name"] = function()
        for _, name in ipairs(NAMES) do
            h.Equal(Generations.Get(name), 0, "start of " .. name)
        end
        h.Equal(Generations.Total(), 0, "start of the total")
    end,

    ["Bump moves only its own counter and the total"] = function()
        Generations.Bump("prices")
        Generations.Bump("prices")
        Generations.Bump("asks")
        for _, name in ipairs(NAMES) do
            local expected = 0
            if name == "prices" then
                expected = 2
            elseif name == "asks" then
                expected = 1
            end
            h.Equal(Generations.Get(name), expected, "value of " .. name)
        end
        h.Equal(Generations.Total(), 3, "total")
    end,

    ["an unknown name raises in Bump and in Get"] = function()
        local okBump, messageBump = pcall(Generations.Bump, "bogus")
        h.Equal(okBump, false, "Bump raises")
        h.True(string.find(messageBump, "bogus", 1, true), "Bump message names the name")
        local okGet, messageGet = pcall(Generations.Get, "bogus")
        h.Equal(okGet, false, "Get raises")
        h.True(string.find(messageGet, "bogus", 1, true), "Get message names the name")
        h.Equal(Generations.Total(), 0, "a failed Bump adds nothing")
    end,

    ["each OnBump listener gets the bumped name once per bump, in order"] = function()
        local seen = {}
        Generations.OnBump(function(name)
            seen[#seen + 1] = "first:" .. name
        end)
        Generations.OnBump(function(name)
            seen[#seen + 1] = "second:" .. name
        end)
        Generations.Bump("roster")
        Generations.Bump("settings")
        h.DeepEqual(seen, {
            "first:roster",
            "second:roster",
            "first:settings",
            "second:settings",
        }, "listener calls")
    end,

    ["a listener sees the counter already moved"] = function()
        local atCall
        Generations.OnBump(function(name)
            atCall = tostring(Generations.Get(name)) .. "/" .. tostring(Generations.Total())
        end)
        Generations.Bump("loadouts")
        h.Equal(atCall, "1/1", "values inside the listener")
    end,
}
