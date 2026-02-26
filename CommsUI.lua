-- CommsUI.lua
--
-- Comms button panel + config panel for ArenaNumbersAndTargets.
-- Loaded second (after ArenaNumbersAndTargets.lua) so the namespace exists.

-- ── SavedVariables defaults ───────────────────────────────────────────────

local DEFAULTS = {
    fontSize     = 94,
    killTemplate = "Kill target %d",
    ccTemplate   = "CC target %d",
    panelX       = nil,
    panelY       = nil,
}

local db   -- shortcut to ArenaNumbersAndTargetsDB after merge

-- ── Helpers ───────────────────────────────────────────────────────────────

local function RGBToHex(r, g, b)
    return string.format("%02X%02X%02X",
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- ── DB init (on ADDON_LOADED) ─────────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "ArenaNumbersAndTargets" then return end
    self:UnregisterEvent("ADDON_LOADED")

    if type(ArenaNumbersAndTargetsDB) ~= "table" then
        ArenaNumbersAndTargetsDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if ArenaNumbersAndTargetsDB[k] == nil then
            ArenaNumbersAndTargetsDB[k] = v
        end
    end
    db = ArenaNumbersAndTargetsDB

    ArenaNumbersAndTargets.SetFontSize(db.fontSize)

    BuildCommsPanel()

    if db.panelX and db.panelY then
        commsPanel:ClearAllPoints()
        commsPanel:SetPoint("CENTER", UIParent, "CENTER", db.panelX, db.panelY)
    end
end)

-- ── SendCallout ───────────────────────────────────────────────────────────

local function SendCallout(msgType, arenaNum)
    local template, colorHex
    if msgType == "kill" then
        template = db.killTemplate
        colorHex = "FF3333"   -- red
    else
        template = db.ccTemplate
        colorHex = "4CFF00"   -- fel green
    end

    local msg   = "|cff" .. colorHex .. string.format(template, arenaNum) .. "|r"
    local plain = string.format(template, arenaNum)

    -- Append name + class.  Local print gets class colour; chat gets plain "Name - Class".
    local uid  = "arena" .. arenaNum
    local name = UnitName(uid)
    if name then
        local localizedClass, classFile = UnitClass(uid)
        local nameHex = "FFFFFF"
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local c = RAID_CLASS_COLORS[classFile]
            nameHex = RGBToHex(c.r, c.g, c.b)
        end
        msg   = msg   .. " - |cff" .. nameHex .. name .. "|r"
        plain = plain .. " - " .. name
        if localizedClass then
            plain = plain .. " - " .. localizedClass
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(msg)
    local channel = IsActiveBattlefieldArena() and "INSTANCE_CHAT" or "PARTY"
    SendChatMessage(plain, channel)
end

-- ── Comms panel ───────────────────────────────────────────────────────────
-- commsPanel is a GLOBAL so the arena hooks at the bottom can reference it
-- directly without closures. This matches the original working implementation.

commsPanel = nil

function BuildCommsPanel()
    local panel = CreateFrame("Frame", "ANT_CommsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(156, 54)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    panel:SetFrameStrata("MEDIUM")
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")

    -- Start mouse-disabled; enable only while visible so the hidden frame
    -- never swallows right-click camera rotation or targeting clicks.
    panel:EnableMouse(false)
    panel:SetScript("OnShow", function(self) self:EnableMouse(true)  end)
    panel:SetScript("OnHide", function(self) self:EnableMouse(false) end)

    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 8, edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y   = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        db.panelX = x - ux
        db.panelY = y - uy
    end)

    local rows = {
        { label = "Kill", r = 1.0, g = 0.2, b = 0.2, msgType = "kill" },  -- red
        { label = "CC",   r = 0.3, g = 1.0, b = 0.0, msgType = "cc"   },  -- fel green
    }

    local BTN_W, BTN_H = 30, 18
    local COL_X = { 32, 68, 104 }  -- x of each column from TOPLEFT
    local ROW_Y = { -6, -30 }      -- y of each row top from TOPLEFT

    for rowIdx, rowDef in ipairs(rows) do
        -- Label anchored from TOPLEFT, vertically centred with the button row.
        -- ROW_Y[rowIdx] = button top; subtracting BTN_H/2 gives button centre.
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", panel, "TOPLEFT", 4, ROW_Y[rowIdx] - BTN_H / 2)
        lbl:SetTextColor(rowDef.r, rowDef.g, rowDef.b, 1)
        lbl:SetText(rowDef.label)

        for colIdx = 1, 3 do
            local arenaNum = colIdx
            local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            btn:SetSize(BTN_W, BTN_H)
            btn:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_X[colIdx], ROW_Y[rowIdx])
            btn:SetText(tostring(arenaNum))
            btn:GetFontString():SetTextColor(rowDef.r, rowDef.g, rowDef.b, 1)

            local capturedType = rowDef.msgType
            btn:SetScript("OnClick", function()
                SendCallout(capturedType, arenaNum)
            end)
        end
    end

    panel:Hide()
    commsPanel = panel
end

-- ── Config panel (lazy, built on first /abn config) ───────────────────────

local configPanel = nil

local function BuildConfigPanel()
    local panel = CreateFrame("Frame", "ANT_ConfigPanel", UIParent, "BackdropTemplate")
    panel:SetSize(310, 185)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)

    -- Same EnableMouse toggle – hidden config panel must not block mouse.
    panel:EnableMouse(false)
    panel:SetScript("OnHide", function(self) self:EnableMouse(false) end)
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 32,
        insets   = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    panel:SetBackdropColor(0, 0, 0, 1)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetText("ArenaNumbersAndTargets Settings")

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    local function Row(yOff, labelStr, numeric)
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, yOff)
        lbl:SetText(labelStr)
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(165, 20)
        box:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        box:SetAutoFocus(false)
        if numeric then box:SetNumeric(true) end
        return box
    end

    local sizeBox = Row(-46,  "Number size:", true)
    local killBox = Row(-74,  "Kill msg:")
    local ccBox   = Row(-102, "CC msg:")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -126)
    hint:SetTextColor(0.7, 0.7, 0.7, 1)
    hint:SetText("%d = arena target number")

    local cancelBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -94, 12)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() panel:Hide() end)

    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 12)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        local sz   = tonumber(sizeBox:GetNumber())
        local kill = killBox:GetText()
        local cc   = ccBox:GetText()
        if not sz or sz < 8 or sz > 200 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF3333ANT: size must be 8-200|r") ; return
        end
        if not kill:find("%%d") then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF3333ANT: kill template needs %%d|r") ; return
        end
        if not cc:find("%%d") then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF3333ANT: cc template needs %%d|r") ; return
        end
        db.fontSize, db.killTemplate, db.ccTemplate = sz, kill, cc
        ArenaNumbersAndTargets.SetFontSize(sz)
        panel:Hide()
    end)

    -- Single OnShow does both: enable mouse AND populate fields.
    panel:SetScript("OnShow", function(self)
        self:EnableMouse(true)
        sizeBox:SetNumber(db.fontSize)
        killBox:SetText(db.killTemplate)
        ccBox:SetText(db.ccTemplate)
    end)

    panel:Hide()
    configPanel = panel
end

function ArenaNumbersAndTargets.ToggleConfig()
    if not configPanel then BuildConfigPanel() end
    if configPanel:IsShown() then configPanel:Hide() else configPanel:Show() end
end

-- ── Arena hooks ───────────────────────────────────────────────────────────
-- Reference commsPanel as a global directly (no closure, no nil guard)
-- matching the original implementation that was confirmed working.

ArenaNumbersAndTargets.OnEnterArena = function() commsPanel:Show() end
ArenaNumbersAndTargets.OnLeaveArena = function() commsPanel:Hide() end
