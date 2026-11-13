-- Describe: readable spell facts constrain attribution on Chinese clients.
MikSBT = {}
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Spells.lua")
local ns = MikSBT.CombatEngine
local locale, description = "zhCN", "造成32点物理伤害。"
local helpful, loads = false, 0
GetLocale = function() return locale end
C_Spell = {
    GetSpellDescription = function() return description end,
    IsSpellHelpful = function() return helpful end,
    RequestLoadSpellData = function() loads = loads + 1 end,
}
local function Facts()
    ns.ForgetSpellFacts(90001)
    return ns.SpellFacts(90001)
end

-- Given localized school labels supplied by the client.
for _, language in ipairs({ "zhCN", "zhTW" }) do
    locale = language
    local damage = language == "zhCN" and "伤害" or "傷害"
    for _, case in ipairs({
        { "PHYSICAL", "物理", 1 }, { "HOLY", "神圣", 2, "神聖" },
        { "FIRE", "火焰", 4 }, { "NATURE", "自然", 8 },
        { "FROST", "冰霜", 16 }, { "SHADOW", "暗影", 32 },
        { "ARCANE", "奥术", 64, "奧術" },
    }) do
        local label = language == "zhTW" and (case[4] or case[2]) or case[2]
        _G["STRING_SCHOOL_" .. case[1]] = label
        description = "造成32点" .. label .. damage .. "。"
        -- When a public description states its damage school.
        local facts = Facts()
        -- Then the matching school is retained without guessing timing or type.
        assert(facts and facts.school == case[3],
            "Chinese spell school was discarded: " .. language .. case[1])
        assert(facts.direct == nil and facts.ticks == nil and facts.period == nil)
    end
end

-- Given a physical Hawk spell and a Nature tick on a Chinese client.
locale, description = "zhCN", "造成32点物理伤害，并继续攻击18秒。"
local facts = Facts()
local mine = ns.NewMine(nil, nil, function() return facts end)
mine:Cast("player", 90001, "target", 10)
-- When the Nature tick arrives after the Hawk cast.
local hit = mine:Hit("target", "damage", 8, 13, false, true, 92, false, "tick")
-- Then the physical spell cannot take that tick's name or icon.
assert(hit.spell ~= 90001, "physical Hawk spell took a Nature tick")

-- Given both the physical Hawk and a Nature sting were cast on that target.
local hawkFacts = facts
description = "在15秒内造成90点自然伤害。"
local stingFacts = Facts()
mine = ns.NewMine(nil, nil, function(id)
    return id == 90001 and hawkFacts or stingFacts
end)
mine:Cast("player", 90001, "target", 10)
mine:Cast("player", 90002, "target", 11)
-- When the sting's first confirmed tick arrives.
hit = mine:Hit("target", "damage", 8, 14, false, true, 92, false, "tick")
-- Then the Nature spell retains its identity instead of taking the Hawk icon.
assert(hit.spell == 90002 and hit.tick)

-- Given school words that do not describe damage, or multiple damage schools.
for _, text in ipairs({
    "使自然抗性提高60点。", "造成物理伤害和自然伤害。", "未知描述。",
    "使目标受到的自然伤害提高20%。",
}) do
    description = text
    -- When the description cannot establish a single damage school.
    facts = Facts()
    -- Then the school remains unknown instead of selecting one arbitrarily.
    assert(not facts or facts.school == nil)
end

-- Given a missing client label.
description = "造成32点自然伤害。"
STRING_SCHOOL_NATURE = nil
-- When its text is read, then no untranslated school name is assumed.
facts = Facts()
assert(not facts or facts.school == nil)
STRING_SCHOOL_NATURE = "自然"

-- Given a helpful spell in any locale, including one with no text parser.
for _, language in ipairs({ "zhCN", "zhTW", "deDE" }) do
    locale, description, helpful = language, "未知描述。", true
    -- When the readable API marks it as helpful.
    facts = Facts()
    -- Then it cannot claim damage or enter damage matching while text is unknown.
    assert(facts and facts.helpful and facts.damages == false)
    mine = ns.NewMine(nil, nil, function() return facts end)
    mine:Cast("player", 90001, "target", 20)
    hit = mine:Hit("target", "damage", 8, 23, false, true, 92, false, "tick")
    assert(hit.spell ~= 90001)
end

-- Given an opaque description and helpfulness result.
local secret = setmetatable({}, {
    __tostring = function() error("spell facts inspected a secret") end,
})
issecretvalue = function(value) return value == secret end
locale, description, helpful = "zhCN", secret, secret
-- When neither value is available to Lua.
facts = Facts()
-- Then no facts are inferred, and spell loading is requested instead.
assert(facts == nil and loads > 0)

-- Given a helpfulness API that is missing or fails.
description, helpful = "造成32点自然伤害。", false
local helper = C_Spell.IsSpellHelpful
for _, replacement in ipairs({ false, function() error("unavailable") end }) do
    C_Spell.IsSpellHelpful = replacement
    -- When a readable school can still be obtained.
    facts = Facts()
    -- Then the school remains usable without invented helpfulness.
    assert(facts and facts.school == 8 and facts.helpful == nil)
end
C_Spell.IsSpellHelpful = helper

-- Given text that has not loaded yet.
description = nil
ns.ForgetSpellFacts(90001)
assert(ns.SpellFacts(90001) == nil)
-- When it becomes readable without a cache reset.
description = "在15秒内造成90点自然伤害。"
facts = ns.SpellFacts(90001)
-- Then the previously unavailable description is retried successfully.
assert(facts and facts.school == 8)

-- Given the existing English parser.
locale, description = "enUS", "Causes 90 Nature damage over 9 sec."
-- When English spell facts are read.
facts = Facts()
-- Then its complete timing and damage classification remain available.
assert(facts.school == 8 and facts.ticks and not facts.direct)
assert(facts.total == 90 and facts.duration == 9)
print("Localized spell fact tests passed")
