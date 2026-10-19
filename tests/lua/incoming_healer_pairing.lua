MikSBT = { Components = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local now, timers, displayed = 10, {}, {}
local profile = { events = {
	INCOMING_HEAL = {}, INCOMING_HEAL_CRIT = {}, PET_INCOMING_HEAL = {},
	OUTGOING_HEAL = {},
} }
local presentation = Presentation:New({
	getProfile = function() return profile end,
	getTime = function() return now end,
	after = function(delay, callback)
		timers[#timers + 1] = { at = now + delay, callback = callback }
	end,
	delay = 0.12,
	getSpellTexture = function(id) return "icon-" .. id end,
	formatMessage = function(_, record)
		return tostring(record.amount) .. ":" .. (record.sourceName or "")
	end,
	display = function(_, message, icon)
		displayed[#displayed + 1] = { message = message, icon = icon }
	end,
	displayRestricted = function(_, amount, icon)
		displayed[#displayed + 1] = { amount = amount, icon = icon }
	end,
})
local function Advance(seconds)
	local finish = now + seconds
	while true do
		local nextIndex
		for index, timer in ipairs(timers) do
			if timer.at <= finish and (not nextIndex
				or timer.at < timers[nextIndex].at) then nextIndex = index end
		end
		if not nextIndex then break end
		local timer = table.remove(timers, nextIndex)
		now = timer.at
		timer.callback()
	end
	now = finish
end

-- Given a healer notice preceding the player's heal by 150 ms.
presentation:Healer("Early healer")
Advance(0.15)
-- When the heal arrives with a supplied icon.
presentation:In({ event = "heal", amount = 10, icon = "heal-icon" })
Advance(0.21)
-- Then its amount, healer and supplied icon are preserved.
assert(displayed[1].message == "10:Early healer", "early healer notice was lost")
assert(displayed[1].icon == "heal-icon")

-- Given a heal whose healer notice comes after grouping has finished.
presentation:In({ event = "heal", amount = 20 })
Advance(0.15)
-- When the notice arrives within 200 ms.
presentation:Healer("Late healer")
Advance(0.06)
-- Then the late name is included without inventing a spell icon.
assert(displayed[2].message == "20:Late healer", "late healer notice was lost")
assert(displayed[2].icon == nil)

-- Given two heals arriving more than 120 ms apart.
presentation:In({ event = "heal", amount = 30 })
Advance(0.15)
presentation:In({ event = "heal", amount = 40 })
-- When one healer notice follows the latest heal.
presentation:Healer("Latest healer")
Advance(0.21)
-- Then only the latest heal gets that name and the amounts stay separate.
assert(displayed[3].message == "30:", "notice attached to an older heal")
assert(displayed[4].message == "40:Latest healer")

-- Given two matching heals inside the 120 ms grouping window.
presentation:In({ event = "heal", amount = 5 })
Advance(0.1)
-- When the second heal and its healer notice arrive.
presentation:In({ event = "heal", amount = 6 })
presentation:Healer("Grouped healer")
Advance(0.21)
-- Then the original grouping still produces one combined amount.
assert(displayed[5].message == "11:Grouped healer")

-- Given an expired healer notice and a pet heal beside a player heal.
presentation:Healer("Expired healer")
Advance(0.21)
presentation:In({ event = "heal", amount = 50 })
presentation:In({ event = "heal", amount = 60, pet = true })
-- When a current player-healer notice arrives.
presentation:Healer("Player healer")
Advance(0.21)
-- Then pet healing cannot consume the player's notice.
local messages = {}
for _, line in ipairs(displayed) do messages[line.message or ""] = true end
assert(messages["50:Player healer"] and messages["60:"])

-- Given an opaque heal amount.
local secret = {}
issecretvalue = function(value) return value == secret end
-- When the incoming heal is displayed.
presentation:In({ event = "heal", amount = secret, icon = "secret-heal-icon" })
Advance(0.21)
-- Then the renderer receives the original amount without arithmetic.
assert(displayed[#displayed].amount == secret)
assert(displayed[#displayed].icon == "secret-heal-icon")
issecretvalue = nil

-- Given an unmatched healer notice in the current session.
presentation:Healer("Old session")
-- When the presentation is reset before the next heal.
presentation:Reset()
presentation:In({ event = "heal", amount = 70 })
Advance(0.21)
-- Then the old notice cannot leak into the new session.
assert(displayed[#displayed].message == "70:")

-- Given a heal waiting for its healer notice.
local count = #displayed
presentation:In({ event = "heal", amount = 80 })
Advance(0.15)
-- When a reset invalidates the remaining presentation callback.
presentation:Reset()
Advance(0.1)
-- Then no old-session heal is emitted.
assert(#displayed == count)
print("Incoming healer pairing tests passed")
