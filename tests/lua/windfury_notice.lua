MikSBT = {
    Components = {},
    Compatibility = { Client = { isForever = true } },
}

dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Helpers.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Spells.lua")
dofile("Combat/Healing.lua")
dofile("Combat/Reader.lua")
local Engine = dofile("Components/CombatEngine.lua")
local Presentation = dofile("Components/CombatPresentation.lua")

local now, displayed, batches = 10, {}, {}
GetTime = function() return now end
C_Timer = {
    After = function() end,
    NewTicker = function() return { Cancel = function() end } end,
}
C_EventUtils = { IsEventValid = function() return true end }
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        RegisterUnitEvent = function() end,
        SetScript = function() end,
        UnregisterAllEvents = function() end,
    }
end
UnitExists = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitGUID = function() return nil end
UnitName = function() return nil end
GetLocale = function() return "enUS" end
local names = { [439440] = "Windfury Weapon", [8232] = "Windfury Weapon" }
local icons = { [439440] = "windfury-attack", [8232] = "windfury-imbue" }
C_Spell = {
    GetSpellName = function(spell) return names[spell] end,
    GetSpellTexture = function(spell) return icons[spell] end,
    GetSpellDescription = function() return "Grants extra attacks." end,
    IsSpellHelpful = function() return false end,
}

local profile = { events = {
    NOTIFICATION_PROC = { message = "%sl!", scrollArea = "My notices" },
} }
local presentation = Presentation:New({
    getProfile = function() return profile end,
    batcher = { Queue = function(_, ...) batches[#batches + 1] = { ... } end },
    getSpellTexture = function(spell) return icons[spell] end,
    formatMessage = function(settings, record)
        return (settings.message:gsub("%%sl", record.name or ""))
    end,
    display = function(settings, message, icon)
        displayed[#displayed + 1] = { settings, message, icon }
    end,
})
local engine = Engine:New({
    presentation = presentation,
    log = {
        ConfigureNamespace = function() end,
        IsReady = function() return true end,
    },
    getSaved = function() end,
    setSaved = function() end,
})
local ns = MikSBT.CombatEngine
ns.KeepCombatLog = function() end
engine:Start()

local function Cast(unit, guid, spell)
    engine:HandleEvent("UNIT_SPELLCAST_SUCCEEDED", unit, guid, spell)
end

-- Describe: an explicit player Windfury cast gets a separate proc notice.
-- Given a readable player cast, without an enchant or selected target.
-- When that exact Windfury attack succeeds.
Cast("player", "Cast-windfury-1", 439440)

-- Then the existing proc settings supply the localized notice and icon.
assert(#displayed == 1, "explicit Windfury cast did not display a notice")
assert(displayed[1][1] == profile.events.NOTIFICATION_PROC)
assert(displayed[1][2] == "Windfury Weapon!")
assert(displayed[1][3] == "windfury-attack")
assert(#batches == 0, "Windfury notice fabricated a damage amount")

-- Given an owned unidentified hit after the Windfury notice.
local unknown = { who = "you", procCandidate = true, candidateSpell = 8232 }

-- When the outgoing presentation receives its real amount.
presentation:Out({ event = "damage", amount = 28, school = 1, result = unknown })

-- Then the number stays unnamed and iconless; the notice lends no identity.
assert(#batches == 1 and batches[1][2] == 28)
assert(batches[1][1] == nil and batches[1][4] == nil)
assert(unknown.spell == nil and unknown.procSpell == nil)

-- Describe: UI coalescing is not a fixed proc cooldown or an attack counter.
-- Given a replay of the same cast and another notification in its frame.
-- When duplicate and same-frame cast events arrive.
Cast("player", "Cast-windfury-1", 439440)
Cast("player", "Cast-windfury-2", 439440)
now = 10.05
Cast("player", "Cast-windfury-2", 439440)

-- Then each frame and already-observed cast can produce at most one notice.
assert(#displayed == 1, "duplicate Windfury activity produced extra notices")

-- Given a distinct Windfury cast shortly afterward.
-- When it succeeds within the ordinary proc-glow three-second hold.
Cast("player", "Cast-windfury-3", 439440)

-- Then the new activity remains visible without assuming a game cooldown.
assert(#displayed == 2, "a fixed proc throttle hid distinct Windfury activity")

-- Describe: source, spell identity, and client must all be explicit.
-- Given other actors, the imbue, a bleed, and unrelated cooldown metadata.
local before = #displayed

-- When these signals reach the normal engine.
Cast("pet", "Cast-pet", 439440)
Cast("target", "Cast-target", 439440)
Cast("player", "Cast-imbue", 8232)
Cast("player", "Cast-bleed", 21949)
engine:HandleEvent("SPELL_UPDATE_COOLDOWN", 439440, 439440, 0, 0, nil)
MikSBT.Compatibility.Client.isForever = false
Cast("player", "Cast-retail", 439440)
MikSBT.Compatibility.Client.isForever = true

-- Then none can claim a new Windfury activity notice.
assert(#displayed == before, "unproven Windfury signal displayed a notice")

-- Given unreadable unit, spell, or GUID metadata.
local opaque = setmetatable({}, {
    __eq = function() error("compared secret Windfury metadata") end,
    __tostring = function() error("formatted secret Windfury metadata") end,
})
issecretvalue = function(value) return rawequal(value, opaque) end

-- When hidden identities and a public Windfury cast with hidden GUID arrive.
Cast(opaque, "Cast-unit-hidden", 439440)
Cast("player", "Cast-spell-hidden", opaque)
now = 10.1
Cast("player", opaque, 439440)
Cast("player", opaque, 439440)

-- Then hidden identities are ignored; the public spell can coalesce by frame.
assert(#displayed == before + 1, "secret metadata changed notice ownership")
issecretvalue = nil

-- Describe: existing notification settings and engine lifecycle are retained.
-- Given the proc notification is disabled.
profile.events.NOTIFICATION_PROC.disabled = true
before = #displayed
now = 11

-- When another Windfury cast succeeds.
Cast("player", "Cast-disabled", 439440)

-- Then the notification stays hidden.
assert(#displayed == before, "disabled proc notice was displayed")

-- Given the engine is stopped and notifications are enabled again.
profile.events.NOTIFICATION_PROC.disabled = false
engine:Stop()

-- When a cast arrives while stopped.
Cast("player", "Cast-stopped", 439440)

-- Then it cannot display; restarting clears earlier cast deduplication.
assert(#displayed == before, "stopped engine displayed Windfury")
engine:Start()
Cast("player", "Cast-windfury-1", 439440)
assert(#displayed == before + 1, "restart retained stale Windfury cast state")

-- Given the attack spell has no public name or icon, but the imbue does.
names[439440], icons[439440] = nil, nil
now = 12

-- When the exact player Windfury attack succeeds again.
Cast("player", "Cast-icon-fallback", 439440)

-- Then known imbue metadata supplies presentation only, never a damage ID.
assert(displayed[#displayed][2] == "Windfury Weapon!")
assert(displayed[#displayed][3] == "windfury-imbue")
assert(#batches == 1, "presentation fallback invented damage")
print("Explicit Windfury notice tests passed")
