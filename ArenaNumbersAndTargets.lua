-- ArenaNumbersAndTargets.lua
--
-- Displays a giant number (1, 2, 3 …) above each enemy's nameplate in arenas.
-- Works automatically – no targeting or keypresses needed.
-- TBC Anniversary (Interface 20505) compatible.
--
-- Architecture
-- ────────────
-- Five persistent label frames are created once at load time and parented to
-- UIParent.  When a nameplate for an arena enemy appears, the matching label
-- is anchored to that nameplate frame and shown.  When the nameplate is
-- removed (stealth, out of range, etc.) the label is hidden.  The label
-- reappears automatically the next time that enemy's nameplate returns.

local ADDON_NAME    = "ArenaNumbersAndTargets"
local MAX_ARENA     = 5
local FONT_PATH     = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE     = 94
local FONT_FLAGS    = "OUTLINE"
local ABOVE_PLATE_Y = 10   -- extra pixels above nameplate top-edge

-- Shared namespace (populated further by CommsUI.lua)
ArenaNumbersAndTargets = {}

-- ── Persistent label frames (created once at load-time) ──────────────────

-- arenaLabels[i] = { frame = Frame, text = FontString, trackedUnit = "nameplateX"|nil }
local arenaLabels = {}

for i = 1, MAX_ARENA do
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(120, 90)
    f:SetFrameStrata("HIGH")
    f:Hide()

    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT_PATH, FONT_SIZE, FONT_FLAGS)
    fs:SetPoint("CENTER", f, "CENTER", 0, 0)
    fs:SetTextColor(1, 0.82, 0, 1)   -- gold
    fs:SetText(tostring(i))

    arenaLabels[i] = { frame = f, text = fs, trackedUnit = nil }
end

-- Allows CommsUI (or any other module) to resize the nameplate numbers at runtime.
function ArenaNumbersAndTargets.SetFontSize(size)
    FONT_SIZE = size
    for i = 1, MAX_ARENA do
        arenaLabels[i].text:SetFont(FONT_PATH, size, FONT_FLAGS)
    end
end

-- ── Arena state ───────────────────────────────────────────────────────────

local isInArena  = false
local eventFrame = CreateFrame("Frame", ADDON_NAME .. "_EventFrame", UIParent)

-- ── Helpers ───────────────────────────────────────────────────────────────

-- Returns 1-5 if nameplateUnit maps to an arena enemy, else nil.
local function GetArenaIndexForUnit(nameplateUnit)
    for i = 1, MAX_ARENA do
        local au = "arena" .. i
        if UnitExists(au) and UnitIsUnit(au, nameplateUnit) then
            return i
        end
    end
    return nil
end

-- Returns the label index whose trackedUnit matches nameplateUnit, or nil.
local function GetLabelIndexByTrackedUnit(nameplateUnit)
    for i = 1, MAX_ARENA do
        if arenaLabels[i].trackedUnit == nameplateUnit then
            return i
        end
    end
    return nil
end

-- ── Label attachment ──────────────────────────────────────────────────────

local function AttachLabel(arenaIndex, nameplateUnit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(nameplateUnit)
    if not nameplate then return end

    local label = arenaLabels[arenaIndex]
    label.trackedUnit = nameplateUnit
    label.frame:ClearAllPoints()
    -- Anchor the label's BOTTOM to the nameplate's TOP so it floats above it.
    -- Because the label is anchored (not merely parented) to the nameplate frame,
    -- it will follow the nameplate as the unit moves on screen.
    label.frame:SetPoint("BOTTOM", nameplate, "TOP", 0, ABOVE_PLATE_Y)
    label.frame:Show()
end

local function DetachLabel(arenaIndex)
    local label = arenaLabels[arenaIndex]
    label.trackedUnit = nil
    label.frame:Hide()
end

local function DetachAllLabels()
    for i = 1, MAX_ARENA do
        DetachLabel(i)
    end
end

-- ── Nameplate event handlers ──────────────────────────────────────────────

local function OnNamePlateAdded(nameplateUnit)
    if not isInArena then return end
    local arenaIndex = GetArenaIndexForUnit(nameplateUnit)
    if arenaIndex then
        AttachLabel(arenaIndex, nameplateUnit)
    end
end

local function OnNamePlateRemoved(nameplateUnit)
    local labelIndex = GetLabelIndexByTrackedUnit(nameplateUnit)
    if labelIndex then
        DetachLabel(labelIndex)
    end
end

-- ── Scan nameplates that were already visible when we entered the arena ───

local function ScanExistingNameplates()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local nameplates = C_NamePlate.GetNamePlates()
    for _, np in ipairs(nameplates) do
        -- In TBC Classic each entry in the list is the nameplate Frame itself
        -- and exposes .namePlateUnitToken directly.
        local token = np.namePlateUnitToken
        if token then
            OnNamePlateAdded(token)
        end
    end
end

-- ── Arena enter / leave ───────────────────────────────────────────────────

local function EnterArena()
    isInArena = true
    -- Ensure enemy nameplates are visible; the addon is useless without them.
    SetCVar("nameplateShowEnemies", 1)
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    ScanExistingNameplates()
    if ArenaNumbersAndTargets.OnEnterArena then ArenaNumbersAndTargets.OnEnterArena() end
end

local function LeaveArena()
    isInArena = false
    eventFrame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    DetachAllLabels()
    if ArenaNumbersAndTargets.OnLeaveArena then ArenaNumbersAndTargets.OnLeaveArena() end
end

local function CheckArenaState()
    local inArena = IsActiveBattlefieldArena()
    if inArena and not isInArena then
        EnterArena()
    elseif not inArena and isInArena then
        LeaveArena()
    end
end

-- ── Main event handler ────────────────────────────────────────────────────

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Check immediately; also schedule a deferred check because
        -- IsActiveBattlefieldArena() may not return true on the very first frame.
        CheckArenaState()
        if C_Timer and C_Timer.After then
            C_Timer.After(2.0, CheckArenaState)
        end

    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        CheckArenaState()

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        OnNamePlateAdded(...)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        OnNamePlateRemoved(...)
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────

SLASH_ARENANUMBERSANDTARGETS1 = "/abn"
SLASH_ARENANUMBERSANDTARGETS2 = "/arenanumbersandtargets"
SlashCmdList["ARENANUMBERSANDTARGETS"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "status" then
        print(ADDON_NAME .. ": inArena=" .. tostring(isInArena))
        for i = 1, MAX_ARENA do
            local label = arenaLabels[i]
            print(string.format("  arena%d -> tracked=%s  visible=%s",
                i,
                tostring(label.trackedUnit),
                tostring(label.frame:IsShown())))
        end
    elseif cmd == "config" then
        if ArenaNumbersAndTargets.ToggleConfig then ArenaNumbersAndTargets.ToggleConfig() end
    else
        print(ADDON_NAME .. " commands:")
        print("  /abn status  – show current tracking state")
        print("  /abn config  – open settings panel")
    end
end
