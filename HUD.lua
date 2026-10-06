-- HUD: compact dark bar with Cast / Lure / Pole buttons, skill, zone, lure timer and catch rate.
--
--  [Cast][Lure][Pole]  Fishing 187/225 +75      Zone 225
--                      Lure 7:32           23 fish · 41/h
--  [======== cast progress ======|=================]   (| = typical bite time)
local _, ns = ...

local HUD = {}
ns.HUD = HUD

local COLOR = ns.COLOR
local BG     = { 0.05, 0.06, 0.08, 0.88 }
local EDGE   = { 0, 0, 0, 1 }
local ACCENT = { 0.31, 0.76, 0.97 } -- COLOR.accent as RGB
local GOOD   = { 0.49, 0.99, 0 }    -- COLOR.good as RGB
local GOLD   = { 1, 0.82, 0 }
local RED    = { 0.9, 0.2, 0.2 }
local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local PAD, ICON, GAP = 6, 30, 4
local WIDTH, HEIGHT = 310, ICON + PAD * 2

local hud = CreateFrame("Frame", "EzFishingHUD", UIParent, "BackdropTemplate")
hud:SetSize(WIDTH, HEIGHT)
hud:SetFrameStrata("MEDIUM")
hud:SetClampedToScreen(true)
hud:SetMovable(true)
hud:EnableMouse(true)
hud:RegisterForDrag("LeftButton")
hud:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 })
hud:SetBackdropColor(unpack(BG))
hud:SetBackdropBorderColor(unpack(EDGE))
hud:Hide()

local function HideTooltip() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function StyleIcon(btn, index)
    btn:SetParent(hud)
    btn:SetSize(ICON, ICON)
    btn:ClearAllPoints()
    btn:SetPoint("LEFT", hud, "LEFT", PAD + (index - 1) * (ICON + GAP), 0)
    btn.border = btn:CreateTexture(nil, "BACKGROUND")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetColorTexture(unpack(EDGE))
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", -1, 2)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:HookScript("OnEnter", function(self) HUD.ShowTooltip(self) end)
    btn:HookScript("OnLeave", HideTooltip)
end

local castBtn = ns.castButton
StyleIcon(castBtn, 1)
castBtn.icon:SetTexture("Interface\\Icons\\Trade_Fishing")

local lureBtn = ns.Gear.lureButton
StyleIcon(lureBtn, 2)

local poleBtn = CreateFrame("Button", nil, hud)
poleBtn:RegisterForClicks("AnyUp")
poleBtn:SetScript("OnClick", ns.Gear.TogglePole)
StyleIcon(poleBtn, 3)

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
local TEXT_LEFT = PAD + 3 * ICON + 2 * GAP + 10

local function Text(point, x, y, justify)
    local fs = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint(point, hud, point, x, y)
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    return fs
end

local skillText = Text("TOPLEFT", TEXT_LEFT, -PAD - 3, "LEFT")
local zoneText  = Text("TOPRIGHT", -PAD - 2, -PAD - 3, "RIGHT")
local lureText  = Text("BOTTOMLEFT", TEXT_LEFT, PAD + 4, "LEFT")
local rateText  = Text("BOTTOMRIGHT", -PAD - 2, PAD + 4, "RIGHT")
-- Left texts stop short of their right-hand neighbour, so the two can never overlap.
skillText:SetPoint("RIGHT", zoneText, "LEFT", -8, 0)
lureText:SetPoint("RIGHT", rateText, "LEFT", -8, 0)

---------------------------------------------------------------------------
-- Cast progress bar with typical-bite marker (only updates while the bobber is out)
---------------------------------------------------------------------------
local bar = CreateFrame("StatusBar", nil, hud)
bar:SetPoint("BOTTOMLEFT", 1, 1)
bar:SetPoint("BOTTOMRIGHT", -1, 1)
bar:SetHeight(2)
bar:SetStatusBarTexture(WHITE8)
bar:SetStatusBarColor(unpack(ACCENT))
bar:Hide()

local biteMark = bar:CreateTexture(nil, "OVERLAY")
biteMark:SetColorTexture(1, 1, 1, 0.9)
biteMark:SetSize(2, 6)

local function UpdateBar()
    local startTime, endTime = ns.FishingChannel()
    if not startTime then return end
    bar:SetMinMaxValues(startTime, endTime)
    bar:SetValue(GetTime())
    local avg, duration = ns.Stats.AvgBite(), endTime - startTime
    if avg and avg < duration then
        biteMark:ClearAllPoints()
        biteMark:SetPoint("BOTTOM", bar, "BOTTOMLEFT", bar:GetWidth() * avg / duration, 0)
        biteMark:Show()
    else
        biteMark:Hide()
    end
end

local barTick = 0
local function OnUpdate(_, elapsed)
    barTick = barTick + elapsed
    if barTick < 0.05 then return end
    barTick = 0
    UpdateBar()
end

-- Cast button border: blue while the bobber is out, green once the interact key is locked
-- onto the bobber (pressing now hooks it).
ns.On("EZF_CAST_START", function()
    UpdateBar()
    bar:Show()
    castBtn.border:SetColorTexture(unpack(ACCENT))
    hud:SetScript("OnUpdate", OnUpdate)
end)

ns.On("EZF_BOBBER_TARGET", function(onBobber)
    if ns.IsFishing() then castBtn.border:SetColorTexture(unpack(onBobber and GOOD or ACCENT)) end
end)

ns.On("EZF_CAST_STOP", function()
    hud:SetScript("OnUpdate", nil)
    bar:Hide()
    castBtn.border:SetColorTexture(unpack(EDGE))
end)

---------------------------------------------------------------------------
-- Content (text is only rebuilt when the shown values change)
---------------------------------------------------------------------------
local shown = { rank = false } -- false so the first update always draws

local function UpdateSkill()
    if not hud:IsShown() then return end
    local rank, maxRank, mod = ns.FishingSkill()
    local req = ns.ZoneRequirement()
    if rank == shown.rank and maxRank == shown.maxRank and mod == shown.mod and req == shown.req then return end
    shown.rank, shown.maxRank, shown.mod, shown.req = rank, maxRank, mod, req

    if not rank then
        skillText:SetText(COLOR.dim .. "Fishing not learned|r")
        zoneText:SetText("")
        return
    end
    skillText:SetText(format("Fishing %d/%d%s", rank, maxRank, mod > 0 and format(" %s+%d|r", COLOR.good, mod) or ""))

    if not req then
        zoneText:SetText(COLOR.dim .. "Zone ?|r")
        return
    end
    local effective = rank + mod
    local color = effective >= req and COLOR.good or (effective >= req - 50 and COLOR.warn or COLOR.bad)
    zoneText:SetText(format("%sZone %d|r", color, req))
end

local NO_LURE, NO_LURE_WARN = COLOR.dim .. "No lure|r", COLOR.bad .. "No lure|r"

local function UpdateLureAndRate()
    if not hud:IsShown() then return end
    local left = ns.PoleEquipped() and ns.LureTimeLeft()
    -- Whole seconds, or a negative code for the two "no lure" looks.
    local lureKey = left and floor(left + 0.5) or ((ns.active and ns.db.lureWarning) and -2 or -1)
    if lureKey ~= shown.lure then
        shown.lure = lureKey
        if left then
            lureText:SetText(format("%sLure %s|r", left < 60 and COLOR.warn or COLOR.accent, ns.FormatTime(left)))
        else
            lureText:SetText(lureKey == -2 and NO_LURE_WARN or NO_LURE)
        end
    end

    local catches = ns.Stats.session.catches
    local rate = ns.Stats.PerHour()
    rate = rate and floor(rate + 0.5)
    if catches ~= shown.catches or rate ~= shown.rate then
        shown.catches, shown.rate = catches, rate
        rateText:SetText(format("%d fish%s", catches, rate and format(" %s·|r %d/h", COLOR.dim, rate) or ""))
    end
end

local function SetIcon(btn, item, active)
    btn.icon:SetTexture(ns.ItemIcon(item))
    btn.icon:SetDesaturated(not active)
end

local function UpdateButtons()
    if not hud:IsShown() then return end
    local lure = ns.Gear.BestLure()
    SetIcon(lureBtn, lure and lure.id or ns.PLACEHOLDER_LURE, lure)
    lureBtn.count:SetText(lure and ns.ItemCount(lure.id) or "")

    -- Pole equipped: show the weapon you'd swap back to. Otherwise: the pole you'd equip.
    if ns.PoleEquipped() then
        local weapons = ns.char.weapons
        SetIcon(poleBtn, weapons and weapons.main or GetInventoryItemID("player", INVSLOT_MAINHAND), weapons)
    else
        local pole = ns.Gear.BestPole()
        SetIcon(poleBtn, pole or ns.PLACEHOLDER_POLE, pole)
    end
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
local function Row(tt, left, right)
    tt:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
end

local function Note(tt, text)
    tt:AddLine(text, 0.7, 0.7, 0.7, true)
end

local function TopRows(tt, items)
    for _, row in ipairs(ns.Stats.Top(items, 6)) do Row(tt, "  " .. row[1], row[2]) end
end

local TOOLTIPS = {}

TOOLTIPS[castBtn] = function(tt)
    tt:AddLine("Cast / Hook")
    local key = GetBindingKey(ns.BINDING_CAST)
    if key then
        tt:AddLine(format("Press %s%s|r to cast, and again when the bobber splashes.", COLOR.accent, GetBindingText(key)),
            1, 1, 1, true)
    else
        tt:AddLine(COLOR.bad .. "No key bound.|r Set one in /ezf config (top of the page).", 1, 1, 1, true)
    end
    if ns.db.doubleClick then Note(tt, "Double right-click in the world also casts and hooks.") end
end

TOOLTIPS[lureBtn] = function(tt)
    local lure = ns.Gear.BestLure()
    if lure then
        tt:AddLine(format("Apply %s", C_Item.GetItemNameByID(lure.id) or "lure"))
        tt:AddLine(format("+%d fishing skill, %d in bags", lure.bonus, ns.ItemCount(lure.id)), 1, 1, 1)
    else
        tt:AddLine("Apply lure")
        Note(tt, "No usable lure in your bags.")
    end
    local left = ns.PoleEquipped() and ns.LureTimeLeft()
    if left then tt:AddLine("Current lure: " .. ns.FormatTime(left) .. " left", 1, 1, 1) end
end

TOOLTIPS[poleBtn] = function(tt)
    if ns.PoleEquipped() then
        local w = ns.char.weapons
        tt:AddLine("Swap back to weapons")
        if not w then
            Note(tt, "No saved weapons.")
        elseif w.main then
            tt:AddLine(w.main .. (w.off and (" + " .. w.off) or ""))
        end
    else
        local pole = ns.Gear.BestPole()
        tt:AddLine("Equip fishing pole")
        Note(tt, pole and (C_Item.GetItemNameByID(pole) or "pole") or "No pole in your bags.")
    end
end

TOOLTIPS[hud] = function(tt)
    local Stats = ns.Stats
    local s = Stats.session
    tt:AddLine("EzFishing")
    Row(tt, "Casts / catches", format("%d / %d", s.casts, s.catches))
    if s.escapes > 0 then tt:AddDoubleLine("Got away", s.escapes, 1, 1, 1, 1, 0.4, 0.4) end
    local rate = Stats.PerHour()
    if rate then Row(tt, "Catches per hour", format("%.0f", rate)) end
    if Stats.AvgBite() then Row(tt, "Typical bite", format("%.1fs", Stats.AvgBite())) end
    Row(tt, "Fishing time", ns.FormatTime(Stats.FishingTime()))
    TopRows(tt, s.items)

    local zone = ns.ZoneName()
    local z = ns.char.zones[zone]
    if z and z.catches > 0 then
        tt:AddLine(" ")
        tt:AddDoubleLine(zone .. " (all time)", format("%d caught, %d got away", z.catches, z.escapes),
            ACCENT[1], ACCENT[2], ACCENT[3], 1, 1, 1)
    end
    local req, where = ns.ZoneRequirement()
    if req then Row(tt, "Skill for no getaways", format("%d (%s)", req, where)) end

    tt:AddLine(" ")
    tt:AddDoubleLine("All time", format("%d catches", ns.char.catches), ACCENT[1], ACCENT[2], ACCENT[3], 1, 1, 1)
    TopRows(tt, ns.char.items)
    tt:AddLine(" ")
    tt:AddLine((ns.db.locked and "Shift-drag" or "Drag") .. " to move. /ezf for options.", 0.5, 0.5, 0.5)
end

function HUD.ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    TOOLTIPS[owner](GameTooltip)
    GameTooltip:Show()
end

hud:SetScript("OnEnter", HUD.ShowTooltip)
hud:SetScript("OnLeave", HideTooltip)

---------------------------------------------------------------------------
-- Position, scale, visibility. The HUD holds secure buttons, so it can only be
-- shown, hidden, moved or scaled out of combat.
---------------------------------------------------------------------------
local function ApplyPosition()
    local p = ns.db.pos
    hud:ClearAllPoints()
    if p then
        hud:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        hud:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

local function Refresh()
    local mode = ns.db.hudMode
    hud:SetScale(ns.db.scale)
    hud:SetShown(mode == ns.HUD_ALWAYS or (mode == ns.HUD_AUTO and (ns.active or ns.PoleEquipped())))
    UpdateSkill()
    UpdateLureAndRate()
    UpdateButtons()
end

function HUD.ApplyPosition() ns.OutOfCombat(ApplyPosition) end
function HUD.Refresh() ns.OutOfCombat(Refresh) end

hud:SetScript("OnDragStart", function(self)
    if InCombatLockdown() or (ns.db.locked and not IsShiftKeyDown()) then return end
    self.moving = true
    self:StartMoving()
end)

hud:SetScript("OnDragStop", function(self)
    if not self.moving then return end
    self.moving = false
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.pos = { point, relPoint, x, y }
end)

local function Flash(color, seconds)
    hud:SetBackdropBorderColor(unpack(color))
    C_Timer.After(seconds, function() hud:SetBackdropBorderColor(unpack(EDGE)) end)
end

ns.On("EZF_READY", HUD.ApplyPosition)
ns.On("PLAYER_LOGIN", HUD.Refresh)
for _, event in ipairs({ "EZF_MODE_START", "EZF_MODE_END", "EZF_GEAR_CHANGED" }) do ns.On(event, HUD.Refresh) end
for _, event in ipairs({ "EZF_SKILL_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do ns.On(event, UpdateSkill) end
for _, event in ipairs({ "EZF_TICK", "EZF_STATS_CHANGED" }) do ns.On(event, UpdateLureAndRate) end
ns.On("EZF_SKILL_UP", function() Flash(GOLD, 2) end)
ns.On("EZF_LURE_EXPIRED", function() Flash(RED, 3) end)
