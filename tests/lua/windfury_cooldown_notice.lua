MikSBT = {
    Components = {},
    Compatibility = { Client = { isForever = true } },
}
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Classes/Shaman.lua")
dofile("Combat/Helpers.lua")
dofile("Combat/SpellCatalog.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Spells.lua")
dofile("Combat/Healing.lua")
dofile("Combat/Reader.lua")
local Engine = dofile("Components/CombatEngine.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local CombatLog = dofile("Components/CombatLogFilter.lua")

local now, timers, displayed, frames = 47275.996, {}, {}, {}
GetTime = function() return now end
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    NewTicker = function() return { Cancel = function() end } end,
}
C_EventUtils = { IsEventValid = function() return true end }
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event) self:RegisterEvent(event) end
    function frame:SetScript() end
    function frame:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = frame
    return frame
end
UnitExists = function(unit) return unit == "target" end
UnitIsUnit = function(a, b) return a == b end
UnitGUID = function(unit) return unit == "target" and "Creature-test" end
UnitName = function() return "Training target" end
local playerClass = "SHAMAN"
UnitClass = function(unit)
    assert(unit == "player", "class filtering checked a unit other than player")
    return "Localized class", playerClass
end
GetLocale = function() return "enUS" end
C_Spell = {
    GetSpellName = function(spell) return "Spell " .. spell end,
    GetSpellTexture = function(spell) return "icon-" .. spell end,
    GetSpellDescription = function(spell)
        if spell == 21949 then
            return "Wounds the target causing them to bleed for 210 damage over 7 sec."
        end
        if spell == 17364 or spell == 2643 or spell == 999999 then
            return "Deals 100 Physical damage."
        end
        return "Grants extra attacks."
    end,
    SpellHasRange = function(spell) return spell == 17364 or spell == 2643 end,
    GetSpellInfo = function(spell)
        return { maxRange = spell == 2643 and 35 or 5 }
    end,
    IsSpellHelpful = function() return false end,
}
Enum = {
    PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
    CombatLogMessageOrder = { Oldest = 0, Newest = 1 },
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
Blizzard_CombatLog_Filters = { filters = {} }
local log = CombatLog:New({
    getSaved = function() return Blizzard_CombatLog_Filters end,
    mineFlag = 1, petFlag = 2,
})
assert(log:WriteSettings())
local settings = { message = "%sl", scrollArea = "Notification" }
local presentation = Presentation:New({
    getProfile = function() return { events = { NOTIFICATION_PROC = settings } } end,
    formatMessage = function(_, record) return record.name end,
    display = function(_, message, icon)
        displayed[#displayed + 1] = { message = message, icon = icon }
    end,
})
local engine = Engine:New({
    presentation = presentation, log = log,
    getSaved = function() end, setSaved = function() end,
    notify = function() end,
})
local ns = MikSBT.CombatEngine
engine:Start()
assert(ns.reader.frame.events.SPELL_UPDATE_COOLDOWN,
    "supported Forever client did not register cooldown updates")

local function Event(event, ...)
    engine:HandleEvent(event, ...)
end
local function Line(event)
    local color = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring[event]
    Event("COMBAT_LOG_MESSAGE", "opaque line", color.r, color.g, color.b, 1)
end
local function Cooldown(spell, base)
    Event("SPELL_UPDATE_COOLDOWN", spell, base, 0, 0, nil)
end
local function EndFrame()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= now then timer.callback()
        else timers[#timers + 1] = timer end
    end
end

-- Describe: the recorded client exposes Windfury through cooldown updates.
-- Given swing #106, with simultaneous axe-bleed and Windfury updates.
-- When the cooldown arrives before the swing and its direct spell lines.
Cooldown(21949)
Cooldown(439440)
Event("PLAYER_SWING", 2.5, 0)
Line("SWING_DAMAGE")
Line("SPELL_DAMAGE")
Line("SPELL_DAMAGE")
EndFrame()

-- Then one separate Windfury notice appears without any damage report.
assert(#displayed == 1, "cooldown-only Windfury frame did not display a notice")
assert(displayed[1].message == "Spell 439440")
assert(displayed[1].icon == "icon-439440")
for _, line in ipairs(ns.reader.logLines) do
    assert(not line.claimed and not line.hit, "notice consumed a damage confirmation")
end

-- Given swing #126 with the opposite event order, then #132 with a totem cast.
-- When those recorded frames arrive without a Windfury succeeded event.
now = 47313.089
Event("PLAYER_SWING", 2.5, 0)
Line("SWING_DAMAGE")
Line("SPELL_DAMAGE")
Line("SPELL_DAMAGE")
Cooldown(439440)
Cooldown(439440)
EndFrame()
assert(#displayed == 2, "repeated updates duplicated or hid Windfury")
now = 47316.301
Cooldown(439440)
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-totem", 10614)
Event("PLAYER_SWING", 2.5, 0)
Line("SWING_DAMAGE")
Line("SPELL_DAMAGE")
Line("SPELL_DAMAGE")
EndFrame()

-- Then each corroborated frame gets one notice; unrelated casts do not steal it.
assert(#displayed == 3, "simultaneous totem cast suppressed Windfury activity")

-- Describe: a cooldown update cannot identify a proc by itself.
-- Given isolated, stale, periodic, ranged, pet, and wrong-ID evidence.
local before = #displayed
now = 47320
Cooldown(439440)
EndFrame()
now = 47320.05
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
EndFrame()
now = 47321
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_PERIODIC_DAMAGE")
Cooldown(439440)
EndFrame()
now = 47322
Event("PLAYER_SWING", 2.5, 2)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()
now = 47323
Event("UNIT_SPELLCAST_SUCCEEDED", "pet", "Cast-pet", 17364)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()
now = 47324
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
Cooldown(21949)
Cooldown(nil)
Cooldown(8232)
Cooldown(1234, 439440)
EndFrame()

-- Then none of these frames can assert Windfury activity.
assert(#displayed == before, "uncorroborated cooldown displayed Windfury")

-- Given a bleed application without an independent player melee trigger.
now = 47324.5

-- When the bleed, a direct line, and Windfury update share a frame.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-bleed", 21949)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()

-- Then the periodic-only bleed cannot stand in for a weapon ability.
assert(#displayed == before, "bleed application became a melee trigger")

-- Given a physical ranged ability, without a player melee swing.
now = 47324.7

-- When that ranged cast shares a direct line and Windfury cooldown update.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-multishot", 2643)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()

-- Then physical school alone cannot establish a melee trigger.
assert(#displayed == before, "physical ranged ability became a melee trigger")

-- Given a hidden spell ID, alongside an otherwise compatible melee frame.
local opaque = {}
issecretvalue = function(value) return rawequal(value, opaque) end
now = 47325
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")

-- When the cooldown's identity is unreadable.
Cooldown(opaque)
EndFrame()

-- Then its hidden identity cannot produce a Windfury notice.
assert(#displayed == before, "secret cooldown identity displayed Windfury")
issecretvalue = nil

-- Given a player physical weapon ability between normal swings.
now = 47326

-- When its cast, direct line, and Windfury update share a frame.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-stormstrike", 17364)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()

-- Then the ability supplies the player trigger without inventing an auto swing.
assert(#displayed == before + 1, "weapon ability could not corroborate Windfury")

-- Given an explicit Windfury cast and its cooldown in the same attack frame.
before = #displayed
now = 47326.2
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
Cooldown(439440)

-- When the succeeded event arrives before the deferred cooldown check.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-windfury", 439440)
EndFrame()

-- Then both signal paths share one notice.
assert(#displayed == before + 1, "cast and cooldown duplicated the notice")

-- Given a valid cached line followed by a foreign-source filter change.
before = #displayed
now = 47326.4
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
local sources = Blizzard_CombatLog_Filters.filters[1].filters[1].sourceFlags
sources[4] = true

-- When the Windfury update is evaluated under the untrusted filter.
Cooldown(439440)
EndFrame()

-- Then old line colors cannot bypass the current source restriction.
assert(#displayed == before, "unready source filter corroborated Windfury")
sources[4] = nil

-- Given the player is a Shaman and the range API is unavailable.
local hasRange = C_Spell.SpellHasRange
C_Spell.SpellHasRange = nil
now = 47326.6

-- When its physical cast, direct line, and cooldown update coincide.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-catalogued-melee", 17364)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()

-- Then the Shaman rule supplies the melee reach needed to corroborate Windfury.
assert(#displayed == before + 1, "Shaman's Stormstrike did not corroborate Windfury")

-- Given the same spell signal while the current player is another class.
playerClass = "MAGE"
before = #displayed
now = 47326.65

-- When the cast and Windfury update coincide with a direct line.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-other-class", 17364)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()

-- Then the Shaman rule cannot supply missing melee reach to another class.
assert(#displayed == before, "another class inherited Shaman's Windfury rule")
playerClass = "SHAMAN"

-- Given a physical cast whose reach is absent from the catalog and API.
before = #displayed
now = 47326.7
local unknown = ns.SpellFacts(999999)
assert(unknown.direct and unknown.school == 1)

-- When that cast, a direct line, and the Windfury update coincide.
Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-unknown-reach", 999999)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()

-- Then physical damage alone does not establish melee reach.
assert(#displayed == before, "unknown ability reach corroborated Windfury")
C_Spell.SpellHasRange = hasRange

-- Given a melee frame whose extra attack is avoided.
now = 47326.8

-- When a direct miss line corroborates its Windfury update.
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_MISSED")
Cooldown(439440)
EndFrame()

-- Then activity remains visible without inventing a successful hit.
assert(#displayed == before + 1, "direct miss could not corroborate activity")

-- Given disabled notifications, then a stopped engine with pending work.
settings.disabled = true
before = #displayed
now = 47327
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
Cooldown(439440)
EndFrame()
settings.disabled = false
now = 47328
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
Cooldown(439440)

-- When the engine stops and restarts before queued callbacks run.
engine:Stop()
engine:Start()
EndFrame()

-- Then neither disabled output nor callbacks from the old session display.
assert(#displayed == before, "old or disabled session displayed Windfury")

-- Given another corroborated frame with its evaluation still pending.
now = 47329
Event("PLAYER_SWING", 2.5, 0)
Line("SPELL_DAMAGE")
Cooldown(439440)

-- When the player enters a new world before the callback runs.
Event("PLAYER_ENTERING_WORLD")
EndFrame()

-- Then old world evidence cannot create a notification in the new world.
assert(#displayed == before, "world entry retained old Windfury frame evidence")

-- Given an unsupported client or no positive event-capability check.
-- When the reader starts under each environment.
engine:Stop()
MikSBT.Compatibility.Client.isForever = false
engine:Start()
assert(not ns.reader.frame.events.SPELL_UPDATE_COOLDOWN,
    "Retail registered the Forever-only cooldown observer")
engine:Stop()
MikSBT.Compatibility.Client.isForever = true
C_EventUtils = { IsEventValid = function(event)
    return event ~= "SPELL_UPDATE_COOLDOWN"
end }
engine:Start()
assert(not ns.reader.frame.events.SPELL_UPDATE_COOLDOWN,
    "cooldown observer ignored a negative capability check")
engine:Stop()
C_EventUtils = nil
engine:Start()

-- Then modern cooldown payloads are not registered speculatively.
assert(not ns.reader.frame.events.SPELL_UPDATE_COOLDOWN,
    "cooldown observer registered without a capability check")
print("Corroborated Windfury cooldown notice tests passed")
