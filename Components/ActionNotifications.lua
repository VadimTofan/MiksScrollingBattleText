local ActionNotifications = {}
ActionNotifications.__index = ActionNotifications

local MAX_ACTIONS_PER_UPDATE = 5

function ActionNotifications:New(config)
	return setmetatable({ config = config }, self)
end

function ActionNotifications:HandleDelta(spellID, count, _, sourceKey)
	local config = self.config
	if config.isSecret(spellID) or config.isSecret(count)
		or type(count) ~= "number" or count <= 0 or count % 1 ~= 0 then
		return
	end

	local name, _, texture = config.getSpellInfo(spellID)
	if config.isSecret(name) or type(name) ~= "string" then
		name = ""
	end
	if config.isSecret(texture) then texture = nil end

	for index = 1, math.min(count, MAX_ACTIONS_PER_UPDATE) do
		config.emit({
			eventType = config.eventType,
			sourceUnit = sourceKey == "1" and "player" or "pet",
			extraSkillID = spellID,
			extraSkillName = name,
			effectTexture = texture,
		})
	end
end

MikSBT.Components = MikSBT.Components or {}
MikSBT.Components.ActionNotifications = ActionNotifications

return ActionNotifications
