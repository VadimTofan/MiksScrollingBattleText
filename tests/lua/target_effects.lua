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
ENCOUNTER_JOURNAL_SECTION_FLAG13 = "Bleed"
dofile("Combat/Effects.lua")
local ns = MikSBT.CombatEngine
local shown = {}
ns.liveRouter = { Effect = function(_, word, spell) shown[#shown + 1] = { word, spell } end }

local FROSTBOLT, RAKE, BANISH, FIREBALL, POLYMORPH = 205, 1822, 710, 143, 118
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
ns.NoteEffectCast("player", RAKE, now)
Aura({ addedAuras = { {} } })
Hit(RAKE)
Advance(0.21)

-- Then the bleed shows once, with the spell it came from.
assert(Shown(1, "Bleed", RAKE), "an effect that landed was not shown once")

-- When the same strike is resisted: no aura comes, one came a second
-- before, or one only goes.
Advance(5)
ns.NoteEffectCast("player", RAKE, now)
Advance(0.21)
Aura({ addedAuras = { {} } })
Advance(1)
ns.NoteEffectCast("player", RAKE, now)
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
ns.NoteEffectCast("player", FROSTBOLT, now)
Advance(1.2)
Aura({ updatedAuraInstanceIDs = { 3 } })
Hit(FROSTBOLT)
Advance(0.21)

-- Then the slow shows with the hit.
assert(Shown(2, "Snared", FROSTBOLT), "a flying spell's effect was not shown at its hit")

-- When the aura list is hidden, as in a fight.
Advance(5)
ns.NoteEffectCast("player", BANISH, now)
Aura(hidden)
Advance(0.21)

-- Then the hidden change counts.
assert(Shown(3, "Banished", BANISH), "a hidden aura change did not count")

-- When the hit comes long after the cast, is someone else's, is a miss, or
-- lands on another enemy while the target's auras change.
Advance(5)
ns.NoteEffectCast("player", FROSTBOLT, now)
Advance(3.5)
Aura({ addedAuras = { {} } })
Hit(FROSTBOLT)
Advance(5)
ns.NoteEffectCast("player", FROSTBOLT, now)
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
ns.NoteEffectCast("player", FIREBALL, now)
ns.NoteEffectCast("pet", RAKE, now)
ns.NoteEffectCast("player", POLYMORPH, now)
Aura({ addedAuras = { {} } })
Advance(0.21)

-- Then nothing shows.
assert(ns.SPELL_MECHANICS[POLYMORPH] == 17 and ns.SPELL_MECHANICS[FIREBALL] == nil)
assert(Shown(3, "Banished", BANISH), "a notice showed with no effect or no word")

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
