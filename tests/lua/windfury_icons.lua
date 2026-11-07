MikSBT = { Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Reader.lua")
local engine = MikSBT.CombatEngine

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

-- Then it receives Windfury's spell ID for the existing icon renderer.
assert(spell == 8232, "Windfury proc has no icon identity after reload")

for _, enchantID in ipairs({ 283, 284, 525, 1669 }) do
    -- Given each Vanilla rank of Windfury Weapon.
    mainEnchant = { enchantID = enchantID }

    -- When the enchant is queried on a confirmed physical proc.
    spell = engine.ProcSpell(10, 1)

    -- Then ranks share the same localized Windfury icon/name identity.
    assert(spell == 8232)
end

-- Given an expired enchant, replacement enchant, or off-hand Windfury.
mainEnchant = nil
assert(engine.ProcSpell(10, 1) == nil, "expired Windfury icon was cached")
mainEnchant = { enchantID = 9999 }
assert(engine.ProcSpell(10, 1) == nil, "unrelated enchant was named Windfury")
offEnchant = { enchantID = 283 }
assert(engine.ProcSpell(10, 1) == 8232)

-- Given a Fire proc, unknown school, or another game client.
-- When the icon is requested, then Windfury is not assigned.
assert(engine.ProcSpell(10, 4) == nil)
assert(engine.ProcSpell(10, nil) == nil)
MikSBT.Compatibility.Client.isForever = false
assert(engine.ProcSpell(10, 1) == nil)
MikSBT.Compatibility.Client.isForever = true

-- Given unreadable enchant metadata.
local opaque = setmetatable({}, {
    __index = function() error("read opaque enchant metadata") end,
})
issecretvalue = function(value) return value == opaque end
mainEnchant, offEnchant = { enchantID = opaque }, nil

-- When a proc asks for its icon, then hidden values are not used as keys.
assert(engine.ProcSpell(10, 1) == nil)
mainEnchant = opaque
assert(engine.ProcSpell(10, 1) == nil)

-- Given the API fails, then no stale icon or alternative secret read is used.
C_PaperDollInfo.GetTemporaryEnchantmentInfo = function() error("unavailable") end
assert(engine.ProcSpell(10, 1) == nil)

-- Given an older client API shape supported by Forever.
C_PaperDollInfo = nil
local active, enchantID = true, 283
GetWeaponEnchantInfo = function()
    return active, 300000, 0, enchantID, false, 0, 0, 0
end

-- When querying the legacy tuple, then its active ID is recognized safely.
assert(engine.ProcSpell(10, 1) == 8232)
active = false
assert(engine.ProcSpell(10, 1) == nil)
active, enchantID = true, opaque
assert(engine.ProcSpell(10, 1) == nil)
active, enchantID = opaque, 283
assert(engine.ProcSpell(10, 1) == nil)
GetWeaponEnchantInfo = function()
    return false, 0, 0, 0, true, 300000, 0, 283
end
assert(engine.ProcSpell(10, 1) == 8232)
GetWeaponEnchantInfo = function() error("unavailable") end
assert(engine.ProcSpell(10, 1) == nil)

-- Given no enchant API and an existing learned Fire proc source.
GetWeaponEnchantInfo = nil
engine.reader.procSources.oil = { at = 0, spell = 601, school = 4 }

-- When ordinary proc sources resolve, then their existing behavior remains.
assert(engine.ProcSpell(10, 4) == 601)
assert(engine.ProcSpell(10, 1) == nil)
print("Windfury icon identity tests passed")
