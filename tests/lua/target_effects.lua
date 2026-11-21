-- Describe: what a spell of yours did to your target shows in the game's word.
MikSBT = { Components = {}, Services = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
dofile("Combat/Context.lua")
dofile("Combat/SpellMechanics.lua")
local now, timers, frame = 100, {}, nil
GetTime = function() return now end
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { at = now + delay, callback = callback }
end }
C_EventUtils = { IsEventValid = function() return true end }
CreateFrame = function()
    frame = {}
    function frame:RegisterUnitEvent(event, unit) self.event, self.unit = event, unit end
    function frame:SetScript(_, callback) self.callback = callback end
    return frame
end
local hidden = {}
issecretvalue = function(value) return value == hidden end
LOSS_OF_CONTROL_DISPLAY_SNARE, LOSS_OF_CONTROL_DISPLAY_BANISH = "Snared", "Banished"
LOSS_OF_CONTROL_DISPLAY_ROOT, ENCOUNTER_JOURNAL_SECTION_FLAG13 = "Rooted", "Bleed"
dofile("Combat/Effects.lua")
local ns = MikSBT.CombatEngine
local shown = {}
ns.liveRouter = { Effect = function(_, word, spell) shown[#shown + 1] = { word, spell } end }
-- The reader's key for your target and its count of the targets you
-- selected (Reader.lua): selecting another starts a new count.
local target = "nameplate1:1"
ns.reader = { epoch = 1 }
ns.TargetKey = function() return target end
local function Select(key)
    target = key
    ns.reader.epoch = ns.reader.epoch + 1
end

local FROSTBOLT, RAKE, BANISH, FIREBALL, POLYMORPH = 205, 1822, 710, 143, 118
local FROST_NOVA, RIP, MARK_OF_THE_WILD = 122, 1079, 1126
local function Advance(seconds)
    now = now + seconds
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
    end
end
local function Aura(info) frame.callback(frame, "UNIT_AURA", "target", info) end
local function Hit(spell, extra)
    local result = { who = "you", spell = spell }
    for field, value in pairs(extra or {}) do result[field] = value end
    ns.NoteEffectHit({ event = "damage", result = result }, now)
end
local function Shown(count, word, spell)
    return #shown == count and (count == 0 or (shown[count][1] == word and shown[count][2] == spell))
end

-- Given the module watches the target's auras.
assert(frame and frame.event == "UNIT_AURA" and frame.unit == "target")

-- When a strike that makes its target bleed lands with an aura and its own
-- hit in its frame.
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ addedAuras = { {} } })
Hit(RAKE)
Advance(0.21)

-- Then the bleed shows once, with the spell it came from.
assert(Shown(1, "Bleed", RAKE), "an effect that landed was not shown once")

-- When the same strike is resisted: no aura comes, one came a second
-- before, or one only goes.
Advance(5)
ns.NoteEffectCast("player", RAKE, now, target)
Advance(0.21)
Aura({ addedAuras = { {} } })
Advance(1)
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ removedAuraInstanceIDs = { 7 } })
Aura({ isFullUpdate = true })
Advance(0.21)

-- Then nothing shows.
assert(Shown(1, "Bleed", RAKE), "an effect showed with no aura added in its frame")

-- When a tick of an older bleed comes with an aura change after that cast.
Advance(1)
Aura({ updatedAuraInstanceIDs = { 3 } })
Hit(RAKE, { tick = true })
Advance(0.21)

-- Then the tick does not stand for the cast.
assert(Shown(1, "Bleed", RAKE), "a tick showed an effect")

-- When a bolt flies: no aura at its cast, one in the frame of its hit.
Advance(5)
ns.NoteEffectCast("player", FROSTBOLT, now, target)
Advance(1.2)
Aura({ updatedAuraInstanceIDs = { 3 } })
Hit(FROSTBOLT)
Advance(0.21)

-- Then the slow shows with the hit.
assert(Shown(2, "Snared", FROSTBOLT), "a flying spell's effect was not shown at its hit")

-- When the aura list is hidden, as in a fight.
Advance(5)
ns.NoteEffectCast("player", BANISH, now, target)
Aura(hidden)
Advance(0.21)

-- Then the hidden change counts.
assert(Shown(3, "Banished", BANISH), "a hidden aura change did not count")

-- When the hit comes long after the cast, is someone else's, is a miss, or
-- lands on another enemy while the target's auras change.
Advance(5)
ns.NoteEffectCast("player", FROSTBOLT, now, target)
Advance(3.5)
Aura({ addedAuras = { {} } })
Hit(FROSTBOLT)
Advance(5)
ns.NoteEffectCast("player", FROSTBOLT, now, target)
Advance(1)
Aura({ addedAuras = { {} } })
Hit(FROSTBOLT, { who = "other" })
ns.NoteEffectHit({ event = "miss", result = { who = "you", spell = FROSTBOLT } }, now)
ns.NoteEffectHit({ event = "damage", plate = "nameplate2", result = { who = "you", spell = FROSTBOLT } }, now)
Advance(0.21)

-- Then none of them shows the effect.
assert(Shown(3, "Banished", BANISH), "an effect showed for a hit that is not the cast's")

-- When a spell with no effect of its own, a pet's cast, or an effect the
-- client has no word for comes with an aura.
Advance(5)
ns.NoteEffectCast("player", FIREBALL, now, target)
ns.NoteEffectCast("pet", RAKE, now, target)
ns.NoteEffectCast("player", POLYMORPH, now, target)
Aura({ addedAuras = { {} } })
Advance(0.21)

-- Then nothing shows.
assert(ns.SPELL_MECHANICS[POLYMORPH] == 17 and ns.SPELL_MECHANICS[FIREBALL] == nil)
assert(Shown(3, "Banished", BANISH), "a notice showed with no effect or no word")

-- When an aura comes on your target, and you select another and cast at it
-- in the same frame.
Advance(5)
Aura({ addedAuras = { {} } })
Select("nameplate2:2")
ns.NoteEffectCast("player", FROSTBOLT, now, target)
Advance(0.21)

-- Then the aura on the target before does not stand for the cast.
assert(Shown(3, "Banished", BANISH), "an aura on the previous target confirmed a cast at the next")

-- When a strike at your target comes with an aura, and you select another
-- target before the look.
Advance(5)
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ addedAuras = { {} } })
Advance(0.1)
Select("nameplate3:3")
Advance(0.11)

-- Then it is dropped with the target it was watched on.
assert(Shown(3, "Banished", BANISH), "a cast watched on the previous target showed")

-- When a cast goes to another unit than your target (your focus), or to one
-- the reader cannot name (two units of one name), or one with no target
-- comes while you have yourself targeted, with an aura change on your target
-- in its frame.
Advance(5)
ns.NoteEffectCast("player", BANISH, now, "nameplate4:4")
ns.NoteEffectCast("player", RAKE, now, nil)
Aura({ addedAuras = { {} } })
Advance(5)
Select(nil)
ns.NoteEffectCast("player", FROST_NOVA, now, nil)
Aura({ addedAuras = { {} } })
Advance(0.21)

-- Then nothing shows: only your target's auras are seen.
assert(Shown(3, "Banished", BANISH), "a cast at a unit other than your target showed")

-- When a strike's frame adds an aura that reads as someone else's buff (a
-- party member's Mark of the Wild), or only as not harmful, from another
-- unit, not from you or your pet, or of spells that do something else.
Select("nameplate5:5")
Advance(5)
for _, aura in ipairs({
    { spellId = MARK_OF_THE_WILD, isHarmful = false, sourceUnit = "party1" },
    { isHarmful = false }, { sourceUnit = "party1" }, { isFromPlayerOrPlayerPet = false },
}) do
    ns.NoteEffectCast("player", RAKE, now, target)
    Aura({ addedAuras = { aura } })
    Advance(1)
end
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ addedAuras = { { spellId = FROSTBOLT }, { spellId = MARK_OF_THE_WILD } } })
Advance(0.21)

-- Then nothing shows.
assert(Shown(3, "Banished", BANISH), "a readable aura that is not the strike's confirmed it")

-- When an aura in the strike's frame reads as its own beside someone
-- else's, as another bleed from your pet, or is hidden beside someone else's.
Advance(5)
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ addedAuras = { { spellId = MARK_OF_THE_WILD, isHarmful = false },
    { spellId = RAKE, isHarmful = true, sourceUnit = "player", isFromPlayerOrPlayerPet = true } } })
Advance(0.21)
assert(Shown(4, "Bleed", RAKE), "the strike's own aura did not confirm it")
Advance(5)
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ addedAuras = { { spellId = RIP, sourceUnit = "pet" } } })
Advance(0.21)
assert(Shown(5, "Bleed", RAKE), "an aura of the same effect from your pet did not confirm it")
Advance(5)
ns.NoteEffectCast("player", RAKE, now, target)
Aura({ addedAuras = { { sourceUnit = "party1" }, hidden } })
Advance(0.21)

-- Then the bleed shows each time.
assert(Shown(6, "Bleed", RAKE), "a hidden aura beside someone else's did not count")

-- When a bolt hits with a refreshed aura that the client lets you look up and
-- that reads as someone else's, then with one whose look-up is refused.
C_UnitAuras = { GetAuraDataByAuraInstanceID = function(unit, id)
    assert(unit == "target")
    if id == 9 then return { spellId = MARK_OF_THE_WILD, isHarmful = false, sourceUnit = "party1" } end
    error("Auras cannot be accessed when secret while tainted")
end }
Advance(5)
ns.NoteEffectCast("player", FROSTBOLT, now, target)
Advance(1)
Aura({ updatedAuraInstanceIDs = { 9 } })
Hit(FROSTBOLT)
Advance(0.21)
assert(Shown(6, "Bleed", RAKE), "a refreshed aura that reads as someone else's confirmed a hit")
Aura({ updatedAuraInstanceIDs = { 10 } })
Hit(FROSTBOLT)
Advance(0.21)
C_UnitAuras = nil

-- Then only the one the client hides stands for the slow.
assert(Shown(7, "Snared", FROSTBOLT), "a refreshed aura the client hides did not count")

-- When a fight hides only the list of added auras, then of refreshed ones.
Advance(5)
ns.NoteEffectCast("player", BANISH, now, target)
Aura({ addedAuras = hidden })
Advance(0.21)
assert(Shown(8, "Banished", BANISH), "a hidden list of added auras did not count")
Advance(5)
ns.NoteEffectCast("player", BANISH, now, target)
Aura({ updatedAuraInstanceIDs = hidden })
Advance(0.21)

-- Then each counts.
assert(Shown(9, "Banished", BANISH), "a hidden list of refreshed auras did not count")

-- Given the display with settings for the notice.
local displayed = {}
local profile = { events = { OUTGOING_EFFECT = { message = "<%sl>", scrollArea = "My outgoing" } } }
local presentation = Presentation:New({
    getProfile = function() return profile end,
    getSpellTexture = function(id) return "icon-" .. id end,
    formatMessage = function(_, record) return record.name end,
    display = function(...) displayed[#displayed + 1] = { ... } end,
})

-- When an effect reaches it.
presentation:Effect("Snared", FROSTBOLT)

-- Then the word scrolls with the spell's icon under the effect's settings.
assert(displayed[1][1] == profile.events.OUTGOING_EFFECT)
assert(displayed[1][2] == "Snared" and displayed[1][3] == "icon-205")
