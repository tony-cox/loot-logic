--[[
The first-run Welcome dialog (docs/ux.md 2.1, technical findings 14, Help and
Welcome). It waits until 5 seconds after PLAYER_LOGIN, the player is out of
combat and no client dialog is shown, checks again every 2 seconds, and gives up
for the session at 60 seconds. Closing it by any route sets ui.firstRunDone.
Nothing is built when the file loads: the frame is created the first time it
shows. The client calls below are API guesses checked in game by live check L43.
]]

local _, ns = ...

local Welcome = {}
ns.Welcome = Welcome

local L = ns.L
local Log = ns.Log
local DB = ns.DB
local Events = ns.Events
local Widgets = ns.Widgets

-- Named so that the client can find it for Escape (UISpecialFrames); the name
-- is the one global this file creates (style guide 3).
local FRAME_NAME = "LootLogicWelcome"

local FIRST_CHECK_SECONDS = 5
local CHECK_INTERVAL_SECONDS = 2
local GIVE_UP_SECONDS = 60

-- Size and position are chosen here and tunable in game (docs/ux.md 2.1; L43).
local DIALOG_WIDTH = 440
local DIALOG_HEIGHT = 270
local DIALOG_TOP_OFFSET = 120
local MARGIN = 24
local TEXT_WIDTH = DIALOG_WIDTH - 2 * MARGIN
local PARAGRAPH_GAP = 10
local BUTTON_GAP = 12
local BUTTON_BOTTOM = 20

local loginTime
local dialog
local finished = false

-- Called when the dialog closes by any route: [Not now], [Show commands], the
-- close button or Escape. The flag goes to the read-only copy in a read-only
-- session (docs/ux.md 2.1).
local function MarkDone()
    DB.Data().ui.firstRunDone = true
end

-- Every route closes by hiding the frame, so one OnHide handler sets the flag.
-- A parent that hides runs OnHide on a child that is still shown (API guess),
-- so only a hide of the frame itself counts as a close.
local function OnHide(frame)
    if not frame:IsShown() then
        MarkDone()
    end
end

local function ShowCommands()
    if not Welcome.onShowCommands then
        return
    end
    Welcome.onShowCommands()
    dialog:Hide()
end

local function Close()
    dialog:Hide()
end

local function Build()
    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    Widgets.StyleDialog(frame, DIALOG_WIDTH, DIALOG_HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -DIALOG_TOP_OFFSET)
    table.insert(UISpecialFrames, FRAME_NAME)
    frame:SetScript("OnHide", OnHide)
    Widgets.CloseButton(frame, Close)

    local title = Widgets.Text(frame, "GameFontNormalLarge", TEXT_WIDTH)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN)
    title:SetText(L.welcomeTitle)
    local about = Widgets.Text(frame, "GameFontHighlight", TEXT_WIDTH)
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -PARAGRAPH_GAP)
    about:SetText(L.welcomeAbout)
    local optional = Widgets.Text(frame, "GameFontHighlight", TEXT_WIDTH)
    optional:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -PARAGRAPH_GAP)
    optional:SetText(L.welcomeOptional)

    local showCommands = Widgets.Button(frame, L.welcomeShowCommands, ShowCommands)
    showCommands:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", MARGIN, BUTTON_BOTTOM)
    local notNow = Widgets.Button(frame, L.welcomeNotNow, Close)
    notNow:SetPoint("LEFT", showCommands, "RIGHT", BUTTON_GAP, 0)
    return frame
end

local function ClientDialogShown()
    for index = 1, 4 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() then
            return true
        end
    end
    return false
end

local function CanShow()
    return not InCombatLockdown() and not ClientDialogShown()
end

-- One check. It stops when the flag is set, shows the dialog when it can, and
-- otherwise tries again in 2 seconds while the next try is within the 60
-- seconds (the last try is at 59 seconds after PLAYER_LOGIN). Giving up writes
-- nothing, so the dialog tries again at the next login.
local function Check()
    if finished or DB.Data().ui.firstRunDone then
        return
    end
    local elapsed = GetTime() - loginTime
    if elapsed >= GIVE_UP_SECONDS then
        finished = true
        return
    end
    if CanShow() then
        finished = true
        dialog = Build()
        dialog:Show()
        return
    end
    if elapsed + CHECK_INTERVAL_SECONDS > GIVE_UP_SECONDS then
        finished = true
        return
    end
    C_Timer.After(CHECK_INTERVAL_SECONDS, function()
        Log.Guard("events", Check)
    end)
end

-- Polling only: the end of combat or another dialog closing does not trigger a
-- check (docs/ux.md 2.1). C_Timer.After only (live check L63).
Events.Register("PLAYER_LOGIN", function()
    loginTime = GetTime()
    finished = false
    C_Timer.After(FIRST_CHECK_SECONDS, function()
        Log.Guard("events", Check)
    end)
end)

-- Welcome.onShowCommands is set by Slash.lua when it loads (technical findings
-- 14): it prints the command list. While it is nil, [Show commands] does
-- nothing.
