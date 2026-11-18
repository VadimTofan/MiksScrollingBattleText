-- Describe: the client's settings for effects on targets and for reputation and honor at the
-- character are read and written through their switches, and the texts of their boxes are in both
-- languages.
local file = assert(io.open("MSBTProfiles.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match(
    "(local BLIZZARD_SWITCH_SETTINGS.-)local function SetAddonEnabled"))
local build = assert(loadstring(body ..
    "\nreturn GetSpellMechanicsText, SetSpellMechanicsText, GetBlizzardSwitch, SetBlizzardSwitch,"
    .. " SetBlizzardCombatTextV2Enabled, TakeBlizzardSwitches, RestoreBlizzardSwitches"))
assert(source:find("module.GetSpellMechanicsText", 1, true), "Get is not exported")
assert(source:find("module.SetSpellMechanicsText", 1, true), "Set is not exported")

local OWN = "floatingCombatTextSpellMechanics_v2"
local OTHERS = "floatingCombatTextSpellMechanicsOther_v2"
local REPUTATION = "floatingCombatTextRepChanges_v2"
local HONOR = "floatingCombatTextHonorGains_v2"
local cvars, writes = {}, {}
local profile = { blizzardSwitches = { version = 1 } }
local function Written(name)
    for _, write in ipairs(writes) do
        if write:match("^[^=]+") == name then return true end
    end
    return false
end
local env = {
    GetCVar = function(name) return cvars[name] end,
    GetCVarBool = function(name) return cvars[name] == "1" end,
    SetCVar = function(name, value)
        assert(name, "an unknown setting was written")
        writes[#writes + 1] = name .. "=" .. tostring(value)
        cvars[name] = tostring(value)
    end,
    -- The settings are not secure: a block on writing in combat would show here.
    InCombatLockdown = function() error("combat state must not matter") end,
    Client = { hasModernAPI = true }, IsClassic = false,
    CombatText = { Hide = function() end, Show = function() end },
    currentProfile = profile,
    pairs = pairs, ipairs = ipairs, tostring = tostring, type = type, pcall = pcall,
}
setfenv(build, env)
local getEffects, setEffects, get, set, apply, take, restore = build()

-- Given the client has both settings, one on and one off, and the profile has set neither.
cvars[OWN], cvars[OTHERS] = "1", "0"
-- When they are read.
local own, others = getEffects()
-- Then each is the client's value as a boolean.
assert(own == true and others == false, "read of the two settings")

-- Given the client changed a setting elsewhere, such as in Blizzard's menu.
cvars[OTHERS] = "1"
-- When they are read again.
own, others = getEffects()
-- Then the current state shows.
assert(own == true and others == true, "the client's current state does not show")

-- Given the client lacks the setting for other players' targets.
cvars[OTHERS] = nil
-- When they are read.
own, others = getEffects()
-- Then it is nil, not false.
assert(own == true and others == nil, "a missing setting is not nil")
cvars[OTHERS] = "1"

-- When a setting is switched on and off.
setEffects("own", false)
setEffects("others", false)
setEffects("own", true)
-- Then each is written at once as "1" or "0", in or out of combat, and kept in the profile.
assert(table.concat(writes, ",") == OWN .. "=0," .. OTHERS .. "=0," .. OWN .. "=1",
    "a setting is not written at once as 1 or 0")
assert(profile.blizzardSwitches.effectsOwn == 1 and profile.blizzardSwitches.effectsOthers == 0,
    "a setting is not kept in the profile")
assert(select(1, getEffects()) == true, "the value written is not read back")

-- Given a change made in Blizzard's menu after the last write of MSBT.
cvars[OWN] = "0"
-- When the settings are read.
-- Then the profile's value shows, as MSBT writes it again when it applies its settings.
assert(select(1, getEffects()) == true, "the profile's value does not show")

-- When an unknown setting is asked for.
writes = {}
setEffects("elsewhere", true)
-- Then nothing is written.
assert(#writes == 0, "an unknown setting was written")

-- Describe: the reputation and honor switches follow the same rule.
-- Given a new profile and a client with the reputation text on and the honor text off.
local inCombat = false
env.InCombatLockdown = function() return inCombat end
local texts = { blizzardSwitches = { version = 1 } }
env.currentProfile = texts
cvars[OWN], cvars[OTHERS], cvars[REPUTATION], cvars[HONOR] = "1", "1", "1", "0"
writes = {}
-- When MSBT applies its settings and they are read.
apply(true, true, texts)
-- Then neither is written, and each shows the client's value and is not set.
assert(not Written(REPUTATION) and not Written(HONOR), "an unset text switch was written")
local isShown, isSet = get("reputation")
assert(isShown == true and isSet == false, "an unset reputation switch does not mirror the client")
isShown, isSet = get("honor")
assert(isShown == false and isSet == false, "an unset honor switch does not mirror the client")
-- Given the client changes the honor text elsewhere.
cvars[HONOR] = "1"
-- When the switch is read, then it follows the client.
assert(get("honor") == true, "an unset honor switch does not follow the client")
cvars[HONOR] = "0"

-- When honor is shown in combat.
inCombat = true
set("honor", true)
inCombat = false
-- Then the profile keeps it as 1 and only its own setting is written, at once.
assert(texts.blizzardSwitches.honor == 1 and cvars[HONOR] == "1", "a click on honor is not kept and written")
assert(not Written(REPUTATION) and texts.blizzardSwitches.reputation == nil, "a click on honor touched reputation")
-- When reputation is hidden.
set("reputation", false)
-- Then it is kept as 0 and written, without touching honor.
assert(texts.blizzardSwitches.reputation == 0 and cvars[REPUTATION] == "0",
    "a click on reputation is not kept and written")
assert(cvars[HONOR] == "1", "a click on reputation touched honor")

-- Given the client changed both elsewhere.
cvars[REPUTATION], cvars[HONOR] = "1", "0"
-- When MSBT applies its settings.
apply(true, true, texts)
-- Then both are forced to the profile's values.
assert(cvars[REPUTATION] == "0" and cvars[HONOR] == "1", "a set text switch is not forced")

-- Given the client lacks both settings.
cvars[REPUTATION], cvars[HONOR] = nil, nil
writes = {}
-- When they are read and applied.
apply(true, true, texts)
-- Then they read as missing and are not written.
assert(get("reputation") == nil and get("honor") == nil, "a missing text setting is not nil")
assert(not Written(REPUTATION) and not Written(HONOR) and cvars[REPUTATION] == nil,
    "a missing text setting was written")

-- Describe: an options window takes the text switches and puts them back.
-- Given reputation set hidden, honor unset, and a client with both shown.
local kept = { blizzardSwitches = { version = 1, reputation = 0 } }
env.currentProfile = kept
cvars[REPUTATION], cvars[HONOR] = "1", "1"
local textRecord = take()
set("reputation", true)
set("honor", false)
-- When they are put back.
restore(textRecord)
-- Then the marks and the client's values are as they were.
assert(kept.blizzardSwitches.reputation == 0 and kept.blizzardSwitches.honor == nil,
    "a restore does not put the text marks back")
assert(cvars[REPUTATION] == "1" and cvars[HONOR] == "1", "a restore does not put the text settings back")

-- Describe: the effect switches are forced and put back with the others.
-- Given the own effects set shown, the other players' effects unset, and a client with both off.
local effects = { blizzardSwitches = { version = 1, effectsOwn = 1 } }
env.currentProfile = effects
cvars[OWN], cvars[OTHERS] = "0", "0"
-- When MSBT applies its settings.
apply(true, true, effects)
-- Then the set effect is forced and the unset one stays as the client has it.
assert(cvars[OWN] == "1" and cvars[OTHERS] == "0", "an effect switch is not forced")
assert(select(2, get("effectsOthers")) == false, "an unset effect switch reads as set")
-- When they are taken, both are changed, and they are put back.
local effectRecord = take()
set("effectsOwn", false)
set("effectsOthers", true)
restore(effectRecord)
-- Then the marks and the client's values are as they were.
assert(effects.blizzardSwitches.effectsOwn == 1 and effects.blizzardSwitches.effectsOthers == nil,
    "a restore does not put the effect marks back")
assert(cvars[OWN] == "1" and cvars[OTHERS] == "0", "a restore does not put the effect settings back")

-- Given the English and German texts of the two boxes.
local function Read(path)
    local handle = assert(io.open(path, "r"))
    local text = handle:read("*a")
    handle:close()
    return text
end
local english = Read("MSBTOptions/Localization/localization.lua")
local german = Read("MSBTOptions/Localization/localization.de.lua")
-- Then both keys have a label and a tooltip in each.
for _, key in ipairs({ "spellMechanicsOwn", "spellMechanicsOthers" }) do
    assert(english:find('obj["' .. key .. '"] = {', 1, true), key .. " is not in English")
    assert(german:find("L.CHECKBOXES." .. key .. ".label = ", 1, true), key .. " has no German label")
    assert(german:find("L.CHECKBOXES." .. key .. ".tooltip = ", 1, true), key .. " has no German tooltip")
end
-- Then the boxes of the text at the character have a label and a tooltip in each.
for _, key in ipairs({ "blizzardReputation", "blizzardHonor" }) do
    assert(english:find('obj["' .. key .. '"] = {', 1, true), key .. " is not in English")
    assert(german:find("L.CHECKBOXES." .. key .. ".label = ", 1, true), key .. " has no German label")
    assert(german:find("L.CHECKBOXES." .. key .. ".tooltip = ", 1, true), key .. " has no German tooltip")
end
-- Then each of the two tooltips says the text shows only with Blizzard's text enabled and its
-- notifications not disabled, and that a change shows after the next reload.
for _, key in ipairs({ "blizzardReputation", "blizzardHonor" }) do
    local englishTooltip = assert(english:match('obj%["' .. key .. '"%] = (%b{})'), key .. " is not in English")
    local germanTooltip = assert(german:match("L%.CHECKBOXES%." .. key .. "%.tooltip = ([^\n]*)"),
        key .. " has no German tooltip")
    assert(englishTooltip:find("It shows only while Enable Blizzard Text is checked and Blizzard's Disable notifications is not.", 1, true),
        "the English text tooltips do not say what the text depends on: " .. key)
    assert(germanTooltip:find("Er erscheint nur, solange Blizzard-Kampftext aktivieren angehakt ist und Blizzards Benachrichtigungen deaktivieren nicht.", 1, true),
        "the German text tooltips do not say what the text depends on: " .. key)
    assert(englishTooltip:find("A change shows after the next reload of the interface.", 1, true),
        "the English text tooltips do not say when a change shows: " .. key)
    assert(germanTooltip:find("Eine Änderung wirkt nach dem nächsten Neuladen der Oberfläche.", 1, true),
        "the German text tooltips do not say when a change shows: " .. key)
end
print("Blizzard text switch tests passed")
