local AuraTracking = {}
local RestrictedValue = MikSBT.API.RestrictedValue
local Spells = MikSBT.API.Spells
local STYLE_FIELDS = {
	"message", "colorR", "colorG", "colorB", "fontName", "fontSize",
	"fontAlpha", "outlineIndex", "scrollArea", "soundFile", "alwaysSticky",
}

local function SpellKey(value)
	local id = RestrictedValue:Number(value)
	if id and id > 0 and id <= 2147483647 and id == math.floor(id) then
		return tostring(id)
	end
end

local function NameKey(spellID, name)
	name = RestrictedValue:String(name)
	if not name then
		local id = SpellKey(spellID)
		local info = id and Spells:GetInfo(tonumber(id))
		name = info and info.name
	end
	if name and name ~= "" then return "name:" .. name end
end

function AuraTracking:Resolve(input)
	if type(input) ~= "string" then return end
	input = input:match("^%s*(.-)%s*$")
	if input == "" then return end
	local number = tonumber(input)
	local info = Spells:GetInfo(number or input)
	if not info then return end
	if number then return SpellKey(number) end
	return NameKey(nil, info.name)
end

function AuraTracking:ShouldShow(rules, spellID, name)
	if type(rules) ~= "table" then return true end
	local key = SpellKey(spellID)
	if key and rules[key] == false then return false end
	local named = NameKey(spellID, name)
	return not named or rules[named] ~= false
end

function AuraTracking:FindID(rules, spellID, name)
	if type(rules) ~= "table" then return end
	local key = SpellKey(spellID)
	if key and rules[key] ~= nil then return key end
	local named = NameKey(spellID, name)
	if named and rules[named] ~= nil then return named end
end

function AuraTracking:GetSettings(profile, id, eventKey)
	local base = profile.events[eventKey or "NOTIFICATION_BUFF"]
	local overrides = profile.auraSettings and profile.auraSettings[id]
	if not base or type(overrides) ~= "table" then return base end
	local settings = setmetatable({}, { __index = base })
	for _, field in ipairs(STYLE_FIELDS) do
		if overrides[field] ~= nil then settings[field] = overrides[field] end
	end
	return settings
end

MikSBT.Configuration.AuraTracking = AuraTracking
return AuraTracking
