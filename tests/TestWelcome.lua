local _, ns, h = ...

local L = ns.L
local Stub = h.Stub

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, inner in pairs(value) do
        result[key] = Copy(inner)
    end
    return result
end

local function GenerationSnapshot()
    local names = { "asks", "gearHere", "gearOthers", "loadouts", "prices", "roster", "settings" }
    local snapshot = { total = ns.Generations.Total() }
    for _, name in ipairs(names) do
        snapshot[name] = ns.Generations.Get(name)
    end
    return snapshot
end

-- Boots a character on a fresh account, or on the given saved data.
local function Boot(database)
    Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = "WARLOCK",
        className = "Warlock",
        level = 60,
    })
    LootLogicDB = database
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.FireEvent("PLAYER_LOGIN")
    Stub.ClearChat()
end

local function Texts(frame)
    local texts = {}
    for _, region in ipairs(frame.regions) do
        texts[#texts + 1] = region:GetText()
    end
    return texts
end

local function ButtonNamed(frame, label)
    for _, child in ipairs(frame.children) do
        if child.frameType == "Button" and child:GetText() == label then
            return child
        end
    end
end

local function CloseButton(frame)
    for _, child in ipairs(frame.children) do
        if child.template == "UIPanelCloseButton" then
            return child
        end
    end
end

local function IsShown()
    return LootLogicWelcome ~= nil and LootLogicWelcome:IsShown()
end

-- Boots a fresh account and runs the clock to the moment the dialog shows,
-- after the login chat lines have printed.
local function OpenDialog()
    Boot(nil)
    Stub.Advance(5)
    Stub.ClearChat()
    return LootLogicWelcome
end

local function Lines()
    local copy = {}
    for index, line in ipairs(Stub.ChatLines()) do
        copy[index] = line
    end
    return copy
end

-- The saved data a close may change: only ui.firstRunDone.
local function ExpectOnlyFlagChanged(before, generations)
    local expected = Copy(before)
    expected.ui.firstRunDone = true
    h.DeepEqual(LootLogicDB, expected, "only ui.firstRunDone changed")
    h.DeepEqual(GenerationSnapshot(), generations, "generations unchanged")
end

local function ExpectClosed(dialog)
    h.Equal(dialog:IsShown(), false, "hidden")
    h.Equal(LootLogicDB.ui.firstRunDone, true, "flag set")
    h.DeepEqual(Lines(), {}, "no chat line")
    Stub.Advance(120)
    h.Equal(dialog:IsShown(), false, "not shown again")
end

return {
    ["Welcome: no frame is built at load or before the first check"] = function()
        Boot(nil)
        local count = #Stub.Frames()
        Stub.Advance(4.9)
        h.Nil(LootLogicWelcome, "no global yet")
        h.Equal(#Stub.Frames(), count, "no frame created")
    end,

    ["Welcome: shows at 5 seconds with the documented frame settings"] = function()
        Boot(nil)
        Stub.Advance(4.9)
        h.Equal(IsShown(), false, "not at 4.9")
        Stub.Advance(0.1)
        h.Equal(IsShown(), true, "shown at 5")
        local dialog = LootLogicWelcome
        h.Equal(dialog:GetFrameStrata(), "DIALOG", "strata")
        h.Equal(dialog:GetParent(), UIParent, "parent")
        h.Equal(dialog:IsKeyboardEnabled(), false, "no keyboard focus")
        h.Equal(dialog:IsMovable(), true, "movable")
        h.DeepEqual(dialog.dragButtons, { "LeftButton" }, "drag with the left button")
        h.Equal(dialog.name, "LootLogicWelcome", "frame name")
        h.DeepEqual(UISpecialFrames, { "LootLogicWelcome" }, "listed for Escape")
        h.Equal(dialog.points[1][1], "TOP", "anchored at the upper middle")
        h.Equal(
            dialog.backdrop.bgFile,
            "Interface\\DialogFrame\\UI-DialogBox-Background",
            "backdrop background path"
        )
        h.Equal(
            dialog.backdrop.edgeFile,
            "Interface\\DialogFrame\\UI-DialogBox-Border",
            "backdrop border path"
        )
        dialog:GetScript("OnDragStart")(dialog)
        h.Equal(dialog.moving, true, "dragging moves it")
        dialog:GetScript("OnDragStop")(dialog)
        h.Equal(dialog.moving, false, "drag stop stops it")
        h.Equal(dialog.userPlaced, false, "the dragged position is not kept")
        h.DeepEqual(
            Texts(dialog),
            { L.welcomeTitle, L.welcomeAbout, L.welcomeOptional },
            "texts from L"
        )
        h.True(ButtonNamed(dialog, L.welcomeShowCommands), "Show commands button")
        h.True(ButtonNamed(dialog, L.welcomeNotNow), "Not now button")
        h.True(CloseButton(dialog), "close button")
    end,

    ["Welcome: never shown when the flag is already set"] = function()
        Boot(nil)
        LootLogicDB.ui.firstRunDone = true
        Stub.FireEvent("PLAYER_LOGIN")
        Stub.Advance(300)
        h.Nil(LootLogicWelcome, "no frame")
    end,

    ["Welcome: waits out combat and shows at the next check"] = function()
        Stub.SetCombat(true)
        Boot(nil)
        Stub.Advance(5)
        h.Equal(IsShown(), false, "in combat at 5")
        Stub.Advance(3)
        h.Equal(IsShown(), false, "in combat at 8")
        Stub.SetCombat(false)
        Stub.FireEvent("PLAYER_REGEN_ENABLED")
        h.Equal(IsShown(), false, "the end of combat does not show it")
        Stub.Advance(0.9)
        h.Equal(IsShown(), false, "not before the check at 9")
        Stub.Advance(0.1)
        h.Equal(IsShown(), true, "shown at 9")
    end,

    ["Welcome: waits for StaticPopup1 to close"] = function()
        Stub.SetPopupShown(1, true)
        Boot(nil)
        Stub.Advance(8)
        h.Equal(IsShown(), false, "blocked")
        Stub.SetPopupShown(1, false)
        Stub.Advance(0.9)
        h.Equal(IsShown(), false, "no early check")
        Stub.Advance(0.1)
        h.Equal(IsShown(), true, "shown at 9")
    end,

    ["Welcome: waits for StaticPopup2 to close"] = function()
        Stub.SetPopupShown(2, true)
        Boot(nil)
        Stub.Advance(8)
        h.Equal(IsShown(), false, "blocked")
        Stub.SetPopupShown(2, false)
        Stub.Advance(1)
        h.Equal(IsShown(), true, "shown at 9")
    end,

    ["Welcome: waits for StaticPopup3 to close"] = function()
        Stub.SetPopupShown(3, true)
        Boot(nil)
        Stub.Advance(8)
        h.Equal(IsShown(), false, "blocked")
        Stub.SetPopupShown(3, false)
        Stub.Advance(1)
        h.Equal(IsShown(), true, "shown at 9")
    end,

    ["Welcome: waits for StaticPopup4 to close"] = function()
        Stub.SetPopupShown(4, true)
        Boot(nil)
        Stub.Advance(8)
        h.Equal(IsShown(), false, "blocked")
        Stub.SetPopupShown(4, false)
        Stub.Advance(1)
        h.Equal(IsShown(), true, "shown at 9")
    end,

    ["Welcome: a missing StaticPopup counts as not shown"] = function()
        Stub.SetGlobal("StaticPopup3", nil)
        Boot(nil)
        Stub.Advance(5)
        h.Equal(IsShown(), true, "shown")
    end,

    ["Welcome: the last check is at 59 seconds and giving up writes nothing"] = function()
        Stub.SetCombat(true)
        Boot(nil)
        local saved = Copy(LootLogicDB)
        Stub.Advance(59)
        Stub.SetCombat(false)
        Stub.Advance(300)
        h.Nil(LootLogicWelcome, "no frame")
        h.DeepEqual(LootLogicDB, saved, "nothing written")
        h.Equal(LootLogicDB.ui.firstRunDone, false, "flag still false")
    end,

    ["Welcome: a check at 59 seconds still shows it"] = function()
        Stub.SetCombat(true)
        Boot(nil)
        Stub.Advance(58.9)
        Stub.SetCombat(false)
        Stub.Advance(0.1)
        h.Equal(IsShown(), true, "shown at 59")
    end,

    ["Welcome: a check that runs late, after 60 seconds, does not show it"] = function()
        Boot(nil)
        Stub.JumpClock(70)
        Stub.Advance(0)
        h.Nil(LootLogicWelcome, "no frame")
    end,

    ["Welcome: a dialog that gave up shows at the next login"] = function()
        Stub.SetCombat(true)
        Boot(nil)
        Stub.Advance(300)
        Stub.SetCombat(false)
        h.Nil(LootLogicWelcome, "gave up")
        Stub.FireEvent("PLAYER_LOGIN")
        Stub.Advance(5)
        h.Equal(IsShown(), true, "shown at the next login")
    end,

    ["Welcome: shown once, with no second frame"] = function()
        Boot(nil)
        Stub.Advance(5)
        local count = #Stub.Frames()
        Stub.Advance(120)
        h.Equal(#Stub.Frames(), count, "no second frame")
        h.Equal(#UISpecialFrames, 1, "listed once")
    end,

    ["Welcome: showing writes nothing and bumps no generation"] = function()
        Boot(nil)
        local saved = Copy(LootLogicDB)
        local generations = GenerationSnapshot()
        Stub.Advance(10)
        h.Equal(IsShown(), true, "shown")
        h.DeepEqual(LootLogicDB, saved, "saved data unchanged")
        h.DeepEqual(GenerationSnapshot(), generations, "generations unchanged")
    end,

    ["Welcome: a read-only session shows it and leaves the saved data alone"] = function()
        Boot(h.Fixture("dbNewer"))
        h.True(ns.DB.IsReadOnly(), "read-only")
        Stub.Advance(5)
        h.Equal(IsShown(), true, "shown from the copy")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data unchanged")
    end,

    ["Welcome: Not now closes it and sets the flag"] = function()
        local dialog = OpenDialog()
        local before, generations = Copy(LootLogicDB), GenerationSnapshot()
        ButtonNamed(dialog, L.welcomeNotNow):Click()
        ExpectClosed(dialog)
        ExpectOnlyFlagChanged(before, generations)
    end,

    ["Welcome: the close button closes it and sets the flag"] = function()
        local dialog = OpenDialog()
        local before, generations = Copy(LootLogicDB), GenerationSnapshot()
        CloseButton(dialog):Click()
        ExpectClosed(dialog)
        ExpectOnlyFlagChanged(before, generations)
    end,

    ["Welcome: Escape closes it and sets the flag"] = function()
        local dialog = OpenDialog()
        local before, generations = Copy(LootLogicDB), GenerationSnapshot()
        Stub.PressEscape()
        ExpectClosed(dialog)
        ExpectOnlyFlagChanged(before, generations)
    end,

    ["Welcome: Show commands prints the help list only, then closes it"] = function()
        local dialog = OpenDialog()
        ns.Slash.Run("help")
        local helpLines = Lines()
        Stub.ClearChat()
        local before, generations = Copy(LootLogicDB), GenerationSnapshot()
        ButtonNamed(dialog, L.welcomeShowCommands):Click()
        h.DeepEqual(Lines(), helpLines, "the lines /ll help prints")
        h.True(#helpLines > 1, "a real list")
        for _, row in ipairs(ns.Checklist.Rows()) do
            local rowLine = L.chatPrefix .. " " .. ns.Checklist.Format(row)
            for _, line in ipairs(Lines()) do
                h.True(line ~= rowLine, "no checklist row: " .. rowLine)
            end
        end
        h.Equal(dialog:IsShown(), false, "hidden")
        h.Equal(LootLogicDB.ui.firstRunDone, true, "flag set")
        Stub.Advance(120)
        h.Equal(dialog:IsShown(), false, "not shown again")
        ExpectOnlyFlagChanged(before, generations)
    end,

    ["Welcome: Show commands does nothing while its callback is not set"] = function()
        local dialog = OpenDialog()
        ns.Welcome.onShowCommands = nil
        ButtonNamed(dialog, L.welcomeShowCommands):Click()
        h.DeepEqual(Lines(), {}, "no line")
        h.Equal(dialog:IsShown(), true, "dialog stays")
        h.Equal(LootLogicDB.ui.firstRunDone, false, "flag unchanged")
    end,

    ["Welcome: hiding the parent does not count as a close"] = function()
        local dialog = OpenDialog()
        UIParent:Hide()
        h.Equal(LootLogicDB.ui.firstRunDone, false, "flag unchanged")
        h.Equal(dialog:IsShown(), true, "the frame keeps its own shown state")
    end,

    ["Welcome: a close in a read-only session sets the flag in the copy only"] = function()
        Boot(h.Fixture("dbNewer"))
        Stub.Advance(5)
        ButtonNamed(LootLogicWelcome, L.welcomeNotNow):Click()
        h.Equal(LootLogicWelcome:IsShown(), false, "hidden")
        h.Equal(ns.DB.Data().ui.firstRunDone, true, "copy flag set")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data unchanged")
    end,
}
