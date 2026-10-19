MikSBT = { Components = {}, Services = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local displayed, restricted = {}, {}
local profile = { events = {
	OUTGOING_SPELL_DOT = { message = "Tick %a", scrollArea = "My outgoing" },
	INCOMING_HEAL_CRIT = { message = "+%a", isCrit = true, scrollArea = "My heals" },
	PET_INCOMING_DAMAGE = { message = "Pet %a", scrollArea = "My pet" },
	OUTGOING_HEAL = { message = "Heal %a", scrollArea = "My outgoing" },
	NOTIFICATION_BUFF = { message = "[%sl]", scrollArea = "My notices" },
	NOTIFICATION_COMBAT_ENTER = { message = "+Combat", scrollArea = "My notices" },
	SELF_HEAL = { message = "Self %a", scrollArea = "My self heals" },
	NOTIFICATION_REACTIVE = { message = "<%sl>", scrollArea = "My notices" },
} }
local queued
local presentation = Presentation:New({
	getProfile = function() return profile end,
	batcher = { Queue = function(_, ...) queued = { ... } end },
	getSpellTexture = function(id) return "icon-" .. id end,
	getSpellName = function(id) return "Spell " .. id end,
	formatMessage = function(settings, record)
		return (settings.message:gsub("%%a", tostring(record.amount or "")))
	end,
	display = function(...) displayed[#displayed + 1] = { ... } end,
	displayRestricted = function(...) restricted[#restricted + 1] = { ... } end,
})

-- Given a confirmed DoT result from the new engine.
-- When it reaches the MSBT presentation adapter.
presentation:Out({ event = "damage", amount = 42, crit = true,
	result = { who = "you", spell = 101, tick = true } })
-- Then existing outgoing batching receives the spell, crit and DoT flags.
assert(queued[1] == 101 and queued[2] == 42 and queued[3])
assert(queued[4] == "icon-101" and queued[7])

-- Given existing customized incoming healing and pet damage settings.
-- When incoming records arrive.
presentation:In({ event = "heal", amount = 90, crit = true })
presentation:In({ event = "damage", amount = 20, pet = true, school = 1 })
-- Then the same setting objects reach the unchanged display service.
assert(displayed[1][1] == profile.events.INCOMING_HEAL_CRIT)
assert(displayed[1][2] == "+90" and displayed[1][1].scrollArea == "My heals")
assert(displayed[2][1] == profile.events.PET_INCOMING_DAMAGE)

-- Given an outgoing heal identified by the engine.
-- When it is presented.
presentation:Out({ event = "heal", amount = 30,
	result = { who = "you", spell = 102 } })
-- Then it uses outgoing heal settings rather than a damage batch.
assert(displayed[3][1] == profile.events.OUTGOING_HEAL)

-- Given a restricted amount and a restricted aura name.
local secret = {}
issecretvalue = function(value) return value == secret end
-- When those records are drawn.
presentation:In({ event = "heal", amount = secret, crit = true })
presentation:Aura(true, false, secret, "aura-icon")
-- Then the exact opaque values survive as separate rendering arguments.
assert(restricted[1][2] == secret)
assert(restricted[2][2] == secret and restricted[2][3] == "aura-icon")
presentation:Alert({ kind = "reactive", args = { secret } })
assert(restricted[3][2] == secret)

-- Given hidden and unrelated outgoing damage.
local before = #displayed
presentation:Out({ event = "damage", amount = 999, result = { who = "other" } })
profile.events.INCOMING_HEAL_CRIT.disabled = true
presentation:In({ event = "heal", amount = 50, crit = true })
-- Then no extra text is emitted and profile settings stay intact.
assert(#displayed == before)
assert(profile.events.INCOMING_HEAL_CRIT.scrollArea == "My heals")

-- Given combat entry from the new reader.
presentation:Alert({ kind = "combat", entering = true })
-- Then the existing configured combat notice is used.
assert(displayed[#displayed][1] == profile.events.NOTIFICATION_COMBAT_ENTER)

-- Given a self heal identified by the shared reader.
presentation:In({ event = "heal", amount = 15, selfHeal = true, spell = 103 })
-- Then it retains the dedicated self-heal event and spell icon.
assert(displayed[#displayed][1] == profile.events.SELF_HEAL)
assert(displayed[#displayed][3] == "icon-103")
print("Combat presentation tests passed")
