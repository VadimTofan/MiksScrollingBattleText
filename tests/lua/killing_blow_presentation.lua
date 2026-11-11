-- Describe: unclassified killing blows share NPC controls, separate from PvP.
MikSBT = { API = {}, Components = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local events = {
	NOTIFICATION_PC_KILLING_BLOW = { message = "Player kill", soundFile = "pc" },
	NOTIFICATION_NPC_KILLING_BLOW = { message = "NPC kill", soundFile = "npc" },
	-- A stale separate setting must never override the current NPC toggle.
	NOTIFICATION_KILLING_BLOW = { message = "Old generic", soundFile = "unknown" },
}
local shown = {}
local presentation = Presentation:New({
	getProfile = function() return { events = events } end,
	formatMessage = function(settings) return settings.message end,
	display = function(settings, message, icon)
		shown[#shown + 1] = { settings, message, icon }
	end,
})

-- Given independently customized player and NPC notification settings.
-- When each type of killing blow is received.
presentation:Alert({ kind = "kill", victimIsPlayer = true, icon = 101 })
presentation:Alert({ kind = "kill", victimIsPlayer = false, icon = 102 })
presentation:Alert({ kind = "kill", icon = 103 })
-- Then unknown victims share the NPC style, message, sound and toggle.
assert(shown[1][1] == events.NOTIFICATION_PC_KILLING_BLOW,
	"player kill was routed through NPC settings")
assert(shown[2][1] == events.NOTIFICATION_NPC_KILLING_BLOW)
assert(shown[3][1] == events.NOTIFICATION_NPC_KILLING_BLOW,
	"unclassified kill did not use NPC settings")
assert(shown[1][2] == "Player kill" and shown[1][3] == 101)
assert(shown[3][2] == "NPC kill" and shown[3][3] == 103)

-- Given NPC alerts are disabled while PvP alerts remain enabled.
events.NOTIFICATION_NPC_KILLING_BLOW.disabled = true
-- When both types and a delayed melee fallback arrive.
presentation:Alert({ kind = "kill", victimIsPlayer = false })
presentation:Alert({ kind = "kill" })
presentation:Out({ event = "killed", result = { who = "you" } })
presentation:Alert({ kind = "kill", victimIsPlayer = true })
presentation:Out({ event = "killed", victimIsPlayer = true,
	result = { who = "you" } })
-- Then NPC and unknown kills stay hidden while both PvP paths use player settings.
assert(#shown == 5 and shown[4][1] == events.NOTIFICATION_PC_KILLING_BLOW)
assert(shown[5][1] == events.NOTIFICATION_PC_KILLING_BLOW)

-- Given a restricted victim type and disabled NPC notifications.
local secret = {}
issecretvalue = function(value) return value == secret end
-- When an unidentifiable killing blow arrives.
presentation:Alert({ kind = "kill", victimIsPlayer = secret })
-- Then it follows the NPC toggle without inspecting or guessing the type.
assert(#shown == 5)

-- Given NPC alerts are enabled while player alerts are disabled.
events.NOTIFICATION_NPC_KILLING_BLOW.disabled = nil
events.NOTIFICATION_PC_KILLING_BLOW.disabled = true
-- When a known player kill and an unknown victim arrive.
presentation:Alert({ kind = "kill", victimIsPlayer = true })
presentation:Alert({ kind = "kill", victimIsPlayer = secret })
-- Then only the unknown victim appears, using the NPC sound and style.
assert(#shown == 6 and shown[6][1] == events.NOTIFICATION_NPC_KILLING_BLOW)
print("Killing-blow presentation tests passed")
