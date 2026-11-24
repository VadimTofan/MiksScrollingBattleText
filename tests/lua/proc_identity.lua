MikSBT = { Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
dofile("Combat/Context.lua")
dofile("Combat/Classes/Shaman.lua")
dofile("Combat/Mine.lua")
dofile("Combat/Reader.lua")
local engine = MikSBT.CombatEngine

-- Given a shaman with an active Windfury enchant but no spell-level evidence.
UnitClass = function() return "Shaman", "SHAMAN" end
GetWeaponEnchantInfo = function() return true, 10000, 0, 283 end

-- When identity is requested for an unidentified physical proc.
local identity = engine.ProcSpell(10, 1)

-- Then the active enchant cannot invent a Windfury name.
assert(identity == nil, "an active enchant was treated as a spell identity")

-- When the same state is inspected as candidate evidence.
local candidate = engine.ProcCandidate(10, 1)

-- Then it can support grouping and diagnostics independently of naming.
assert(candidate == 8232)

-- Given a known oil source with matching school.
engine.reader.procSources.oil = { at = 10, spell = 601, school = 4 }

-- When its effect is plausible but the damage spell itself is unidentified.
local oilIdentity = engine.ProcSpell(10.1, 4)
local oilCandidate = engine.ProcCandidate(10.1, 4)

-- Then a guessed oil name is not authoritative either.
assert(oilIdentity == nil and oilCandidate == 601)
