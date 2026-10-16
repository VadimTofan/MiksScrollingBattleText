local file = assert(io.open("MSBTMain.lua", "r"))
local source = file:read("*a")
file:close()
local body = assert(source:match("GetOverheal = function%b()%s*.-\n\tend"))
local cache = {}
local environment = {
	PlainNumber = tonumber,
	UnitHealth = function() return 100 end,
	UnitHealthMax = function() return 100 end,
	GetTime = function() return 10 end,
	healthCache = cache,
	math = math,
}
local factory = assert(loadstring(
	"local GetOverheal\n" .. body .. "\nreturn GetOverheal"
))
setfenv(factory, environment)
local getOverheal = factory()

-- Given a unit already at full health with no pre-heal sample.
-- When a heal amount arrives after the health update.
local overheal = getOverheal("player", 20)

-- Then unknown effective healing must not be discarded as overheal.
assert(overheal == nil, "missing history discarded the full heal")

-- Given a matching pre-heal sample from this frame.
cache.player = { prev = 90, cur = 100, time = 10 }

-- When a 20-point heal fills the remaining ten health.
overheal = getOverheal("player", 20)

-- Then only the observed excess is treated as overheal.
assert(overheal == 10, "known health history produced the wrong overheal")
