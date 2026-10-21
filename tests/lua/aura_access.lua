-- Describe: aura reads respect global and individual secrecy restrictions.
MikSBT = { API = {} }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Reader.lua")
local ns = MikSBT.CombatEngine
GetTime = function() return 10 end
local globalSecret, individualSecret = false, false
local indexReads, instanceReads = 0, 0
local aura = {
    auraInstanceID = 7, isHarmful = false, name = "Test buff",
    icon = 123, spellId = 17, expirationTime = 30,
}
C_Secrets = {
    ShouldAurasBeSecret = function() return globalSecret end,
    ShouldUnitAuraIndexBeSecret = function() return individualSecret end,
    ShouldUnitAuraInstanceBeSecret = function() return individualSecret end,
}
C_UnitAuras = {
    GetAuraDataByIndex = function(_, index, filter)
        indexReads = indexReads + 1
        assert(not globalSecret, "indexed aura read while globally restricted")
        if index == 1 and filter == "HELPFUL" then return aura end
    end,
    GetAuraDataByAuraInstanceID = function()
        instanceReads = instanceReads + 1
        assert(not globalSecret, "instance aura read while globally restricted")
        return aura
    end,
}
local function FullUpdate()
    ns.ReaderEvent(nil, "UNIT_AURA", "player", { isFullUpdate = true })
end
local function Refresh()
    ns.ReaderEvent(nil, "UNIT_AURA", "player", {
        isFullUpdate = false, updatedAuraInstanceIDs = { 7 },
    })
end

-- Given unrestricted aura access.
-- When the cache is rebuilt and a known aura refreshed.
FullUpdate()
Refresh()
-- Then readable buffs remain cached and refreshable.
assert(ns.reader.auras[7].name == "Test buff")
assert(indexReads == 3 and instanceReads == 1)

-- Given global restrictions despite permissive individual predicates.
globalSecret = true
indexReads, instanceReads = 0, 0
-- When a cached aura is refreshed and a full update arrives.
Refresh()
FullUpdate()
-- Then neither restricted API is called and the old cache is cleared.
assert(indexReads == 0 and instanceReads == 0)
assert(next(ns.reader.auras) == nil)

-- Given individual aura restrictions without global restrictions.
globalSecret, individualSecret = false, true
-- When a full update arrives.
FullUpdate()
-- Then individual secret auras are still skipped.
assert(indexReads == 0)

-- Given a client exposing C_Secrets without individual aura predicates.
C_Secrets.ShouldUnitAuraIndexBeSecret = nil
-- When rebuilding the cache.
FullUpdate()
-- Then unverified access is skipped conservatively.
assert(indexReads == 0)

-- Given a legacy client without secret APIs.
C_Secrets = nil
-- When rebuilding the cache.
FullUpdate()
-- Then legacy aura reads still work.
assert(indexReads == 3 and ns.reader.auras[7].spell == 17)
print("Aura access tests passed")
