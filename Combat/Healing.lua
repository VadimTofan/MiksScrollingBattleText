local ns = MikSBT.CombatEngine
local casts = {}
local targets = {}
local DIRECT_WINDOW, HOT_WINDOW, MAX_CASTS = 3, 30, 64

function ns.ResetHealing() casts, targets = {}, {} end

-- Whether a spell's description speaks of healing. Unreadable: no.
local function Heals(spell)
	if not (C_Spell and C_Spell.GetSpellDescription) then return false end
	local ok, text = pcall(C_Spell.GetSpellDescription, spell)
	if not ok or not ns.Text(text) then return false end
	return text:lower():find("heal", 1, true) ~= nil
end

function ns.NoteHealTarget(unit, target, guid, spell, now)
	if (unit ~= "player" and unit ~= "pet")
		or not ns.Text(guid) or not ns.Number(spell, 1) then return end
	local recipient, open
	if ns.Public(target) and (target == nil or target == "") then
		-- Sent with no target at all (Mend Pet on Forever, 1.60.1.70862): the
		-- spell picks its own recipient, you or your pet. A hidden target is
		-- not this case and is still not guessed.
		open = true
	else
		if not ns.Text(target) or type(UnitName) ~= "function" then return end
		for _, token in ipairs({ "player", "pet" }) do
			local ok, name, realm = pcall(UnitName, token)
			if ok and ns.Text(name) and (target == name
				or (ns.Text(realm) and target == name .. "-" .. realm)) then
				if recipient then return end
				recipient = token
			end
		end
		if not recipient then return end
	end
	for index = #targets, 1, -1 do
		if now - targets[index].at > HOT_WINDOW then
			table.remove(targets, index)
		end
	end
	targets[#targets + 1] = { unit = unit, guid = guid, spell = spell,
		key = recipient, open = open, at = now }
	while #targets > MAX_CASTS do table.remove(targets, 1) end
end

function ns.NoteHealCast(unit, spell, key, now, guid)
	local helpful = C_Spell and C_Spell.IsSpellHelpful
		and C_Spell.IsSpellHelpful(spell)
	if not ns.Bool(helpful) or not helpful then return end
	local recipient, open
	if ns.Text(guid) then
		for index = #targets, 1, -1 do
			local target = targets[index]
			if target.unit == unit and target.guid == guid
				and target.spell == spell then
				if now >= target.at and now - target.at <= HOT_WINDOW then
					recipient, open = target.key, target.open
				end
				table.remove(targets, index)
				break
			end
		end
	end
	if recipient then
		key = recipient
	else
		local selfTarget = UnitIsUnit("target", "player")
		if ns.Bool(selfTarget) and selfTarget then key = "player" end
		local petTarget = UnitIsUnit("target", "pet")
		if ns.Bool(petTarget) and petTarget then key = "pet" end
	end
	-- A healing spell sent with no target, while neither you nor your pet is
	-- selected: its recipient is whichever of the two its heal lands on
	-- (MatchHealing). The selected enemy is not it.
	open = open and key ~= "player" and key ~= "pet" and Heals(spell) or nil
	if open then key = nil end
	if not key and not open then return end
	for i = #casts, 1, -1 do
		if now - casts[i].at > HOT_WINDOW then table.remove(casts, i) end
	end
	casts[#casts + 1] = {
		at = now, spell = spell, key = key, open = open,
		who = unit == "pet" and "pet" or "you",
	}
	while #casts > MAX_CASTS do table.remove(casts, 1) end
end

function ns.MatchHealing(key, now, tick, confirmed)
	if confirmed == false then return nil end
	local best, age, ambiguous
	for _, cast in ipairs(casts) do
		local since = now - cast.at
		if cast.key == key and since >= 0
			and since <= (tick and HOT_WINDOW or DIRECT_WINDOW)
			and (tick or not cast.used) then
			if not age or since < age then
				best, age, ambiguous = cast, since, false
			elseif since == age and cast.spell ~= best.spell then
				ambiguous = true
			end
		end
	end
	-- No cast on this unit: a cast still open to you or your pet takes it,
	-- and is bound to that unit from then on.
	if not best and (key == "player" or key == "pet") then
		for _, cast in ipairs(casts) do
			local since = now - cast.at
			if cast.open and since >= 0
				and since <= (tick and HOT_WINDOW or DIRECT_WINDOW)
				and (tick or not cast.used)
				and (not age or since < age) then
				best, age = cast, since
			end
		end
		if best then best.key, best.open = key, nil end
	end
	if not best or ambiguous then return nil end
	best.used = true
	return { who = best.who, spell = best.spell, tick = tick }
end

function ns.TagIncomingHeal(record, unit, now)
	local result = ns.MatchHealing(unit, now, record.tick, nil)
	if not result then return end
	record.selfHeal = unit == "player" and result.who == "you"
	record.spell = result.spell
	record.icon = ns.SpellIcon(result.spell)
	record.name = ns.SpellName(result.spell)
	return result
end

function ns.RekeyHealing(old, new)
	for _, cast in ipairs(casts) do
		if cast.key == old then cast.key = new end
	end
end

function ns.ForgetHealing(key)
	for i = #casts, 1, -1 do
		if casts[i].key == key then table.remove(casts, i) end
	end
end
