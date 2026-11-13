-- Describe: recent features have explicit translations in every supported locale.
local function Load(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    source = source:gsub("^\239\187\191", "")
    assert(loadstring(source, "@" .. path))()
end

local locales = {
    { "deDE", "de" }, { "frFR", "fr" }, { "itIT", "it" },
    { "koKR", "kr" }, { "ruRU", "ru" },
    { "zhCN", "zhcn" }, { "zhTW", "zhtw" },
}
local core = { "COSMIC", "CP_FULL", "COMBO_POINT", "COMBO_POINTS", "SETUP_RELOAD_PROMPT" }
local options = {
    "POPUP_CONFIRM_TITLE", "AURA_TRACKING_TITLE", "AURA_TRACKING_INPUT",
    "AURA_TRACKING_ADD", "AURA_TRACKING_HELP", "AURA_TRACKING_ALL_RANKS",
    "AURA_TRACKING_CHECKBOX", "AURA_TRACKING_REMOVE", "AURA_TRACKING_UNKNOWN",
    "AURA_TRACKING_INVALID", "RESOURCE_CHECKBOX_TITLE", "RESOURCE_CHECKBOX_HELP",
    "RESOURCE_CHECKBOX_SOUND", "RESOURCE_COMBO_POINT", "MSG_SOUND_PLAYBACK_FAILED",
    "MSG_INVALID_SOUND_FILE", "LANGUAGE_CURRENT", "LANGUAGE_INFO",
    "RESET_BLIZZARD_INFO", "MSG_BLIZZARD_TEXT_RESTORED",
}
local resources = {
    "MANA", "RAGE", "FOCUS", "ENERGY", "COMBO_POINTS", "RUNES",
    "RUNIC_POWER", "SOUL_SHARDS", "LUNAR_POWER", "HOLY_POWER",
    "ALTERNATE_POWER", "MAELSTROM", "CHI", "INSANITY", "BURNING_EMBERS",
    "DEMONIC_FURY", "ARCANE_CHARGES", "FURY", "PAIN", "ESSENCE",
    "RUNE_BLOOD", "RUNE_FROST", "RUNE_UNHOLY", "ALTERNATE_QUEST_POWER",
    "ALTERNATE_ENCOUNTER_POWER", "ALTERNATE_MOUNT_POWER", "BALANCE",
    "HAPPINESS", "SHADOW_ORBS", "RUNE_CHROMATIC",
}
local groups = {
    TABS = { "profile", "sounds", "language", "resetBlizzardSCT" },
    CHECKBOXES = {
        "enableMSBT", "enableBlizzardDamage", "disableIncoming",
        "disableOutgoing", "disableNotifications", "enableNames",
        "lowHealthSound", "lowManaSound", "shortenNumbers", "groupNumbers",
        "stackSimilarHits", "currencyGains",
    },
    BUTTONS = { "resetBlizzardSCT" },
    NOTIFICATION_EVENTS = {
        "NOTIFICATION_RESOURCE_GAIN", "NOTIFICATION_ITEM_COOLDOWN",
        "NOTIFICATION_CROWD_CONTROL", "NOTIFICATION_PROC", "NOTIFICATION_REACTIVE",
        "NOTIFICATION_PC_KILLING_BLOW", "NOTIFICATION_NPC_KILLING_BLOW",
    },
    INCOMING_PLAYER_EVENTS = { "SELF_HEAL", "SELF_HEAL_CRIT", "SELF_HOT", "SELF_HOT_CRIT" },
}

local function Formats(text)
    local tokens = {}
    for token in text:gmatch("%%[a-z]+") do
        tokens[token] = (tokens[token] or 0) + 1
    end
    return tokens
end

for _, locale in ipairs(locales) do
    -- Given English defaults, mark required strings to detect silent fallbacks.
    GetLocale = function() return locale[1] end
    MikSBT = { translations = {}, COMMAND = "/msbt" }
    OKAY, CANCEL, SAVE = "Okay", "Cancel", "Save"
    Load("Localization/localization.lua")
    local L, pending = MikSBT.translations, {}
    local function Mark(table, key, path, allowMissing)
        local value = table[key]
        assert(allowMissing or type(value) == "string", "Missing default: " .. path)
        local marker = "UNTRANSLATED:" .. path
        pending[#pending + 1] = {
            table = table, key = key, path = path, marker = marker,
            formats = Formats(value or ""),
        }
        table[key] = marker
    end
    for _, key in ipairs(core) do Mark(L, key, key) end
    L.RESOURCE_NAMES = L.RESOURCE_NAMES or {}
    for _, key in ipairs(resources) do
        Mark(L.RESOURCE_NAMES, key, "RESOURCE_NAMES." .. key, true)
    end
    for _, candidate in ipairs(locales) do
        Load("Localization/localization." .. candidate[2] .. ".lua")
    end
    Load("MSBTOptions/Localization/localization.lua")
    for _, key in ipairs(options) do Mark(L, key, key) end
    for group, entries in pairs(groups) do
        for _, key in ipairs(entries) do
            for _, field in ipairs({ "label", "tooltip" }) do
                Mark(L[group][key], field, group .. "." .. key .. "." .. field)
            end
        end
    end
    for _, key in ipairs({ "RESOURCE_AMOUNT", "RESOURCE_NAME" }) do
        Mark(L.EVENT_CODES, key, "EVENT_CODES." .. key)
    end
    for key, value in pairs(L.PROFILE_TRANSFER) do
        if type(value) == "string" then
            Mark(L.PROFILE_TRANSFER, key, "PROFILE_TRANSFER." .. key)
        end
    end
    for key in pairs(L.PROFILE_TRANSFER.errors) do
        Mark(L.PROFILE_TRANSFER.errors, key, "PROFILE_TRANSFER.errors." .. key)
    end
    -- When the normal XML locale files load after the defaults.
    for _, candidate in ipairs(locales) do
        Load("MSBTOptions/Localization/localization." .. candidate[2] .. ".lua")
    end
    -- Then every required value is translated and preserves its format tokens.
    for _, item in ipairs(pending) do
        local value = L
        for part in item.path:gmatch("[^.]+") do value = value and value[part] end
        assert(type(value) == "string" and value ~= "" and value ~= item.marker,
            locale[1] .. " missing translation: " .. item.path)
        local tokens = Formats(value)
        for token, count in pairs(item.formats) do
            assert(tokens[token] == count, locale[1] .. " lost " .. token .. ": " .. item.path)
        end
        for token, count in pairs(tokens) do
            assert(item.formats[token] == count, locale[1] .. " added " .. token .. ": " .. item.path)
        end
    end
end
print("Recent feature translations and format tokens verified for seven locales")
