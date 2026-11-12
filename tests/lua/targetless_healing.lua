-- Describe: targetless Mend Pet uses its spell identity and fixed recipient.
MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
local ns = MikSBT.CombatEngine
local selectedUnit = "enemy"
local mendPetName = "Mend Pet"
C_Spell = {
	IsSpellHelpful = function() return true end,
	GetSpellName = function(spell)
		if spell == 136 or spell == 3661 then return mendPetName end
		return "Helpful Buff"
	end,
	GetSpellDescription = function()
		return "Heals your pet 68 health every second."
	end,
}
UnitName = function(unit)
	return unit == "player" and "Healer" or "Wolf"
end
UnitIsUnit = function(_, unit) return unit == selectedUnit end
dofile("Combat/Healing.lua")

-- Given Mend Pet was sent without a target while an enemy is selected.
ns.NoteHealTarget("player", "", "mend-pet", 3661, 10)
ns.NoteHealCast("player", 3661, "enemy", 10, "mend-pet")

-- When an unrelated incoming self-heal arrives before its first pet tick.
local incoming = ns.MatchHealing("player", 10.1, false, nil)
local outgoing = ns.MatchHealing("pet", 11, true, true)

-- Then the self-heal stays unclaimed and Mend Pet retains its own cast.
assert(incoming == nil, "an unrelated self-heal claimed the Mend Pet cast")
assert(outgoing and outgoing.spell == 3661 and outgoing.who == "you",
	"the first pet tick lost its targetless Mend Pet cast")

-- Given a ranked Mend Pet with a localized name and no readable description.
for _, name in ipairs({ "Mend Pet", "Guérison du familier", "Tier heilen" }) do
	ns.ResetHealing()
	mendPetName = name
	C_Spell.GetSpellDescription = function()
		error("targetless heal detection read a localized description")
	end
	ns.NoteHealTarget("player", "", "localized-mend", 3661, 20)

	-- When its successful cast is followed by a confirmed pet tick.
	ns.NoteHealCast("player", 3661, "enemy", 20, "localized-mend")
	local result = ns.MatchHealing("pet", 21, true, true)

	-- Then the spell identity works regardless of the client's language.
	assert(result and result.spell == 3661,
		"localized Mend Pet was not matched by its spell identity")
end

-- Given the player is selected when targetless Mend Pet is cast.
ns.ResetHealing()
selectedUnit = "player"
ns.NoteHealTarget("player", nil, "self-selected", 136, 30)

-- When the cast succeeds and the pet receives its first tick.
ns.NoteHealCast("player", 136, "player", 30, "self-selected")
local pet = ns.MatchHealing("pet", 31, true, true)

-- Then the spell's fixed recipient takes precedence over the selected unit.
assert(pet and pet.spell == 136,
	"selected player replaced Mend Pet's actual recipient")

-- Given a helpful buff whose description mentions healing.
ns.ResetHealing()
selectedUnit = "enemy"
C_Spell.GetSpellDescription = function()
	return "Increases healing received by 20%."
end
ns.NoteHealTarget("player", "", "healing-buff", 999, 40)

-- When that buff succeeds before another heal on the pet.
ns.NoteHealCast("player", 999, "enemy", 40, "healing-buff")
local buff = ns.MatchHealing("pet", 41, true, true)

-- Then mentioning healing cannot turn a buff into a healing cast.
assert(buff == nil, "a healing buff was mistaken for targetless Mend Pet")

-- Given Mend Pet's sent recipient is hidden, rather than absent.
ns.ResetHealing()
local hidden = {}
issecretvalue = function(value) return rawequal(value, hidden) end
ns.NoteHealTarget("player", hidden, "hidden-mend", 3661, 50)

-- When its success has no readable recipient evidence.
ns.NoteHealCast("player", 3661, "enemy", 50, "hidden-mend")

-- Then hidden recipients still cannot be inferred from a nearby pet heal.
assert(ns.MatchHealing("pet", 51, true, true) == nil,
	"a hidden recipient was treated as an empty recipient")
print("Targetless healing attribution tests passed")
