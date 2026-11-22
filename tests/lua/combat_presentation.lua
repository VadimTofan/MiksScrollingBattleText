MikSBT = { Components = {}, Services = {} }
dofile("API/RestrictedValue.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local displayed, restricted = {}, {}
local profile = { events = {
	OUTGOING_SPELL_DOT = { message = "Tick %a", scrollArea = "My outgoing" },
	INCOMING_HEAL_CRIT = { message = "+%a", isCrit = true, scrollArea = "My heals" },
	PET_INCOMING_DAMAGE = { message = "Pet %a", scrollArea = "My pet" },
	OUTGOING_HEAL = { message = "Heal %a", scrollArea = "My outgoing" },
	NOTIFICATION_BUFF = { message = "[%sl]", scrollArea = "My notices" },
	NOTIFICATION_COMBAT_ENTER = { message = "+Combat", scrollArea = "My notices" },
	SELF_HEAL = { message = "Self %a", scrollArea = "My self heals" },
	NOTIFICATION_REACTIVE = { message = "<%sl>", scrollArea = "My notices" },
} }
local queued
local presentation = Presentation:New({
	getProfile = function() return profile end,
	batcher = { Queue = function(_, ...) queued = { ... } end },
	getSpellTexture = function(id) return "icon-" .. id end,
	formatMessage = function(settings, record)
		return (settings.message:gsub("%%a", tostring(record.amount or "")))
	end,
	display = function(...) displayed[#displayed + 1] = { ... } end,
	displayRestricted = function(...) restricted[#restricted + 1] = { ... } end,
})

-- Given a confirmed DoT result from the new engine.
-- When it reaches the MSBT presentation adapter.
presentation:Out({ event = "damage", amount = 42, crit = true,
	result = { who = "you", spell = 101, tick = true } })
-- Then existing outgoing batching receives the spell, crit and DoT flags.
assert(queued[1] == 101 and queued[2] == 42 and queued[3])
assert(queued[4] == "icon-101" and queued[7])

-- Given existing customized incoming healing and pet damage settings.
-- When incoming records arrive.
presentation:In({ event = "heal", amount = 90, crit = true })
presentation:In({ event = "damage", amount = 20, pet = true, school = 1 })
-- Then the same setting objects reach the unchanged display service.
assert(displayed[1][1] == profile.events.INCOMING_HEAL_CRIT)
assert(displayed[1][2] == "+90" and displayed[1][1].scrollArea == "My heals")
assert(displayed[2][1] == profile.events.PET_INCOMING_DAMAGE)

-- Given an outgoing heal identified by the engine.
-- When it is presented.
presentation:Out({ event = "heal", amount = 30,
	result = { who = "you", spell = 102 } })
-- Then it uses outgoing heal settings rather than a damage batch.
assert(displayed[3][1] == profile.events.OUTGOING_HEAL)

-- Given a restricted amount and a restricted aura name.
local secret = {}
issecretvalue = function(value) return value == secret end
-- When those records are drawn.
presentation:In({ event = "heal", amount = secret, crit = true })
presentation:Aura(true, false, secret, "aura-icon")
-- Then the exact opaque values survive as separate rendering arguments.
assert(restricted[1][2] == secret)
assert(restricted[2][2] == secret and restricted[2][3] == "aura-icon")
presentation:Alert({ kind = "reactive", args = { secret } })
assert(restricted[3][2] == secret)

-- Given hidden and unrelated outgoing damage.
local before = #displayed
presentation:Out({ event = "damage", amount = 999, result = { who = "other" } })
profile.events.INCOMING_HEAL_CRIT.disabled = true
presentation:In({ event = "heal", amount = 50, crit = true })
-- Then no extra text is emitted and profile settings stay intact.
assert(#displayed == before)
assert(profile.events.INCOMING_HEAL_CRIT.scrollArea == "My heals")

-- Given combat entry from the new reader.
presentation:Alert({ kind = "combat", entering = true })
-- Then the existing configured combat notice is used.
assert(displayed[#displayed][1] == profile.events.NOTIFICATION_COMBAT_ENTER)

-- Given a self heal identified by the shared reader.
presentation:In({ event = "heal", amount = 15, selfHeal = true, spell = 103 })
-- Then it retains the dedicated self-heal event and spell icon.
assert(displayed[#displayed][1] == profile.events.SELF_HEAL)
assert(displayed[#displayed][3] == "icon-103")
print("Combat presentation tests passed")

-- Given confirmed damage whose spell remains ambiguous.
-- When normal and restricted amounts reach presentation.
for _, amount in ipairs({ 75, secret }) do
    presentation.config.batcher.DisplayRestricted = function(_, ...)
        queued = { ... }
    end
    presentation:Out({ event = "damage", amount = amount,
        result = { who = "you", ambiguous = true } })
    -- Then the exact damage survives without an icon or spell identity.
    assert(queued[1] == nil and queued[2] == amount)
    assert(queued[4] == nil,
        "ambiguous spell damage retained an icon")
end

-- Given confirmed proc damage with no identified spell.
for _, amount in ipairs({ 36, secret }) do
    -- When readable and restricted critical hits reach presentation.
    presentation:Out({ event = "damage", amount = amount, crit = true,
        result = { who = "you", proc = true } })

    -- Then both keep their amount and critical flag without a guessed name.
    assert(queued[1] == nil and queued[2] == amount and queued[3])
    assert(queued[4] == nil,
        "unidentified proc damage retained an icon")
end

-- Given a proc whose spell identity is available to presentation.
-- When its damage is drawn.
presentation:Out({ event = "damage", amount = 24,
    result = { who = "you", proc = true, procSpell = 601 } })

-- Then the identified source retains its own spell and icon.
assert(queued[1] == 601 and queued[2] == 24)
assert(queued[4] == "icon-601")

-- Describe: your lines on a unit other than your target go to the area beside Outgoing.
do
	local Batcher = dofile("Components/OutgoingBatcher.lua")
	local Areas = dofile("Display/ScrollAreas.lua")
	local function Event(fields)
		fields.scrollArea = fields.scrollArea or "Outgoing"
		if fields.scrollAreaOther == nil then fields.scrollAreaOther = "OutgoingOther" end
		return fields
	end
	local areaProfile = {
		scrollAreas = {
			Outgoing = { name = "Outgoing" },
			OutgoingOther = { name = "Outgoing (others)", disabled = true },
			OutgoingPet = { name = "Outgoing PET" },
			Custom = { name = "Custom" },
			Notification = { name = "Notification" },
		},
		events = {
			OUTGOING_SPELL_DAMAGE = Event({ message = "%a" }),
			OUTGOING_SPELL_DAMAGE_CRIT = Event({ message = "%a!", isCrit = true }),
			OUTGOING_SPELL_DOT = Event({ message = "dot %a" }),
			OUTGOING_SPELL_DAMAGE_SHIELD = Event({ message = "shield %a" }),
			OUTGOING_RANGED_DAMAGE = Event({ message = "ranged %a" }),
			OUTGOING_HEAL = Event({ message = "heal %a" }),
			OUTGOING_SPELL_MISS = Event({ message = "miss" }),
			PET_OUTGOING_SPELL_DAMAGE = Event({ message = "pet %a", scrollArea = "OutgoingPet" }),
		},
	}
	local masterAreas = { OutgoingOther = { name = "Outgoing (others)", disabled = true } }
	Areas:Configure({
		getProfile = function() return areaProfile end,
		getMasterProfile = function() return { scrollAreas = masterAreas } end,
		defaultArea = "Notification",
	})
	Areas:Update()
	local lines, pending = {}, {}
	local function Line(settings, message, amount)
		lines[#lines + 1] = { settings = settings, area = settings.scrollArea,
			message = message, amount = amount }
	end
	local function Flush()
		local callbacks = pending
		pending = {}
		for _, callback in ipairs(callbacks) do callback() end
	end
	local after = function(_, callback) pending[#pending + 1] = callback end
	local batcher = Batcher:New({
		getProfile = function() return areaProfile end,
		formatAmount = function(amount) return tostring(amount) end,
		formatEventMessage = function(_, amount) return tostring(amount) end,
		display = function(settings, message) Line(settings, message) end,
		displayRestricted = function(settings, amount) Line(settings, nil, amount) end,
		displayRestrictedGroup = function(settings, amounts) Line(settings, nil, amounts) end,
		after = after,
		getSpellTexture = function(id) return "icon-" .. id end,
		isAutoAttack = function(id) return id == 6603 end,
		autoAttackSpellID = 6603,
		scrollAreas = Areas,
		delay = 0.2,
	})
	local presentationConfig = {
		getProfile = function() return areaProfile end,
		batcher = batcher,
		after = after,
		getSpellTexture = function(id) return "icon-" .. id end,
		formatMessage = function(settings, record)
			return (settings.message:gsub("%%a", tostring(record.amount or "")))
		end,
		display = function(settings, message) Line(settings, message) end,
		displayRestricted = function(settings, amount) Line(settings, nil, amount) end,
	}
	-- Without scroll areas in its config, the presentation shows every line where its event puts it.
	local bare = Presentation:New(presentationConfig)
	local configured = {}
	for field, value in pairs(presentationConfig) do configured[field] = value end
	configured.scrollAreas = Areas
	local presentation = Presentation:New(configured)
	local function Hit(fields, plate, through)
		local record = { event = fields.event or "damage", amount = fields.amount,
			crit = fields.crit, missWord = fields.missWord, plate = plate,
			result = { who = fields.who or "you", spell = fields.spell, tick = fields.tick,
				shield = fields.shield, melee = fields.melee, hand = fields.hand } }
		;(through or presentation):Out(record)
	end
	local function Shown()
		local seen = {}
		for index, line in ipairs(lines) do
			seen[index] = line.area
		end
		lines = {}
		return seen
	end
	local events = areaProfile.events

	-- Given the area beside Outgoing switched off, as it is by default.
	-- When one hit of a spell lands on your target and one on another unit in one frame.
	Hit({ amount = 10, spell = 101 })
	Hit({ amount = 20, spell = 101 }, "nameplate2")
	-- Then they merge under the plain batch key into one line with the event's own settings.
	assert(batcher.batches["OUTGOING_SPELL_DAMAGE:101"], "the batch key changed")
	Flush()
	assert(#lines == 1 and lines[1].settings == events.OUTGOING_SPELL_DAMAGE
		and lines[1].message == "30", "a switched-off area changed how hits merge")
	lines = {}
	-- And a heal and a hidden amount on another unit keep their own event settings.
	Hit({ event = "heal", amount = 5, spell = 104 }, "nameplate2")
	Hit({ amount = secret, spell = 102 }, "nameplate2")
	Flush()
	assert(#lines == 2 and lines[1].settings == events.OUTGOING_SPELL_DAMAGE
		and lines[2].settings == events.OUTGOING_HEAL,
		"a switched-off area changed the settings of a line")
	lines = {}

	-- Given the area switched on.
	areaProfile.scrollAreas.OutgoingOther.disabled = false
	Areas:Update()

	-- When hits of every kind land on your target and on another unit.
	local kinds = {
		{ name = "a hit", fields = { spell = 101 } },
		{ name = "a tick", fields = { spell = 102, tick = true } },
		{ name = "a crit", fields = { spell = 101, crit = true } },
		{ name = "a damage shield", fields = { spell = 105, shield = true } },
		{ name = "a heal", fields = { event = "heal", spell = 104 } },
		{ name = "a miss", fields = { event = "miss", spell = 103, missWord = "MISS" } },
	}
	for _, kind in ipairs(kinds) do
		local fields = kind.fields
		fields.amount = fields.event ~= "miss" and 10 or nil
		Hit(fields)
		Hit(fields, "nameplate2")
		Flush()
		-- Then the one on your target stays in Outgoing and the other moves.
		local seen = Shown()
		assert(#seen == 2, kind.name .. " made " .. #seen .. " lines")
		assert(seen[1] == "Outgoing", kind.name .. " on your target moved to " .. tostring(seen[1]))
		assert(seen[2] == "OutgoingOther", kind.name .. " on another unit went to " .. tostring(seen[2]))
	end
	-- And a moved crit keeps its own event's settings, without changing the saved ones.
	Hit({ amount = 10, spell = 101, crit = true }, "nameplate2")
	Flush()
	assert(lines[1].area == "OutgoingOther" and lines[1].settings.isCrit
		and lines[1].settings.message == "%a!"
		and events.OUTGOING_SPELL_DAMAGE_CRIT.scrollArea == "Outgoing",
		"a moved crit lost its own settings or changed the saved ones")
	lines = {}
	-- And a crit heal follows its own event's area, apart from the normal heal's.
	events.OUTGOING_HEAL_CRIT = Event({ message = "heal %a!", isCrit = true, scrollArea = "Custom", scrollAreaOther = false })
	Hit({ event = "heal", amount = 10, spell = 104, crit = true }, "nameplate2")
	Flush()
	events.OUTGOING_HEAL_CRIT = nil
	assert(#lines == 1 and lines[1].area == "Custom", "a crit heal bound elsewhere moved")
	lines = {}
	-- And a disabled event shows nothing on another unit, without an error.
	events.OUTGOING_HEAL.disabled, events.OUTGOING_SPELL_DAMAGE.disabled = true, true
	Hit({ event = "heal", amount = 10, spell = 104 }, "nameplate2")
	Hit({ amount = 10, spell = 101 }, "nameplate2")
	Hit({ amount = secret, spell = 101 }, "nameplate2")
	Flush()
	events.OUTGOING_HEAL.disabled, events.OUTGOING_SPELL_DAMAGE.disabled = nil, nil
	assert(#lines == 0, "a disabled event showed a line on another unit")
	-- And a presentation without scroll areas leaves the line in Outgoing.
	Hit({ amount = 10, spell = 101 }, "nameplate2", bare)
	Flush()
	assert(#lines == 1 and lines[1].settings == events.OUTGOING_SPELL_DAMAGE,
		"a presentation without scroll areas moved a line")
	lines = {}
	-- And a crit follows its own event's second area, or the normal event's when its own is off.
	events.OUTGOING_SPELL_DAMAGE_CRIT.scrollAreaOther = "Custom"
	Hit({ amount = 10, spell = 101, crit = true }, "nameplate2")
	Flush()
	events.OUTGOING_SPELL_DAMAGE_CRIT.disabled = true
	Hit({ amount = 10, spell = 101, crit = true }, "nameplate2")
	Flush()
	events.OUTGOING_SPELL_DAMAGE_CRIT.disabled = nil
	events.OUTGOING_SPELL_DAMAGE_CRIT.scrollAreaOther = "OutgoingOther"
	local critAreas = Shown()
	assert(critAreas[1] == "Custom" and critAreas[2] == "OutgoingOther",
		"a crit did not follow its event's second area: " .. tostring(critAreas[1]) .. ", " .. tostring(critAreas[2]))

	-- When an event names another area as its second area.
	events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = "Custom"
	events.OUTGOING_HEAL.scrollAreaOther = "Custom"
	Hit({ amount = 10, spell = 101 }, "nameplate2")
	Hit({ event = "heal", amount = 5, spell = 104 }, "nameplate2")
	Hit({ amount = secret, spell = 102 }, "nameplate2")
	Hit({ amount = 40, spell = 101 })
	Flush()
	-- Then its lines on other units run there with the event's own settings, and the one on
	-- your target stays in the own area.
	assert(#lines == 4 and lines[1].area == "Custom" and lines[1].amount == secret
		and lines[2].area == "Custom" and lines[2].message == "10"
		and lines[2].settings.message == "%a" and lines[3].area == "Custom"
		and lines[4].area == "Outgoing",
		"an event's second area did not receive its lines on other units")
	assert(events.OUTGOING_SPELL_DAMAGE.scrollArea == "Outgoing", "the saved settings changed")
	lines = {}

	-- When the second area is no area, a switched-off one, one that does not exist, or the own area.
	areaProfile.scrollAreas.Off = { name = "Off", disabled = true }
	Areas:Update()
	for _, case in ipairs({ { "false", false }, { "nil" }, { "empty", "" },
		{ "switched off", "Off" }, { "deleted", "Nowhere" } }) do
		events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = case[2]
		Hit({ amount = 10, spell = 101 }, "nameplate2")
		Hit({ amount = secret, spell = 102 }, "nameplate2")
		Flush()
		-- Then the lines stay in the event's own area, with the plain batch key and the event's own settings.
		assert(#lines == 2 and lines[1].settings == events.OUTGOING_SPELL_DAMAGE
			and lines[2].settings == events.OUTGOING_SPELL_DAMAGE,
			"a second area that is " .. case[1] .. " moved a line")
		lines = {}
	end
	areaProfile.scrollAreas.Off = nil
	Areas:Update()
	for _, own in ipairs({ "Outgoing", "My Outgoing" }) do
		areaProfile.scrollAreas.Outgoing.name = "My Outgoing"
		Areas:Update()
		events.OUTGOING_SPELL_DAMAGE.scrollArea = own
		events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = "Outgoing"
		Hit({ amount = 10, spell = 101 })
		Hit({ amount = 20, spell = 101 }, "nameplate2")
		-- Then a second area equal to the own area, by key or by name, moves nothing.
		assert(batcher.batches["OUTGOING_SPELL_DAMAGE:101"], "a second area equal to the own one split the batch")
		Flush()
		assert(#lines == 1 and lines[1].message == "30" and lines[1].area == own,
			"a second area equal to the own area moved a line")
		lines = {}
	end
	areaProfile.scrollAreas.Outgoing.name = "Outgoing"
	Areas:Update()
	events.OUTGOING_SPELL_DAMAGE.scrollArea = "Outgoing"
	events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = "OutgoingOther"
	events.OUTGOING_HEAL.scrollAreaOther = "OutgoingOther"

	-- When a ranged hit lands on another unit on Forever.
	MikSBT.Compatibility = { Client = { isForever = true } }
	Hit({ amount = 10, melee = true, hand = "ranged" }, "nameplate2")
	Flush()
	MikSBT.Compatibility = nil
	-- Then it moves with the ranged settings.
	assert(#lines == 1 and lines[1].settings.message == "ranged %a"
		and lines[1].settings.scrollArea == "OutgoingOther", "a ranged hit on another unit did not move")
	lines = {}

	-- When a heal on yourself and a pet's hit on another unit arrive.
	Hit({ event = "heal", amount = 7, spell = 104 })
	Hit({ amount = 9, spell = 106, who = "pet" }, "nameplate2")
	Flush()
	events.PET_OUTGOING_SPELL_DAMAGE.scrollArea = "Outgoing"
	Hit({ amount = 9, spell = 106, who = "pet" }, "nameplate2")
	Flush()
	events.PET_OUTGOING_SPELL_DAMAGE.scrollArea = "OutgoingPet"
	-- Then the heal stays in Outgoing and the pet's hit in its event's area.
	local seen = Shown()
	assert(seen[1] == "Outgoing" and seen[2] == "OutgoingPet" and seen[3] == "Outgoing",
		"a heal on yourself or a pet's hit moved")

	-- When the event is bound to another area, or names the renamed Outgoing area by its name.
	areaProfile.scrollAreas.Outgoing.name = "My Outgoing"
	Areas:Update()
	for _, own in ipairs({ "Custom", "Notification", "My Outgoing", "Outgoing" }) do
		events.OUTGOING_SPELL_DAMAGE.scrollArea = own
		Hit({ amount = 10, spell = 101 }, "nameplate2")
		Flush()
		-- Then its second area receives the line, whatever the own area is.
		seen = Shown()
		assert(seen[1] == "OutgoingOther", "an event bound to " .. own .. " showed in " .. tostring(seen[1]))
		-- And without a second area the line stays in the own area.
		events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = nil
		Hit({ amount = 10, spell = 101 }, "nameplate2")
		Flush()
		events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = "OutgoingOther"
		seen = Shown()
		assert(seen[1] == own, "an event without a second area showed in " .. tostring(seen[1]))
	end
	-- And an event without an own area moves its line too, also when Outgoing has no name.
	areaProfile.scrollAreas.Outgoing.name = nil
	Areas:Update()
	events.OUTGOING_SPELL_DAMAGE.scrollArea = nil
	Hit({ amount = 10, spell = 101 }, "nameplate2")
	Flush()
	assert(lines[1].area == "OutgoingOther", "an event without an own area did not move")
	lines = {}
	events.OUTGOING_SPELL_DAMAGE.scrollArea = "Outgoing"
	areaProfile.scrollAreas.Outgoing.name = "Outgoing"
	Areas:Update()

	-- When two hits land on other units and one on your target in one frame.
	Hit({ amount = 10, spell = 101 }, "nameplate2")
	Hit({ amount = 20, spell = 101 }, "nameplate3")
	Hit({ amount = 40, spell = 101 })
	Hit({ event = "heal", amount = 1, spell = 104 }, "nameplate2")
	Hit({ event = "heal", amount = 2, spell = 104 }, "nameplate3")
	Hit({ event = "heal", amount = 4, spell = 104 })
	Flush()
	-- Then the other units' hits merge among themselves, apart from the target's.
	assert(#lines == 4, "hits on the target and on other units merged: " .. #lines .. " lines")
	assert(lines[1].message == "30" and lines[1].settings.scrollArea == "OutgoingOther"
		and lines[2].message == "40" and lines[2].settings.scrollArea == "Outgoing",
		"hits on other units did not merge as hits on the target do")
	assert(lines[3].message == "heal 3" and lines[3].settings.scrollArea == "OutgoingOther"
		and lines[4].message == "heal 4" and lines[4].settings.scrollArea == "Outgoing",
		"heals on other units did not merge as heals on the target do")
	lines = {}

	-- When hidden amounts land on another unit, single and grouped.
	Hit({ amount = secret, spell = 102 }, "nameplate2")
	Hit({ amount = secret, spell = 102 })
	areaProfile.stackSimilarHits = true
	Hit({ amount = secret, spell = 8232 }, "nameplate2")
	Hit({ amount = secret, spell = 8232 }, "nameplate3")
	Hit({ amount = secret, spell = 8232 })
	Flush()
	areaProfile.stackSimilarHits = nil
	-- Then the single ones and the group follow the unit they landed on.
	assert(#lines == 4 and lines[1].amount == secret and lines[2].amount == secret
		and #lines[3].amount == 2 and lines[4].amount == secret,
		"hidden amounts were not shown as single and grouped: " .. #lines .. " lines")
	seen = Shown()
	assert(seen[1] == "OutgoingOther" and seen[2] == "Outgoing", "a hidden amount went to the wrong area")
	assert(seen[3] == "OutgoingOther" and seen[4] == "Outgoing",
		"a hidden group went to the wrong area or merged with the target's")

	-- When lines wait for their batch while their second area is switched off, or deleted.
	local custom = areaProfile.scrollAreas.Custom
	events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = "Custom"
	events.OUTGOING_HEAL.scrollAreaOther = "Custom"
	areaProfile.stackSimilarHits = true
	for _, way in ipairs({ "switched off", "deleted" }) do
		Hit({ amount = 10, spell = 101 }, "nameplate2")
		Hit({ amount = secret, spell = 8232 }, "nameplate2")
		Hit({ amount = secret, spell = 8232 }, "nameplate2")
		Hit({ event = "heal", amount = 5, spell = 104 }, "nameplate2")
		if way == "deleted" then areaProfile.scrollAreas.Custom = nil else custom.disabled = true end
		Areas:Update()
		Flush()
		areaProfile.scrollAreas.Custom, custom.disabled = custom, nil
		Areas:Update()
		-- Then a plain amount, a hidden group and a heal show in the event's own area.
		seen = Shown()
		assert(#seen == 3, "a line waiting for a " .. way .. " area was lost: " .. #seen .. " lines")
		for index, area in ipairs(seen) do
			assert(area == "Outgoing", "line " .. index .. " waiting for a " .. way
				.. " area showed in " .. tostring(area))
		end
	end
	areaProfile.stackSimilarHits = nil
	events.OUTGOING_SPELL_DAMAGE.scrollAreaOther = "OutgoingOther"
	events.OUTGOING_HEAL.scrollAreaOther = "OutgoingOther"
	-- And a heal waiting beside a plain amount still moves while the area stays on.
	Hit({ amount = 10, spell = 101 }, "nameplate2")
	Hit({ event = "heal", amount = 5, spell = 104 }, "nameplate2")
	Flush()
	seen = Shown()
	assert(#seen == 2 and seen[1] == "OutgoingOther" and seen[2] == "OutgoingOther",
		"waiting lines did not move while their area stayed on")

	local profileArea = areaProfile.scrollAreas.OutgoingOther

	-- When the area is switched off again, or a profile has no such area at all.
	areaProfile.scrollAreas.OutgoingOther = profileArea
	profileArea.disabled = true
	Areas:Update()
	Hit({ amount = 10, spell = 101 }, "nameplate2")
	areaProfile.scrollAreas.OutgoingOther, masterAreas.OutgoingOther = nil, nil
	Areas:Update()
	Hit({ amount = 20, spell = 102 }, "nameplate2")
	Flush()
	-- Then the lines show with the event's own settings.
	assert(#lines == 2 and lines[1].settings == events.OUTGOING_SPELL_DAMAGE
		and lines[2].settings == events.OUTGOING_SPELL_DAMAGE,
		"switching the area off did not restore the event's own display")
	MikSBT.Display = nil
end

-- Describe: the max combo alert doubles the resolved combo-point font size.
-- Given an inherited resource font and a green normal event color.
local Service = dofile("Display/DisplayService.lua")
local rendered = {}
profile.events.NOTIFICATION_RESOURCE_GAIN = { colorR = 0, colorG = 1, colorB = 0 }
Service:Configure({
	getProfile = function() return profile end,
	isModDisabled = function() return false end,
	scrollAreas = { Resolve = function() return { normalFontSize = 24 } end },
	fonts = {}, display = function(...) rendered[#rendered + 1] = { ... } end,
})
presentation.config.display = function(...) Service:DisplayEvent(...) end
presentation.config.displayResource = function(settings, amount, name)
	Service:DisplayEvent(settings, tostring(amount) .. " " .. name)
end
-- When a normal total is followed by the maximum alert.
presentation:ComboPoints(4, 5)
presentation:ComboPoints(5, 5)
-- Then only the alert becomes red and twice the effective normal font size.
assert(rendered[1][7] == 24 and rendered[2][7] == 48,
	"Finish Him did not double the resolved combo-point font")
assert(rendered[1][4] == 0 and rendered[1][5] == 1)
assert(rendered[2][4] == 1 and rendered[2][5] == 0 and rendered[2][6] == 0,
	"Finish Him did not use red text")

-- Describe: a partly blocked hit on you shows the amount blocked.
do
	local shown, hidden, pending, dealt = {}, {}, {}, {}
	local function Trailer(record)
		if not record.blocked then return nil end
		return record.blockedAmount
			and " <" .. record.blockedAmount .. " blocked>" or " <blocked>"
	end
	local blocking = Presentation:New({
		getProfile = function()
			return { events = { INCOMING_DAMAGE = { message = "-%a" } } }
		end,
		after = function(_, callback) pending[#pending + 1] = callback end,
		formatBlockedTrailer = Trailer,
		formatMessage = function(settings, record)
			return settings.message:gsub("%%a", tostring(record.amount))
				.. (Trailer(record) or "")
		end,
		display = function(_, message) shown[#shown + 1] = message end,
		displayRestricted = function(...) hidden[#hidden + 1] = { ... } end,
		batcher = { DisplayRestricted = function(_, ...) dealt[#dealt + 1] = { ... } end },
		getSpellTexture = function() return "icon" end,
	})
	local function Flush()
		for _, callback in ipairs(pending) do callback() end
		pending = {}
	end

	-- Given a hidden amount that was partly blocked.
	-- When it is drawn.
	blocking:In({ event = "damage", amount = secret, school = 1,
		blocked = true, blockedAmount = 3 })
	-- Then the trailer follows the hidden amount.
	assert(hidden[1][2] == secret and hidden[1][5] == " <3 blocked>",
		"a hidden partly blocked hit lost its trailer")

	-- Given readable hits merged into one line, two of them partly blocked.
	for _, blockedAmount in ipairs({ 3, false, 4 }) do
		blocking:In({ event = "damage", amount = 10, school = 1,
			blocked = blockedAmount and true or nil,
			blockedAmount = blockedAmount or nil })
	end
	Flush()
	-- Then the line keeps the total blocked.
	assert(shown[1] == "-30 <7 blocked>", "merged hits lost their blocked total")

	-- Given a merged line where one blocked amount is unknown.
	blocking:In({ event = "damage", amount = 10, school = 1,
		blocked = true, blockedAmount = 3 })
	blocking:In({ event = "damage", amount = 10, school = 1, blocked = true })
	Flush()
	-- Then the total is not guessed.
	assert(shown[2] == "-20 <blocked>", "a partly unknown total was guessed")

	-- Given hits of yours with hidden amounts, the first partly blocked.
	-- When they are drawn.
	for _, blocked in ipairs({ true, false }) do
		blocking:Out({ event = "damage", amount = secret, school = 1,
			blocked = blocked or nil,
			result = { who = "you", melee = true, hand = "main" } })
	end
	-- Then the trailer goes on with the blocked one, without an amount.
	assert(dealt[1][2] == secret and dealt[1][12] == " <blocked>",
		"a partly blocked hit of yours lost its trailer")
	assert(dealt[2][2] == secret and dealt[2][12] == nil,
		"an unblocked hit of yours got a trailer")
end
