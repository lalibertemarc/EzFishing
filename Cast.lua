-- Casting: one key (or a double right-click) casts Fishing; while the bobber is out the same
-- input becomes Interact, which hooks the bobber through soft targeting.
-- Addons can't cast or interact on their own (both need a real key press), so this is as close
-- to auto-fishing as the API allows.
local _, ns = ...

local BUTTON_NAME = "EzFishingCastButton"
local castName

local btn = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
-- Both halves are registered; the template itself picks down or up from ActionButtonUseKeyDown.
btn:RegisterForClicks("AnyUp", "AnyDown")
ns.castButton = btn

-- Override bindings put on the button by a double right-click are wiped in secure code right after
-- the click, so the right mouse button goes back to normal even if we can't run code (combat).
btn:SetScript("PostClick", function() end)
SecureHandlerWrapScript(btn, "PostClick", btn, [[ if not down then self:ClearBindings() end ]])

local function SetCastSpell()
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", castName)
end

local function RefreshSpell()
    castName = ns.SpellName(ns.FISHING_SPELL) or ns.SpellName(ns.FISHING_SPELL_FALLBACK)
    ns.OutOfCombat(SetCastSpell)
end

-- Smart cast key: equip a pole or apply a lure first when needed, otherwise cast.
local lastDecision = 0
btn:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local now = GetTime()
    -- PreClick runs for both halves of a click; decide once.
    if now - lastDecision < 0.5 then return end
    lastDecision = now

    local db, Gear = ns.db, ns.Gear
    if db.smartPole and not ns.PoleEquipped() and Gear.BestPole() then
        self:SetAttribute("type", nil)
        Gear.EquipPole()
    elseif db.smartLure and ns.PoleEquipped() and not ns.LureTimeLeft() and Gear.BestLure() then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", Gear.LureMacro())
    else
        SetCastSpell()
    end
end)

---------------------------------------------------------------------------
-- Cast key -> Interact while the bobber is out
---------------------------------------------------------------------------
local hookOwner = CreateFrame("Frame")
local wantHook = false

local function ApplyHook()
    ClearOverrideBindings(hookOwner)
    if not (wantHook and ns.db.keyHook) then return end
    for _, key in ipairs({ GetBindingKey(ns.BINDING_CAST) }) do
        SetOverrideBinding(hookOwner, true, key, "INTERACTTARGET")
    end
end

-- Reused every cast instead of building a new table each time.
local interactCVars = {
    SoftTargetInteract = 3,
    SoftTargetInteractArc = 2,
    SoftTargetInteractRange = 60,
}

local function Hook()
    local icon = ns.db.bobberIcon and 1 or 0
    interactCVars.SoftTargetIconGameObject = icon
    interactCVars.SoftTargetIconInteract = icon
    ns.CVars.Push("interact", interactCVars)
    wantHook = true
    ns.OutOfCombat(ApplyHook)
end

local function Unhook()
    ns.CVars.Pop("interact")
    wantHook = false
    ns.OutOfCombat(ApplyHook)
end

---------------------------------------------------------------------------
-- Is the bobber the soft target? Interact falls back to your regular target when it isn't,
-- which shows up as "too far to interact". EZF_BOBBER_TARGET(onBobber) tells the HUD.
---------------------------------------------------------------------------
local INTERACT_HINT = "Turn on Options > Controls > Enable Interact Key, then try again."
local onBobber, hinted = false, false

local function SetOnBobber(value)
    if value == onBobber then return end
    onBobber = value
    ns.Fire("EZF_BOBBER_TARGET", value)
end

ns.On("PLAYER_SOFT_INTERACT_CHANGED", function(_, newTarget)
    -- The bobber is a game object; its GUID can be secret in restricted areas, then we just don't know.
    SetOnBobber(ns.IsFishing() and type(newTarget) == "string" and not ns.issecret(newTarget)
        and newTarget:find("^GameObject") ~= nil)
end)

local function CheckBobber()
    if hinted or onBobber or not ns.IsFishing() then return end
    hinted = true
    ns.Print("The interact key isn't picking up the bobber, so it may hit your current target instead. "
        .. "Clear your target and face the bobber. " .. INTERACT_HINT)
end

ns.On("EZF_CVAR_BLOCKED", function(name)
    if name:find("^SoftTargetInteract") then ns.Print(INTERACT_HINT) end
end)

ns.On("EZF_CAST_START", function()
    Hook()
    C_Timer.After(4, CheckBobber)
end)
ns.On("EZF_CAST_STOP", function()
    Unhook()
    SetOnBobber(false)
end)
-- Combat and loading screens can end the channel without a stop event.
ns.On("EZF_MODE_END", Unhook)
ns.On("PLAYER_LEAVING_WORLD", Unhook)

---------------------------------------------------------------------------
-- Double right-click
---------------------------------------------------------------------------
local function CanFish()
    return castName and ns.PoleEquipped()
        and not IsMounted() and not IsFlying() and not IsFalling() and not IsSwimming()
        and not (IsSubmerged and IsSubmerged()) and not IsPlayerMoving() and not IsStealthed()
        and not UnitExists("mouseover") and not UnitIsDeadOrGhost("player")
        and not UnitHasVehicleUI("player") and HasFullControl()
end

local lastRight, interactBinding = 0, false

local function ClearMouseBindings()
    interactBinding = false
    ClearOverrideBindings(btn)
end

ns.On("GLOBAL_MOUSE_DOWN", function(button)
    if button ~= "RightButton" or not ns.db.doubleClick or InCombatLockdown() then return end
    if IsMouseButtonDown("LeftButton") or GetNumLootItems() > 0 then
        lastRight = 0
        return
    end
    local now = GetTime()
    local dt = now - lastRight
    if dt >= 0.04 and dt <= ns.db.doubleClickSpeed then
        lastRight = 0
        if ns.IsFishing() then
            SetOverrideBinding(btn, true, "BUTTON2", "INTERACTTARGET")
            interactBinding = true
        elseif CanFish() then
            SetOverrideBindingClick(btn, true, "BUTTON2", BUTTON_NAME)
        end
    else
        lastRight = now
    end
end)

ns.On("GLOBAL_MOUSE_UP", function(button)
    if interactBinding and button == "RightButton" and not InCombatLockdown() then ClearMouseBindings() end
end)

-- After combat: drop mouse overrides left behind and undo any pole/lure decision PreClick
-- left on the button. (The hook itself is re-synced through ns.OutOfCombat.)
ns.On("PLAYER_REGEN_ENABLED", function()
    ClearMouseBindings()
    SetCastSpell()
end)

ns.On("SPELLS_CHANGED", RefreshSpell)
ns.On("EZF_READY", RefreshSpell)
