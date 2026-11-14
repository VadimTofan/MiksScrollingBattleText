-- Public-event subset of NameplateSCT Reforged's warlock-tick-jitter trace,
-- pinned at e678a89bb7fe15232e0425c81735779da13d5111 (MIT). See the repository's
-- Combat/LICENSE-NameplateSCTReforged. Times are relative to its first cast;
-- names, GUIDs, cast IDs, unreadable line text, and amounts are sanitized.
-- Entry IDs are retained solely to locate the source observation.
--
-- This replays a fixed-target prefix, not a whole-addon accuracy benchmark.
-- Target/nameplate aliases are normalized to one report because the recording
-- contains several aliases for each observation. Player and pet reports remain
-- present so healing and channel ordering reach the real reader.
-- Recorded public line kinds are translated into MSBT's own filter colours.
--
-- Unrecorded API assumptions: one living hostile target with a visible plate,
-- a living pet, no weapon enchant, enUS, harmful cast classification, and no
-- spellbook/aura state. Pet target and tooltip availability vary below. Timers
-- defer zero-delay work by at least 17 ms to model end-of-frame dispatch.

local timeline = {
    { 0.000, "sent", "player", 6217 },
    { 0.000, "cast", "player", 6217 },
    { 1.092, "local", "player", "WOUND", 1 },
    { 1.500, "sent", "player", 6223 },
    { 1.500, "cast", "player", 6223 },
    { 1.675, "line", "swing" },
    { 1.776, "line", "direct" },
    { 1.776, "hit", 9, 32 },
    { 1.776, "cast", "pet", 7815 },
    { 2.020, "hit", 13, 32 },
    { 2.020, "line", "tick" },
    { 2.633, "hit", 17, 1 },
    { 2.945, "sent", "player", 18265 },
    { 2.945, "cast", "player", 18265 },
    { 3.019, "local", "pet", "WOUND", 1 },
    { 3.733, "line", "swing" },
    { 4.000, "hit", 25, 32 },
    { 4.000, "line", "tick" },
    { 4.512, "hit", 29, 32 },
    { 4.512, "line", "tick" },
    { 4.691, "hit", 33, 1 },
    { 4.992, "sent", "player", 1456 },
    { 4.992, "cast", "player", 1456 },
    { 5.002, "local", "pet", "WOUND", 1 },
    { 5.778, "line", "swing" },
    { 6.004, "hit", 41, 32 },
    { 6.004, "line", "tick" },
    { 6.004, "line", "tick" },
    { 6.004, "hit", 46, 32 },
    { 6.004, "local", "player", "HEAL", 1 },
    { 6.004, "line", "heal" },
    { 6.542, "sent", "player", 3699 },
    { 6.542, "channel", 3699 },
    { 6.542, "cast", "player", 3699 },
    { 6.725, "hit", 54, 1 },
    { 7.029, "local", "pet", "WOUND", 1 },
    { 7.519, "hit", 59, 32 },
    { 7.519, "line", "tick" },
    { 7.619, "local", "player", "WOUND", 32 },
    { 7.619, "line", "tick" },
    { 7.619, "local", "pet", "HEAL", 1 },
    { 7.619, "line", "hot" },
    { 7.736, "line", "swing" },
    { 8.008, "hit", 69, 32 },
    { 8.008, "line", "tick" },
    { 8.008, "stop", 3699 },
    { 8.533, "sent", "player", 709 },
    { 8.533, "channel", 709 },
    { 8.533, "cast", "player", 709 },
    { 8.686, "hit", 77, 1 },
    { 8.920, "line", "tick" },
    { 8.920, "hit", 81, 32 },
    { 8.920, "local", "player", "HEAL", 1 },
    { 8.920, "line", "heal" },
    { 9.717, "line", "tick" },
    { 9.717, "hit", 88, 32 },
    { 9.717, "local", "player", "HEAL", 1 },
    { 9.717, "line", "heal" },
    { 9.724, "local", "player", "WOUND", 1 },
    { 9.786, "line", "swing" },
    { 9.994, "hit", 97, 32 },
    { 9.994, "line", "tick" },
    { 10.526, "hit", 101, 32 },
    { 10.526, "line", "tick" },
    { 10.526, "line", "tick" },
    { 10.526, "hit", 106, 32 },
    { 10.526, "local", "player", "HEAL", 1 },
    { 10.526, "line", "heal" },
}

local descriptions = {
    [709] = "Transfers 29 health every 1 sec from the target to the caster.",
    [18265] = "Transfers 15 health every 3 sec from the target to the caster.",
    [6217] = "Curses the target with agony, causing 324 Shadow damage over 24 sec.",
    [6223] = "Corrupts the target, causing 222 Shadow damage over 18 sec.",
}
local lineEvents = {
    direct = "SPELL_DAMAGE", tick = "SPELL_PERIODIC_DAMAGE",
    swing = "SWING_DAMAGE", heal = "SPELL_HEAL", hot = "SPELL_PERIODIC_HEAL",
}

local function Replay(petFollowsTarget, hasDescriptions)
    local now, timers, results, displayed, amounts = 100, {}, {}, {}, {}
    local opaque = setmetatable({}, { __mode = "k" })
    local function Amount()
        local value = setmetatable({}, {
            __add = function() error("added a recorded opaque amount") end,
            __lt = function() error("ordered a recorded opaque amount") end,
            __le = function() error("compared a recorded opaque amount") end,
            __tostring = function() error("read a recorded opaque amount") end,
        })
        opaque[value] = true
        return value
    end

    MikSBT = { Components = {},
        Compatibility = { Client = { isForever = true } } }
    issecretvalue = function(value)
        return value == "<secret>" or opaque[value] == true
    end
    GetTime = function() return now end
    GetLocale = function() return "enUS" end
    UnitExists = function(unit)
        return unit == "player" or unit == "pet" or unit == "target"
            or unit == "nameplate1" or unit == "pettarget"
    end
    UnitIsUnit = function(a, b)
        local function Canonical(unit)
            if unit == "target" then return "nameplate1" end
            if unit == "pettarget" then
                return petFollowsTarget and "nameplate1" or "other-target"
            end
            return unit
        end
        return Canonical(a) == Canonical(b)
    end
    UnitGUID = function(unit)
        if unit == "player" then return "Player-Replay" end
        if unit == "pet" then return "Pet-Replay" end
        return "<secret>"
    end
    UnitIsPlayer = function(unit) return UnitIsUnit(unit, "player") end
    UnitIsDead = function() return false end
    UnitName = function(unit) return unit == "pet" and "Pet" or "Player" end
    UnitClass = function() return "Warlock", "WARLOCK" end
    UnitHealthMax = function() return 1000 end
    GetWeaponEnchantInfo = function() return false end
    Enum = { CombatLogMessageOrder = { Newest = 0, Oldest = 1 } }
    C_EventUtils = { IsEventValid = function() return true end }
    C_Timer = {
        After = function(delay, callback)
            timers[#timers + 1] = {
                at = now + math.max(delay, 0.017), callback = callback,
            }
        end,
        NewTicker = function() return { Cancel = function() end } end,
    }
    CreateFrame = function()
        return {
            RegisterEvent = function() end,
            RegisterUnitEvent = function() end,
            UnregisterAllEvents = function() end,
            SetScript = function() end,
        }
    end
    C_Spell = {
        GetSpellDescription = function(id)
            return hasDescriptions and descriptions[id] or nil
        end,
        IsSpellHelpful = function() return false end,
        GetSpellTexture = function(id) return "icon-" .. id end,
        GetSpellName = function(id) return "Spell " .. id end,
    }
    dofile("API/RestrictedValue.lua")
    for _, file in ipairs({ "Context", "Helpers", "SpellCatalog", "Mine",
        "Spells", "Healing", "Reader" }) do
        dofile("Combat/" .. file .. ".lua")
    end
    local Log = dofile("Components/CombatLogFilter.lua")
    local Engine = dofile("Components/CombatEngine.lua")
    local Presentation = dofile("Components/CombatPresentation.lua")
    local Batcher = dofile("Components/OutgoingBatcher.lua")
    COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
    Blizzard_CombatLog_Filters = { filters = {} }
    local log = Log:New({
        getSaved = function() return Blizzard_CombatLog_Filters end,
        mineFlag = 1, petFlag = 2,
    })
    assert(log:WriteSettings())
    local profile = { events = {
        OUTGOING_DAMAGE = {}, OUTGOING_SPELL_DAMAGE = {},
        OUTGOING_SPELL_DOT = {}, PET_OUTGOING_DAMAGE = {},
        PET_OUTGOING_SPELL_DAMAGE = {}, PET_OUTGOING_SPELL_DOT = {},
    } }
    local batcher = Batcher:New({
        getProfile = function() return profile end,
        getSpellTexture = C_Spell.GetSpellTexture,
        isAutoAttack = function(id) return id == 6603 or id == 5019 end,
        autoAttackSpellID = 6603, after = C_Timer.After,
        displayRestricted = function(_, amount, icon, _, _, _, spell)
            displayed[amount] = displayed[amount] or {}
            local outputs = displayed[amount]
            outputs[#outputs + 1] = { spell = spell, icon = icon }
        end,
        displayRestrictedGroup = function()
            error("recorded periodic reports should not be aggregated")
        end,
        display = function() error("opaque amount reached text formatting") end,
    })
    local presentation = Presentation:New({
        batcher = batcher, getSpellTexture = C_Spell.GetSpellTexture,
    })
    local engine = Engine:New({
        log = log, getSaved = function() return nil end,
        setSaved = function() end, notify = function() end,
        presentation = {
            Out = function(_, record)
                if record.event ~= "damage" then return end
                local observations = results[record.amount] or {}
                results[record.amount] = observations
                local snapshot = {}
                for field, value in pairs(record.result or {}) do
                    snapshot[field] = value
                end
                observations[#observations + 1] = snapshot
                presentation:Out(record)
            end,
            In = function() end, Alert = function() end,
            Aura = function() end, Healer = function() end,
            Resource = function() end, ComboPoints = function() end,
        },
    })
    local function Event(event, ...) engine:HandleEvent(event, ...) end
    local function At(time)
        assert(time >= now, "recorded events must be chronological")
        while true do
            local earliest
            for index, timer in ipairs(timers) do
                if timer.at <= time
                    and (not earliest or timer.at < timers[earliest].at) then
                    earliest = index
                end
            end
            if not earliest then break end
            local timer = table.remove(timers, earliest)
            now = timer.at
            timer.callback()
        end
        now = time
    end

    -- Given one fixed hostile target and its public cast/channel history.
    engine:Start()
    Event("PLAYER_ENTERING_WORLD")
    Event("NAME_PLATE_UNIT_ADDED", "nameplate1")

    -- When recorded timing reaches the production reader with opaque amounts.
    for _, entry in ipairs(timeline) do
        At(100 + entry[1])
        local kind = entry[2]
        if kind == "cast" or kind == "sent" then
            local unit, spell = entry[3], entry[4]
            local guid = "Cast-Replay-" .. spell
            if kind == "sent" then
                Event("UNIT_SPELLCAST_SENT", unit, "", guid, spell)
            else
                Event("UNIT_SPELLCAST_SUCCEEDED", unit, guid, spell)
            end
        elseif kind == "channel" or kind == "stop" then
            local event = kind == "channel" and "UNIT_SPELLCAST_CHANNEL_START"
                or "UNIT_SPELLCAST_CHANNEL_STOP"
            Event(event, "player", nil, entry[3])
        elseif kind == "hit" then
            local amount = Amount()
            amounts[entry[3]] = amount
            Event("UNIT_COMBAT", "target", "WOUND", "", amount, entry[4])
        elseif kind == "local" then
            Event("UNIT_COMBAT", entry[3], entry[4], "", Amount(), entry[5])
        elseif kind == "line" then
            local rgb = Blizzard_CombatLog_Filters.filters[1]
                .colors.eventColoring[lineEvents[entry[3]]]
            Event("COMBAT_LOG_MESSAGE", "unreadable line",
                rgb.r, rgb.g, rgb.b, Enum.CombatLogMessageOrder.Newest)
        end
    end
    At(116)
    engine:Stop()
    return results, displayed, amounts
end

-- Offline combat-log labels are assertion data only. Nothing above receives
-- spell IDs inferred from the combat log, readable amounts, or label mappings.
local expected = {
    [13] = 6217, [25] = 6217, [29] = 6223, [41] = 6217,
    [46] = 18265, [59] = 6223, [69] = 6217, [81] = 18265,
    [88] = 709, [97] = 6217, [101] = 6223, [106] = 709,
}
local expectedEntries = { 13, 25, 29, 41, 46, 59, 69, 81, 88, 97, 101, 106 }
local sameFrame = {
    { entries = { 41, 46 }, spells = { [6217] = 1, [18265] = 1 } },
    { entries = { 101, 106 }, spells = { [6223] = 1, [709] = 1 } },
}
local grouped = { [41] = true, [46] = true, [101] = true, [106] = true }
local failures = {}
local function Check(condition, message)
    if not condition then failures[#failures + 1] = message end
end

for _, petFollowsTarget in ipairs({ false, true }) do
    for _, hasDescriptions in ipairs({ false, true }) do
        local variant = "petTarget=" .. tostring(petFollowsTarget)
            .. " descriptions=" .. tostring(hasDescriptions) .. ": "
        local results, displayed, amounts = Replay(
            petFollowsTarget, hasDescriptions)

        -- Then every confirmed player periodic report survives exactly once.
        for _, entry in ipairs(expectedEntries) do
            local spell = expected[entry]
            local observations = results[amounts[entry]] or {}
            local outputs = displayed[amounts[entry]] or {}
            Check(#observations == 1,
                variant .. "entry " .. entry .. " decision count "
                    .. #observations .. ", expected 1")
            Check(#outputs == 1,
                variant .. "entry " .. entry .. " display count "
                    .. #outputs .. ", expected 1")
            local result, output = observations[1], outputs[1]
            if result then
                Check(result.who == "you" and result.tick == true,
                    variant .. "entry " .. entry .. " lost player tick ownership")
                local actual = result.spell or result.procSpell
                if not grouped[entry] then
                    Check(actual == nil or actual == spell,
                        variant .. "entry " .. entry .. " named "
                            .. tostring(actual) .. ", expected " .. spell
                            .. " or unnamed")
                end
                if output then
                    Check(output.spell == actual,
                        variant .. "entry " .. entry
                            .. " changed identity before display")
                    if actual == nil then
                        Check(output.icon == nil,
                            variant .. "entry " .. entry
                                .. " unnamed damage acquired an icon")
                    else
                        Check(output.icon == "icon-" .. actual,
                            variant .. "entry " .. entry
                                .. " named damage acquired the wrong icon")
                    end
                end
            end
        end

        -- Then an ambiguous frame may abstain, but never repeats one identity
        -- when its offline truth contains that spell only once.
        for _, group in ipairs(sameFrame) do
            local remaining = {}
            for spell, count in pairs(group.spells) do
                remaining[spell] = count
            end
            for _, entry in ipairs(group.entries) do
                local observation = (results[amounts[entry]] or {})[1]
                local spell = observation
                    and (observation.spell or observation.procSpell)
                if spell then
                    Check((remaining[spell] or 0) > 0,
                        variant .. "same-frame entry " .. entry
                            .. " named unsupported/repeated spell " .. spell)
                    remaining[spell] = (remaining[spell] or 0) - 1
                end
            end
        end

        -- Then known, isolated periodic identities remain usable; accepting
        -- unknown for every report would not satisfy these assertions.
        for _, entry in ipairs({ 13, 25, 29 }) do
            local observation = (results[amounts[entry]] or {})[1]
            Check(observation and observation.spell == expected[entry],
                variant .. "isolated entry " .. entry .. " lost its known spell")
        end
    end
end

assert(#failures == 0, table.concat(failures, "\n"))
print("Recorded spell identity tests passed")
