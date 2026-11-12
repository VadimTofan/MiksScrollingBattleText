local ns = MikSBT.CombatEngine

-- What a spell of yours did to your target, in the game's own word: a
-- Frostbolt that slowed it shows "Snared", a Rake "Bleed", a Banish
-- "Banished". The game draws these words over the target itself and gives an
-- addon none of them: the target's auras are secret in a fight
-- (GetAuraDataByIndex is refused), and the loss of control list of a target
-- stayed empty under a Frostbolt's slow. What is left is the spell you cast,
-- which reads plainly, and the moment: an aura added or refreshed on the
-- target in the frame of the cast, or in the frame of the hit that cast is
-- named for when its missile flies. What the spell does comes from the
-- game's data (SpellMechanics.lua), since no function tells it. A resisted
-- or dodged cast changes no aura and shows nothing. Only the moment is seen,
-- not the aura: another aura changing on the target in that frame counts as
-- well (predicted, not yet seen in client).

-- Mechanic id to the global string that names it. The client translates them.
local WORDS = {
    [1] = "LOSS_OF_CONTROL_DISPLAY_CHARM", [2] = "LOSS_OF_CONTROL_DISPLAY_DISORIENT",
    [3] = "LOSS_OF_CONTROL_DISPLAY_DISARM", [5] = "LOSS_OF_CONTROL_DISPLAY_FEAR",
    [7] = "LOSS_OF_CONTROL_DISPLAY_ROOT", [8] = "LOSS_OF_CONTROL_DISPLAY_PACIFY",
    [9] = "LOSS_OF_CONTROL_DISPLAY_SILENCE", [10] = "LOSS_OF_CONTROL_DISPLAY_SLEEP",
    [11] = "LOSS_OF_CONTROL_DISPLAY_SNARE", [12] = "LOSS_OF_CONTROL_DISPLAY_STUN",
    [13] = "LOSS_OF_CONTROL_DISPLAY_FREEZE", [14] = "LOSS_OF_CONTROL_DISPLAY_INCAPACITATE",
    [15] = "ENCOUNTER_JOURNAL_SECTION_FLAG13", [17] = "LOSS_OF_CONTROL_DISPLAY_POLYMORPH",
    [18] = "LOSS_OF_CONTROL_DISPLAY_BANISH", [20] = "LOSS_OF_CONTROL_DISPLAY_SHACKLE_UNDEAD",
    [22] = "LOSS_OF_CONTROL_DISPLAY_CHARM", [23] = "LOSS_OF_CONTROL_DISPLAY_TURN_UNDEAD",
    [24] = "LOSS_OF_CONTROL_DISPLAY_HORROR", [27] = "LOSS_OF_CONTROL_DISPLAY_DAZE",
    [30] = "LOSS_OF_CONTROL_DISPLAY_SAP",
}

-- An aura change within EFFECT_FRAME of the cast or its hit is its doing; the
-- look comes EFFECT_SETTLE later, once that frame's events are all in. A hit
-- counts for EFFECT_FLIGHT after its cast.
local EFFECT_FRAME, EFFECT_SETTLE, EFFECT_FLIGHT = 0.05, 0.2, 3
local KEEP = 8
local auraTimes, casts = {}, {}

local function Present(list)
    if not ns.Public(list) then return true end
    return type(list) == "table" and #list > 0
end

-- UNIT_AURA of your target: only the time is kept, and only when something
-- was added or refreshed (a hidden list counts as present).
function ns.NoteTargetAura(info)
    if ns.Public(info) then
        if type(info) ~= "table" then return end
        if not (Present(info.addedAuras) or Present(info.updatedAuraInstanceIDs)) then return end
    end
    auraTimes[#auraTimes + 1] = GetTime()
    while #auraTimes > KEEP do table.remove(auraTimes, 1) end
end

local function AuraNear(at)
    for _, time in ipairs(auraTimes) do
        if math.abs(time - at) <= EFFECT_FRAME then return true end
    end
    return false
end

local function Watch(spell, cast, moment)
    C_Timer.After(EFFECT_SETTLE, function()
        if cast.shown or not AuraNear(moment) then return end
        local word = _G[WORDS[cast.mechanic]]
        local router = ns.liveRouter
        if type(word) ~= "string" or not router then return end
        cast.shown = true
        router:Effect(word, spell)
    end)
end

-- A cast of yours (Reader.lua, OnCast).
function ns.NoteEffectCast(unit, spell, now)
    if unit ~= "player" then return end
    local mechanic = ns.SPELL_MECHANICS and ns.SPELL_MECHANICS[spell]
    if not mechanic or not WORDS[mechanic] then return end
    local cast = { at = now, mechanic = mechanic }
    casts[spell] = cast
    Watch(spell, cast, now)
end

-- A hit shown as yours (Reader.lua, OnYourHit): the hit a flying spell lands
-- with brings its aura. Never a tick, which lands on an aura already there.
-- Nor a hit reported on another enemy's plate: only the target's auras are watched.
function ns.NoteEffectHit(record, at)
    if record.plate then return end
    local result = record.result
    local cast = result and result.who == "you" and casts[result.spell]
    if not cast or cast.shown or result.tick or record.event ~= "damage" then return end
    if at - cast.at > EFFECT_FLIGHT then return end
    Watch(result.spell, cast, at)
end

if CreateFrame and ns.EventAvailable and ns.EventAvailable("UNIT_AURA") then
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_AURA", "target")
    frame:SetScript("OnEvent", function(_, _, _, info) ns.NoteTargetAura(info) end)
end
