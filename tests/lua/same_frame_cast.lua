-- Describe: a hit goes to the cast in its own frame before older casts.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local spells = {
    [2973] = { range = 5, text = "A strong attack that increases melee damage by 5." },
    [16827] = { range = 5, text = "Claw the enemy, causing 16 to 22 damage." },
    [2649] = { range = 5, text = "Taunt the target, increasing the likelihood the creature will "
        .. "focus attacks on you." },
    [24423] = { range = 5, text = "Blasts a single enemy for 7 to 9 damage." },
}
C_Spell = {
    GetSpellInfo = function(id) return spells[id] and { maxRange = spells[id].range, minRange = 0 } end,
    SpellHasRange = function(id) return spells[id] ~= nil end,
}
UnitClass = function() return "Hunter", "HUNTER" end
local function New()
    return ns.NewMine(nil, nil, function(spell)
        return spells[spell] and ns.ParseSpellDescription(spells[spell].text)
    end)
end
local function Is(result, who, spell)
    return result.who == who and result.spell == spell
end

-- Given a pet's Growl still waiting for a resist, then its Claw.
local mine = New()
mine:Cast("pet", 2649, "target", 10)
mine:Cast("pet", 16827, "target", 11)

-- When a dodge is reported in Claw's own frame.
local dodged = mine:Hit("target", "miss", 1, 11, true, true, nil, false, nil, nil, "DODGE")

-- Then Claw was dodged, not the older Growl.
assert(Is(dodged, "pet", 16827) and dodged.missed == true, "the older cast took the miss")

-- Given a pet's Claw whose hit never came, then the player's strike.
mine = New()
mine:Cast("pet", 16827, "target", 19.7)
mine:Cast("player", 2973, "target", 20)

-- When a confirmed physical hit is reported in the strike's own frame.
local struck = mine:Hit("target", "damage", 1, 20, true, true, nil, false)

-- Then it is the strike's, neither ambiguous nor the older Claw's.
assert(Is(struck, "you", 2973) and not struck.ambiguous, "the strike's own frame did not decide")

-- Given two pet abilities, each reported in its own frame.
mine = New()
mine:Cast("pet", 24423, "target", 30)
local screech = mine:Hit("target", "damage", 1, 30, true, true, nil, false)
mine:Cast("pet", 16827, "target", 30.4)
local claw = mine:Hit("target", "damage", 1, 30.4, true, true, nil, false)

-- Then each keeps its own name.
assert(Is(screech, "pet", 24423) and Is(claw, "pet", 16827))

-- Given a single cast whose hit comes later, as a spell in flight does.
mine = New()
mine:Cast("pet", 16827, "target", 40)

-- When it lands, then it is matched as before.
assert(Is(mine:Hit("target", "damage", 1, 40.4, true, true, nil, false), "pet", 16827))

-- Given the player's strike and the pet's Claw cast in one frame.
mine = New()
mine:Cast("player", 2973, "target", 50)
mine:Cast("pet", 16827, "target", 50)

-- When that frame's two confirmed hits are decided.
local first = mine:Hit("target", "damage", 1, 50, true, true, nil, false)
local second = mine:Hit("target", "damage", 1, 50, true, true, nil, false)

-- Then each cast keeps one, in the order cast, and neither is hidden.
assert(Is(first, "you", 2973) and Is(second, "pet", 16827), "a mixed frame hid its hits")

-- Given two different spells of the player's own cast in one frame.
mine = New()
mine:Cast("player", 2973, "target", 60)
mine:Cast("player", 24423, "target", 60)

-- When one confirmed hit comes in that frame.
local either = mine:Hit("target", "damage", 1, 60, false, true, nil, false)

-- Then it stays ambiguous: nothing tells the two apart.
assert(either.who == "you" and either.ambiguous == true and either.spell == nil)
