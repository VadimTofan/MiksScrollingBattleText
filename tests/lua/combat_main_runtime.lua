-- Reuse the full legacy runtime regression fixture before exercising both
-- modern clients through the real main module and real adapted reader.
dofile("tests/lua/notification_runtime.lua")

local createFrame = CreateFrame
local frames, timers, displayed = {}, {}, {}
local popups, reloads = {}, 0
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
Enum.PlayerSwingType = { MainHand = 1, OffHand = 2, Ranged = 3 }
Enum.CombatLogMessageOrder = { Oldest = 0, Newest = 1 }
local meterReads = 0
C_DamageMeter = {
	GetCombatSessionSourceFromType = function() meterReads = meterReads + 1 end,
}
Enum.DamageMeterType = { DamageDone = 0 }
C_EventUtils = { IsEventValid = function(event) return event ~= "PLAYER_SWING" end }
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
	assert(popupCount == (forever and 1 or 0))
	inCombat = false
	Dispatch("ADDON_LOADED", "Blizzard_CombatLog")

	-- Then leaving combat allows one persistent, dismissible reload prompt.
	assert(#popups == popupCount + 1, "missing filter did not show a popup")
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

	-- Given resource notifications and the resource labels supplied by Blizzard.
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
	assert(displayed[beforeResource + 1][2] == "20 - MANA")
	assert(displayed[beforeResource + 2][2] == "1 - HOLY_POWER")
	assert(displayed[#displayed][1] == resourceSettings)

	-- Given Blizzard supplies the amount as text, as its own renderer supports.
	resourceAmount, resourceToken = "25", "MANA"
	beforeResource = #displayed
	-- When the gain arrives, then its numeric text is displayed as an amount.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(#displayed == beforeResource + 1, "numeric text dropped a resource gain")
	assert(displayed[#displayed][2] == "25 - MANA")

	-- Given number shortening is enabled and Blizzard supplies a custom label.
	local previousShortening = MikSBT.Profiles.currentProfile.shortenNumbers
	MikSBT.Profiles.currentProfile.shortenNumbers = true
	resourceAmount, resourceToken = "001250", "Energy supplied by Blizzard"
	-- When the gain is displayed, then both supplied strings stay unchanged.
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(displayed[#displayed][2] == "001250 - Energy supplied by Blizzard")
	MikSBT.Profiles.currentProfile.shortenNumbers = previousShortening

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
	assert(displayed[#displayed][2] == "%s - %s")
	assert(displayed[#displayed][4] == secretResource)
	assert(displayed[#displayed][5] == "MANA")

	-- When the resource token is hidden too, then its label reaches rendering.
	resourceToken = secretToken
	beforeResource = #displayed
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	Dispatch("COMBAT_TEXT_UPDATE", "ENERGIZE")
	assert(#displayed == beforeResource + 2, "hidden resource type dropped a gain")
	assert(displayed[#displayed][2] == "%s - %s")
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

	-- Given a helpful spell cast while the player explicitly targets themselves.
	local unitIsUnit = UnitIsUnit
	UnitIsUnit = function(a, b)
		return (a == "target" and b == "player") or unitIsUnit(a, b)
	end
	C_Spell.IsSpellHelpful = function(id) return id == 201 end
	events.SELF_HEAL = { message = "Self %a", scrollArea = "Custom heals" }
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
		Advance(0.21)
		-- Then exactly one self-heal keeps the actual spell's icon.
		heal = displayed[#displayed]
		assert(#displayed == beforeHeal + 1)
		assert(heal[1] == events.SELF_HEAL)
		assert(heal[2] == "Self 93" and heal[3] == "icon",
			"self-target heal lost its spell icon")
	end
	UnitIsUnit = unitIsUnit
	C_Spell.IsSpellHelpful = function() return false end

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
