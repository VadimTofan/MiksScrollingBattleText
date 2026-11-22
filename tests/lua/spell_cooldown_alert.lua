-- Describe: Ability Ready plays the bundled click once for each confirmed cooldown.
local now, cooldowns, displayed = 10, {}, {}
local frame = { scripts = {}, events = {}, visible = false }
function frame:SetScript(event, handler) self.scripts[event] = handler end
function frame:RegisterEvent(event) self.events[event] = true end
function frame:RegisterUnitEvent(event, unit)
	assert(unit == "player")
	self:RegisterEvent(event)
end
function frame:Show() self.visible = true end
function frame:Hide() self.visible = false end
CreateFrame = function() return frame end
hooksecurefunc = function() end
GetTime = function() return now end
C_Item = { GetItemInfo = function() end }
C_Container = { GetItemCooldown = function() end }
C_SpellBook = { IsSpellKnownOrInSpellBook = function(id) return id ~= 104 end }
C_Spell = {
	GetSpellCooldown = function(id)
		return cooldowns[id] or { startTime = 0, duration = 0, isEnabled = true }
	end,
	GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = id } end,
}

local profile = {
	cooldownThreshold = 5, cooldownExclusions = {}, ignoreCooldownThreshold = {},
	events = { NOTIFICATION_ABILITY_READY = {
		disabled = true, message = "%s ready!", soundFile = "MSBT Cooldown",
	} },
}
MikSBT = {
	API = {}, Components = {}, Profiles = { currentProfile = profile },
	Animations = { DisplayEvent = function(settings, message, icon)
		displayed[#displayed + 1] = { settings.soundFile, message, icon }
	end },
}
dofile("API/RestrictedValue.lua")
dofile("API/Cooldowns.lua")
dofile("API/Spells.lua")
dofile("Components/ItemCooldownTracker.lua")
dofile("MSBTCooldowns.lua")
MikSBT.Cooldowns.Enable()

local function Cast(id, unit)
	if frame.events.UNIT_SPELLCAST_SUCCEEDED then
		frame.scripts.OnEvent(frame, "UNIT_SPELLCAST_SUCCEEDED", unit or "player", nil, id)
	end
end

local function Advance(seconds)
	now = now + seconds
	if frame.visible then frame.scripts.OnUpdate(frame, seconds) end
end

-- Given the event is off, then enabling it takes effect on the next cast.
Cast(101)
assert(not frame.visible)
profile.events.NOTIFICATION_ABILITY_READY.disabled = false
Cast(101)
assert(frame.visible, "an enabled Ability Ready event did not watch the player cast")

-- When the spell reports a real cooldown after the cast.
cooldowns[101] = { startTime = now, duration = 10, isEnabled = true }
Advance(0.2)
assert(#displayed == 0 and frame.visible)
Advance(9)
assert(#displayed == 0)

-- Then the ready state produces a single alert with the spell and original click.
cooldowns[101] = nil
Advance(1)
Advance(1)
assert(#displayed == 1 and not frame.visible)
assert(displayed[1][1] == "MSBT Cooldown")
assert(displayed[1][2] == "Spell 101 ready!" and displayed[1][3] == 101)

-- Given an ordinary global cooldown, a short spell, a pet, and an item spell.
local gcd = { startTime = now, duration = 1.5, isEnabled = true }
cooldowns[61304], cooldowns[102] = gcd, gcd
cooldowns[103] = { startTime = now, duration = 3, isEnabled = true }
cooldowns[104] = { startTime = now, duration = 15, isEnabled = true }
cooldowns[105] = { startTime = now, duration = 15, isEnabled = true }
profile.cooldownThreshold = 1
Cast(102)
Advance(0.2)
profile.cooldownThreshold = 5
Cast(103)
Cast(104)
Cast(105, "pet")

-- When all of those cooldowns are over, then no ability click was created.
Advance(1.1)
cooldowns = {}
Advance(16)
assert(#displayed == 1 and not frame.visible)

-- Given a valid cooldown becomes unreadable temporarily.
Cast(101)
cooldowns[101] = { startTime = now, duration = 10, isEnabled = true }
Advance(0.2)
local secret = {}
issecretvalue = function(value) return value == secret end
cooldowns[101] = { startTime = secret, duration = secret, isEnabled = true }

-- When the API hides the cooldown, then the addon waits for confirmation.
Advance(10)
assert(#displayed == 1)
cooldowns[101] = nil
Advance(0.2)
assert(#displayed == 2 and not frame.visible)

-- Given the timer is restricted but the cooldown update reports public state.
local function CooldownChanged()
	if frame.events.SPELL_UPDATE_COOLDOWN then
		frame.scripts.OnEvent(frame, "SPELL_UPDATE_COOLDOWN")
	end
end
Cast(101)
cooldowns[101] = {
	startTime = secret, duration = secret, isEnabled = true,
	isActive = true, isOnGCD = false,
}
CooldownChanged()
Advance(6)
assert(#displayed == 2)

-- When the game confirms the ability is ready, the click can play.
cooldowns[101].isActive = false
CooldownChanged()
assert(#displayed == 3 and not frame.visible, "public ready state was ignored")
cooldowns[101] = nil

-- Given a spell whose cooldown is held while its effect is active.
cooldowns[101] = { startTime = now, duration = 0, isEnabled = false }
Cast(101)
Advance(0.2)
Advance(5)
assert(#displayed == 3)

-- When the effect ends, the real cooldown starts and then completes.
cooldowns[101] = { startTime = now, duration = 10, isEnabled = true }
Advance(0.2)
cooldowns[101] = nil
Advance(10)

-- Then the click follows the cooldown and never plays while the effect is active.
assert(#displayed == 4 and not frame.visible, "a held cooldown was lost")

-- Given a tracked spell and the addon is disabled before it becomes ready.
Cast(101)
cooldowns[101] = { startTime = now, duration = 10, isEnabled = true }
Advance(0.2)
MikSBT.Cooldowns.Disable()

-- When it finishes after re-enabling, then the stale cooldown was cleared.
MikSBT.Cooldowns.Enable()
cooldowns[101] = nil
Advance(11)
assert(#displayed == 4 and not frame.visible)
