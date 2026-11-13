-- Reuse the full legacy runtime regression fixture before exercising both
-- modern clients through the real main module and real adapted reader.
dofile("tests/lua/notification_runtime.lua")
MikSBT.Configuration = MikSBT.Configuration or {}
dofile("Configuration/ResourcePolicy.lua")

local createFrame = CreateFrame
local frames, timers, displayed = {}, {}, {}
local popups, reloads = {}, 0
local chatMessages = {}
MikSBT.Print = function(message)
	chatMessages[#chatMessages + 1] = message
end
-- Given Blizzard's shared popup system, MSBT must leave it untouched.
StaticPopupDialogs = setmetatable({}, {
	__newindex = function()
		error("reload prompt wrote to Blizzard's shared popup definitions")
	end,
})
RELOADUI, CANCEL = "Reload UI", "Cancel"
StaticPopup_Show = function()
	error("reload prompt used Blizzard's shared popup frames")
end
ReloadUI = function() reloads = reloads + 1 end
CreateFrame = function(kind, name, parent, template)
	local frame = createFrame(kind, name, parent, template)
	frame.children, frame.fontStrings = {}, {}
	if parent and parent.children then
		parent.children[#parent.children + 1] = frame
	end
	function frame:SetSize() end
	function frame:SetPoint() end
	function frame:EnableMouse() end
	function frame:SetClampedToScreen() end
	function frame:SetBackdrop() end
	function frame:SetBackdropColor() end
	function frame:SetBackdropBorderColor() end
	function frame:SetText(text) self.text = text end
	function frame:SetFrameStrata(strata)
		if strata == "DIALOG" then popups[#popups + 1] = self end
	end
	function frame:CreateFontString()
		local fontString = {}
		function fontString:SetPoint() end
		function fontString:SetWidth() end
		function fontString:SetText(text) self.text = text end
		self.fontStrings[#self.fontStrings + 1] = fontString
		return fontString
	end
	frames[#frames + 1] = frame
	return frame
end
local now = 10
GetTime = function() return now end
C_Timer.After = function(delay, callback)
	timers[#timers + 1] = { at = now + delay, callback = callback }
end
C_Timer.NewTicker = function() return { Cancel = function() end } end
UnitExists = function(unit) return unit == "target" end
UnitIsUnit = function(a, b) return a == b end
UnitCanAttack = function() return true end
UnitXP = function() return 0 end
UnitXPMax = function() return 100 end
GetMoney = function() return 0 end
UnitHealthMax = function() return 1000 end
local inCombat = true
InCombatLockdown = function() return inCombat end
C_Spell = {
	IsSpellHelpful = function() return false end,
	GetSpellDescription = function() return "Deals 42 Fire damage." end,
	GetSpellTexture = function() return "icon" end,
	GetSpellName = function() return "Test spell" end,
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
DEFAULT_COMBATLOG_FILTER_TEMPLATE = { settings = {}, colors = {} }
Enum.PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 }
Enum.CombatLogMessageOrder = { Oldest = 0, Newest = 1 }
local meterReads = 0
C_DamageMeter = {
	GetCombatSessionSourceFromType = function() meterReads = meterReads + 1 end,
}
Enum.DamageMeterType = { DamageDone = 0 }
local swingEventsSupported = false
C_EventUtils = { IsEventValid = function(event)
	return swingEventsSupported or event ~= "PLAYER_SWING"
end }
MikSBT.Animations.DisplayEvent = function(settings, message, icon, _, ...)
	displayed[#displayed + 1] = { settings, message, icon, ... }
end
local events = MikSBT.Profiles.currentProfile.events
events.OUTGOING_SPELL_DAMAGE = { message = "Hit %a", scrollArea = "Custom outgoing" }
events.INCOMING_DAMAGE = { message = "Taken %a", scrollArea = "Custom incoming" }
events.INCOMING_DAMAGE_CRIT = nil
events.NOTIFICATION_COMBAT_ENTER = { message = "+Combat" }
events.NOTIFICATION_COMBAT_LEAVE = { message = "-Combat" }
local function Load(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("^\239\187\191", "")
	file:close()
	assert(loadstring(source, "@" .. path))()
end
for _, path in ipairs({
	"Combat/Context.lua", "Combat/Helpers.lua", "Combat/Mine.lua",
	"Combat/Spells.lua", "Combat/Healing.lua", "Combat/Reader.lua",
	"Components/CombatLogFilter.lua",
	"Components/CombatPresentation.lua", "Components/CombatEngine.lua",
}) do Load(path) end
local function Dispatch(event, ...)
	for _, frame in ipairs(frames) do
		if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
	end
end
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

for _, forever in ipairs({ false, true }) do
	swingEventsSupported = forever
	MikSBT.Profiles.currentProfile.damageColoringDisabled = true
	-- Isolate each client's fixture from palette edits in the previous run.
	for _, key in pairs(MikSBT.Main.damageColorProfileEntries) do
		MikSBT.Profiles.currentProfile[key] = nil
	end
	-- Given a modern client and the player's existing event configuration.
	timers, displayed = {}, {}
	Blizzard_CombatLog_Filters = { filters = {}, currentFilter = 1 }
	MikSBT.Compatibility.Client.isForever = forever
	MikSBT.Compatibility.Client.isMainline = not forever
	MikSBT.Compatibility.Client.hasModernAPI = true
	Load("MSBTMain.lua")
	local main = MikSBT.Main
	local mainFrame = frames[#frames]
	main.Enable()
	-- Given first-run setup while the player is in combat.
	-- When the missing filter is checked, then no popup interrupts combat.
	local popupCount = #popups
	local chatCount = #chatMessages
	assert(popupCount == (forever and 1 or 0))
	inCombat = false
	Dispatch("ADDON_LOADED", "Blizzard_CombatLog")

	-- Then leaving combat allows one persistent, dismissible reload prompt.
	assert(#popups == popupCount + 1, "missing filter did not show a popup")
	assert(#chatMessages == chatCount,
		"reload popup also printed a redundant chat reminder")
	local dialog = popups[#popups]
	assert(dialog.fontStrings[2].text:find("In order for MSBT to start", 1, true))
	local reloadButton, cancelButton = dialog.children[1], dialog.children[2]
	assert(reloadButton.text == RELOADUI and cancelButton.text == CANCEL)
	assert(dialog:IsVisible())
	assert(reloads == (forever and 1 or 0), "setup reloaded automatically")

	-- Given Cancel on MSBT's own window.
	-- When setup is checked again, then it stays dismissed without reloading.
	cancelButton.scripts.OnClick(cancelButton)
	assert(not dialog:IsVisible(), "cancel did not hide the window")
	Dispatch("ADDON_LOADED", "AnotherAddon")
	main.Disable()
	main.Enable()
	assert(#popups == popupCount + 1, "cancelled popup reopened")
	assert(reloads == (forever and 1 or 0))

	-- When Reload UI is accepted, then it invokes the game's reload action.
	reloadButton.scripts.OnClick(reloadButton)
	assert(not dialog:IsVisible())
	assert(reloads == (forever and 2 or 1))
	inCombat = true
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 999, 4)
	Advance(0.4)
	Advance(0.3)
	assert(#displayed == 0, "outgoing damage was guessed before filter setup")

	-- When the first session saves the combat filter at logout.
	Dispatch("PLAYER_LOGOUT")
	main.Disable()
	main.Enable()
	-- Then an activated filter needs no further setup popup.
	assert(#popups == popupCount + 1)

	-- Given an already visible setup prompt while saved filters finish loading.
	dialog:Show()
	-- When maintenance sees the now-valid filter.
	Dispatch("ADDON_LOADED", "Blizzard_CombatLog")
	-- Then the stale prompt closes instead of requesting another reload.
	assert(not dialog:IsVisible(), "ready filter left a stale reload popup visible")
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("PLAYER_REGEN_DISABLED")
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 42, 4)
	local filter = Blizzard_CombatLog_Filters.filters[1]
	local rgb = filter.colors.eventColoring.SPELL_DAMAGE
	Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
	Advance(0.02)
	Advance(0.31)

	-- Then one outgoing hit keeps the configured message, area and icon.
	local hits = 0
	for _, record in ipairs(displayed) do
		if record[1] == events.OUTGOING_SPELL_DAMAGE then
			hits = hits + 1
			assert(record[2] == "Hit 42" and record[3] == "icon")
			assert(record[1].scrollArea == "Custom outgoing")
		end
	end
	assert(hits == 1, "modern combat did not produce exactly one hit")
	assert(not mainFrame.events.UNIT_COMBAT, "legacy incoming reader remained active")
	assert(meterReads == 0, "duplicate damage-meter source was queried")

	if forever then
		for _, spell in ipairs({ 2973, 78, 6807 }) do
			-- Given a queued strike with two opaque physical hit reports.
			Advance(4)
			local beforeStrike = #displayed
			local opaqueZero, opaqueDamage = {}, {}
			local secretCheck = issecretvalue
			local spellDescription = C_Spell.GetSpellDescription
			issecretvalue = function(value)
				return value == opaqueZero or value == opaqueDamage
			end
			C_Spell.GetSpellDescription = function(id)
				if id == 6807 then
					return "Increases the druid's next attack by 18 damage."
				elseif id == spell then
					return "A strong attack that increases melee damage by 5."
				end
				return spellDescription(id)
			end

			-- When the cast, zero, real hit and one line share the same frame.
			Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, spell)
			Dispatch("UNIT_COMBAT", "target", "WOUND", "", opaqueZero, 1)
			Dispatch("UNIT_COMBAT", "target", "WOUND", "", opaqueDamage, 1)
			Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
			Advance(0.02)
			Advance(0.31)

			-- Then only the real amount reaches MSBT's native text renderer.
			assert(#displayed == beforeStrike + 1,
				"queued strike produced missing or duplicate damage text")
			local hit = displayed[#displayed]
			assert(hit[1] == events.OUTGOING_SPELL_DAMAGE)
			assert(hit[2] == "Hit %s" and hit[3] == "icon")
			assert(hit[4] == opaqueDamage,
				"queued strike's zero report reached the final renderer")
			issecretvalue = secretCheck
			C_Spell.GetSpellDescription = spellDescription
		end

		-- Given a shaman with Windfury and two unidentified physical procs.
		Advance(4)
		local beforeBurst = #displayed
		local firstProc, normalHit, delayedProc = {}, {}, {}
		local secretCheck = issecretvalue
		local meleeSettings = events.OUTGOING_DAMAGE
		local weaponEnchantInfo = GetWeaponEnchantInfo
		local unitClass = UnitClass
		UnitClass = function() return "Shaman", "SHAMAN" end
		GetWeaponEnchantInfo = function()
			return true, 300000, 0, 283, false, 0, 0, 0
		end
		events.OUTGOING_DAMAGE = { message = "Swing %a", scrollArea = "Outgoing" }
		issecretvalue = function(value)
			return value == firstProc or value == normalHit or value == delayedProc
		end
		local melee = filter.colors.eventColoring.SWING_DAMAGE
		local windfuryIcon = "icon"

		-- When their confirmations share a swing but their reports cross frames.
		Dispatch("PLAYER_SWING", 3.8, 0)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", melee.r, melee.g, melee.b, 1)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
		Advance(0.213)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
		Advance(0.01)
		Advance(0.362)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
		Advance(0.01)
		Advance(0.414)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", delayedProc, 1)
		Advance(0.01)

		-- Then the final renderer receives both procs and the ordinary swing.
		assert(#displayed == beforeBurst + 3,
			"the delayed Windfury hit did not reach the real display pipeline")
		assert(displayed[beforeBurst + 1][4] == firstProc)
		assert(displayed[beforeBurst + 1][1] == events.OUTGOING_SPELL_DAMAGE)
		assert(displayed[beforeBurst + 1][3] == windfuryIcon,
			"an early shaman proc did not receive Windfury's icon")
		assert(displayed[beforeBurst + 2][4] == normalHit)
		assert(displayed[beforeBurst + 2][1] == events.OUTGOING_DAMAGE)
		assert(displayed[beforeBurst + 3][4] == delayedProc)
		assert(displayed[beforeBurst + 3][1] == events.OUTGOING_SPELL_DAMAGE)
		assert(displayed[beforeBurst + 3][3] == windfuryIcon,
			"a delayed shaman proc did not receive Windfury's icon")

		-- Given another burst with an unidentified extra-attack grant.
		Advance(4)
		local beforeOffsetBurst = #displayed
		Dispatch("PLAYER_SWING", 3.8, 0)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", melee.r, melee.g, melee.b, 1)
		Advance(0.099)
		local extra = filter.colors.eventColoring.SPELL_EXTRA_ATTACKS
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", extra.r, extra.g, extra.b, 1)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)

		-- When the proc reports follow the normal hit by 0.379 and 0.873 s.
		Advance(0.213)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
		Advance(0.01)
		Advance(0.369)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
		Advance(0.01)
		Advance(0.484)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "GLANCING", delayedProc, 1)
		Advance(0.01)

		-- Then the event display receives every original amount exactly once.
		assert(#displayed == beforeOffsetBurst + 3,
			"offset Windfury confirmations lost damage before presentation")
		assert(displayed[beforeOffsetBurst + 1][4] == normalHit)
		assert(displayed[beforeOffsetBurst + 2][4] == firstProc)
		assert(displayed[beforeOffsetBurst + 3][4] == delayedProc)
		assert(displayed[beforeOffsetBurst + 2][3] == windfuryIcon,
			"a shaman extra-attack proc lost the Windfury fallback")
		assert(displayed[beforeOffsetBurst + 3][3] == windfuryIcon)

		-- Given stacking is enabled for a shaman's next Windfury burst.
		local previousStacking = MikSBT.Profiles.currentProfile.stackSimilarHits
		MikSBT.Profiles.currentProfile.stackSimilarHits = true
		Advance(4)
		local beforeStackedBurst = #displayed
		Dispatch("PLAYER_SWING", 3.8, 0)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", melee.r, melee.g, melee.b, 1)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)

		-- When the two opaque procs arrive across the normal batch window.
		Advance(0.213)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", firstProc, 1)
		Advance(0.01)
		Advance(0.362)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", normalHit, 1)
		Advance(0.01)
		Advance(0.414)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", delayedProc, 1)
		Advance(1.1)

		-- Then one Windfury line holds both values, separate from the swing.
		assert(#displayed == beforeStackedBurst + 2,
			"stacking did not combine the restricted Windfury burst")
		local stacked = displayed[#displayed]
		assert(stacked[2] == "%s + %s [2 hits]",
			"restricted Windfury group lost its native format placeholders")
		assert(stacked[3] == windfuryIcon)
		assert(stacked[4] == firstProc and stacked[5] == delayedProc,
			"stacked Windfury changed or dropped restricted damage")
		MikSBT.Profiles.currentProfile.stackSimilarHits = previousStacking
		issecretvalue = secretCheck
		GetWeaponEnchantInfo = weaponEnchantInfo
		UnitClass = unitClass
		events.OUTGOING_DAMAGE = meleeSettings
	end

	-- Given resource notifications and the resource labels supplied by Blizzard.
	-- Generic template cases intentionally have no class context.
	local genericResourceClass = UnitClass
	UnitClass = nil
	local resourceSettings = { message = "%a - %p", scrollArea = "Notification" }
	events.NOTIFICATION_RESOURCE_GAIN = resourceSettings
	MANA, HOLY_POWER = "Mana", "Holy Power"
	local resourceAmount, resourceToken = 20, "MANA"
	C_CombatText = { GetCurrentEventInfo = function()
		return resourceAmount, resourceToken
	end }
	local beforeResource = #displayed

	-- When direct and periodic resource gains arrive through the real reader.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	resourceAmount, resourceToken = 1, "HOLY_POWER"
	Dispatch("COMBAT_TEXT_UPDATE", "PERIODIC_ENERGIZE")

	-- Then the amount, resource name, and configured area reach the display.
	assert(#displayed == beforeResource + 2, "resource gains were delayed")
	assert(displayed[beforeResource + 1][2] == "20 Mana")
	assert(displayed[beforeResource + 2][2] == "1 Holy Power")
	assert(displayed[#displayed][1] == resourceSettings)

	-- Given a readable combo-point gain on either modern client.
	resourceAmount, resourceToken = 1, "COMBO_POINTS"
	-- When it reaches the real reader, presentation, and template formatter.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	-- Then it immediately displays the requested resource label.
	assert(displayed[#displayed][2] == "1 Combo Point")

	-- Given the simple template or no configured resource template.
	for _, message in ipairs({ "%a %p", false }) do
		resourceSettings.message = message or nil
		-- When a mana gain reaches the real formatter.
		resourceAmount, resourceToken = 8, "MANA"
		Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
		-- Then amount and resource use one space without a separator.
		assert(displayed[#displayed][2] == "8 Mana")
	end
	resourceSettings.message = "%a - %p"
	resourceAmount, resourceToken = 1, "COMBO_POINTS"

	-- Given the resource editor has unchecked combo points in this profile.
	MikSBT.Profiles.currentProfile.resourceExclusions = { COMBO_POINTS = true }
	beforeResource = #displayed
	-- When a combo point and a separate energy gain reach the real runtime.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	resourceAmount, resourceToken = 20, "ENERGY"
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	-- Then only energy is displayed on both Retail and Forever.
	assert(#displayed == beforeResource + 1)
	assert(displayed[#displayed][2] == "20 Energy")
	MikSBT.Profiles.currentProfile.resourceExclusions = {}

	-- Given Blizzard supplies the amount as text, as its own renderer supports.
	resourceAmount, resourceToken = "25", "MANA"
	beforeResource = #displayed
	-- When the gain arrives, then its numeric text is displayed as an amount.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(#displayed == beforeResource + 1, "numeric text dropped a resource gain")
	assert(displayed[#displayed][2] == "25 Mana")

	-- Given number shortening is enabled and Blizzard supplies a custom label.
	local previousShortening = MikSBT.Profiles.currentProfile.shortenNumbers
	MikSBT.Profiles.currentProfile.shortenNumbers = true
	resourceAmount, resourceToken = "001250", "Energy supplied by Blizzard"
	-- When the gain is displayed, then both supplied strings stay unchanged.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(displayed[#displayed][2] == "001250 Energy supplied by Blizzard")
	MikSBT.Profiles.currentProfile.shortenNumbers = previousShortening

	-- Given a druid currently using energy in cat form.
	local resourceClass, resourcePower = UnitClass, UnitPowerType
	UnitClass = function() return "Druide", "DRUID" end
	UnitPowerType = function() return 3, "ENERGY" end
	beforeResource = #displayed
	resourceAmount = 9
	-- When gains belonging to other forms arrive through the real reader.
	for _, token in ipairs({ "RAGE", "LUNAR_POWER" }) do
		resourceToken = token
		Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	end
	-- Then neither is shown, while a cat energy gain remains visible.
	assert(#displayed == beforeResource)
	resourceToken = "ENERGY"
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(displayed[#displayed][2] == "9 Energy")
	-- When the player shifts to bear, rage becomes valid immediately.
	UnitPowerType = function() return 1, "RAGE" end
	resourceToken = "RAGE"
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(displayed[#displayed][2] == "9 Rage")
	UnitClass, UnitPowerType = resourceClass, resourcePower

	-- Given a restricted amount and a restricted resource token in combat.
	local secretResource, secretToken = {}, {}
	local previousSecretCheck = issecretvalue
	issecretvalue = function(value)
		return value == secretResource or value == secretToken
			or (previousSecretCheck and previousSecretCheck(value)) or false
	end
	resourceAmount, resourceToken = secretResource, "MANA"

	-- When only the amount is hidden, then the resource name stays visible.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(displayed[#displayed][2] == "%s %s")
	assert(displayed[#displayed][4] == secretResource)
	assert(displayed[#displayed][5] == "Mana")

	-- When the resource token is hidden too, then its label reaches rendering.
	resourceToken = secretToken
	beforeResource = #displayed
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(#displayed == beforeResource + 2, "hidden resource type dropped a gain")
	assert(displayed[#displayed][2] == "%s %s")
	assert(displayed[#displayed][4] == secretResource)
	assert(displayed[#displayed][5] == secretToken,
		"hidden resource name was replaced by a generic label")

	-- Given a customized template with reversed and repeated resource tokens.
	resourceSettings.message = "%p: %a (%p) 100%"
	-- When the same opaque values arrive, then template order is preserved.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	local resource = displayed[#displayed]
	assert(resource[2] == "%s: %s (%s) 100%%")
	assert(resource[4] == secretToken and resource[5] == secretResource)
	assert(resource[6] == secretToken)
	resourceSettings.message = "%a - %p"
	issecretvalue = previousSecretCheck

	-- Given zero, negative, missing, and invalid amounts.
	beforeResource = #displayed
	resourceToken = "MANA"
	-- When unusable gains arrive, then no notification is displayed.
	for _, amount in ipairs({ 0, -5, "invalid" }) do
		resourceAmount = amount
		Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	end
	resourceAmount = nil
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(#displayed == beforeResource)

	-- Given a disabled gain event, then subsequent gains stay hidden.
	resourceSettings.disabled = true
	resourceAmount = 10
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(#displayed == beforeResource)
	assert(resourceSettings.message == "%a - %p", "resource template was mutated")
	resourceSettings.disabled = nil
	UnitClass = genericResourceClass

	-- Given absorb templates for player and pet melee and spell attacks.
	for _, case in ipairs({
		{ key = "OUTGOING_ABSORB", who = "you", melee = true },
		{ key = "OUTGOING_SPELL_ABSORB", who = "you" },
		{ key = "PET_OUTGOING_ABSORB", who = "pet", melee = true },
		{ key = "PET_OUTGOING_SPELL_ABSORB", who = "pet" },
	}) do
		local settings = { message = "Absorb! <%a> (%s)",
			scrollArea = "Custom outgoing" }
		events[case.key] = settings
		local beforeAbsorb = #displayed

		-- When a fully absorbed hit has no amount from the reader.
		MikSBT.CombatEngine.liveRouter:Out({
			event = "miss", missWord = "Absorb",
			result = { who = case.who, melee = case.melee, spell = 123 },
		})

		-- Then only the fallback text appears with the original settings and icon.
		assert(#displayed == beforeAbsorb + 1)
		local absorb = displayed[#displayed]
		assert(absorb[2] == "Absorb!",
			"missing absorb amount leaked the template: " .. absorb[2])
		assert(absorb[1] == settings and absorb[3] == "icon")
		assert(settings.message == "Absorb! <%a> (%s)")
	end

	-- Given an absorbed spell hit with a known amount.
	-- When it is formatted through the same presentation adapter.
	MikSBT.CombatEngine.liveRouter:Out({
		event = "miss", missWord = "Absorb", amount = 17,
		result = { who = "you", spell = 123 },
	})
	Advance(0.13)
	-- Then the configured amount and spell name are preserved.
	assert(displayed[#displayed][2] == "Absorb! <17> (Spell 123)",
		"known absorb amount changed: " .. displayed[#displayed][2])

	-- Given similar incoming hits arriving 150 ms apart.
	local beforeDamage = #displayed
	Dispatch("UNIT_COMBAT", "player", "WOUND", "", 25, 1)
	-- When the second hit arrives within the 200 ms grouping window.
	Advance(0.15)
	assert(#displayed == beforeDamage, "incoming damage flushed before 200 ms")
	Dispatch("UNIT_COMBAT", "player", "WOUND", "", 15, 1)
	Advance(0.06)
	-- Then one combined damage line is displayed after the window closes.
	assert(#displayed == beforeDamage + 1)
	Dispatch("PLAYER_REGEN_ENABLED")
	-- Then the incoming window and combat notices retain their settings.
	local taken, entered, left = 0, 0, 0
	for _, record in ipairs(displayed) do
		if record[1] == events.INCOMING_DAMAGE then
			taken = taken + 1
			assert(record[2] == "Taken 40")
		end
		if record[1] == events.NOTIFICATION_COMBAT_ENTER then entered = entered + 1 end
		if record[1] == events.NOTIFICATION_COMBAT_LEAVE then left = left + 1 end
	end
	assert(taken == 1 and entered == 1 and left == 1)

	-- Given the existing Hide Skills setting is enabled.
	local profile = MikSBT.Profiles.currentProfile
	profile.hideSkills = true
	events.OUTGOING_SPELL_DAMAGE.message = "Hit %a (%s)"
	events.INCOMING_DAMAGE.message = "Taken %a (%s)"
	-- When outgoing and incoming records include their spell names.
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 43, 4)
	Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
	MikSBT.CombatEngine.liveRouter:In({
		event = "damage", amount = 26, name = "Fireball", school = 1,
	})
	Advance(0.02)
	Advance(0.31)
	-- Then amounts and icons remain, with spell names and empty brackets removed.
	local hiddenOutgoing, hiddenIncoming = false, false
	for _, record in ipairs(displayed) do
		if record[1] == events.OUTGOING_SPELL_DAMAGE and record[2] == "Hit 43" then
			hiddenOutgoing = record[3] == "icon"
		end
		if record[1] == events.INCOMING_DAMAGE and record[2] == "Taken 26" then
			hiddenIncoming = true
		end
	end
	assert(hiddenOutgoing and hiddenIncoming, "Hide Skills did not hide combat spell names")
	-- Buff names remain useful notification text while combat names are hidden.
	events.NOTIFICATION_BUFF = { message = "[%sl]" }
	MikSBT.CombatEngine.liveRouter:Aura(true, false, "Arcane Intellect", "buff-icon")
	assert(displayed[#displayed][2] == "[Arcane Intellect]")
	profile.hideSkills = false
	events.OUTGOING_SPELL_DAMAGE.message = "Hit %a"
	events.INCOMING_DAMAGE.message = "Taken %a"

	-- Given incoming heals have their own styling and damage-school colours are on.
	profile.damageColoringDisabled = false

	do
		-- Given custom school colors and templates with spell names.
		local savedFrost, savedShadow = profile.frost, profile.shadow
		local savedStacking = profile.stackSimilarHits
		local keys = { "OUTGOING_SPELL_DAMAGE", "OUTGOING_SPELL_DAMAGE_CRIT",
			"OUTGOING_SPELL_DOT", "PET_OUTGOING_SPELL_DAMAGE" }
		local savedEvents = {}
		for _, key in ipairs(keys) do
			savedEvents[key] = events[key]
			events[key] = { message = "Hit %a (%s)", scrollArea = "Outgoing" }
		end
		profile.frost = { colorR = 0, colorG = 0, colorB = 1 }
		profile.shadow = { colorR = 1, colorG = 0, colorB = 1 }
		profile.stackSimilarHits = false
		local function Out(amount, school, result, crit)
			MikSBT.CombatEngine.liveRouter:Out({ event = "damage",
				amount = amount, school = school, crit = crit, result = result
					or { who = "you", spell = 123 } })
		end

		-- When normal, critical, periodic and pet spell damage is displayed.
		for _, case in ipairs({
			{ school = 16, color = "0000ff", who = "you" },
			{ school = 32, color = "ff00ff", who = "you", crit = true },
			{ school = 32, color = "ff00ff", who = "you", tick = true },
			{ school = 16, color = "0000ff", who = "pet" },
		}) do
			Out(42, case.school, { who = case.who, spell = 123,
				tick = case.tick }, case.crit)
			Advance(0.31)
			-- Then only the number has the configured school color.
			assert(displayed[#displayed][2]
				== "Hit |cFF" .. case.color .. "42|r (Spell 123)",
				"outgoing school color missing or applied to spell name")
		end

		-- Given old disabled flags or an unknown school.
		for _, mode in ipairs({ "global", "school", "unknown" }) do
			profile.damageColoringDisabled = mode == "global"
			profile.frost.disabled = mode == "school"
			-- When another outgoing hit is rendered.
			Out(42, mode == "unknown" and 255 or 16)
			Advance(0.31)
			-- Then old flags cannot suppress a known school's baseline color.
			local expected = mode == "unknown" and "Hit 42 (Spell 123)"
				or "Hit |cFF0000ff42|r (Spell 123)"
			assert(displayed[#displayed][2] == expected,
				"baseline or unknown school coloring changed the message")
		end
		profile.damageColoringDisabled, profile.frost.disabled = false, false

		-- Given a damage amount or school which Lua must not inspect.
		local opaque = {}
		local secretCheck, largeNumbers = issecretvalue, BreakUpLargeNumbers
		issecretvalue = function(value) return value == opaque end
		BreakUpLargeNumbers = nil
		-- When the amount is hidden but Frost remains readable.
		Out(opaque, 16)
		local hidden = displayed[#displayed]
		-- Then color surrounds its placeholder and the original amount survives.
		assert(hidden[2] == "Hit |cFF0000ff%s|r" and hidden[4] == opaque,
			"school coloring inspected or lost restricted damage")
		-- When only the school is hidden, then no school color is guessed.
		Out(42, opaque)
		Advance(0.31)
		assert(displayed[#displayed][2] == "Hit 42 (Spell 123)",
			"restricted school was inspected or assigned a color")
		issecretvalue, BreakUpLargeNumbers = secretCheck, largeNumbers

		-- Given two hits with one inferred spell identity but different schools.
		profile.stackSimilarHits = true
		local beforeSchools = #displayed
		-- When both are queued inside one grouping window.
		Out(42, 16)
		Out(43, 32)
		Advance(0.31)
		-- Then their amounts remain separate and each retains its own color.
		assert(#displayed == beforeSchools + 2,
			"different damage schools were combined into one colored amount")
		assert(displayed[beforeSchools + 1][2]
			== "Hit |cFF0000ff42|r (Spell 123)")
		assert(displayed[beforeSchools + 2][2]
			== "Hit |cFFff00ff43|r (Spell 123)")

		-- When two hits of the same school are grouped instead.
		Out(42, 16)
		Out(43, 16)
		Advance(0.31)
		-- Then the total is colored while the name and hit count are not.
		assert(displayed[#displayed][2]
			== "Hit |cFF0000ff85|r (Spell 123) [2 hits]",
			"same-school stacking lost number-only coloring")

		-- Given hidden Windfury amounts that must remain separate native values.
		issecretvalue = function(value) return value == opaque end
		BreakUpLargeNumbers = nil
		local beforeHiddenGroup = #displayed
		-- When an existing stacked burst uses the restricted-group path.
		Out(opaque, 32, { who = "you", spell = 8232 })
		Out(opaque, 32, { who = "you", spell = 8232 })
		Advance(1.1)
		-- Then each placeholder is colored without formatting or summing damage.
		local group = displayed[#displayed]
		assert(#displayed == beforeHiddenGroup + 1)
		assert(group[2]
			== "|cFFff00ff%s|r + |cFFff00ff%s|r [2 hits]",
			"restricted group lost per-number school coloring")
		assert(group[4] == opaque and group[5] == opaque,
			"restricted group changed its damage values")
		profile.damageColoringDisabled = true
		events.OUTGOING_SPELL_DAMAGE.message = "100% Hit %a (%s)"
		Out(opaque, 16)
		assert(displayed[#displayed][2] == "100%% Hit |cFF0000ff%s|r",
			"baseline hidden coloring or literal percent escaping changed")
		profile.damageColoringDisabled = false
		issecretvalue, BreakUpLargeNumbers = secretCheck, largeNumbers

		-- Restore the profile before the incoming-style regressions below.
		profile.frost, profile.shadow = savedFrost, savedShadow
		profile.stackSimilarHits = savedStacking
		for _, key in ipairs(keys) do events[key] = savedEvents[key] end
	end

	-- Given incoming damage uses red text and a negative amount template.
	local incomingMessage = events.INCOMING_DAMAGE.message
	local incomingSpellSettings = events.INCOMING_SPELL_DAMAGE
	events.INCOMING_DAMAGE.message = "(%n) -%a"
	events.INCOMING_DAMAGE.colorR = 1
	events.INCOMING_DAMAGE.colorG = 0
	events.INCOMING_DAMAGE.colorB = 0
	events.INCOMING_SPELL_DAMAGE = {
		message = "(%s) -%a", scrollArea = "Incoming",
		colorR = 1, colorG = 0, colorB = 0,
	}
	profile.physical = { colorR = 1, colorG = 1, colorB = 1 }
	profile.fire = { colorR = 1, colorG = 0.5, colorB = 0 }

	for _, school in ipairs({ 1, 4 }) do
		-- When the player's physical or spell damage reaches the real formatter.
		MikSBT.CombatEngine.liveRouter:In({
			event = "damage", amount = 37, school = school,
		})
		Advance(0.21)

		-- Then the minus remains and school colors cannot override event red.
		local damage = displayed[#displayed]
		assert(damage[2] == "-37",
			"incoming damage lost its minus sign or event color: " .. damage[2])
		assert(damage[1].colorR == 1 and damage[1].colorG == 0
			and damage[1].colorB == 0)
	end

	-- Given an opaque incoming damage amount that Lua cannot inspect.
	local opaque = {}
	local wasSecret, largeNumbers = issecretvalue, BreakUpLargeNumbers
	issecretvalue = function(value) return value == opaque end
	BreakUpLargeNumbers = nil

	-- When it takes the restricted display path through the real main module.
	MikSBT.CombatEngine.liveRouter:In({
		event = "damage", amount = opaque, school = 1,
	})

	-- Then the negative template and separate amount keep the event's red style.
	local restrictedDamage = displayed[#displayed]
	assert(restrictedDamage[2] == "-%s" and restrictedDamage[4] == opaque,
		"restricted incoming damage lost its negative template")
	assert(restrictedDamage[1].colorG == 0 and restrictedDamage[1].colorB == 0)
	issecretvalue, BreakUpLargeNumbers = wasSecret, largeNumbers
	events.INCOMING_DAMAGE.message = incomingMessage
	events.INCOMING_SPELL_DAMAGE = incomingSpellSettings

	profile.holy = { colorR = 1, colorG = 0.5, colorB = 0 }
	events.INCOMING_HEAL = { message = "+%a", scrollArea = "Custom heals" }
	events.INCOMING_HEAL_CRIT = nil
	-- When a heal with a Holy school mask is reported.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 90, 2)
	Advance(0.13)
	Advance(0.08)
	-- Then its amount retains heal styling instead of embedded damage colouring.
	local heal = displayed[#displayed]
	assert(heal[1] == events.INCOMING_HEAL)
	assert(heal[2] == "+90", "incoming heal amount received damage-school colour")

	-- Given a healer notice arriving before the UNIT_COMBAT amount.
	events.INCOMING_HEAL.message = "+%a (%n)"
	C_CombatText = { GetCurrentEventInfo = function()
		return "Early healer", 41
	end }
	Dispatch("COMBAT_TEXT_UPDATE", "HEAL")
	Advance(0.15)
	-- When the matching heal arrives within 200 ms.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 41, 2)
	Advance(0.13)
	Advance(0.08)
	-- Then the name reaches the real formatter without an invented icon.
	heal = displayed[#displayed]
	assert(heal[2] == "+41 (Early healer)" and heal[3] == nil)

	-- Given a heal whose name arrives after its 120 ms grouping window.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 42, 2)
	Advance(0.13)
	Advance(0.02)
	C_CombatText.GetCurrentEventInfo = function() return "Late healer", 42 end
	-- When the notice arrives before the 200 ms pairing deadline.
	Dispatch("COMBAT_TEXT_UPDATE", "HEAL")
	Advance(0.06)
	-- Then the same amount is displayed once with the late healer name.
	heal = displayed[#displayed]
	assert(heal[2] == "+42 (Late healer)" and heal[3] == nil)

	-- Describe: incoming healer names stay opaque through native rendering.
	local hiddenName = setmetatable({}, {
		__tostring = function() error("hidden healer converted to text") end,
		__concat = function() error("hidden healer concatenated in Lua") end,
	})
	local hiddenAmount = setmetatable({}, {
		__tostring = function() error("hidden heal amount converted to text") end,
	})
	local oldSecretCheck, oldLargeNumbers = issecretvalue, BreakUpLargeNumbers
	issecretvalue = function(value)
		return value == hiddenName or value == hiddenAmount
			or (oldSecretCheck and oldSecretCheck(value)) or false
	end
	BreakUpLargeNumbers = nil
	for _, amount in ipairs({ 43, hiddenAmount }) do
		for _, nameFirst in ipairs({ true, false }) do
			-- Given a hidden healer and a message with repeated names and percent text.
			Advance(4)
			events.INCOMING_HEAL.message = "%n: +%a (%n) 100%"
			local beforeHeal = #displayed
			C_CombatText.GetCurrentEventInfo = function() return hiddenName, amount end
			-- When the healer notice and amount arrive in either order.
			if nameFirst then Dispatch("COMBAT_TEXT_UPDATE", "HEAL") end
			Dispatch("UNIT_COMBAT", "player", "HEAL", "", amount, 2)
			Advance(0.05)
			if not nameFirst then Dispatch("COMBAT_TEXT_UPDATE", "HEAL") end
			Advance(0.21)
			-- Then one native template retains each original opaque argument in order.
			heal = displayed[#displayed]
			assert(#displayed == beforeHeal + 1, "hidden healer duplicated a heal")
			assert(heal[1] == events.INCOMING_HEAL and heal[3] == nil)
			assert(heal[4] == hiddenName, "hidden healer did not reach native rendering")
			if amount == hiddenAmount then
				assert(heal[2] == "%s: +%s (%s) 100%%")
				assert(heal[5] == hiddenAmount and heal[6] == hiddenName)
			else
				assert(heal[2] == "%s: +43 (%s) 100%%")
				assert(heal[5] == hiddenName)
			end
		end
	end
	-- Given a known heal spell alongside a hidden healer and hidden amount.
	local hideHealSkills = profile.hideSkills
	for _, hideSkills in ipairs({ false, true }) do
		Advance(4)
		profile.hideSkills = hideSkills
		events.INCOMING_HEAL.message = "+%a (%s - %n)"
		-- When the enriched heal uses the native name path.
		MikSBT.CombatEngine.liveRouter:In({ event = "heal", amount = hiddenAmount,
			sourceName = hiddenName, spell = 201 })
		Advance(0.21)
		heal = displayed[#displayed]
		-- Then public spell metadata respects Hide Skills and the healer survives.
		local expected = hideSkills and "+%s (%s)" or "+%s (Spell 201 - %s)"
		assert(heal[2] == expected, "hidden healer disrupted spell formatting")
		assert(heal[3] == "icon" and heal[4] == hiddenAmount
			and heal[5] == hiddenName)
	end
	profile.hideSkills = hideHealSkills

	-- Given the user intentionally omits the healer placeholder.
	Advance(4)
	events.INCOMING_HEAL.message = "+%a"
	-- When a hidden healer accompanies a readable heal amount.
	MikSBT.CombatEngine.liveRouter:In({ event = "heal", amount = 44,
		sourceName = hiddenName })
	Advance(0.21)
	-- Then the message remains amount-only, without adding a source label.
	heal = displayed[#displayed]
	assert(heal[2] == "+44" and heal[4] == nil)
	issecretvalue, BreakUpLargeNumbers = oldSecretCheck, oldLargeNumbers
	events.INCOMING_HEAL.message = "+%a (%n)"

	-- Given a helpful spell cast while the player explicitly targets themselves.
	local unitIsUnit = UnitIsUnit
	UnitIsUnit = function(a, b)
		return (a == "target" and b == "player") or unitIsUnit(a, b)
	end
	C_Spell.IsSpellHelpful = function(id) return id == 201 end
	events.SELF_HEAL = { message = "Self %a", scrollArea = "Custom heals" }
	events.OUTGOING_HEAL = { message = "Healed %a (%s)",
		scrollArea = "Outgoing heals" }
	for _, healFirst in ipairs({ true, false }) do
		MikSBT.CombatEngine.ResetHealing()
		local beforeHeal = #displayed
		-- When the heal and cast success arrive in either order in one frame.
		if healFirst then
			Dispatch("UNIT_COMBAT", "player", "HEAL", "", 93, 2)
		end
		Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 201)
		if not healFirst then
			Dispatch("UNIT_COMBAT", "player", "HEAL", "", 93, 2)
		end
		local healRGB = filter.colors.eventColoring.SPELL_HEAL
		Dispatch("COMBAT_LOG_MESSAGE", "opaque",
			healRGB.r, healRGB.g, healRGB.b, 1)
		Advance(0.25)
		-- Then incoming and outgoing each show one correctly attributed heal.
		assert(#displayed == beforeHeal + 2,
			"self healing did not display once in each direction")
		local outgoingHeal
		for index = beforeHeal + 1, #displayed do
			local item = displayed[index]
			if item[1] == events.SELF_HEAL then heal = item end
			if item[1] == events.OUTGOING_HEAL then outgoingHeal = item end
		end
		assert(heal[2] == "Self 93" and heal[3] == "icon",
			"self-target heal lost its spell icon")
		assert(outgoingHeal and outgoingHeal[2] == "Healed 93 (Test spell)"
			and outgoingHeal[3] == "icon", "outgoing self-heal settings lost")
	end
	-- Given known outgoing heals with restricted combat amounts.
	local secretCheck = issecretvalue
	local hiddenHeal = {}
	issecretvalue = function(value) return value == hiddenHeal end
	local savedHideSkills = profile.hideSkills
	local savedHot = events.OUTGOING_HOT
	events.OUTGOING_HOT = { message = "Tick %a (%sl)",
		scrollArea = "Outgoing heals" }
	for _, hideSkills in ipairs({ false, true }) do
		profile.hideSkills = hideSkills
		for _, tick in ipairs({ false, true }) do
			-- When direct and periodic heals enter the real display pipeline.
			MikSBT.CombatEngine.liveRouter:Out({
				event = "heal", amount = hiddenHeal,
				result = { who = "you", spell = 201, tick = tick },
			})
			local output = displayed[#displayed]
			local prefix = tick and "Tick " or "Healed "
			local expected = prefix .. "%s"
			if not hideSkills then expected = expected .. " (Spell 201)" end
			-- Then the name setting applies and the opaque amount is untouched.
			assert(output[2] == expected,
				"restricted outgoing heal lost its skill name: " .. output[2])
			assert(output[3] == "icon" and output[4] == hiddenHeal)
		end
	end
	profile.hideSkills = savedHideSkills
	events.OUTGOING_HOT = savedHot
	issecretvalue = secretCheck
	UnitIsUnit = unitIsUnit
	C_Spell.IsSpellHelpful = function() return false end

	-- Given localized ranked Mend Pet while an enemy remains selected.
	local mendName = C_Spell.GetSpellName
	local mendDescription = C_Spell.GetSpellDescription
	C_Spell.IsSpellHelpful = function(id) return id == 3661 end
	C_Spell.GetSpellName = function(id)
		if id == 136 or id == 3661 then return "Guérison du familier" end
		return mendName(id)
	end
	C_Spell.GetSpellDescription = function(id)
		if id == 3661 then return "Rend des points de vie au familier." end
		return mendDescription(id)
	end
	local mendHot = events.OUTGOING_HOT
	events.OUTGOING_HOT = { message = "Pet tick %a", scrollArea = "Outgoing" }
	MikSBT.CombatEngine.ResetHealing()
	Advance(4)
	Dispatch("UNIT_SPELLCAST_SENT", "player", "", "ranked-mend", 3661)
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "ranked-mend", 3661)

	-- When an unrelated self-heal precedes the confirmed pet tick.
	Dispatch("UNIT_COMBAT", "player", "HEAL", "", 14, 2)
	Advance(0.25)
	local beforeMend = #displayed
	Dispatch("UNIT_COMBAT", "pet", "HEAL", "", 68, 1)
	local hotRGB = filter.colors.eventColoring.SPELL_PERIODIC_HEAL
	Dispatch("COMBAT_LOG_MESSAGE", "opaque", hotRGB.r, hotRGB.g, hotRGB.b, 1)
	Advance(0.25)

	-- Then the real reader and renderer retain one outgoing Mend Pet tick.
	local mendTicks = 0
	for index = beforeMend + 1, #displayed do
		if displayed[index][1] == events.OUTGOING_HOT then
			assert(displayed[index][2] == "Pet tick 68")
			mendTicks = mendTicks + 1
		end
	end
	assert(mendTicks == 1, "localized targetless Mend Pet lost its outgoing tick")
	events.OUTGOING_HOT = mendHot
	C_Spell.GetSpellName = mendName
	C_Spell.GetSpellDescription = mendDescription
	C_Spell.IsSpellHelpful = function() return false end

	-- Given two indistinguishable direct casts and visible spell names.
	local activeProfile = MikSBT.Profiles.currentProfile
	local previousHideSkills = activeProfile.hideSkills
	local previousMessage = events.OUTGOING_SPELL_DAMAGE.message
	local previousSecretCheck = issecretvalue
	local opaqueHit = {}
	issecretvalue = function(value) return value == opaqueHit end
	activeProfile.hideSkills = false
	events.OUTGOING_SPELL_DAMAGE.message = "Hit %a - %sl"
	for _, amount in ipairs({ 42, opaqueHit }) do
		Advance(4)
		local beforeAmbiguous = #displayed
		Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1001)
		Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1002)
		-- When one confirmed hit reaches the real matcher and display pipeline.
		Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
		Dispatch("UNIT_COMBAT", "target", "WOUND", "", amount, 4)
		Advance(0.02)
		Advance(0.31)
		-- Then the hit appears once with a generic icon and no guessed name.
		assert(#displayed == beforeAmbiguous + 1,
			"ambiguous confirmed damage was dropped or displayed twice")
		local output = displayed[#displayed]
		assert(output[3] == "Interface\\Icons\\INV_Misc_QuestionMark")
		if amount == opaqueHit then
			assert(output[4] == amount, "opaque damage was changed")
			assert(not output[2]:find("Test spell", 1, true))
		else
			assert(output[2] == "Hit |cFFff7f0042|r",
				"ambiguous damage lost its school color or kept a guessed label")
		end
	end
	issecretvalue = previousSecretCheck
	activeProfile.hideSkills = previousHideSkills
	events.OUTGOING_SPELL_DAMAGE.message = previousMessage

	-- Given one direct cast and two competing reports for one confirmation.
	Advance(4)
	local previousDescription = C_Spell.GetSpellDescription
	C_Spell.GetSpellDescription = function(id)
		if id == 1003 then return "Deals 50 Fire damage." end
		return previousDescription(id)
	end
	local beforeRanked = #displayed
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1003)
	-- When only the second report fits the cast after accounting for crits.
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 75, 4)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 100, 4)
	Dispatch("COMBAT_LOG_MESSAGE", "opaque", rgb.r, rgb.g, rgb.b, 1)
	Advance(0.02)
	Advance(0.31)
	-- Then the reader spends the confirmation on the matching critical hit.
	assert(#displayed == beforeRanked + 1)
	assert(displayed[#displayed][2]:find("100", 1, true),
		"ownership ranking did not pass the critical flag to matching")
	C_Spell.GetSpellDescription = previousDescription

	-- Given the active filter was changed to include another player's lines.
	local before = #displayed
	filter.filters[1].sourceFlags[99] = true
	Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 123)
	Dispatch("UNIT_COMBAT", "target", "WOUND", "", 999, 4)
	Advance(0.02)
	Advance(0.31)
	-- Then unconfirmed outgoing damage stays hidden on a log-capable client.
	assert(#displayed == before, "changed filter allowed guessed outgoing damage")
	main.Disable()
	for _, frame in ipairs(frames) do assert(next(frame.events) == nil) end
end
print("Retail and Forever combat runtime tests passed")
