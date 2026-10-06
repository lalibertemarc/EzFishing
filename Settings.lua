-- Options page: Esc > Options > AddOns > EzFishing.
local _, ns = ...

local function Build()
    local category, layout = Settings.RegisterVerticalLayoutCategory("EzFishing")
    ns.settingsCategory = category
    local db = ns.db

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Register(key, varType, name, onChange)
        local setting = Settings.RegisterAddOnSetting(category, "EZFISHING_" .. key:upper(), key, db, varType,
            name, ns.DEFAULTS[key])
        if onChange then setting:SetValueChangedCallback(onChange) end
        return setting
    end

    local function Check(key, name, tooltip, onChange)
        return Settings.CreateCheckbox(category, Register(key, Settings.VarType.Boolean, name, onChange), tooltip)
    end

    local function Slider(key, name, tooltip, min, max, step, formatter, onChange)
        local options = Settings.CreateSliderOptions(min, max, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
        return Settings.CreateSlider(category, Register(key, Settings.VarType.Number, name, onChange), options, tooltip)
    end

    local function Dropdown(key, name, tooltip, choices, onChange)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            for _, choice in ipairs(choices) do container:Add(choice[1], choice[2]) end
            return container:GetData()
        end
        return Settings.CreateDropdown(category, Register(key, Settings.VarType.Number, name, onChange), GetOptions, tooltip)
    end

    local function Percent(value) return format("%d%%", value * 100 + 0.5) end
    local function Seconds(value) return format("%.2fs", value) end
    local function Whole(value) return format("%ds", value) end

    local ApplySession, RefreshHUD = ns.Gear.ApplySession, ns.HUD.Refresh

    Header("Key bindings")
    -- Same binding rows as the Key Bindings page, so keys can be set right here.
    local bindingsAdded = false
    for _, binding in ipairs(ns.BINDINGS) do
        local index = C_KeyBindings.GetBindingIndex(binding.action)
        if index then
            local initializer = CreateKeybindingEntryInitializer(index, true)
            initializer:AddSearchTags(binding.label)
            layout:AddInitializer(initializer)
            bindingsAdded = true
        end
    end
    if not bindingsAdded then
        layout:AddInitializer(CreateSettingsButtonInitializer("Cast / Hook key", "Key Bindings",
            function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, "EzFishing") end,
            "Bind the keys in the EzFishing section of the Key Bindings page.", true))
    end

    Header("Casting")
    Check("keyHook", "Same key hooks the bobber",
        "While the bobber is out, the Cast key becomes Interact, which loots the bobber through soft targeting.")
    Check("doubleClick", "Double right-click to cast",
        "Double right-click in the world to cast (pole equipped). While fishing, a double right-click hooks the bobber.")
    Slider("doubleClickSpeed", "Double-click speed", "Longest gap between the two right-clicks.", 0.2, 0.6, 0.05, Seconds)
    Check("bobberIcon", "Bobber icon", "Show the soft-target icon over the bobber while fishing.")

    Header("Sound")
    Check("soundPreset", "Fishing sound preset",
        "While fishing: music and ambience off, sound effects at max so the splash is easy to hear. Restored afterwards.",
        ApplySession)
    Check("backgroundSound", "Sound in background", "Keep game sound on while WoW isn't the focused window.", ApplySession)
    Check("masterBoost", "Boost master volume", "Also set the master volume while fishing.", ApplySession)
    Slider("masterVolume", "Master volume while fishing", nil, 0.1, 1, 0.05, Percent, ApplySession)

    Header("Helpers")
    Check("autoLoot", "Auto-loot while fishing", "Turn on auto-loot for the fishing session.", ApplySession)
    Check("smartPole", "Cast key equips your pole",
        "If no pole is equipped, the Cast key equips the best pole in your bags first.")
    Check("smartLure", "Cast key applies a lure",
        "If the pole has no lure, the Cast key applies the best lure in your bags before casting.")
    Check("lureWarning", "Warn when the lure expires")
    Check("swapBackCombat", "Swap weapons back in combat",
        "When combat starts, re-equip the weapons the pole replaced.")
    Check("swapBackOnEnd", "Swap weapons back when done",
        "Re-equip your weapons once you stop fishing (idle timeout).")
    Slider("idleTimeout", "Session ends after", "Fishing session (sound preset, auto-loot) ends after this long without casting.",
        15, 300, 15, Whole)

    Header("HUD")
    Dropdown("hudMode", "Show HUD", nil,
        { { ns.HUD_AUTO, "While fishing or holding a pole" }, { ns.HUD_ALWAYS, "Always" }, { ns.HUD_NEVER, "Never" } },
        RefreshHUD)
    Check("locked", "Lock position", "Shift-drag always moves the HUD.")
    Slider("scale", "Scale", nil, 0.6, 2, 0.05, Percent, RefreshHUD)
    Check("announceSkill", "Announce skill-ups in chat")

    Settings.RegisterAddOnCategory(category)
end

ns.On("EZF_READY", Build)
