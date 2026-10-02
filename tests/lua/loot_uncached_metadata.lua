local callback
local displayed = {}
local cached = false
local profile = {
	qualityExclusions = {}, itemExclusions = {}, itemsAllowed = {},
	events = {NOTIFICATION_LOOT = {message = "%e x%a (%t)"}},
}
MikSBT = {
	Profiles = {currentProfile = profile},
	Parser = {RegisterHandler = function(handler) callback = handler end},
	Animations = {DisplayEvent = function(_, message, texture)
		displayed[#displayed + 1] = {message = message, texture = texture}
	end},
}
C_Item = {
	GetItemInfo = function()
		if cached then return "Potion", nil, 1, nil, nil, "Consumable",
			nil, nil, nil, "icon" end
	end,
	GetItemCount = function() return 0 end,
	GetItemClassInfo = function() return "Quest" end,
}
LE_ITEM_CLASS_QUESTITEM = 12
ITEM_QUALITY_COLORS = {[1] = {r = 1, g = 1, b = 1}}
GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
UNKNOWN = "Unknown"
local file = assert(io.open("Components/LootNotifications.lua", "rb"))
local source = file:read("*a"):gsub("^\239\187\191", "")
file:close()
assert(loadstring(source))()
local event = {
	recipientUnit = "player", eventType = "loot", amount = 2,
	itemLink = "|cffFFFFFF|Hitem:123|h[Potion]|h|r",
}

-- Given a loot link whose item metadata is not cached.
-- When its parsed notification arrives.
local success, message = pcall(callback, event)

-- Then the alert uses the link's item name without throwing or losing quantity.
assert(success, "uncached loot threw: " .. tostring(message))
assert(#displayed == 1, "uncached loot alert was dropped")
assert(displayed[1].message == "Potion x2 (2)", "fallback name or count differs")

-- Given the fallback name is excluded, when the same uncached item arrives.
profile.itemExclusions.Potion = true
callback(event)

-- Then name-based filtering still works before metadata loads.
assert(#displayed == 1, "uncached loot bypassed item exclusions")

-- Given cached metadata and no exclusion, when another alert arrives.
profile.itemExclusions.Potion = nil
cached = true
callback(event)

-- Then normal formatting and the cached icon remain intact.
assert(displayed[2].message:find("Potion", 1, true), "cached name was lost")
assert(displayed[2].texture == "icon", "cached item icon was lost")
