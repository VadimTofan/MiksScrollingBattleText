local frame = {visible = false, scripts = {}, hooks = {}}
function frame:Show() self.visible = true end
function frame:Hide() self.visible = false end
function frame:SetScript(event, handler) self.scripts[event] = handler end
function frame:RegisterEvent() end
CreateFrame = function() return frame end
hooksecurefunc = function(target, method, handler)
	frame.hooks[type(target) == "string" and target or method] = handler or method
end
local context = {frame = frame, now = 10, displayed = {}}
local profile = {
	cooldownThreshold = 1, cooldownExclusions = {}, ignoreCooldownThreshold = {},
	events = {NOTIFICATION_ITEM_COOLDOWN = {
		message = "%e ready", skillColorR = 1, skillColorG = 1, skillColorB = 1,
	}},
}
MikSBT = {
	Components = {}, Profiles = {currentProfile = profile},
	Triggers = {categorizedTriggers = {}},
	Animations = {DisplayEvent = function(_, message)
		context.displayed[#context.displayed + 1] = message
	end},
}
C_Item = {GetItemInfo = function() return "Potion" end}
C_Container = {GetItemCooldown = function() return 10, 5 end}
GetTime = function() return context.now end
GetActionInfo = function() return "item", 123 end
UNKNOWN = "Unknown"
dofile("Components/ItemCooldownTracker.lua")
dofile("MSBTCooldowns.lua")
context.module = MikSBT.Cooldowns
return context
