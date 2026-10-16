MikSBT = { Components = {}, Services = {} }
local handlers = {}
local events = {}
local frame = {
	SetScript = function() end,
	RegisterEvent = function(_, event) events[event] = true end,
	UnregisterAllEvents = function() events = {} end,
}
CreateFrame = function() return frame end
local auraName = "Readable Aura"
local secret = {}
issecretvalue = function(value) return value == secret end
C_CombatText = {
	GetCurrentEventInfo = function() return auraName end,
	GetActiveUnit = function() return "player" end,
}
local routes = dofile("Services/CombatRoutes.lua")
routes:Register({ Register = function(_, name, handler)
	handlers[name] = handler
end }, { autoAttackSpellID = 6603 })
local emitted = {}
local Source = dofile("Components/CombatTextSource.lua")
local source = Source:New({ emit = function(event)
	emitted[#emitted + 1] = event
end })

-- Given an available source and readable aura information.
source:Start()

-- When the player gains and loses an aura.
source:HandleEvent("SPELL_AURA_START")
source:HandleEvent("SPELL_AURA_END_HARMFUL")

-- Then the events route to the existing notification settings.
assert(events.COMBAT_TEXT_UPDATE, "source was not registered")
assert(#emitted == 2, "aura events were lost")
assert(handlers.aura(emitted[1]) == "NOTIFICATION_BUFF")
assert(handlers.aura(emitted[2]) == "NOTIFICATION_DEBUFF_FADE")

-- Given restricted information or a different active combat text unit.
auraName = secret
source:HandleEvent("SPELL_AURA_START")
C_CombatText.GetActiveUnit = function() return "pet" end
auraName = "Pet Aura"
source:HandleEvent("SPELL_AURA_START")

-- Then restricted or non-player auras do not become player notifications.
assert(#emitted == 2, "restricted or pet aura was emitted")

-- When the source stops.
source:Stop()

-- Then its event registration is removed.
assert(next(events) == nil, "source retained events after stopping")
