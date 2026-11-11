-- Describe: killing blows use independently controlled event categories.
MikSBT = { API = {}, Components = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local events = {
	NOTIFICATION_PC_KILLING_BLOW = { message = "Player kill", soundFile = "pc" },
	NOTIFICATION_NPC_KILLING_BLOW = { message = "NPC kill", soundFile = "npc" },
	NOTIFICATION_KILLING_BLOW = { message = "Killing Blow!", soundFile = "unknown" },
}
local shown = {}
local presentation = Presentation:New({
	getProfile = function() return { events = events } end,
	formatMessage = function(settings) return settings.message end,
	display = function(settings, message, icon)
		shown[#shown + 1] = { settings, message, icon }
	end,
})

-- Given separate customized player, NPC and generic notification settings.
-- When each type of killing blow is received.
presentation:Alert({ kind = "kill", victimIsPlayer = true, icon = 101 })
presentation:Alert({ kind = "kill", victimIsPlayer = false, icon = 102 })
presentation:Alert({ kind = "kill", icon = 103 })
-- Then each reaches its own style, message, sound and icon.
assert(shown[1][1] == events.NOTIFICATION_PC_KILLING_BLOW,
	"player kill was routed through NPC settings")
assert(shown[2][1] == events.NOTIFICATION_NPC_KILLING_BLOW)
assert(shown[3][1] == events.NOTIFICATION_KILLING_BLOW)
assert(shown[1][2] == "Player kill" and shown[1][3] == 101)
assert(shown[3][2] == "Killing Blow!")

-- Given NPC alerts are disabled while PvP alerts remain enabled.
events.NOTIFICATION_NPC_KILLING_BLOW.disabled = true
-- When both types and a delayed melee fallback arrive.
presentation:Alert({ kind = "kill", victimIsPlayer = false })
presentation:Alert({ kind = "kill", victimIsPlayer = true })
presentation:Out({ event = "killed", victimIsPlayer = true,
	result = { who = "you" } })
-- Then NPC kills stay hidden while both PvP paths use player settings.
assert(#shown == 5 and shown[4][1] == events.NOTIFICATION_PC_KILLING_BLOW)
assert(shown[5][1] == events.NOTIFICATION_PC_KILLING_BLOW)

-- Given a restricted victim type and disabled generic notifications.
local secret = {}
issecretvalue = function(value) return value == secret end
events.NOTIFICATION_KILLING_BLOW.disabled = true
-- When an unidentifiable killing blow arrives.
presentation:Alert({ kind = "kill", victimIsPlayer = secret })
-- Then it follows the generic toggle without inspecting or guessing the type.
assert(#shown == 5)
print("Killing-blow presentation tests passed")
