-- EzFishing: one-key fishing helper for WoW Forever.
-- Forever runs the modern (Midnight 12.x) API with classic content, so this targets C_* namespaces.
local addonName, ns = ...

local COLOR = ns.COLOR

---------------------------------------------------------------------------
-- Events: ns.On(event, fn) for game events and internal "EZF_*" messages
---------------------------------------------------------------------------
local handlers = {}
local ev = CreateFrame("Frame")

function ns.On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if not event:find("^EZF_") then ev:RegisterEvent(event) end
    end
    list[#list + 1] = fn
end

function ns.Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

ev:SetScript("OnEvent", function(_, event, ...) ns.Fire(event, ...) end)

-- Runs fn now, or once when combat ends if secure frames and bindings are locked.
local afterCombat = {}
function ns.OutOfCombat(fn)
    if InCombatLockdown() then
        afterCombat[fn] = true
    else
        fn()
    end
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for fn in pairs(afterCombat) do
        afterCombat[fn] = nil
        fn()
    end
end)

---------------------------------------------------------------------------
-- API compat: prefer C_* namespaces, fall back to old globals
---------------------------------------------------------------------------
-- Forever can hand addons "secret" values in restricted situations (combat, instances).
local issecret = issecretvalue or function() return false end
ns.issecret = issecret

function ns.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

function ns.ItemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) end
    return GetItemCount(id)
end

function ns.ItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(item) end
    return GetItemIcon and GetItemIcon(item)
end

function ns.EquipItem(item, slot)
    if C_Item and C_Item.EquipItemByName then return C_Item.EquipItemByName(item, slot) end
    return EquipItemByName(item, slot)
end

local function ReadLure()
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local info = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)
        if info and not issecret(info) and info.remainingTimeMs then return info.remainingTimeMs / 1000 end
        return nil
    end
    if GetWeaponEnchantInfo then
        local has, ms = GetWeaponEnchantInfo()
        if has and ms then return ms / 1000 end
    end
end

local function ReadSkill()
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, ns.FISHING_SKILL_LINE)
        if ok and type(info) == "table" and (info.maxRank or 0) > 0 then
            return info.rank, info.maxRank, info.modifier or 0
        end
    end
    if GetProfessions then
        local fish = select(4, GetProfessions())
        if fish then
            local _, _, rank, maxRank, _, _, _, modifier = GetProfessionInfo(fish)
            return rank, maxRank, modifier or 0
        end
    end
end

---------------------------------------------------------------------------
-- Cached lure and skill: those APIs build a new table per call, so read them on events only
---------------------------------------------------------------------------
local LURE_RESYNC = 10 -- re-read now and then in case an event was missed
local lureExpires, lureReadAt = nil, -math.huge

-- Seconds left on the lure applied to the pole (main hand), or nil.
function ns.LureTimeLeft()
    local now = GetTime()
    if now - lureReadAt > LURE_RESYNC then
        local left = ReadLure()
        lureExpires, lureReadAt = left and now + left, now
    end
    local left = lureExpires and lureExpires - now
    return left and left > 0 and left or nil
end

local skillRank, skillMax, skillMod

-- Returns rank, maxRank, modifier (pole + lure bonus) or nil if Fishing isn't learned.
function ns.FishingSkill()
    return skillRank, skillMax, skillMod
end

local function RefreshSkill()
    local rank, maxRank, mod = ReadSkill()
    if rank == skillRank and maxRank == skillMax and mod == skillMod then return end
    skillRank, skillMax, skillMod = rank, maxRank, mod
    ns.Fire("EZF_SKILL_CHANGED")
end

local function InvalidateLure() lureReadAt = -math.huge end

local function OnGearChanged()
    InvalidateLure()
    RefreshSkill()
end

ns.On("PLAYER_LOGIN", RefreshSkill)
ns.On("SKILL_LINES_CHANGED", RefreshSkill)
ns.On("PLAYER_EQUIPMENT_CHANGED", OnGearChanged)
ns.On("WEAPON_ENCHANT_CHANGED", OnGearChanged)
ns.On("UNIT_INVENTORY_CHANGED", function(unit)
    if unit == "player" then InvalidateLure() end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function ns.IsPole(item)
    if not item then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item)
    return classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Fishingpole
end

function ns.PoleEquipped()
    return ns.IsPole(GetInventoryItemID("player", INVSLOT_MAINHAND))
end

local function IsFishingSpell(spellID)
    return spellID ~= nil and not issecret(spellID) and ns.FISHING_SPELLS[spellID] == true
end

-- Fishing channel info: startSeconds, endSeconds (nil when not fishing).
function ns.FishingChannel()
    local _, _, _, startMs, endMs, _, _, spellID = UnitChannelInfo("player")
    if IsFishingSpell(spellID) then return startMs / 1000, endMs / 1000 end
end

function ns.IsFishing()
    return ns.FishingChannel() ~= nil
end

function ns.ZoneName()
    return GetRealZoneText() or ""
end

-- Skill needed in the current (sub)zone, plus the name it was found under.
function ns.ZoneRequirement()
    local sub, zone = GetSubZoneText(), ns.ZoneName()
    if sub and ns.ZONE_SKILL[sub] then return ns.ZONE_SKILL[sub], sub end
    return ns.ZONE_SKILL[zone], zone
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(COLOR.accent .. "EzFishing|r: " .. msg)
end

function ns.FormatTime(sec)
    sec = floor(sec + 0.5)
    if sec >= 3600 then return format("%dh%02d", floor(sec / 3600), floor(sec % 3600 / 60)) end
    return format("%d:%02d", floor(sec / 60), sec % 60)
end

---------------------------------------------------------------------------
-- Saved variables and key binding labels
---------------------------------------------------------------------------
for _, binding in ipairs(ns.BINDINGS) do
    _G["BINDING_NAME_" .. binding.action] = binding.label
end

ns.On("ADDON_LOADED", function(name)
    if name ~= addonName then return end
    EzFishingDB = EzFishingDB or {}
    for k, v in pairs(ns.DEFAULTS) do
        if EzFishingDB[k] == nil then EzFishingDB[k] = v end
    end
    EzFishingDB.cvarBackup = EzFishingDB.cvarBackup or {}

    EzFishingCharDB = EzFishingCharDB or {}
    local c = EzFishingCharDB
    c.items = c.items or {}   -- itemID -> count, all time
    c.zones = c.zones or {}   -- zone -> { catches, escapes }
    c.casts = c.casts or 0
    c.catches = c.catches or 0

    ns.db, ns.char = EzFishingDB, EzFishingCharDB
    ns.Fire("EZF_READY")
end)

---------------------------------------------------------------------------
-- Fishing mode: starts on the first cast, ends after idle timeout, combat,
-- or when the pole comes off. Sound preset and auto-loot live for its duration.
---------------------------------------------------------------------------
ns.active = false
local lastActivity = 0

function ns.StopMode(reason)
    if not ns.active then return end
    ns.active = false
    ns.Fire("EZF_MODE_END", reason)
end

ns.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
    if unit ~= "player" or not IsFishingSpell(spellID) then return end
    lastActivity = GetTime()
    if not ns.active then
        ns.active = true
        ns.Fire("EZF_MODE_START")
    end
    ns.Fire("EZF_CAST_START")
end)

ns.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit, _, spellID)
    if unit ~= "player" or not IsFishingSpell(spellID) then return end
    lastActivity = GetTime()
    ns.Fire("EZF_CAST_STOP")
end)

ns.On("PLAYER_REGEN_DISABLED", function() ns.StopMode("combat") end)

ns.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
    if slot == INVSLOT_MAINHAND and not ns.PoleEquipped() then ns.StopMode("unequip") end
end)

-- One shared 1s tick (EZF_TICK) for everything time-based.
ns.On("EZF_READY", function()
    C_Timer.NewTicker(1, function()
        if ns.active and not ns.IsFishing() and GetTime() - lastActivity > ns.db.idleTimeout then
            ns.StopMode("idle")
        end
        ns.Fire("EZF_TICK")
    end)
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
    "/ezf config - open settings",
    "/ezf show | hide | auto - HUD always shown, hidden, or only while fishing",
    "/ezf lock | unlock - lock HUD position (shift-drag always moves)",
    "/ezf reset - reset HUD position",
    "/ezf pole - swap fishing pole / weapons",
    "/ezf stats - print catch stats",
    "/ezf clear - clear this character's catch stats",
    "/ezf zone - show the zone name and skill requirement used",
    "/ezf debug - show interact settings and what the interact key would hit",
}

local function SetHudMode(mode, text)
    ns.db.hudMode = mode
    ns.HUD.Refresh()
    ns.Print(text)
end

local function SetLocked(locked, text)
    ns.db.locked = locked
    ns.Print(text)
end

local COMMANDS = {
    config = function() Settings.OpenToCategory(ns.settingsCategory:GetID()) end,
    show   = function() SetHudMode(ns.HUD_ALWAYS, "HUD always shown.") end,
    hide   = function() SetHudMode(ns.HUD_NEVER, "HUD hidden.") end,
    auto   = function() SetHudMode(ns.HUD_AUTO, "HUD shown while fishing or holding a pole.") end,
    lock   = function() SetLocked(true, "Locked.") end,
    unlock = function() SetLocked(false, "Unlocked.") end,
    reset  = function()
        ns.db.pos = nil
        ns.HUD.ApplyPosition()
        ns.Print("Position reset.")
    end,
    pole   = function() ns.Gear.TogglePole() end,
    stats  = function() ns.Stats.PrintSummary() end,
    clear  = function()
        ns.Stats.Clear()
        ns.Print("Catch stats cleared.")
    end,
    zone   = function()
        local req, where = ns.ZoneRequirement()
        ns.Print(format("Zone: %s, subzone: %s -> %s", ns.ZoneName(), GetSubZoneText() or "",
            req and format("needs %d (%s)", req, where) or "no data"))
    end,
    debug  = function()
        for _, cvar in ipairs({ "SoftTargetInteract", "SoftTargetInteractArc", "SoftTargetInteractRange" }) do
            ns.Print(format("%s = %s", cvar, tostring(C_CVar.GetCVar(cvar))))
        end
        ns.Print(format("Fishing: %s, soft target: %s, target: %s", tostring(ns.IsFishing()),
            tostring(UnitName("softinteract") or "none"), tostring(UnitName("target") or "none")))
    end,
}

SLASH_EZFISHING1 = "/ezf"
SLASH_EZFISHING2 = "/ezfishing"
SlashCmdList.EZFISHING = function(msg)
    local fn = COMMANDS[msg:match("^(%S*)"):lower()]
    if fn then
        fn()
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end
