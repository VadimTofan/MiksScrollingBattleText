-- Describe: HoT ticks retain the HoT spell identity even if non-healing buffs or other spells are cast.
MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
local ns = MikSBT.CombatEngine
local selectedUnit = "player"

local descriptions = {
	[774] = "Heals the target for 189 over 12 sec.", -- Rejuvenation (HoT)
	[467] = "Sprouts thorns on the friendly target causing 12 Nature damage to attackers when hit. Lasts 10 min.", -- Thorns (Buff)
	[1126] = "Increases the friendly target's armor by 285 for 30 min.", -- Mark of the Wild (Buff)
	[5185] = "Heals a friendly target for 370 to 441.", -- Healing Touch (Direct heal)
}

local spellNames = {
	[774] = "Rejuvenation",
	[467] = "Thorns",
	[1126] = "Mark of the Wild",
	[5185] = "Healing Touch",
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

print("All HoT attribution tests passed successfully!")
