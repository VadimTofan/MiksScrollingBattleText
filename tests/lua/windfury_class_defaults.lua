-- Describe: inferred Windfury is automatic only for Forever Shamans.
MikSBT = {
    API = {}, Components = {}, Compatibility = { Client = {} },
    CombatEngine = { mine = {}, Timer = { After = function() end } },
}
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
MikSBT.CombatEngine.mine = {}
dofile("Combat/Classes/Shaman.lua")
dofile("Combat/WindfuryInference.lua")
local Engine = dofile("Components/CombatEngine.lua")
local class
UnitClass = function() return "Localized class", class end
local secret = {}
issecretvalue = function(value) return value == secret end

for _, forever in ipairs({ true, false }) do
    for _, token in ipairs({ "SHAMAN", "WARRIOR", "ROGUE", "PALADIN",
        "HUNTER", "DRUID", "MAGE", "PRIEST", "WARLOCK", "DEATHKNIGHT",
        "MONK", "DEMONHUNTER", "EVOKER" }) do
        -- Given each client/class and an old profile that disabled inference.
        MikSBT.Compatibility.Client.isForever = forever
        class = token
        local profile = { inferredWindfuryIcons = false }
        local engine = Engine:New({ getProfile = function() return profile end })

        -- When the engine applies its automatic inference policy.
        engine:UpdateInference()

        -- Then only Forever Shamans have an active inference stage.
        local expected = forever and token == "SHAMAN"
        assert((engine.inference ~= nil) == expected,
            "incorrect inferred Windfury default for " .. token)
        assert(MikSBT.CombatEngine.mine.inferredWindfuryEnabled == expected)
        assert(profile.inferredWindfuryIcons == false,
            "automatic policy rewrote a retired profile preference")
    end
end

-- Given an active Forever Shaman with no opt-in preference.
MikSBT.Compatibility.Client.isForever, class = true, "SHAMAN"
local profile = {}
local engine = Engine:New({ getProfile = function() return profile end })
engine:UpdateInference()
assert(engine.inference, "Shaman still requires opting in")

-- When class identity is unavailable or restricted.
for _, value in ipairs({ false, secret }) do
    class = value
    engine:UpdateInference()

    -- Then inference is disabled without interpreting an unreadable class.
    assert(engine.inference == nil)
end
UnitClass = nil
assert(engine:InferenceEnabled() == false)

-- Given a Shaman with no usable active profile.
UnitClass = function() return "Shaman", "SHAMAN" end
profile = nil
-- When the engine starts without saved profile data.
engine:UpdateInference()
-- Then it cannot start an inference stage.
assert(engine.inference == nil)

-- Given a readable Shaman class with a valid profile but no class policy.
profile = {}
local shaman = MikSBT.CombatEngine.classRules.SHAMAN
MikSBT.CombatEngine.classRules.SHAMAN = {}

-- When the engine checks eligibility, the class must explicitly opt in.
assert(engine:InferenceEnabled() == false)

-- Then restoring the class rules restores the Weapon policy and spell data.
MikSBT.CombatEngine.classRules.SHAMAN = shaman
assert(engine:InferenceEnabled() == true)
assert(shaman.windfuryWeapon.iconSpell == 8232)
assert(shaman.windfuryWeapon.procSpell == 439440)
assert(shaman.windfuryWeapon.triggerSpell == 17364)
assert(shaman.windfuryWeapon.enchants[283])
