-- Catch log: what you caught, where, how fast, plus fishing skill-ups.
local _, ns = ...

local Stats = {}
ns.Stats = Stats

-- This login only.
local session = { casts = 0, catches = 0, escapes = 0, items = {}, fishTime = 0 }
Stats.session = session

local castStart, castLooted, modeStart
local lastRank

local function ZoneEntry()
    local zone = ns.ZoneName()
    local z = ns.char.zones[zone]
    if not z then
        z = { catches = 0, escapes = 0 }
        ns.char.zones[zone] = z
    end
    return z
end

-- Seconds spent in fishing mode this login, including the current stretch.
function Stats.FishingTime()
    return session.fishTime + (modeStart and GetTime() - modeStart or 0)
end

function Stats.PerHour()
    local t = Stats.FishingTime()
    if t < 60 or session.catches == 0 then return nil end
    return session.catches / t * 3600
end

-- Rolling average of seconds from cast to loot (the bite usually comes just before that).
function Stats.AvgBite()
    return ns.char.biteAvg
end

ns.On("EZF_MODE_START", function() modeStart = GetTime() end)
ns.On("EZF_MODE_END", function()
    if modeStart then session.fishTime = session.fishTime + GetTime() - modeStart end
    modeStart = nil
end)

ns.On("EZF_CAST_START", function()
    castStart, castLooted = GetTime(), false
    session.casts = session.casts + 1
    ns.char.casts = ns.char.casts + 1
end)

ns.On("LOOT_OPENED", function()
    if castLooted or not IsFishingLoot() then return end
    castLooted = true

    session.catches = session.catches + 1
    ns.char.catches = ns.char.catches + 1
    local z = ZoneEntry()
    z.catches = z.catches + 1

    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        if link and not ns.issecret(link) then
            local id = C_Item.GetItemInfoInstant(link)
            local qty = select(3, GetLootSlotInfo(i)) or 1
            if id then
                session.items[id] = (session.items[id] or 0) + qty
                ns.char.items[id] = (ns.char.items[id] or 0) + qty
            end
        end
    end

    if castStart then
        local dt = GetTime() - castStart
        if dt > 1 and dt < 30 then
            local avg = ns.char.biteAvg
            ns.char.biteAvg = avg and (avg * 0.8 + dt * 0.2) or dt
        end
    end
    ns.Fire("EZF_STATS_CHANGED")
end)

-- "Your fish got away!" arrives as an error or info message depending on client.
local function OnMessage(_, message)
    if not ERR_FISH_ESCAPED or ns.issecret(message) or message ~= ERR_FISH_ESCAPED then return end
    session.escapes = session.escapes + 1
    local z = ZoneEntry()
    z.escapes = z.escapes + 1
    ns.Fire("EZF_STATS_CHANGED")
end
ns.On("UI_ERROR_MESSAGE", OnMessage)
ns.On("UI_INFO_MESSAGE", OnMessage)

ns.On("EZF_SKILL_CHANGED", function()
    local rank, maxRank = ns.FishingSkill()
    if rank and lastRank and rank > lastRank then
        if ns.db.announceSkill then
            ns.Print(format("Fishing skill %s%d|r / %d", ns.COLOR.good, rank, maxRank))
        end
        ns.Fire("EZF_SKILL_UP", rank)
    end
    lastRank = rank or lastRank
end)

---------------------------------------------------------------------------
-- Reporting
---------------------------------------------------------------------------
local function ItemName(id)
    local name = C_Item.GetItemNameByID(id)
    local quality = C_Item.GetItemQualityByID(id)
    if not name then return "item:" .. id end
    local color = quality and ITEM_QUALITY_COLORS[quality]
    return color and color.hex .. name .. "|r" or name
end

-- Top n items from an itemID -> count table, as { {name, count}, ... }.
function Stats.Top(items, n)
    local list = {}
    for id, count in pairs(items) do list[#list + 1] = { id = id, count = count } end
    table.sort(list, function(a, b) return a.count > b.count end)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = { ItemName(list[i].id), list[i].count } end
    return out
end

local function PrintTop(items)
    for _, row in ipairs(Stats.Top(items, 5)) do ns.Print(format("  %s x%d", row[1], row[2])) end
end

function Stats.PrintSummary()
    local rate = Stats.PerHour()
    ns.Print(format("This session: %d casts, %d catches, %d got away%s.", session.casts, session.catches,
        session.escapes, rate and format(", %.0f/h", rate) or ""))
    PrintTop(session.items)
    ns.Print(format("All time: %d casts, %d catches.", ns.char.casts, ns.char.catches))
    PrintTop(ns.char.items)
end

function Stats.Clear()
    wipe(ns.char.items)
    wipe(ns.char.zones)
    ns.char.casts, ns.char.catches, ns.char.biteAvg = 0, 0, nil
    session.casts, session.catches, session.escapes, session.fishTime = 0, 0, 0, 0
    wipe(session.items)
    ns.Fire("EZF_STATS_CHANGED")
end
