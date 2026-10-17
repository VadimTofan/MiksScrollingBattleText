MikSBT = {Components = {}}
dofile("API/RestrictedValue.lua")
local Incoming = dofile("Components/IncomingCombat.lua")

local now = 10
local health, maxHealth = 100, 100
local lastSpellID, lastSpellTime
local callbacks, displayed = {}, {}
local profile = {
	events = {
		SELF_HEAL = {message = "(%s) +%a"},
		SELF_HOT = {message = "(%s) +%a"},
	},
}
local incoming = Incoming:New({
	getProfile = function() return profile end,
	normalizeNumber = tonumber,
	buildActionMessage = function(_, amount, overheal, spellName)
		return string.format("(%s) +%d <%d>", spellName or "", amount - (overheal or 0), overheal or 0)
	end,
	shouldSplitCritBatch = function() return false end,
	resolveBatchDisplaySettings = function(settings) return settings end,
	display = function(_, message, texture)
		displayed[#displayed + 1] = {message = message, texture = texture}
	end,
	displayRestricted = function() end,
	after = function(_, callback) callbacks[#callbacks + 1] = callback end,
	getTime = function() return now end,
	unitName = function() return "Player" end,
	unitCastingInfo = function() return nil end,
	unitChannelInfo = function() return nil end,
	safeUnitBoolean = function() return false end,
	getSpellInfo = function(spellID) return "Spell" .. spellID, nil, "texture-" .. spellID end,
	isAutoAttackSpellID = function() return false end,
	isHelpfulSpell = function() return true end,
	playerHasAura = function() return false end,
	unitHealth = function() return health end,
	unitHealthMax = function() return maxHealth end,
	unknown = "Unknown",
	groupDelay = 0.12,
	selfHealIconWindow = 12,
	getLastPlayerSpell = function() return lastSpellID, lastSpellTime end,
})

local function runCallbacks()
	local pending = callbacks
	callbacks = {}
	for _, callback in ipairs(pending) do
		callback()
	end
end

-- Given a heal whose UNIT_COMBAT arrives before its cast succeeds in the same frame
lastSpellID, lastSpellTime = 1, 5
health = 50
incoming:HandleUnitCombat("player", "HEAL", nil, 30, nil)
lastSpellID, lastSpellTime = 2050, now

-- When the heal batch is displayed
runCallbacks()

-- Then it is attributed to the cast from its own frame
assert(#displayed == 1, "heal was not displayed")
assert(displayed[1].message == "(Spell2050) +30 <0>", "heal not attributed: " .. displayed[1].message)
assert(displayed[1].texture == "texture-2050", "heal texture not attributed")

-- Given a cast that happens after an unrelated heal
displayed = {}
now = 20
lastSpellID, lastSpellTime = 2050, 10
incoming:HandleUnitCombat("player", "HEAL", nil, 5, nil)
lastSpellID, lastSpellTime = 2050, 20.05
now = 20.1

-- When the heal batch is displayed
runCallbacks()

-- Then the later cast is not used
assert(displayed[1].texture == nil, "later cast was attributed to an earlier heal")

-- Given a fully overhealed tick that UNIT_COMBAT reports as zero
displayed = {}
now = 30
health = 100
lastSpellID = nil
incoming:HandleUnitCombat("player", "HEAL", nil, 0, nil)
incoming:HandleCombatText("PERIODIC_HEAL", 2)

-- When the frame ends
runCallbacks()

-- Then the combat text feed shows its raw amount as overheal
assert(#displayed == 1, "fully overhealed tick was not displayed")
assert(displayed[1].message == "() +0 <2>", "overheal not shown: " .. displayed[1].message)

-- Given a heal UNIT_COMBAT already reported in the same frame
displayed = {}
now = 40
health = 50
incoming:HandleUnitCombat("player", "HEAL", nil, 20, nil)
incoming:HandleCombatText("HEAL", 20)

-- When the frame ends and the heal batch is displayed
runCallbacks()

-- Then the combat text copy is skipped
assert(#displayed == 1, "heal was displayed twice")
