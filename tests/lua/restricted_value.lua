MikSBT = {}

local secretValue = {}
local secretTable = {}

issecretvalue = function(value)
	return value == secretValue
end
canaccessvalue = function(value)
	return value ~= secretValue
end
issecrettable = function(value)
	return value == secretTable
end
canaccesstable = function(value)
	return value ~= secretTable
end

local RestrictedValue = dofile("API/RestrictedValue.lua")

-- Given
local publicTable = { amount = 42 }

-- When / Then
assert(RestrictedValue:Number(42) == 42, "public number was rejected")
assert(RestrictedValue:String("spell") == "spell", "public string was rejected")
assert(RestrictedValue:Boolean(true) == true, "public boolean was rejected")
assert(RestrictedValue:Table(publicTable) == publicTable, "public table was rejected")
assert(RestrictedValue:Value(secretValue) == nil, "secret value was exposed")
assert(RestrictedValue:Table(secretTable) == nil, "secret table was exposed")
assert(RestrictedValue:Number("42") == nil, "string was coerced into a number")

-- Given a client without secret-value APIs
issecretvalue = nil
canaccessvalue = nil
issecrettable = nil
canaccesstable = nil

-- When / Then
assert(RestrictedValue:Number(7) == 7, "legacy public number was rejected")
assert(RestrictedValue:Table(publicTable) == publicTable,
	"legacy public table was rejected")

-- Given secret predicates that fail
local predicateFailure = {}
issecretvalue = function(value)
	if value == predicateFailure then
		error("predicate failed")
	end
	return false
end
issecrettable = function(value)
	if value == predicateFailure then
		error("table predicate failed")
	end
	return false
end

-- When / Then
assert(RestrictedValue:Value(predicateFailure) == nil,
	"failed value inspection granted access")
assert(RestrictedValue:Table(predicateFailure) == nil,
	"failed table inspection granted access")
