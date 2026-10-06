-- Temporary CVar changes that always get undone.
-- Push(tag, values) remembers the original values in saved variables before changing anything;
-- Pop(tag) puts them back. Leftovers (e.g. after a /reload mid-cast) are restored at login.
local _, ns = ...

local CVars = {}
ns.CVars = CVars

local applying = false
local reported = {}

-- The game can refuse a CVar change (protected CVars); say so once instead of failing silently.
local function Set(name, value)
    value = tostring(value)
    applying = true
    local ok, err = pcall(C_CVar.SetCVar, name, value)
    applying = false
    local now = C_CVar.GetCVar(name)
    local stuck = now == value or (tonumber(now) ~= nil and tonumber(now) == tonumber(value)) -- "1" vs "1.0"
    if (ok and stuck) or reported[name] then return end
    reported[name] = true
    ns.Print(format("The game didn't allow changing %s (%s).", name, ok and "value didn't stick" or tostring(err)))
    ns.Fire("EZF_CVAR_BLOCKED", name)
end

function CVars.Push(tag, values)
    local backup = ns.db.cvarBackup
    local saved = backup[tag] or {}
    for name, value in pairs(values) do
        if saved[name] == nil then saved[name] = C_CVar.GetCVar(name) end
        -- GetCVar returns nil for CVars this client doesn't have; leave those alone.
        if saved[name] ~= nil then Set(name, value) end
    end
    backup[tag] = saved
end

function CVars.Pop(tag)
    local saved = ns.db.cvarBackup[tag]
    if not saved then return end
    for name, value in pairs(saved) do Set(name, value) end
    ns.db.cvarBackup[tag] = nil
end

function CVars.PopAll()
    for tag in pairs(ns.db.cvarBackup) do CVars.Pop(tag) end
end

-- If the player changes one of our CVars while it's pushed (e.g. moves a volume slider),
-- keep their new value as the one to restore. SetCVar() goes through C_CVar.SetCVar too.
hooksecurefunc(C_CVar, "SetCVar", function(name, value)
    if applying or not ns.db or not next(ns.db.cvarBackup) or type(name) ~= "string" or value == nil then return end
    local lname = name:lower()
    for _, saved in pairs(ns.db.cvarBackup) do
        for k in pairs(saved) do
            if k:lower() == lname then saved[k] = tostring(value) end
        end
    end
end)

ns.On("EZF_READY", CVars.PopAll)
ns.On("PLAYER_LOGOUT", CVars.PopAll)
