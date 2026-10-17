MikSBT = {Components = {}}
dofile("API/RestrictedValue.lua")
local OutgoingCombat = dofile("Components/OutgoingCombat.lua")

local now = 0
local isSolo = true
local petEngaged = false
local queued = {}
local component = OutgoingCombat:New({
	batcher = {
		Queue = function(_, spellID, amount, isCrit, texture, forceIsSpell, isPet, isDot)
			queued[#queued + 1] = {spellID = spellID, amount = amount, isPet = isPet, isDot = isDot}
		end,
		Reset = function() end,
	},
	getProfile = function() return {events = {}} end,
	normalizeNumber = tonumber,
	buildActionMessage = function(settings) return settings.message end,
	display = function() end,
	getTime = function() return now end,
	inCombat = function() return true end,
	isTargetValid = function() return true end,
	getSpellTexture = function(spellID) return "texture-" .. tostring(spellID) end,
	isAutoAttack = function(spellID) return spellID == 6603 end,
	isHelpfulSpell = function() return false end,
	canUseAutoAttackFallback = function() return false end,
	isPlayerAutoAttacking = function() return false end,
	isPetEngaged = function() return petEngaged end,
	getSwingSpeed = function() return 2 end,
	hasPlayerDebuff = function() return false end,
	isPlayerSolo = function() return isSolo end,
	isLikelySpellSchool = function(schoolMask) return schoolMask ~= 1 end,
	autoAttackSpellID = 6603,
	fallbackAttributionWindow = 0.9,
	delayedAttributionWindow = 3,
	signalWindow = 1.25,
	dotDuration = 18,
	dotSpells = {},
	timedDotSpells = {},
})

local function hit(time, amount, school)
	now = time
	component:HandleUnitCombat("target", "WOUND", nil, amount, school)
	return queued[#queued]
end

-- Given a solo player whose cast already landed
component:HandleSpellcastSucceeded("player", 348)
local castHit = hit(1.5, 60, 4)

-- When later fire hits arrive with no new cast
local tick = hit(4.5, 14, 4)

-- Then the cast keeps its spell and the tick is an unnamed DoT tick
assert(castHit.spellID == 348 and not castHit.isDot, "cast hit was not attributed")
assert(tick.isDot == true and tick.spellID == nil, "solo DoT tick was not shown")

-- Given the same tick while grouped
isSolo = false
local queuedBefore = #queued

-- When it arrives
hit(7.5, 14, 4)

-- Then it is dropped because it could be another player's
assert(#queued == queuedBefore, "grouped unexplained hit was shown")

-- Given an engaged pet that cast a spell
petEngaged = true
component:HandleSpellcastSucceeded("pet", 3110)

-- When its hit lands
local petHit = hit(8, 45, 4)

-- Then it is attributed to the pet
assert(petHit.isPet == true and petHit.spellID == 3110, "pet spell hit was not attributed")
