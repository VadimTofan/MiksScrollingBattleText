-- Describe: Blizzard categories hide output without stopping MSBT's feed.
local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match(
    "(local blizzardCategoryState.-)local function SetAddonEnabled"))
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
print("Blizzard text category tests passed")
