-- Gear and comfort: fishing sound preset, auto-loot, lures, pole swap.
local _, ns = ...

local Gear = {}
ns.Gear = Gear

---------------------------------------------------------------------------
-- Sound preset + auto-loot, active for the whole fishing session
-- (not per cast, so zone music doesn't restart every 20 seconds).
---------------------------------------------------------------------------
local LOOT_CVARS = { autoLootDefault = 1 }

local function SoundCVars()
    local v = {
        Sound_EnableAllSound = 1,
        Sound_EnableSFX = 1,
        Sound_SFXVolume = 1,
        Sound_EnableMusic = 0,
        Sound_EnableAmbience = 0,
        Sound_EnablePetSounds = 0,
    }
    if ns.db.backgroundSound then v.Sound_EnableSoundWhenGameIsInBG = 1 end
    if ns.db.masterBoost then v.Sound_MasterVolume = ns.db.masterVolume end
    return v
end

-- Re-applies the session CVars from current settings (also called when settings change).
function Gear.ApplySession()
    ns.CVars.Pop("sound")
    ns.CVars.Pop("loot")
    if not ns.active then return end
    if ns.db.soundPreset then ns.CVars.Push("sound", SoundCVars()) end
    if ns.db.autoLoot then ns.CVars.Push("loot", LOOT_CVARS) end
end

ns.On("EZF_MODE_START", Gear.ApplySession)
ns.On("EZF_MODE_END", function(reason)
    Gear.ApplySession()
    if reason == "idle" and ns.db.swapBackOnEnd then Gear.EquipWeapons() end
end)

---------------------------------------------------------------------------
-- Best lure / pole in the bags, rescanned only when bags, equipment or skill change
---------------------------------------------------------------------------
local bestLure, bestPole, dirty = nil, nil, true

local function Rescan()
    dirty = false
    local rank = ns.FishingSkill()
    bestLure = nil
    for _, lure in ipairs(ns.LURES) do
        if ns.ItemCount(lure.id) > 0 and (not rank or rank >= lure.req) then
            bestLure = lure
            break
        end
    end
    local bestBonus
    bestPole = nil
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and ns.IsPole(id) then
                local bonus = ns.POLE_BONUS[id] or 0
                if not bestPole or bonus > bestBonus then bestPole, bestBonus = id, bonus end
            end
        end
    end
end

-- Returns the best usable lure entry from ns.LURES.
function Gear.BestLure()
    if dirty then Rescan() end
    return bestLure
end

-- Returns the itemID of the best fishing pole in the bags.
function Gear.BestPole()
    if dirty then Rescan() end
    return bestPole
end

function Gear.LureMacro()
    local lure = Gear.BestLure()
    if not lure then return nil end
    lure.macro = lure.macro or format("/use item:%d\n/use %d", lure.id, INVSLOT_MAINHAND)
    return lure.macro
end

---------------------------------------------------------------------------
-- Lure button and expiry warning
---------------------------------------------------------------------------
local lureBtn = CreateFrame("Button", "EzFishingLureButton", UIParent, "SecureActionButtonTemplate")
lureBtn:RegisterForClicks("AnyUp", "AnyDown")
Gear.lureButton = lureBtn

local function UpdateLureButton()
    local macro = Gear.LureMacro()
    if lureBtn:GetAttribute("macrotext") == macro then return end
    lureBtn:SetAttribute("type", macro and "macro" or nil)
    lureBtn:SetAttribute("macrotext", macro)
end

local function OnGearChanged()
    dirty = true
    ns.OutOfCombat(UpdateLureButton)
    ns.Fire("EZF_GEAR_CHANGED")
end

ns.On("EZF_READY", OnGearChanged)
ns.On("BAG_UPDATE_DELAYED", OnGearChanged)
ns.On("EZF_SKILL_CHANGED", OnGearChanged)
ns.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
    if slot ~= INVSLOT_MAINHAND and slot ~= INVSLOT_OFFHAND then return end
    -- Forget the saved weapons once something other than the pole is back in the main hand.
    if slot == INVSLOT_MAINHAND and not ns.PoleEquipped() then ns.char.weapons = nil end
    OnGearChanged()
end)

-- Warn once when the lure runs out mid-session.
local hadLure = false
ns.On("EZF_TICK", function()
    local left = ns.LureTimeLeft()
    if hadLure and not left and ns.active and ns.PoleEquipped() and ns.db.lureWarning then
        ns.Print(ns.COLOR.bad .. "Lure expired.|r")
        PlaySound(SOUNDKIT.RAID_WARNING)
        ns.Fire("EZF_LURE_EXPIRED")
    end
    hadLure = left ~= nil
end)

---------------------------------------------------------------------------
-- Pole swap (Forever keeps the pole in the main hand)
---------------------------------------------------------------------------
function Gear.EquipPole()
    if ns.PoleEquipped() then return end
    if InCombatLockdown() then return ns.Print("Can't swap to the pole in combat.") end
    local pole = Gear.BestPole()
    if not pole then return ns.Print("No fishing pole in your bags.") end
    ns.char.weapons = {
        main = GetInventoryItemLink("player", INVSLOT_MAINHAND),
        off = GetInventoryItemLink("player", INVSLOT_OFFHAND),
    }
    ns.EquipItem(pole, INVSLOT_MAINHAND)
end

-- Puts the remembered weapons back. Main hand swaps are allowed in combat, so this also runs
-- when combat starts (untested on Forever; failures just leave the pole equipped).
function Gear.EquipWeapons()
    local w = ns.char.weapons
    if not w or not ns.PoleEquipped() then return end
    if w.main then ns.EquipItem(w.main, INVSLOT_MAINHAND) end
    if w.off then
        -- The pole is two-handed; give the main hand a moment to land before the off hand.
        C_Timer.After(0.5, function() ns.EquipItem(w.off, INVSLOT_OFFHAND) end)
    end
end

function Gear.TogglePole()
    if not ns.PoleEquipped() then return Gear.EquipPole() end
    if not ns.char.weapons then return ns.Print("No saved weapons to swap back to.") end
    Gear.EquipWeapons()
end

-- Global for the key binding in Bindings.xml.
EzFishing_TogglePole = Gear.TogglePole

ns.On("PLAYER_REGEN_DISABLED", function()
    if ns.db.swapBackCombat then Gear.EquipWeapons() end
end)
