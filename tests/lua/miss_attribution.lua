-- Describe: a miss goes only to an action that can have caused it.
MikSBT = { CombatEngine = {} }
dofile("Combat/Spells.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local spells = {
    [75] = { range = 35, text = "Automatically shoots the target until cancelled." },
    [1130] = { range = 100, text = "Places the Hunter's Mark on the target, increasing the ranged attack "
        .. "power of all attackers against that target by 20." },
    [5116] = { range = 35, text = "Dazes the target, slowing movement to 50% for 4 sec." },
    [2973] = { range = 5, text = "A strong attack that increases melee damage by 5." },
    [1714] = { range = 30, text = "Forces the target to speak in Demonic." },
    [1978] = { range = 35, text = "Stings the target, causing 20 Nature damage over 15 sec." },
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
local function Is(result, who, spell, melee)
    return result.who == who and result.spell == spell and (melee == nil or result.melee == true)
end

-- Given the reach of each spell.
-- When it is asked what can avoid it.
-- Then only a melee strike can be parried, and only a weapon attack dodged.
assert(ns.SpellReach(2973) == "melee" and ns.SpellReach(5116) == "ranged" and ns.SpellReach(1130) == "spell")
assert(ns.SpellCanAvoid(2973, "PARRY") and ns.SpellCanAvoid(5116, "DODGE"))
assert(not ns.SpellCanAvoid(5116, "PARRY") and not ns.SpellCanAvoid(1130, "DODGE"))
assert(ns.SpellCanAvoid(1130, "RESIST") and ns.SpellCanAvoid(1130, "IMMUNE"))
assert(ns.SpellCanAvoid(999, "PARRY"), "an unreadable range ruled something out")

-- Given Hunter's Mark, then the pet's swing parried.
local mine = New()
mine:Cast("player", 1130, "target", 10)

-- When the parry is reported while the pet attacks that unit.
local parried = mine:Hit("target", "miss", 1, 10.6, true, nil, nil, false, nil, nil, "PARRY")

-- Then it is the pet's swing, not the Mark.
assert(Is(parried, "pet", nil, true), tostring(parried.who) .. " " .. tostring(parried.spell))

-- Given Hunter's Mark, then an Auto Shot that is dodged.
mine = New()
mine:Cast("player", 1130, "target", 20)
mine:Swing("ranged", "target", 20.1, 2.8)

-- When the dodge is reported, with or without the shot's line.
local dodged = mine:Hit("target", "miss", 1, 20.8, false, nil, nil, false, nil, nil, "DODGE")
mine:Cast("player", 1130, "target", 24)
mine:Swing("ranged", "target", 24.2, 2.8)
local lined = mine:Hit("target", "miss", 1, 24.9, false, true, nil, false, nil, nil, "DODGE")

-- Then it is the shot's.
assert(dodged.who == "you" and dodged.hand == "ranged" and dodged.spell == nil)
assert(lined.who == "you" and lined.hand == "ranged" and lined.spell == nil)

-- Given Hunter's Mark on a unit that is immune, and a resisted curse.
mine = New()
mine:Cast("player", 1130, "target", 30)
local immune = mine:Hit("target", "miss", 1, 30.3, false, nil, nil, false, nil, nil, "IMMUNE")
mine:Cast("player", 1714, "target", 34)
local resisted = mine:Hit("target", "miss", 1, 34.3, false, nil, nil, false, nil, nil, "RESIST")

-- Then a magic spell still takes what can answer it.
assert(Is(immune, "you", 1130) and Is(resisted, "you", 1714))

-- Given Hunter's Mark, then a plain miss while the pet attacks.
mine = New()
mine:Cast("player", 1130, "target", 40)
local missed = mine:Hit("target", "miss", 1, 40.5, true, nil, nil, false, nil, nil, "MISS")

-- Then the pet missed, not the Mark.
assert(Is(missed, "pet", nil, true))

-- Given a shot and a melee strike.
mine = New()
mine:Cast("player", 5116, "target", 50)
local shotDodged = mine:Hit("target", "miss", 1, 50.4, false, nil, nil, false, nil, nil, "DODGE")
mine:Cast("player", 5116, "target", 54)
local shotParried = mine:Hit("target", "miss", 1, 54.4, true, nil, nil, false, nil, nil, "PARRY")
mine:Cast("player", 2973, "target", 58)
local strikeParried = mine:Hit("target", "miss", 1, 58.3, false, nil, nil, false, nil, nil, "PARRY")

-- Then a shot can be dodged but never parried, and a strike can be parried.
assert(Is(shotDodged, "you", 5116))
assert(Is(shotParried, "pet", nil, true))
assert(Is(strikeParried, "you", 2973))

-- Given a miss reported with no avoid word, as before this was known.
mine = New()
mine:Cast("player", 1130, "target", 60)

-- When it is decided, then nothing is ruled out.
assert(Is(mine:Hit("target", "miss", 1, 60.3, false, nil), "you", 1130))

-- Given a frame with fewer lines than hits.
mine = New()
mine:Cast("player", 1130, "target", 70)

-- When the reader asks how well a parry fits, then the Mark is no fit for it.
assert(mine:Fit("target", "miss", 1, 70.4, nil, nil, nil, "PARRY", true) == nil)
assert(mine:Fit("target", "miss", 1, 70.4, nil, nil, nil, "IMMUNE", true) ~= nil)

-- Given a DoT's first tick, which is not a miss.
mine = New()
mine:Cast("player", 1978, "target", 80)

-- When it lands, then hits are decided as before.
assert(Is(mine:Hit("target", "damage", 8, 83, false, nil, 4, false), "you", 1978))

-- Given a spell miss confirmed by a direct-spell line, with competing physical activity.
for _, pet in ipairs({ true, false }) do
    mine = New()
    mine:Cast("player", 1130, "target", 90)
    if not pet then mine:Swing("ranged", "target", 90.1, 2.8) end

    -- When the reader ranks and attributes that confirmed spell miss.
    local fit = mine:Fit("target", "miss", 1, 90.4,
        nil, "direct", false, "MISS", pet)
    local result = mine:Hit("target", "miss", 1, 90.4,
        pet, true, nil, false, "direct", nil, "MISS")

    -- Then pet activity or a recent shot cannot remove the confirmed spell.
    assert(fit ~= nil, "confirmed spell miss was rejected during ranking")
    assert(Is(result, "you", 1130),
        "confirmed spell miss lost its attribution to physical activity")
end

-- Given a confirmed spell miss on a unit whose cast target was unavailable.
mine = New()
mine:Cast("player", 1130, "other-target", 100)

-- When the recent-cast fallback resolves it while a pet attacks.
local fallback = mine:Hit("target", "miss", 1, 100.4,
    true, true, nil, false, "direct", nil, "MISS")

-- Then that fallback also respects the direct-spell confirmation.
assert(Is(fallback, "you", 1130), "confirmed fallback spell miss lost its icon")

-- Given a recent ranged shot with no pet or spell to explain a parry.
for _, restrict in ipairs({ "shot", "unknown" }) do
    mine = New()
    mine:Swing("ranged", "target", 110, 2.8)
    local source = restrict == "shot" and "shot" or nil

    -- When ranking a parry beside a valid ranged hit in a crowded frame.
    local parryFit = mine:Fit("target", "miss", 1, 110.4,
        nil, source, false, "PARRY", false)
    local damageFit = mine:Fit("target", "damage", 1, 110.4,
        100, source, false, nil, false)
    local dodgeFit = mine:Fit("target", "miss", 1, 110.4,
        nil, source, false, "DODGE", false)

    -- Then the parry cannot consume the confirmation needed by the valid shot.
    assert(parryFit == nil, "ranking still accepts an impossible ranged parry")
    assert(damageFit ~= nil and dodgeFit ~= nil,
        "valid ranged damage or dodge was excluded")

    -- When final attribution sees the same parry.
    local parry = mine:Hit("target", "miss", 1, 110.4,
        false, true, nil, false, source, nil, "PARRY")

    -- Then it agrees with ranking and leaves the shot available.
    assert(parry.who == "other" and not mine.swings[1].used)
end
