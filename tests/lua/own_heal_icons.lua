-- Describe: your own heals keep their spell by the client's heal facts, in every language.
MikSBT = { Components = {} }
local FOREVER, MAINLINE = { isForever = true }, { isMainline = true }
MikSBT.Compatibility = { Client = FOREVER }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
dofile("Combat/HealSpells.lua")
local ns = MikSBT.CombatEngine

-- The client's own descriptions (build 1.60.1.70888) with their tokens filled in.
local DESCRIPTIONS = {
	deDE = {
		[3627] = "Heilt beim Ziel 12 Sek. lang 756 Punkt(e) Schaden.",
		[8940] = "Heilt ein befreundetes Ziel um 290 und über 21 Sek. um weitere 287.",
		[8941] = "Heilt ein befreundetes Ziel um 350 und über 21 Sek. um weitere 343.",
		[5188] = "Heilt ein befreundetes Ziel um 572 Punkt(e).",
		[768] = "Verwandelt Euch in eine Katzengestalt. Erhöht Angriffskraft um 40 plus Beweglichkeit. Beschützt den Zaubernden auch vor Verwandlungseffekten und erlaubt den Einsatz verschiedener Katzenfähigkeiten.",
		[5215] = "Ermöglicht dem Druiden das Schleichen, verringert jedoch Euer Bewegungstempo um 40%. Hält an, bis die Aktion abgebrochen wird.",
		[8914] = "Aus dem verbündetem Ziel sprießen Dornen, die Angreifern bei einem Treffer 12 Naturschaden zufügen. Die Dauer beträgt 10 Min..",
		[633] = "Heilt ein verbündetes Ziel um einen Betrag, der der maximalen Gesundheit des Paladins entspricht. Verbraucht bei Einsatz das gesamte verbleibende Mana des Paladins, aber unterbricht Manaregeneration nicht.",
		[20473] = "Trifft das Ziel mit heiliger Energie. Verursacht 182 Heiligschaden bei Feinden oder heilt 156 bei Verbündeten.",
		[1244865] = "Stellt sofort 640 Gesundheit wieder her, allerdings erleidet Ihr im Laufe der Zeit Schaden in Höhe von 75% des Werts.\r\n\r\nDie Symptome dieses Effekts können sich als Gift für 6 Sek. oder als Krankheit für 12 Sek. zeigen.",
	},
	enUS = {
		[3627] = "Heals the target for 756 over 12 sec.",
		[8940] = "Heals a friendly target for 290 and another 287 over 21 sec.",
		[8941] = "Heals a friendly target for 350 and another 343 over 21 sec.",
		[5188] = "Heals a friendly target for 572.",
		[768] = "Shapeshift into Cat Form, increasing Attack Power by 40 plus Agility.  Also protects the caster from Polymorph effects and allows the use of various cat abilities.",
		[5215] = "Allows the Druid to prowl around, but reduces your movement speed by 40%.  Lasts until cancelled.",
		[8914] = "Thorns sprout from the friendly target causing 12 Nature damage to attackers when hit.  Lasts 10 min.",
		[633] = "Heals a friendly target for an amount equal to the Paladin's maximum health.  Drains all of the Paladin's remaining Mana when used, but does not interrupt Mana regeneration.",
		[20473] = "Blasts the target with Holy energy, causing 182 Holy damage to an enemy, or 156 healing to an ally.",
		[1244865] = "Restores 640 health instantly; however you also suffer 75% of that amount over time.\r\n\r\nThe symptoms of this effect can manifest as either a 6 sec poison or a 12 sec disease.",
	},
}
local REJUV, REGROWTH, REGROWTH_HIGH, HEALING_TOUCH = 3627, 8940, 8941, 5188
local CAT_FORM, PROWL, THORNS, MEND_PET = 768, 5215, 8914, 136
local LAY_ON_HANDS, HOLY_SHOCK, HEALTH_FUNNEL = 633, 20473, 755
local TRANQUILITY, HEAL_POTION = 740, 1244865
local NEWER_HEAL = ns.HEAL_SPELLS_LAST + 1
-- A heal of the mainline client that Forever's table does not know.
local WILD_GROWTH = 48438
local locale = "deDE"

C_Spell = {
	IsSpellHelpful = function() return true end,
	GetSpellName = function(spell) return spell == MEND_PET and "Mend Pet" or "Spell " .. spell end,
	GetSpellTexture = function(spell) return spell end,
	GetSpellDescription = function(spell)
		if spell == NEWER_HEAL then
			return locale == "deDE" and "Heilt beim Ziel 9 Sek. lang 90 Punkt(e) Schaden."
				or "Heals the target for 90 over 9 sec."
		end
		if spell == WILD_GROWTH then
			return locale == "deDE" and "Heilt bis zu 5 verletzte Verbündete im Verlauf von 7 Sek. um 2592 Punkt(e)."
				or "Heals up to 5 injured allies within 30 yds of the target for 2,592 over 7 sec."
		end
		return DESCRIPTIONS[locale][spell] or ""
	end,
}
-- The selected unit: nil, "player", your pet, an enemy, one from another realm or a friend.
local target
local TARGETS = {
	pet = { name = "Cat", assist = true },
	enemy = { name = "Wolf", assist = false },
	stranger = { name = "Wolf", realm = "Realm", assist = false },
	friend = { name = "Ally", assist = true },
}
UnitName = function(unit)
	if unit == "player" then return "Druid" end
	if unit == "target" and TARGETS[target] then return TARGETS[target].name, TARGETS[target].realm end
end
UnitExists = function(unit) return unit == "target" and target ~= nil end
-- Nothing for a unit that does not exist.
UnitCanAssist = function(_, unit)
	if unit ~= "target" or not target then return nil end
	return target == "player" or TARGETS[target].assist
end
UnitIsUnit = function(a, b) return a == "target" and target ~= nil and target == b end
C_Timer = { After = function(_, callback) callback() end }
-- A recipient the client hides.
local hidden = {}
issecretvalue = function(value) return rawequal(value, hidden) end

dofile("Combat/Healing.lua")

local function Name(result) return result and tostring(result.spell) or "nothing" end
local function Expect(result, spell, message)
	assert(Name(result) == (spell and tostring(spell) or "nothing"),
		locale .. ": " .. message .. ": expected " .. tostring(spell or "nothing") .. ", got " .. Name(result))
end
-- A heal on you as UNIT_COMBAT reports it; tick is what the beat rule says.
local function Incoming(at, tick)
	return ns.TagIncomingHeal({ tick = tick }, "player", at)
end
-- A heal confirmed by its combat log line, which says whether it ticked.
local function Line(key, at, tick)
	return ns.MatchHealing(key, at, tick, true)
end
local cast = 0
-- A cast as the reader passes it: SENT, then SUCCEEDED with the cast's key.
local function Cast(spell, key, at, sent, unit)
	cast = cast + 1
	ns.NoteHealTarget(unit or "player", sent, "Cast-" .. cast, spell, at)
	ns.NoteHealCast(unit or "player", spell, key, at, "Cast-" .. cast)
end

-- Given the table generated from the client's spell tables.
local facts = ns.HEAL_SPELLS
-- Then it knows how the heals heal, and the buffs and forms not as heals.
for spell, expected in pairs({
	[774] = "0 3 12 0", [REJUV] = "0 3 12 0", [8936] = "1 3 21 0", [REGROWTH] = "1 3 21 0",
	[REGROWTH_HIGH] = "1 3 21 0", [5185] = "1 0 0 0", [HEALING_TOUCH] = "1 0 0 0",
	[740] = "0 2 10 0", [MEND_PET] = "0 1 5 1", [139] = "0 3 15 0", [2061] = "1 0 0 0",
	[LAY_ON_HANDS] = "1 0 0 0", [HEALTH_FUNNEL] = "0 1 10 1",
}) do
	local found = facts[spell] and table.concat(facts[spell], " ")
	assert(found == expected, "heal facts of " .. spell .. ": expected " .. expected .. ", got " .. tostring(found))
end
for _, spell in ipairs({ CAT_FORM, PROWL, THORNS, 467, 1126, 783, 5225 }) do
	assert(facts[spell] == nil and not ns.HEAL_SPELLS_UNKNOWN[spell] and spell <= ns.HEAL_SPELLS_LAST,
		"spell " .. spell .. " is listed as a heal")
end
-- And spells that heal through a dummy effect or a triggered spell are left to their description.
for _, spell in ipairs({ HOLY_SHOCK, 22842, 20577 }) do
	assert(facts[spell] == nil and ns.HEAL_SPELLS_UNKNOWN[spell], "spell " .. spell .. " is not listed as unknown")
end

for _, language in ipairs({ "deDE", "enUS" }) do
	locale = language

	-- Given nothing selected (recording 2): Regrowth, then Rejuvenation, no recipient read.
	ns.ResetHealing(); target = nil
	Cast(REGROWTH, nil, 77.585, "")
	Cast(REJUV, nil, 78.777, "")
	-- When its heal lands and both HoTs tick on their own beats.
	-- Then each is named by the spell whose period puts a tick there.
	Expect(Incoming(77.83, false), REGROWTH, "Regrowth's heal with nothing selected")
	Expect(Line("player", 80.6, true), REGROWTH, "Regrowth's first tick")
	Expect(Line("player", 81.8, true), REJUV, "Rejuvenation's first tick")
	Expect(Line("player", 86.6, true), REGROWTH, "Regrowth's third tick")
	Expect(Line("player", 90.8, true), REJUV, "Rejuvenation's last tick")
	Expect(Line("player", 92.6, true), REGROWTH, "Regrowth's tick near Rejuvenation's end")
	Expect(Line("player", 95.6, true), REGROWTH, "Regrowth's tick after Rejuvenation ran out")

	-- Given the same two HoTs and a tick on you that only the reader's beat rule finds.
	ns.ResetHealing(); target = nil
	Cast(REGROWTH, nil, 77.585, "")
	Cast(REJUV, nil, 78.777, "")
	-- Then no spell is named, as the tick may be someone else's.
	Expect(Incoming(80.6, true), nil, "a beat tick two HoTs of yours could own")

	-- Given Rejuvenation and Tranquility cast on you in one frame.
	ns.ResetHealing(); target = "player"
	Cast(REJUV, nil, 0, "Druid")
	Cast(TRANQUILITY, nil, 0, "Druid")
	-- Then a tick line on Tranquility's period is Tranquility's.
	Expect(Line("player", 2.02, true), TRANQUILITY, "Tranquility's tick beside Rejuvenation cast in the same frame")

	-- Given an enemy selected: the game casts the heal on you.
	for sent, label in pairs({ Wolf = "the enemy by name", Druid = "you", ["Wolf-Realm"] = "the enemy with its realm" }) do
		ns.ResetHealing(); target = sent == "Wolf-Realm" and "stranger" or "enemy"
		Cast(REGROWTH, "target1", 10, sent)
		-- Then its heal on you is yours.
		Expect(Incoming(10.25, false), REGROWTH, "Regrowth with an enemy selected, sent at " .. label)
	end

	-- Given a client where a unit has a surname: UnitName gives it as the second name, and the name
	-- a cast is sent at joins the two with the client's separator.
	local unitName = UnitName
	Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
	UnitName = function(unit)
		if unit == "player" then return "Druid", "Green" end
		return unitName(unit)
	end
	for _, selected in ipairs({ "enemy", false }) do
		ns.ResetHealing(); target = selected or nil
		Cast(REGROWTH, selected and "target1" or nil, 10, "Druid Green")
		-- Then its heal on you is yours.
		Expect(Incoming(10.25, false), REGROWTH,
			"Regrowth sent at your name and surname with " .. (selected or "nothing") .. " selected")
	end
	UnitName, Constants = unitName, nil

	-- Given a heal sent at a friend while an enemy or nothing is selected.
	for _, selected in ipairs({ "enemy", false }) do
		ns.ResetHealing(); target = selected or nil
		Cast(REJUV, selected and "target1" or nil, 10, "Ally")
		-- Then a heal on you is not that cast.
		Expect(Line("player", 13, true), nil, "a heal sent at a friend landed on you")
	end

	-- Given yourself selected and a heal whose SENT names a friend.
	ns.ResetHealing(); target = "player"
	Cast(REJUV, nil, 10, "Ally")
	-- Then a heal on you is not that cast.
	Expect(Line("player", 13, true), nil, "a heal sent at a friend with yourself selected landed on you")

	-- Given your pet selected and a heal whose SENT names a friend.
	ns.ResetHealing(); target = "pet"
	Cast(REJUV, nil, 10, "Ally")
	-- Then a heal on your pet is not that cast.
	Expect(Line("pet", 13, true), nil, "a heal sent at a friend with your pet selected landed on your pet")

	-- Given a friend selected: the heal is the friend's.
	ns.ResetHealing(); target = "friend"
	Cast(REJUV, "ally1", 10, nil)
	Expect(Line("player", 13, true), nil, "a heal on the selected friend landed on you")
	Expect(Line("ally1", 13, true), REJUV, "the friend's tick")

	-- Given a friend selected and the recipient hidden, so the cast has no key.
	ns.ResetHealing(); target = "friend"
	Cast(REGROWTH, nil, 10, hidden)
	-- Then a heal on you is not that cast.
	Expect(Incoming(10.25, false), nil, "a heal with a friend selected and its recipient hidden landed on you")

	-- Given forms, Prowl and Thorns with nothing or an enemy selected.
	for _, selected in ipairs({ "enemy", false }) do
		ns.ResetHealing(); target = selected or nil
		Cast(CAT_FORM, selected and "target1" or nil, 2, nil)
		Cast(PROWL, selected and "target1" or nil, 3, nil)
		-- Then none of them claims a heal on you.
		Expect(Incoming(3.5, false), nil, "a form or Prowl claimed a heal on you")
		Expect(Line("player", 5, true), nil, "a form or Prowl claimed a tick on you")
	end

	-- Given Rejuvenation on you, then Thorns and Cat Form.
	ns.ResetHealing(); target = "player"
	Cast(REJUV, nil, 0, "Druid")
	Cast(THORNS, nil, 4, "Druid")
	Cast(CAT_FORM, nil, 5, nil)
	Expect(Line("player", 6, true), REJUV, "Rejuvenation's tick after Thorns and Cat Form")
	Expect(Line("player", 20, true), nil, "a tick after Rejuvenation ran out")

	-- Given Regrowth and Rejuvenation in one frame (recording 3).
	ns.ResetHealing(); target = "player"
	Cast(REGROWTH_HIGH, nil, 78.961, "Druid")
	Cast(REJUV, nil, 78.961, "Druid")
	-- Then the heal is Regrowth's, the only one that heals at once.
	Expect(Incoming(79.216, false), REGROWTH_HIGH, "the heal of two casts in one frame")
	-- And ticks in the same frames name neither, until Rejuvenation runs out.
	Expect(Line("player", 81.97, true), nil, "a tick shared by two HoTs on one beat")
	Expect(Line("player", 90.97, true), nil, "the last shared tick")
	Expect(Line("player", 93.97, true), REGROWTH_HIGH, "Regrowth's tick once the shared beats ended")

	-- Given Healing Touch while Rejuvenation ticks on you (the incoming path).
	ns.ResetHealing(); target = "player"
	Cast(REJUV, nil, 30, "Druid")
	Expect(Incoming(33, true), REJUV, "Rejuvenation's tick before Healing Touch")
	Cast(HEALING_TOUCH, nil, 34, "Druid")
	Expect(Incoming(34.2, false), HEALING_TOUCH, "Healing Touch's heal")
	Expect(Incoming(36, true), REJUV, "Rejuvenation's tick after Healing Touch")

	-- Given Rejuvenation on you and Healing Touch on a selected friend just before its tick.
	ns.ResetHealing(); target = "player"
	Cast(REJUV, nil, 30, "Druid")
	target = "friend"
	Cast(HEALING_TOUCH, "ally1", 32.9, nil)
	-- Then the friend's heal at once, not matched yet, holds back no tick on you.
	Expect(Incoming(33, true), REJUV, "a beat tick on you beside a heal at once on a friend")

	-- Given a HoT cast just before another HoT ticks.
	ns.ResetHealing(); target = "friend"
	Cast(REJUV, "ally1", 0, nil)
	Cast(REGROWTH, "ally1", 2.9, nil)
	Expect(Line("ally1", 2.95, false), REGROWTH, "Regrowth's heal just before another HoT's tick")
	Expect(Line("ally1", 3.02, true), REJUV, "a tick right after another HoT's cast")

	-- Given Rejuvenation recast while Regrowth ticks: the recast restarts its beat.
	ns.ResetHealing(); target = "friend"
	Cast(REJUV, "ally1", 0, nil)
	Cast(REGROWTH, "ally1", 1, nil)
	Cast(REJUV, "ally1", 4.5, nil)
	Expect(Line("ally1", 7.02, true), REGROWTH, "Regrowth's tick beside a recast Rejuvenation")
	Expect(Line("ally1", 7.52, true), REJUV, "the recast Rejuvenation's tick")
	Expect(Line("ally1", 9.02, true), nil, "a tick on the beat the recast ended")

	-- Given Mend Pet with nothing selected and its recipient hidden.
	ns.ResetHealing(); target = nil
	Cast(MEND_PET, nil, 40, hidden)
	Expect(Line("pet", 41, true), MEND_PET, "Mend Pet's tick on the pet")
	Expect(Line("player", 41, true), nil, "Mend Pet's tick on you")

	-- Given Health Funnel, a heal on the pet, with an enemy selected.
	ns.ResetHealing(); target = "enemy"
	Cast(HEALTH_FUNNEL, "target1", 40, "")
	Expect(Line("pet", 41, true), HEALTH_FUNNEL, "Health Funnel's tick on the pet")
	Expect(Line("player", 41, true), nil, "Health Funnel's tick on you")

	-- Given Rejuvenation ticking on you and a heal at once cast just before its
	-- next tick, so the reader takes that heal for a tick.
	for _, spell in ipairs({ REGROWTH, HEALING_TOUCH }) do
		ns.ResetHealing(); target = "player"
		Cast(REJUV, nil, 0, "Druid")
		Expect(Incoming(3.06, true), REJUV, "Rejuvenation's tick before a heal at once")
		Expect(Incoming(6.06, true), REJUV, "Rejuvenation's second tick before a heal at once")
		Cast(spell, nil, 8.91, "Druid")
		-- Then it is not named after Rejuvenation.
		Expect(Incoming(8.91, true), nil, "the heal at once of " .. spell .. " read as a tick")
		-- And a tick its combat log line confirms is still Rejuvenation's.
		Expect(Line("player", 9.02, true), REJUV, "Rejuvenation's tick line beside an unmatched heal at once")
	end

	-- Given heals whose own effects the table reads or not, cast on yourself.
	for _, spell in ipairs({ LAY_ON_HANDS, HOLY_SHOCK }) do
		ns.ResetHealing(); target = "player"
		Cast(spell, nil, 100, "Druid")
		-- Then the heal is named, as the description named it before.
		Expect(Incoming(100.2, false), spell, "the heal of " .. spell .. " cast on yourself")
	end

	-- Given a heal potion the table knows, whose German text speaks of health and damage only.
	ns.ResetHealing(); target = nil
	Cast(HEAL_POTION, nil, 0, "")
	-- Then the table, not the description, says that it heals.
	Expect(Incoming(0.2, false), HEAL_POTION, "a heal the table knows whose description reads as no heal")

	-- Given your pet casts a heal with no recipient read.
	ns.ResetHealing(); target = nil
	Cast(HEALING_TOUCH, nil, 50, nil, "pet")
	Expect(Incoming(50.2, false), nil, "your pet's heal landed on you")

	-- Given a heal newer than the table, it is read from its description as before.
	ns.ResetHealing(); target = "player"
	Cast(NEWER_HEAL, nil, 60, "Druid")
	-- And a tick the beat rule finds a second later is its own, as before.
	Expect(Incoming(61, true), NEWER_HEAL, "a beat tick a second after a heal the table does not know")
	Expect(Line("player", 63, true), NEWER_HEAL, "the first tick line of a heal the table does not know")
	Cast(CAT_FORM, nil, 61, nil)
	Expect(Line("player", 66, true), NEWER_HEAL, "the tick of a heal the table does not know after Cat Form")

	-- Given such a spell with nothing selected: whether it heals is only read.
	ns.ResetHealing(); target = nil
	Cast(NEWER_HEAL, nil, 70, "")
	Expect(Line("player", 73, true), nil, "a spell the table does not know landed on you")

	-- Given it beside a known HoT: the beat of one of them is unknown.
	ns.ResetHealing(); target = "player"
	Cast(REJUV, nil, 80, "Druid")
	Cast(NEWER_HEAL, nil, 81, "Druid")
	Expect(Line("player", 83.02, true), nil, "a tick beside a heal the table does not know")

	-- Given a client that cannot tell whether a target exists.
	ns.ResetHealing(); target = nil
	local unitExists = UnitExists
	UnitExists = nil
	Cast(REGROWTH, nil, 110, "")
	UnitExists = unitExists
	-- Then no friend is taken to be absent.
	Expect(Incoming(110.25, false), nil, "a heal landed on you while the target could not be read")

	-- Given the mainline client: the table is Forever's.
	MikSBT.Compatibility.Client = MAINLINE
	ns.ResetHealing(); target = "player"
	Cast(WILD_GROWTH, nil, 200, "Druid")
	-- Then a heal it does not know is read from its description, as before.
	Expect(Line("player", 202, true), WILD_GROWTH, "a mainline heal the table does not know")
	MikSBT.Compatibility.Client = FOREVER
end

print("Own heal icon tests passed")
