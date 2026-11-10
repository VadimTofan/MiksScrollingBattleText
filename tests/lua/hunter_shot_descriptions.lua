-- Describe: shots that word their damage as ranged damage or missiles.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local descriptions = {
    [19434] = "An aimed shot that increases ranged damage by 70.",
    [2643] = "Fires several missiles, hitting 3 targets.",
    [14288] = "Fires several missiles, hitting 3 targets for an additional 40 damage.",
    [1130] = "Places the Hunter's Mark on the target, increasing the ranged attack power "
        .. "of all attackers against that target by 20.",
    [16828] = "Claw the enemy, causing 26 to 36 damage.",
}
local function Facts(spell) return ns.ParseSpellDescription(descriptions[spell]) end

-- Given the descriptions of Aimed Shot and both wordings of Multi-Shot.
-- When they are read.
for _, spell in ipairs({ 19434, 2643, 14288 }) do
    local facts = Facts(spell)

    -- Then each is a physical hit at once that does not tick.
    assert(facts.damages == true, "spell " .. spell .. " reads as dealing no damage")
    assert(facts.school == 1 and facts.direct == true and not facts.ticks,
        "spell " .. spell .. " is not a physical direct hit")
end

-- Given a debuff that mentions ranged attack power, not ranged damage.
-- When it is read, then it still deals none.
assert(Facts(1130).damages == false)

-- Given a pet's Claw, then an Aimed Shot that lands after its flight.
local mine = ns.NewMine(nil, nil, Facts)
mine:Cast("pet", 16828, "target", 10)
mine:Hit("target", "damage", 1, 10, true, true, 30, false, "direct")
mine:Cast("player", 19434, "target", 12)

-- When the shot's hit is reported with its combat log line.
local shot = mine:Hit("target", "damage", 1, 12.4, true, true, 80, false, "direct")

-- Then it is the shot's, not the pet's.
assert(shot.who == "you" and shot.spell == 19434,
    "Aimed Shot's hit went to " .. tostring(shot.who) .. " " .. tostring(shot.spell))

-- Given a Multi-Shot.
mine:Cast("player", 2643, "target", 20)

-- When its hit on the target is reported.
local multi = mine:Hit("target", "damage", 1, 20.6, true, true, 40, false, "direct")

-- Then it is Multi-Shot's.
assert(multi.who == "you" and multi.spell == 2643)
