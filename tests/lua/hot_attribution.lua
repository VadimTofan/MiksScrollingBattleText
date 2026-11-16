-- Describe: HoT ticks retain the HoT spell identity even if non-healing buffs or other spells are cast.
MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
local ns = MikSBT.CombatEngine
local selectedUnit = "player"

local descriptions = {
	[774] = "Heals the target for 189 over 12 sec.", -- Rejuvenation (HoT)
	[467] = "Thorns sprout from the friendly target causing 12 Nature damage to attackers when hit.  Lasts 10 min.", -- Thorns (Buff)
	[1126] = "Increases the friendly target's armor by 285 for 30 min.", -- Mark of the Wild (Buff)
	[5185] = "Heals a friendly target for 370 to 441.", -- Healing Touch (Direct heal)
	[8936] = "Heals a friendly target for 91 to 108 and another 164 over 21 sec.", -- Regrowth (Direct + HoT)
}

local spellNames = {
	[774] = "Rejuvenation",
	[467] = "Thorns",
	[1126] = "Mark of the Wild",
	[5185] = "Healing Touch",
	[8936] = "Regrowth",
}

C_Spell = {
	IsSpellHelpful = function() return true end,
	GetSpellName = function(spell) return spellNames[spell] or "Unknown" end,
	GetSpellDescription = function(spell) return descriptions[spell] or "" end,
}

UnitName = function(unit)
	return unit == "player" and "Druid" or "Ally"
end
UnitIsUnit = function(_, unit) return unit == selectedUnit end

dofile("Combat/Healing.lua")

-- Scenario 1: Casting a non-healing buff (Thorns) during an active HoT (Rejuvenation)
ns.ResetHealing()
selectedUnit = "player"

-- Cast Rejuvenation at t = 10
ns.NoteHealTarget("player", "Druid", "rejuv-guid", 774, 10)
ns.NoteHealCast("player", 774, "player", 10, "rejuv-guid")

-- First HoT tick at t = 11
local tick1 = ns.MatchHealing("player", 11, true, true)
assert(tick1 and tick1.spell == 774, "first tick should match Rejuvenation")

-- Cast Thorns on the player at t = 12
ns.NoteHealTarget("player", "Druid", "thorns-guid", 467, 12)
ns.NoteHealCast("player", 467, "player", 12, "thorns-guid")

-- Second HoT tick at t = 13 (must still be Rejuvenation, not Thorns!)
local tick2 = ns.MatchHealing("player", 13, true, true)
assert(tick2 and tick2.spell == 774,
	"HoT tick was hijacked by Thorns! Expected 774, got: " .. tostring(tick2 and tick2.spell))

-- Scenario 2: Casting a buff immediately after HoT before the first tick
ns.ResetHealing()
selectedUnit = "player"

-- Cast Rejuvenation at t = 20
ns.NoteHealTarget("player", "Druid", "rejuv-guid-2", 774, 20)
ns.NoteHealCast("player", 774, "player", 20, "rejuv-guid-2")

-- Cast Mark of the Wild at t = 21 before any tick has occurred
ns.NoteHealTarget("player", "Druid", "motw-guid", 1126, 21)
ns.NoteHealCast("player", 1126, "player", 21, "motw-guid")

-- First HoT tick arrives at t = 23 (must match Rejuvenation, not Mark of the Wild)
local tickPre = ns.MatchHealing("player", 23, true, true)
assert(tickPre and tickPre.spell == 774,
	"First HoT tick was hijacked by Mark of the Wild! Expected 774, got: " .. tostring(tickPre and tickPre.spell))

-- Scenario 3: Direct heal used during an active HoT
ns.ResetHealing()
selectedUnit = "player"

-- Cast Rejuvenation at t = 30
ns.NoteHealTarget("player", "Druid", "rejuv-guid-3", 774, 30)
ns.NoteHealCast("player", 774, "player", 30, "rejuv-guid-3")

-- First tick at t = 31
local tickA = ns.MatchHealing("player", 31, true, true)
assert(tickA and tickA.spell == 774)

-- Cast Healing Touch at t = 32
ns.NoteHealTarget("player", "Druid", "ht-guid", 5185, 32)
ns.NoteHealCast("player", 5185, "player", 32, "ht-guid")

-- Direct heal lands at t = 32.2 (tick == false)
local direct = ns.MatchHealing("player", 32.2, false, true)
assert(direct and direct.spell == 5185, "direct heal should match Healing Touch")

-- Next HoT tick at t = 34 (must match Rejuvenation, not Healing Touch!)
local tickB = ns.MatchHealing("player", 34, true, true)
assert(tickB and tickB.spell == 774,
	"HoT tick was hijacked by Healing Touch! Expected 774, got: " .. tostring(tickB and tickB.spell))

-- Scenario 4: Expired HoT yields to a newly cast HoT
ns.ResetHealing()
selectedUnit = "player"

-- Cast Rejuvenation (12s duration) at t = 10
ns.NoteHealTarget("player", "Druid", "rejuv-exp-guid", 774, 10)
ns.NoteHealCast("player", 774, "player", 10, "rejuv-exp-guid")

-- Matches first tick at t = 11
local rejuvTick = ns.MatchHealing("player", 11, true, true)
assert(rejuvTick and rejuvTick.spell == 774)

-- Rejuvenation naturally ends at t = 22.
-- Player casts Regrowth (8936) at t = 25.
ns.NoteHealTarget("player", "Druid", "regrowth-guid", 8936, 25)
ns.NoteHealCast("player", 8936, "player", 25, "regrowth-guid")

-- Periodic heal tick arrives at t = 26 (must match Regrowth, NOT expired Rejuvenation!)
local regrowthTick = ns.MatchHealing("player", 26, true, true)
assert(regrowthTick and regrowthTick.spell == 8936,
	"Expired Rejuvenation blocked new Regrowth! Expected 8936, got: " .. tostring(regrowthTick and regrowthTick.spell))

-- Scenario 5: French localized Rejuvenation description
ns.ResetHealing()
selectedUnit = "player"
descriptions[774] = "Rend 189 points de vie en 12 sec."

ns.NoteHealTarget("player", "Druid", "fr-rejuv-guid", 774, 40)
ns.NoteHealCast("player", 774, "player", 40, "fr-rejuv-guid")

local frTick = ns.MatchHealing("player", 41, true, true)
assert(frTick and frTick.spell == 774,
	"French localized Rejuvenation was rejected! Expected 774, got: " .. tostring(frTick and frTick.spell))

-- Scenario 6: German localized Rejuvenation description
ns.ResetHealing()
selectedUnit = "player"
descriptions[774] = "Heilt das Ziel im Verlauf von 12 Sek. um 189."

ns.NoteHealTarget("player", "Druid", "de-rejuv-guid", 774, 50)
ns.NoteHealCast("player", 774, "player", 50, "de-rejuv-guid")

local deTick = ns.MatchHealing("player", 51, true, true)
assert(deTick and deTick.spell == 774,
	"German localized Rejuvenation was rejected! Expected 774, got: " .. tostring(deTick and deTick.spell))

-- Scenario 7: Multiple concurrent active HoTs interleave
ns.ResetHealing()
selectedUnit = "player"
descriptions[774] = "Heals the target for 189 over 12 sec."

-- Cast Rejuvenation at t = 60
ns.NoteHealTarget("player", "Druid", "multi-rejuv", 774, 60)
ns.NoteHealCast("player", 774, "player", 60, "multi-rejuv")

-- Tick 1 at t = 63 belongs to Rejuvenation
local multi1 = ns.MatchHealing("player", 63, true, true)
assert(multi1 and multi1.spell == 774, "multi-hot tick 1 failed")

-- Cast Regrowth at t = 62 on the same player
ns.NoteHealTarget("player", "Druid", "multi-regrowth", 8936, 62)
ns.NoteHealCast("player", 8936, "player", 62, "multi-regrowth")

-- Tick 2 at t = 65 (Regrowth is younger and Rejuv ticked at 63, so Regrowth claims it)
local multi2 = ns.MatchHealing("player", 65, true, true)
assert(multi2 and multi2.spell == 8936, "multi-hot tick 2 failed, expected Regrowth got: " .. tostring(multi2 and multi2.spell))

-- Tick 3 at t = 66 (Regrowth just ticked at 65 so rate-limited; Rejuv last ticked at 63, claims it)
local multi3 = ns.MatchHealing("player", 66, true, true)
assert(multi3 and multi3.spell == 774, "multi-hot tick 3 failed, expected Rejuv got: " .. tostring(multi3 and multi3.spell))

-- Scenario 8: Spanish localized Rejuvenation description ("s." abbreviation)
ns.ResetHealing()
selectedUnit = "player"
descriptions[774] = "Sana al objetivo 189 p. de salud durante 12 s."

ns.NoteHealTarget("player", "Druid", "es-rejuv-guid", 774, 70)
ns.NoteHealCast("player", 774, "player", 70, "es-rejuv-guid")

local esTick = ns.MatchHealing("player", 71, true, true)
assert(esTick and esTick.spell == 774,
	"Spanish localized Rejuvenation was rejected! Expected 774, got: " .. tostring(esTick and esTick.spell))

-- Scenario 9: Spanish localized Thorns (Espinas) must NOT override Rejuvenation
descriptions[467] = "Hace brotar espinas en el objetivo amistoso que infligen 12 p. de daño de Naturaleza a los atacantes cuando lo golpean. Dura 10 min."
ns.NoteHealTarget("player", "Druid", "es-thorns-guid", 467, 72)
ns.NoteHealCast("player", 467, "player", 72, "es-thorns-guid")

local esTick2 = ns.MatchHealing("player", 73, true, true)
assert(esTick2 and esTick2.spell == 774,
	"Spanish Thorns (Espinas) hijacked Rejuvenation! Expected 774, got: " .. tostring(esTick2 and esTick2.spell))

-- Scenario 10: French localized Thorns (Épines) must NOT override Rejuvenation
descriptions[467] = "Fait pousser des épines sur la cible amie, infligeant 12 points de dégâts de Nature aux attaquants. Dure 10 min."
ns.NoteHealTarget("player", "Druid", "fr-thorns-guid", 467, 74)
ns.NoteHealCast("player", 467, "player", 74, "fr-thorns-guid")

local frTick2 = ns.MatchHealing("player", 75, true, true)
assert(frTick2 and frTick2.spell == 774,
	"French Thorns (Épines) hijacked Rejuvenation! Expected 774, got: " .. tostring(frTick2 and frTick2.spell))

-- Scenario 11: German localized Thorns (Dornen) must NOT override Rejuvenation
descriptions[467] = "Lässt Dornen auf dem befreundeten Ziel sprießen, die Angreifern 12 Naturschaden zufügen. Hält 10 Min. an."
ns.NoteHealTarget("player", "Druid", "de-thorns-guid", 467, 76)
ns.NoteHealCast("player", 467, "player", 76, "de-thorns-guid")

local deTick2 = ns.MatchHealing("player", 77, true, true)
assert(deTick2 and deTick2.spell == 774,
	"German Thorns (Dornen) hijacked Rejuvenation! Expected 774, got: " .. tostring(deTick2 and deTick2.spell))

print("All HoT attribution tests passed successfully!")
