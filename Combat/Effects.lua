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
-- or dodged cast changes no aura and shows nothing. Where the client hides
-- the aura, only the moment is seen: another aura changing on the target in
-- that frame counts as well (predicted, not yet seen in client). Where it
-- shows the aura, one that reads as not harmful, not from you or your pet,
-- or as a spell that does something else is not the cast's. A moment and a
-- cast count only for the target they came on: a cast at another unit, or at
-- one the reader cannot name, is not watched, and selecting another target
-- drops what was seen and what waits.

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
local moments, casts = {}, {}

-- Which target you had: the reader counts every one you select (Reader.lua).
local function Epoch() return ns.reader and ns.reader.epoch end

-- What an aura added or refreshed on your target could be: nil when it reads
-- as someone else's (not harmful, not from you or your pet) or as a spell
-- with another effect or none, true when nothing readable tells, else the
-- effect of its spell.
local function Effect(aura)
    if not ns.Public(aura) or type(aura) ~= "table" then return true end
    local harmful, mine, source = aura.isHarmful, aura.isFromPlayerOrPlayerPet, aura.sourceUnit
    if (ns.Bool(harmful) and not harmful) or (ns.Bool(mine) and not mine)
        or (ns.Text(source) and source ~= "player" and source ~= "pet") then return nil end
    local spell = aura.spellId
    if not ns.Number(spell, 1) then return true end
    return ns.SPELL_MECHANICS and ns.SPELL_MECHANICS[spell]
end

-- A refreshed aura comes as its id; a refused look-up hides it.
local function Refreshed(id)
    local lookup = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if not lookup or not ns.Number(id) then return true end
    local ok, aura = pcall(lookup, "target", id)
    if not ok then return true end
    return Effect(aura)
end

-- mark.any: any effect could be yours; mark[mechanic]: that one could.
local function Count(mark, effect)
    if effect == true then mark.any = true elseif effect then mark[effect] = true end
end

-- UNIT_AURA of your target: the moment, the target it came on and what the
-- auras added or refreshed could be, kept when one could be yours (a hidden
-- list could hold anything).
function ns.NoteTargetAura(info)
    local mark = {}
    if not ns.Public(info) then
        mark.any = true
    elseif type(info) == "table" then
        local added, refreshed = info.addedAuras, info.updatedAuraInstanceIDs
        if not ns.Public(added) then
            mark.any = true
        elseif type(added) == "table" then
            for _, aura in ipairs(added) do Count(mark, Effect(aura)) end
        end
        if not ns.Public(refreshed) then
            mark.any = true
        elseif type(refreshed) == "table" then
            for _, id in ipairs(refreshed) do Count(mark, Refreshed(id)) end
        end
    end
    if next(mark) == nil then return end
    mark.at, mark.epoch = GetTime(), Epoch()
    moments[#moments + 1] = mark
    while #moments > KEEP do table.remove(moments, 1) end
end

local function AuraNear(cast, at)
    for _, mark in ipairs(moments) do
        if mark.epoch == cast.epoch and math.abs(mark.at - at) <= EFFECT_FRAME
            and (mark.any or mark[cast.mechanic]) then return true end
    end
    return false
end

local function Watch(spell, cast, moment)
    C_Timer.After(EFFECT_SETTLE, function()
        -- Dropped once you have selected another target since.
        if cast.shown or cast.epoch ~= Epoch() or not AuraNear(cast, moment) then return end
        local word = _G[WORDS[cast.mechanic]]
        local router = ns.liveRouter
        if type(word) ~= "string" or not router then return end
        cast.shown = true
        router:Effect(word, spell)
    end)
end

-- A cast of yours (Reader.lua, OnCast) and the key of the unit it went to,
-- nil when the reader cannot tell. Only your target's auras are seen: a cast
-- at another unit, or at one unknown, is not watched.
function ns.NoteEffectCast(unit, spell, now, key)
    if unit ~= "player" then return end
    local mechanic = ns.SPELL_MECHANICS and ns.SPELL_MECHANICS[spell]
    if not mechanic or not WORDS[mechanic] then return end
    if key == nil or key ~= ns.TargetKey() then return end
    local cast = { at = now, mechanic = mechanic, epoch = Epoch() }
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
