--[[
Small frame helpers for the Welcome dialog (technical findings 14, layout):
plain frames, client font objects and no embedded libraries. Every client frame
call and template below is an API guess, checked in game by live check L43.
Nothing here creates a frame when the file loads, and no function creates a
global: the caller passes in a frame it created.
]]

local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 24
local CLOSE_BUTTON_SIZE = 32

-- From memory (API guess): the classic dialog textures; BackdropTemplate on the
-- frame gives it SetBackdrop.
local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

--- Turns a frame into a dialog: size, DIALOG strata, backdrop, kept on screen,
--- and movable by dragging with the left button for the session only. It does
--- not enable keyboard input, so the dialog never takes keyboard focus.
-- @param frame table a frame created with the "BackdropTemplate" template
-- @param width number
-- @param height number
function Widgets.StyleDialog(frame, width, height)
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(BACKDROP)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    -- SetUserPlaced(false) keeps the client from storing the dragged position
    -- for a named frame (API guess, from memory; L43).
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
    end)
end

--- A word-wrapped, left-aligned text under a parent.
-- @param parent table
-- @param fontObject string a client font object name, such as "GameFontNormal"
-- @param width number
-- @treturn table the font string
function Widgets.Text(parent, fontObject, width)
    local text = parent:CreateFontString(nil, "ARTWORK", fontObject)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    return text
end

--- A push button with a label.
-- @param parent table
-- @param label string
-- @param onClick function called with no arguments
-- @treturn table the button
function Widgets.Button(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(label)
    button:SetScript("OnClick", function()
        onClick()
    end)
    return button
end

--- The close button in the top right corner of a dialog. Its click replaces the
--- template's own script, so the caller's function decides what closing does.
-- @param parent table
-- @param onClick function called with no arguments
-- @treturn table the button
function Widgets.CloseButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    button:SetSize(CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    button:SetScript("OnClick", function()
        onClick()
    end)
    return button
end
