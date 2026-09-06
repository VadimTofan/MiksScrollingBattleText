MikSBT = { API = {}, Configuration = {}, translations = { FONT_FILES = {} } }
local secret = {}
canaccessvalue = function(value) return value ~= secret end
dofile("API/RestrictedValue.lua")

-- Given shared media and saved registrations from an earlier release.
local shared = { font = {}, sound = { Shared = 12345 } }
local callback
local library = {}
function library:Register(kind, name, path)
	if shared[kind][name] then return false end
	shared[kind][name] = path
	if callback then callback(nil, kind, name) end
	return true
end
function library:List(kind)
	local names = {}
	for name in pairs(shared[kind]) do names[#names + 1] = name end
	return names
end
function library:Fetch(kind, name) return shared[kind][name] end
function library.RegisterCallback(receiver, event, handler)
	assert(receiver ~= library, "callback must use the registry receiver")
	callback = handler
end
LibStub = function() return library end
MikSBT.Profiles = { savedMedia = {
	sounds = { Bell = "Interface\\AddOns\\MySounds\\bell.ogg", Broken = {} },
} }
local calls = {}
PlaySoundFile = function(file, channel)
	calls[#calls + 1] = { file, channel }
	return true, 77
end

-- When media initializes and saved settings load.
dofile("API/Sounds.lua")
dofile("Configuration/MediaRegistry.lua")
dofile("MSBTMedia.lua")
local media = MikSBT.Media
media.OnVariablesInitialized()

-- Then old registrations and shared-media sounds are available.
assert(media.sounds.Bell == "Interface\\AddOns\\MySounds\\bell.ogg")
assert(media.sounds.Shared == 12345)
assert(media.sounds.Broken == nil)
assert(media.PlaySound("Bell"))
assert(calls[1][1] == media.sounds.Bell and calls[1][2] == "Master")
library:Register("sound", "Late", "Interface\\AddOns\\Other\\late.mp3")
assert(media.sounds.Late == shared.sound.Late)
assert(media.RegisterSound("Local", "local.OGG"))
assert(media.sounds.Local == "Interface\\AddOns\\MikScrollingBattleText\\Sounds\\local.OGG")
assert(not media.RegisterSound("Local", "replacement.ogg"))
assert(not media.RegisterSound("Bad", {}))
assert(not media.RegisterSound("", "valid.ogg"))
assert(not media.RegisterSound("None", "valid.ogg"))
local found = {}
for name, file in media.IterateSounds() do found[name] = file end
assert(found.Bell == media.sounds.Bell and found.Late == shared.sound.Late)

-- Given legacy direct paths and file IDs as event selections.
-- When they are played without registration.
assert(media.PlaySound("direct.mp3"))
assert(media.PlaySound("Interface/AddOns/MySounds/direct.ogg"))
assert(media.PlaySound(9876))
assert(media.PlaySound("9876"))

-- Then path normalization and numeric IDs retain their meaning.
assert(calls[2][1] == "Interface\\AddOns\\MikScrollingBattleText\\Sounds\\direct.mp3")
assert(calls[3][1] == "Interface\\AddOns\\MySounds\\direct.ogg")
assert(calls[4][1] == 9876 and calls[5][1] == 9876)

-- Given malformed inputs or inaccessible values.
-- When attempting playback or registration.
for _, value in ipairs({ false, {}, secret, "", "None", "missing name",
	"../outside.ogg", "C:\\sound.ogg", "Interface\\bad.ogg.exe", 0, -1, 1.5 }) do
	assert(not media.PlaySound(value))
end
assert(not media.RegisterSound(secret, "valid.ogg"))
assert(not media.RegisterSound("Secret", secret))

-- Then invalid values never reach the client sound API.
assert(#calls == 5)

-- Given a missing file or a client API failure.
-- When playback is attempted.
PlaySoundFile = function() return false end
assert(not media.PlaySound("Bell"))
PlaySoundFile = function() error("playback unavailable") end
assert(not media.PlaySound("Bell"))
PlaySoundFile = function() return secret end
assert(not media.PlaySound("Bell"))

-- Then bad saved data also cannot prevent addon initialization.
MikSBT.Profiles.savedMedia.sounds = "malformed"
media.OnVariablesInitialized()
