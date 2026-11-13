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
ns.On("EZF_MODE_END", Gear.ApplySession)

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
-- The weapons in hand are remembered on every change while no pole is equipped (and kept after
-- swapping back), so the swap back also works when the pole was put on by hand from the bags.
ns.On("PLAYER_LOGIN", function()
    Gear.SaveWeapons()
    OnGearChanged()
end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
    if slot ~= INVSLOT_MAINHAND and slot ~= INVSLOT_OFFHAND then return end
    Gear.SaveWeapons()
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
-- Pole swap (Forever keeps the pole in the main hand). Forever blocks EquipItemByName from addon
-- code, even from a key binding, so the swap is a secure macro button running /equipslot: the HUD's
-- pole icon, the "Swap pole / weapons" key (override-clicked onto it) and /click EzFishingPoleButton.
-- Its macro is rebuilt out of combat whenever gear or bags change.
---------------------------------------------------------------------------
local poleBtn = CreateFrame("Button", "EzFishingPoleButton", UIParent, "SecureActionButtonTemplate")
poleBtn:RegisterForClicks("AnyUp", "AnyDown")
Gear.poleButton = poleBtn

-- "/equipslot" argument for a saved weapon: its bag and slot (exact, even with two copies of one
-- weapon; skip = a spot already taken), else its item ID.
local function ItemArg(link, skip)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local where = bag .. " " .. slot
            if where ~= skip and C_Container.GetContainerItemLink(bag, slot) == link then return where end
        end
    end
    local id = link:match("item:(%d+)")
    return id and "item:" .. id
end

function Gear.PoleMacro()
    local pole = Gear.BestPole()
    return pole and format("/equipslot %d item:%d", INVSLOT_MAINHAND, pole)
end

-- Both weapons in one press, main hand first, so the two-handed pole is off before the off hand goes on.
function Gear.WeaponsMacro()
    local w = ns.char.weapons
    if not w then return nil end
    local lines = {}
    local main = w.main and ItemArg(w.main)
    if main then lines[#lines + 1] = format("/equipslot %d %s", INVSLOT_MAINHAND, main) end
    local off = w.off and ItemArg(w.off, main)
    if off then lines[#lines + 1] = format("/equipslot %d %s", INVSLOT_OFFHAND, off) end
    return lines[1] and table.concat(lines, "\n")
end

-- Remembers the weapons in hand (never the pole). Empty hands keep the last weapons saved, so
-- taking a weapon off before putting the pole on still swaps back to it.
function Gear.SaveWeapons()
    if ns.PoleEquipped() then return end
    local main = GetInventoryItemLink("player", INVSLOT_MAINHAND)
    local off = GetInventoryItemLink("player", INVSLOT_OFFHAND)
    if not main and not off then return end
    ns.char.weapons = { main = main, off = off }
end

local function UpdatePoleButton()
    local macro
    if ns.PoleEquipped() then macro = Gear.WeaponsMacro() else macro = Gear.PoleMacro() end
    poleBtn:SetAttribute("type", macro and "macro" or nil)
    poleBtn:SetAttribute("macrotext", macro)
end

ns.On("EZF_GEAR_CHANGED", function() ns.OutOfCombat(UpdatePoleButton) end)

-- PreClick runs for both halves of a click; act once.
local lastPress = 0
poleBtn:SetScript("PreClick", function()
    local now = GetTime()
    if now - lastPress < 0.5 then return end
    lastPress = now
    if ns.PoleEquipped() then
        if not ns.char.weapons then ns.Print("No saved weapons to swap back to.") end
    elseif Gear.BestPole() then
        Gear.SaveWeapons()
    else
        ns.Print("No fishing pole in your bags.")
    end
    if not InCombatLockdown() then UpdatePoleButton() end
end)

-- Keys bound to "Swap pole / weapons" click the button instead of running the binding's Lua.
-- Override bindings are protected in combat; only reapplied when the keys change, since setting
-- them fires UPDATE_BINDINGS again.
local boundKeys = ""
local function BindPoleKeys()
    local keys = { GetBindingKey("EZFISHING_POLE") }
    local list = table.concat(keys, " ")
    if list == boundKeys then return end
    boundKeys = list
    ClearOverrideBindings(poleBtn)
    for _, key in ipairs(keys) do SetOverrideBindingClick(poleBtn, false, key, poleBtn:GetName()) end
end

ns.On("EZF_READY", function() ns.OutOfCombat(BindPoleKeys) end)
ns.On("UPDATE_BINDINGS", function() ns.OutOfCombat(BindPoleKeys) end)

local function KeyText()
    local key = GetBindingKey("EZFISHING_POLE")
    return key and (ns.COLOR.accent .. GetBindingText(key) .. "|r") or "the HUD's pole button"
end

-- Addon code can't swap gear, so /ezf pole (and the binding, before its key is set up) only explains.
function Gear.SwapHint()
    ns.Print(format("Swap with %s, or %s/click EzFishingPoleButton|r (works in macros).", KeyText(), ns.COLOR.accent))
end

-- Global for the key binding in Bindings.xml.
EzFishing_TogglePole = Gear.SwapHint

local function Remind(text)
    if ns.PoleEquipped() and ns.char.weapons then ns.Print(format(text, KeyText())) end
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if ns.db.swapBackCombat then Remind(ns.COLOR.bad .. "Still holding the pole.|r Press %s for your weapons.") end
end)

ns.On("EZF_MODE_END", function(reason)
    if reason == "idle" and ns.db.swapBackOnEnd then Remind("Done fishing? Press %s for your weapons.") end
end)
