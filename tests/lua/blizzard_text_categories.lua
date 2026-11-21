-- Describe: Blizzard categories hide output without stopping MSBT's feed.
local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match(
    "(local BLIZZARD_SWITCH_SETTINGS.-)local function SetAddonEnabled"))
local build = assert(loadstring(body ..
    "\nreturn SetBlizzardCombatTextV2Enabled"))
local writes, hooks = {}, {}
local shown = true
local types = {
    DAMAGE = { show = 1 }, SPELL_DAMAGE = { show = 1 },
    HEAL = { show = 1 }, PERIODIC_HEAL = { show = 1 },
    SPELL_AURA_START = { show = 1 }, SPELL_ACTIVE = { show = nil },
    ENTERING_COMBAT = { show = 1 },
}
local frame = {
    Hide = function() shown = false end,
    Show = function() shown = true end,
    UpdateDisplayedMessages = function() end,
}
local env = {
    Client = { hasModernAPI = true }, IsClassic = false,
    CombatText = frame, CombatTextTypeInfo = types,
    SetCVar = function(name, value) writes[name] = value end,
    hooksecurefunc = function(_, _, callback) hooks[#hooks + 1] = callback end,
    pairs = pairs, ipairs = ipairs, type = type,
}
setfenv(build, env)
local apply = build()
local profile = {}

-- Given MSBT resource gains enabled while Blizzard output is hidden.
profile.events = { NOTIFICATION_RESOURCE_GAIN = { message = "+%a %p" } }
profile.blizzardIncomingDisabled = true
profile.blizzardNotificationsDisabled = true
-- When the runtime applies its settings outside combat.
apply(false, true, profile)
-- Then direct and periodic resource feeds are enabled despite hidden output.
assert(writes.floatingCombatTextEnergyGains_v2 == 1,
    "resource-gain feed was not enabled")
assert(writes.floatingCombatTextPeriodicEnergyGains_v2 == 1,
    "periodic resource-gain feed was not enabled")
assert(not shown, "resource feed enabled Blizzard's hidden text")

-- Given resource notifications are disabled in the profile.
profile.events.NOTIFICATION_RESOURCE_GAIN.disabled = true
writes = {}
-- When preferences are reapplied, then resource CVars are left alone.
apply(false, true, profile)
assert(writes.floatingCombatTextEnergyGains_v2 == nil)
assert(writes.floatingCombatTextPeriodicEnergyGains_v2 == nil)

-- Given MSBT is disabled, then enabling its saved event cannot change CVars.
profile.events.NOTIFICATION_RESOURCE_GAIN.disabled = nil
writes = {}
apply(false, false, profile)
assert(writes.floatingCombatTextEnergyGains_v2 == nil)

-- Given combat lockdown, then feed setup waits until combat ends.
env.InCombatLockdown = function() return true end
writes = {}
apply(false, true, profile)
assert(next(writes) == nil)
env.InCombatLockdown = function() return false end
apply(false, true, profile)
assert(writes.floatingCombatTextEnergyGains_v2 == 1)

-- Reset the output preferences for the category-isolation checks below.
profile.blizzardIncomingDisabled = false
profile.blizzardNotificationsDisabled = false

-- Given both systems enabled with only Blizzard incoming text disabled.
profile.blizzardIncomingDisabled = true
-- When the category settings apply.
apply(true, false, profile)
-- Then damage and healing disappear, and notifications and the feed survive.
assert(writes.enableFloatingCombatText == 1 and shown)
assert(types.DAMAGE.show == nil and types.HEAL.show == nil)
assert(types.SPELL_AURA_START.show == 1)
assert(writes.floatingCombatTextCombatDamage_v2 == 1)

-- Given a Blizzard refresh while incoming message types are hidden.
-- When visibility is refreshed and incoming text is re-enabled.
hooks[1]()
profile.blizzardIncomingDisabled = false
apply(true, false, profile)
-- Then fixed-visibility damage and healing types regain their original state.
assert(types.DAMAGE.show == 1 and types.HEAL.show == 1,
    "refresh permanently hid incoming messages")

-- Given only Blizzard notifications and outgoing text disabled.
profile.blizzardIncomingDisabled = false
profile.blizzardNotificationsDisabled = true
profile.blizzardOutgoingDisabled = true
-- When the settings apply.
apply(true, false, profile)
-- Then incoming text returns while notifications and outgoing damage stop.
assert(types.DAMAGE.show == 1 and types.HEAL.show == 1)
assert(types.SPELL_AURA_START.show == nil and types.ENTERING_COMBAT.show == nil)
assert(writes.floatingCombatTextCombatDamage_v2 == 0)
assert(writes.enableFloatingCombatText == 1)

-- Given Blizzard refreshes its per-message visibility from game settings.
types.SPELL_AURA_START.show = 1
types.SPELL_ACTIVE.show = nil
-- When its secure refresh hook runs.
assert(#hooks == 1, "category refresh hook was not installed once")
hooks[1]()
-- Then muted notifications stay hidden without enabling an unwanted reactive.
assert(types.SPELL_AURA_START.show == nil)
profile.blizzardNotificationsDisabled = false
apply(true, false, profile)
assert(types.SPELL_AURA_START.show == 1 and types.SPELL_ACTIVE.show == nil)

-- Given Blizzard's master is off while MSBT still needs aura notices.
-- When the master state applies.
apply(false, true, profile)
-- Then the frame is hidden and MSBT's event source remains enabled.
assert(not shown and writes.enableFloatingCombatText == 1)
assert(writes.floatingCombatTextCombatDamage_v2 == 0)

-- Given combat lockdown.
env.InCombatLockdown = function() return true end
writes = {}
-- When a different category selection is requested.
apply(true, false, profile)
-- Then protected CVar changes wait until combat ends.
assert(next(writes) == nil and not shown)

-- Given Forever with both MSBT resource gains and Blizzard text enabled.
env.Client.isForever = true
env.InCombatLockdown = function() return false end
profile.blizzardIncomingDisabled = false
profile.blizzardNotificationsDisabled = false
types.ENERGIZE = { show = 1, cvar = "floatingCombatTextEnergyGains_v2" }
types.PERIODIC_ENERGIZE = {
    show = 1, cvar = "floatingCombatTextPeriodicEnergyGains_v2",
}
types.RUNE = { show = 1, cvar = "floatingCombatTextEnergyGains_v2" }
writes = {}

-- When the runtime enables the resource feed.
apply(true, true, profile)

-- Then Blizzard skips both resource renderers and MSBT keeps the feed.
assert(shown and types.ENERGIZE.show == nil and types.PERIODIC_ENERGIZE.show == nil,
    "Forever still sent an MSBT resource gain to Blizzard's renderer")
assert(writes.floatingCombatTextEnergyGains_v2 == 1)
assert(writes.floatingCombatTextPeriodicEnergyGains_v2 == 1)
assert(types.RUNE.show == 1 and types.DAMAGE.show == 1
    and types.SPELL_AURA_START.show == 1)

-- Given a Blizzard settings refresh makes the feed-backed rows visible again.
types.ENERGIZE.show, types.PERIODIC_ENERGIZE.show = 1, 1
-- When the registered refresh callback runs, then both remain suppressed.
hooks[1]()
assert(types.ENERGIZE.show == nil and types.PERIODIC_ENERGIZE.show == nil)

-- Given MSBT resource gains are turned off.
profile.events.NOTIFICATION_RESOURCE_GAIN.disabled = true
writes = {}
-- When the settings are applied, then Blizzard's own visibility is restored.
apply(true, true, profile)
assert(types.ENERGIZE.show == 1 and types.PERIODIC_ENERGIZE.show == 1)
assert(writes.floatingCombatTextEnergyGains_v2 == nil)
assert(writes.floatingCombatTextPeriodicEnergyGains_v2 == nil)

-- Given the same settings on Retail, both systems can display resource gains.
env.Client.isForever = false
profile.events.NOTIFICATION_RESOURCE_GAIN.disabled = nil
-- When the runtime applies the profile, then the Forever guard stays off.
apply(true, true, profile)
assert(types.ENERGIZE.show == 1 and types.PERIODIC_ENERGIZE.show == 1)
print("Blizzard text category tests passed")
