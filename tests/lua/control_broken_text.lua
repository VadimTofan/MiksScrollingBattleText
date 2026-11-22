-- Describe: the notice for crowd control a hit of yours broke is told in the locale's words.
MikSBT = { Components = {}, Services = {}, translations = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local names = {}
local profile = { events = {
	NOTIFICATION_CROWD_CONTROL = { message = "%sl", scrollArea = "Notification" },
	OUTGOING_DISPEL = { message = "%sl", scrollArea = "Outgoing" },
} }
local presentation = Presentation:New({
	getProfile = function() return profile end,
	batcher = { Queue = function() end },
	getSpellTexture = function(id) return "icon-" .. id end,
	formatMessage = function(_, record)
		names[#names + 1] = record.name
		return record.name
	end,
	display = function() end,
	displayRestricted = function() end,
})
-- The reader's records, as it hands them over.
local function Broke() presentation:Alert({ kind = "broke", text = "Broke crowd control", icon = 1 }) end

-- Rule: where the locale has no text for it, the reader's own words are shown.
do
	Broke()
	assert(names[1] == "Broke crowd control", "the reader's words are not shown: " .. tostring(names[1]))
end

-- Rule: the locale's text replaces the reader's words for broken crowd control, and for nothing else.
do
	MikSBT.translations.MSG_CONTROL_BROKEN = "Its own words"
	Broke()
	assert(names[2] == "Its own words", "the locale's words are not shown: " .. tostring(names[2]))
	presentation:Alert({ kind = "dispel", text = "Purged", icon = 1 })
	assert(names[3] == "Purged", "a dispel took the words of broken crowd control")
	presentation:Alert({ kind = "cc", text = "Stunned", icon = 1 })
	assert(names[4] == "Stunned", "crowd control on you took the words of broken crowd control")
end

-- Rule: English keeps the reader's words, and German says what happened in German.
do
	local function Load(path)
		local file = assert(io.open(path, "rb"))
		local source = file:read("*a"):gsub("^\239\187\191", "")
		file:close()
		assert(loadstring(source, "@" .. path))()
	end
	MikSBT.translations, MikSBT.COMMAND = {}, "/msbt"
	GetLocale = function() return "deDE" end
	Load("Localization/localization.lua")
	assert(MikSBT.translations.MSG_CONTROL_BROKEN == "Broke crowd control", "the English text differs from the reader's words")
	Load("Localization/localization.de.lua")
	Broke()
	assert(names[5] == "Kontrolleffekt gebrochen", "the German text is not shown: " .. tostring(names[5]))
end
print("control broken text OK")
