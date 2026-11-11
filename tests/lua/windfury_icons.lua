MikSBT = { Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Reader.lua")
local engine = MikSBT.CombatEngine
local playerClass = "SHAMAN"
UnitClass = function() return playerClass, playerClass end

-- Given the modern API reports an active Windfury enchant, with no cast
-- history after loading the addon.
local mainEnchant = { enchantID = 283 }
local offEnchant
C_PaperDollInfo = {
    GetTemporaryEnchantmentInfo = function(slot)
        assert(slot == 16 or slot == 17)
        if slot == 16 then return mainEnchant end
        return offEnchant
    end,
}
GetWeaponEnchantInfo = function() error("modern API must take precedence") end

-- When a confirmed physical proc needs its spell identity.
local spell = engine.ProcSpell(10, 1)

-- Then a shaman's uncertain physical proc uses the Windfury best guess.
assert(spell == 8232, "shaman physical proc did not receive Windfury")

-- Given an extra-attack grant with a hidden spell and attack count.
engine.reader.logLines = { { at = 10, source = "mine", kind = "extra" } }

-- When a physical proc resolves beside that grant.
spell = engine.ProcSpell(10, 1)

-- Then an extra-attack grant keeps the same shaman fallback.
assert(spell == 8232, "extra-attack proc lost the Windfury fallback")

-- Given a cached physical proc that competes with the active enchant.
engine.reader.procSources.enchant = { at = 0, spell = 602, school = 1 }

-- When physical damage is unresolved, then the requested best guess applies.
assert(engine.ProcSpell(10, 1) == 8232,
    "cached source bypassed the shaman Windfury fallback")
engine.reader.procSources.enchant = nil

-- Given another class with an active Windfury effect.
playerClass = "WARRIOR"

-- When its uncertain physical proc is resolved.
spell = engine.ProcSpell(10, 1)

-- Then the shaman-only fallback does not name its proc.
assert(spell == nil, "another class received the shaman fallback")
playerClass = "SHAMAN"

for _, enchantID in ipairs({ 283, 284, 525, 1669 }) do
    -- Given each Vanilla rank of Windfury Weapon.
    mainEnchant = { enchantID = enchantID }

    -- When diagnostics query the active enchant independently of damage.
    spell = engine.ActiveWindfurySpell(1)

    -- Then all ranks remain available to the opt-in capture tool.
    assert(spell == 8232)
end

-- Given an expired enchant, replacement enchant, or off-hand Windfury.
mainEnchant = nil
assert(engine.ActiveWindfurySpell(1) == nil, "expired enchant was cached")
assert(engine.ProcSpell(10, 1) == nil, "expired Windfury supplied an icon")
mainEnchant = { enchantID = 9999 }
assert(engine.ActiveWindfurySpell(1) == nil, "unrelated enchant was named Windfury")
assert(engine.ProcSpell(10, 1) == nil, "replacement imbue supplied Windfury")
offEnchant = { enchantID = 283 }
assert(engine.ActiveWindfurySpell(1) == 8232)

-- Given a Fire proc, unknown school, or another game client.
-- When the icon is requested, then Windfury is not assigned.
assert(engine.ProcSpell(10, 4) == nil)
assert(engine.ProcSpell(10, nil) == nil)
assert(engine.ActiveWindfurySpell(4) == nil)
assert(engine.ActiveWindfurySpell(nil) == nil)
MikSBT.Compatibility.Client.isForever = false
assert(engine.ProcSpell(10, 1) == nil)
assert(engine.ActiveWindfurySpell(1) == nil)
MikSBT.Compatibility.Client.isForever = true

-- Given unreadable enchant metadata.
local opaque = setmetatable({}, {
    __index = function() error("read opaque enchant metadata") end,
})
issecretvalue = function(value) return value == opaque end
mainEnchant, offEnchant = { enchantID = opaque }, nil

-- When a proc asks for its icon, then hidden values are not used as keys.
assert(engine.ProcSpell(10, 1) == nil)
assert(engine.ActiveWindfurySpell(1) == nil)
mainEnchant = opaque
assert(engine.ProcSpell(10, 1) == nil)
assert(engine.ActiveWindfurySpell(1) == nil)

-- Given the API fails, then no stale icon or alternative secret read is used.
C_PaperDollInfo.GetTemporaryEnchantmentInfo = function() error("unavailable") end
assert(engine.ProcSpell(10, 1) == nil)
assert(engine.ActiveWindfurySpell(1) == nil)

-- Given an older client API shape supported by Forever.
C_PaperDollInfo = nil
local active, enchantID = true, 283
GetWeaponEnchantInfo = function()
    return active, 300000, 0, enchantID, false, 0, 0, 0
end

-- When querying the legacy tuple, then its active ID is recognized safely.
assert(engine.ActiveWindfurySpell(1) == 8232)
active = false
assert(engine.ActiveWindfurySpell(1) == nil)
active, enchantID = true, opaque
assert(engine.ActiveWindfurySpell(1) == nil)
active, enchantID = opaque, 283
assert(engine.ActiveWindfurySpell(1) == nil)
GetWeaponEnchantInfo = function()
    return false, 0, 0, 0, true, 300000, 0, 283
end
assert(engine.ActiveWindfurySpell(1) == 8232)
GetWeaponEnchantInfo = function() error("unavailable") end
assert(engine.ActiveWindfurySpell(1) == nil)

-- Given no enchant API and an existing learned Fire proc source.
GetWeaponEnchantInfo = nil
engine.reader.procSources.oil = { at = 0, spell = 601, school = 4 }

-- When ordinary proc sources resolve, then their existing behavior remains.
assert(engine.ProcSpell(10, 4) == 601)
assert(engine.ProcSpell(10, 1) == nil)
print("Shaman Windfury fallback tests passed")
