-- Describe: a pet's swing shows the pet's icon, not the player's weapon.
MikSBT = { Components = {}, Services = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local queued, displayed = nil, {}
local profile = { events = {
	PET_OUTGOING_MISS = { message = "Pet Miss", scrollArea = "My pet" },
} }
local presentation = Presentation:New({
	getProfile = function() return profile end,
	batcher = { Queue = function(_, ...) queued = { ... } end },
	getSpellTexture = function(id) return "icon-" .. id end,
	formatMessage = function(settings) return settings.message end,
	display = function(...) displayed[#displayed + 1] = { ... } end,
	displayRestricted = function() end,
})

-- Given a client that names the pet's icon.
GetPetIcon = function() return "pet-family-icon" end

-- When the pet's swing lands.
presentation:Out({ event = "damage", amount = 32,
	result = { who = "pet", melee = true } })

-- Then it carries the pet's icon and is still batched as a pet's melee hit.
assert(queued[4] == "pet-family-icon", tostring(queued[4]))
assert(queued[1] == 6603 and queued[2] == 32 and queued[6] == true)

-- Given the player's own swing, a pet's ability and a record with its own icon.
-- When each is presented, then none of them takes the pet's icon.
presentation:Out({ event = "damage", amount = 47,
	result = { who = "you", melee = true, hand = "main" } })
assert(queued[4] == "icon-6603")
presentation:Out({ event = "damage", amount = 10,
	result = { who = "pet", spell = 16828 } })
assert(queued[4] == "icon-16828")
presentation:Out({ event = "damage", amount = 12, icon = "kept",
	result = { who = "pet", melee = true } })
assert(queued[4] == "kept")

-- Given a pet's swing that missed.
-- When it is presented.
presentation:Out({ event = "miss", missWord = "Miss",
	result = { who = "pet", melee = true, missed = true } })

-- Then the miss carries the pet's icon too.
assert(displayed[1][1] == profile.events.PET_OUTGOING_MISS)
assert(displayed[1][3] == "pet-family-icon", tostring(displayed[1][3]))

-- Given a client without GetPetIcon, or one whose icon is protected.
GetPetIcon = nil

-- When the pet's swing lands, then it shows no icon rather than the weapon.
presentation:Out({ event = "damage", amount = 32,
	result = { who = "pet", melee = true } })
assert(queued[4] == nil)
local hidden = {}
issecretvalue = function(value) return value == hidden end
GetPetIcon = function() return hidden end
presentation:Out({ event = "damage", amount = 32,
	result = { who = "pet", melee = true } })
assert(queued[4] == nil)
