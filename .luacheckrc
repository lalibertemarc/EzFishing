std = "lua51"
max_line_length = false
self = false

globals = {
    "EzFishingDB",
    "EzFishingCharDB",
    "EzFishing_TogglePole",
    "_G", -- BINDING_NAME_* labels are set through _G (some contain spaces)
    "SLASH_EZFISHING1",
    "SLASH_EZFISHING2",
    "SlashCmdList",
}

read_globals = {
    -- Lua / WoW utility
    "format", "floor", "wipe", "unpack", "hooksecurefunc",
    -- Frames & UI
    "CreateFrame", "UIParent", "GameTooltip", "DEFAULT_CHAT_FRAME", "ITEM_QUALITY_COLORS",
    "SecureHandlerWrapScript", "PlaySound", "SOUNDKIT",
    -- Settings panel
    "Settings", "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",
    "CreateKeybindingEntryInitializer", "C_KeyBindings",
    "MinimalSliderWithSteppersMixin",
    -- Namespaced APIs
    "C_Spell", "C_Item", "C_Container", "C_CVar", "C_SkillInfo", "C_PaperDollInfo",
    "C_Timer", "issecretvalue", "Enum",
    -- Constants
    "INVSLOT_MAINHAND", "INVSLOT_OFFHAND", "NUM_BAG_SLOTS", "ERR_FISH_ESCAPED",
    -- Global APIs
    "GetSpellInfo", "GetItemCount", "GetItemIcon", "EquipItemByName",
    "GetWeaponEnchantInfo", "GetProfessions", "GetProfessionInfo",
    "GetInventoryItemID", "GetInventoryItemLink", "UnitChannelInfo", "UnitExists", "UnitIsDeadOrGhost",
    "UnitHasVehicleUI", "GetRealZoneText", "GetSubZoneText", "GetTime", "InCombatLockdown",
    "IsShiftKeyDown", "IsMouseButtonDown", "IsMounted", "IsFlying", "IsFalling", "IsSwimming", "IsSubmerged",
    "IsPlayerMoving", "IsStealthed", "HasFullControl",
    "GetBindingKey", "GetBindingText", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
    "UnitName", "IsFishingLoot", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo",
}
