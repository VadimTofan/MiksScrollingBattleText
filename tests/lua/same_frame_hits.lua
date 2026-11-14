MikSBT = { CombatEngine = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine

-- Given a client that describes no spell and hides every amount: a taunt and
-- two strikes, all known as physical and as hitting at once.
local TAUNT, STRIKE, CLEAVE = 1, 2, 3
local function Learned(field) return field ~= "period" and 1 or nil end
local function NewMine(facts)
    return ns.NewMine(Learned, function() end, facts or function() end)
end
local function Cast(mine, spell, at) mine:Cast("player", spell, "target", at) end
local function Hit(mine, at, amount)
    return mine:Hit("target", "damage", 1, at, false, true, amount, false, "direct")
end

-- When the taunt takes no hit and the strikes follow in turn, each hit in the
-- frame of its own cast.
local mine = NewMine()
Cast(mine, TAUNT, 0)
for _, step in ipairs({ { 1, STRIKE }, { 2, CLEAVE }, { 2.5, STRIKE }, { 4, CLEAVE } }) do
    Cast(mine, step[2], step[1])
    local result = Hit(mine, step[1])
    -- Then each hit is named after the cast of its frame.
    assert(result.who == "you" and result.spell == step[2] and not result.ambiguous,
        "hit at " .. step[1] .. " was not named after the cast of its frame")
end

-- When the cast's event comes just after its hit.
mine = NewMine()
Cast(mine, TAUNT, 0)
Cast(mine, STRIKE, 1.016)
local result = Hit(mine, 1)
-- Then it is still the cast of that frame.
assert(result.spell == STRIKE and not result.ambiguous, "cast event just after its hit was not counted")

-- When two different casts share the hit's frame.
mine = NewMine()
Cast(mine, STRIKE, 1)
Cast(mine, CLEAVE, 1)
result = Hit(mine, 1)
-- Then the frame cannot tell them apart and no name is given.
assert(result.ambiguous and result.spell == nil, "two casts of one frame were told apart by guessing")

-- When the hit comes in no cast's frame, a moment after the newer cast.
mine = NewMine()
Cast(mine, STRIKE, 1)
Cast(mine, CLEAVE, 2.2)
result = Hit(mine, 2.5)
-- Then no name is given, as before.
assert(result.ambiguous and result.spell == nil, "a hit outside any cast's frame was named by its time")

-- Given descriptions and a readable amount that fits the older cast only.
local described = {
    [STRIKE] = { damages = true, direct = true, ticks = false, school = 1, low = 100, high = 110 },
    [CLEAVE] = { damages = true, direct = true, ticks = false, school = 1, low = 10, high = 12 },
}
mine = NewMine(function(spell) return described[spell] end)
Cast(mine, STRIKE, 1)
Cast(mine, CLEAVE, 2)
-- When the hit comes in the frame of the newer cast.
result = Hit(mine, 2, 105)
-- Then the amount outranks the frame.
assert(result.spell == STRIKE and not result.ambiguous, "the frame outranked a clear amount")
