local OutgoingCombat = {}
OutgoingCombat.__index = OutgoingCombat

function OutgoingCombat:New(config)
	return setmetatable({
		config = config,
		lastSpellID = nil,
		lastSpellTime = 0,
		dotSpellID = nil,
		dotAuraIDs = nil,
		dotRequiresAura = true,
		dotExpires = 0,
		dotSchool = nil,
		lastAutoAttackTime = 0,
		pendingShotTime = nil,
		shotSchool = nil,
		activeDots = {},
		pendingCastID = nil,
		pendingCastTime = 0,
		castTargets = {},
	}, self)
end

local MISS_ACTIONS = {
	MISS = true, DODGE = true, PARRY = true, BLOCK = true, DEFLECT = true,
	ABSORB = true, RESIST = true, IMMUNE = true, EVADE = true, REFLECT = true,
}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function PlainName(name)
	if type(name) ~= "string" or IsSecret(name) or name == "" then
		return nil
	end
	return name
end

local function NameKey(name)
	name = PlainName(name)
	if not name then
		return nil
	end
	name = string.match(name, "^[^%-]+") or name
	return name
end

function OutgoingCombat:HandleSpellcastSent(unitID, targetName, castGUID)
	if unitID ~= "player" or castGUID == nil or IsSecret(castGUID) then
		return
	end
	self.castTargets[castGUID] = NameKey(targetName) or false
end

function OutgoingCombat:IsRepeatShot(spellID)
	return spellID ~= nil and self.config.repeatShotSpells ~= nil
		and self.config.repeatShotSpells[spellID] == true
end

function OutgoingCombat:GetNamedDot(spellID)
	if not self.config.namedDots or not self.config.getSpellName then
		return nil
	end
	local name = self.config.getSpellName(spellID)
	return name and self.config.namedDots()[name], name
end

function OutgoingCombat:HasActiveNamedDot(now)
	for _, dot in pairs(self.activeDots) do
		if now <= dot.expires + 1 then
			return true
		end
	end
	return false
end

-- Several periodic spells can run at once with the same school, so a tick is
-- matched by timing: each one ticks on its own interval counted from the cast.
function OutgoingCombat:PickNamedDot(now, schoolMask)
	local best, bestDistance
	local targetKey = self.attributionTarget
	for name, dot in pairs(self.activeDots) do
		if now > dot.expires + 1 then
			self.activeDots[name] = nil
		elseif (schoolMask == nil or dot.school == nil or dot.school == schoolMask)
			and (targetKey == nil or dot.target == nil or dot.target == targetKey) then
			local elapsed = now - dot.start
			if elapsed >= dot.interval * 0.5 then
				local phase = elapsed % dot.interval
				local distance = math.min(phase, dot.interval - phase)
				if dot.lastHit and now - dot.lastHit < dot.interval * 0.6 then
					distance = distance + dot.interval
				end
				if not bestDistance or distance < bestDistance then
					best, bestDistance = dot, distance
				end
			end
		end
	end
	return best, bestDistance
end

function OutgoingCombat:UseNamedDot(dot, now)
	dot.lastHit = now
	return dot.spellID, self.config.getSpellTexture(dot.spellID)
end

function OutgoingCombat:GetLastSpell()
	return self.lastSpellID, self.lastSpellTime
end

function OutgoingCombat:Reset()
	self:ResetCombatState()
	self.config.batcher:Reset()
end

function OutgoingCombat:ResetCombatState(isCombatStart)
	self.dotSpellID = nil
	self.dotAuraIDs = nil
	self.dotRequiresAura = true
	self.dotExpires = 0
	self.dotSchool = nil
	self.lastAutoAttackTime = 0
	self.pendingShotTime = nil
	local now = self.config.getTime()
	if self.pendingCastID and now - self.pendingCastTime > 1.5 then
		self.pendingCastID = nil
	end
	for castGUID in pairs(self.castTargets) do
		self.castTargets[castGUID] = nil
	end
	for name, dot in pairs(self.activeDots) do
		if now > dot.expires + 1 then
			self.activeDots[name] = nil
		end
	end
	if self.config.damageMeter then
		if isCombatStart == false then
			self.config.damageMeter:Poll()
		end
		self.config.damageMeter:Reset(isCombatStart == true)
	end
end

function OutgoingCombat:Start()
	if self.config.damageMeter then
		self.config.damageMeter:Start()
	end
end

function OutgoingCombat:Stop(isShutdown)
	if self.config.damageMeter then
		self.config.damageMeter:Stop(isShutdown)
	end
end

function OutgoingCombat:HandleSpellcastSucceeded(unitID, spellID, castGUID)
	if unitID ~= "player" or not spellID or IsSecret(spellID) then
		return false
	end

	self.lastSpellID = spellID
	self.lastSpellTime = self.config.getTime()
	local castTarget
	if castGUID ~= nil and not IsSecret(castGUID) then
		castTarget = self.castTargets[castGUID] or nil
		self.castTargets[castGUID] = nil
	end

	if self:IsRepeatShot(spellID) then
		self.pendingShotTime = self.lastSpellTime
		return true
	end

	local namedDot, dotName = self:GetNamedDot(spellID)
	if namedDot then
		self.activeDots[dotName .. "|" .. tostring(castTarget)] = {
			spellID = spellID,
			start = self.lastSpellTime,
			expires = self.lastSpellTime + namedDot.duration,
			school = namedDot.school,
			interval = namedDot.interval or 3,
			target = castTarget,
		}
		return true
	end

	if not (self.config.isHelpfulSpell and self.config.isHelpfulSpell(spellID)) then
		self.pendingCastID = spellID
		self.pendingCastTime = self.lastSpellTime
	end

	local timedDuration = self.config.timedDotSpells[spellID]
	if timedDuration then
		self.dotSpellID = spellID
		self.dotAuraIDs = nil
		self.dotRequiresAura = false
		self.dotExpires = self.lastSpellTime + timedDuration
		return true
	end

	local auraIDs = self.config.dotSpells[spellID]
	if auraIDs then
		self.dotSpellID = spellID
		self.dotAuraIDs = auraIDs
		self.dotRequiresAura = true
		self.dotExpires = self.lastSpellTime + self.config.dotDuration
	end
	return true
end

function OutgoingCombat:IsDirectDamageCast(spellID)
	if self:IsRepeatShot(spellID) then
		return true
	end
	return self.pendingCastID == spellID and self.pendingCastTime == self.lastSpellTime
end

function OutgoingCombat:IsDotFallbackActive(now)
	if not self.dotSpellID or now > self.dotExpires then
		return false
	end
	if not self.dotRequiresAura then
		return true
	end
	return self.config.hasPlayerDebuff(self.dotAuraIDs)
end

function OutgoingCombat:HasRecentSignal(now, schoolMask)
	if self.lastSpellID
		and now - self.lastSpellTime <= self.config.signalWindow then
		return true
	end
	if self:IsDotFallbackActive(now) or self:HasActiveNamedDot(now) then
		return true
	end
	if not self.config.isLikelySpellSchool(schoolMask) then
		return self.config.canUseAutoAttackFallback(
			now,
			self.lastAutoAttackTime
		)
	end
	return false
end

local DOT_TICK_PRIORITY = 0.3

function OutgoingCombat:ResolveDamageAttribution(now, schoolMask, strict)
	local dot, dotDistance = self:PickNamedDot(now, schoolMask)
	local dotIsDue = dot ~= nil and dotDistance <= DOT_TICK_PRIORITY

	if self.config.isChanneling and self.config.isChanneling() and self.lastSpellID
		and not self:IsRepeatShot(self.lastSpellID) and not dotIsDue
		and (not strict or self.config.isLikelySpellSchool(schoolMask)) then
		return self.lastSpellID, self.config.getSpellTexture(self.lastSpellID)
	end

	local shotPending = self.pendingShotTime ~= nil
		and now - self.pendingShotTime <= self.config.shotHitWindow
	if shotPending and dot then
		local schoolSaysDot = self.shotSchool ~= nil and schoolMask ~= nil
			and self.shotSchool ~= schoolMask and dot.school == schoolMask
		if schoolSaysDot then
			shotPending = false
		end
	end
	if shotPending then
		self.pendingShotTime = nil
		if schoolMask ~= nil then
			self.shotSchool = schoolMask
		end
		return self.lastSpellID, self.config.getSpellTexture(self.lastSpellID)
	end

	local castPending = self.pendingCastID ~= nil
		and now - self.pendingCastTime <= self.config.delayedAttributionWindow
	if castPending and not dotIsDue then
		local spellID = self.pendingCastID
		self.pendingCastID = nil
		return spellID, self.config.getSpellTexture(spellID)
	end

	if dot then
		return self:UseNamedDot(dot, now)
	end
end

function OutgoingCombat:ResolveStrictAttribution(now, schoolMask)
	local spellID, texture = self:ResolveDamageAttribution(now, schoolMask, true)
	if spellID or self:IsRepeatShot(self.lastSpellID) then
		return spellID, texture
	end
	if not self.config.isLikelySpellSchool(schoolMask)
		and self.config.canUseAutoAttackFallback(now, self.lastAutoAttackTime) then
		spellID = self.config.autoAttackSpellID
		return spellID, self.config.getSpellTexture(spellID)
	end
end

function OutgoingCombat:ResolveAttribution(now, isDamage, schoolMask)
	if isDamage and (self:HasActiveNamedDot(now) or self:IsRepeatShot(self.lastSpellID)) then
		local spellID, texture = self:ResolveDamageAttribution(now, schoolMask)
		if spellID or self:IsRepeatShot(self.lastSpellID) then
			return spellID, texture
		end
	end

	local spellID
	local texture
	if self.lastSpellID
		and now - self.lastSpellTime
			<= self.config.fallbackAttributionWindow then
		spellID = self.lastSpellID
		texture = self.config.getSpellTexture(spellID)
	end
	if not texture and isDamage and self.lastSpellID
		and not self.config.isAutoAttack(self.lastSpellID)
		and now - self.lastSpellTime
			<= self.config.delayedAttributionWindow then
		spellID = self.lastSpellID
		texture = self.config.getSpellTexture(spellID)
	end
	if not texture and isDamage and self:IsDotFallbackActive(now)
		and (self.dotSchool == nil or schoolMask == nil or self.dotSchool == schoolMask) then
		spellID = self.dotSpellID
		texture = self.config.getSpellTexture(spellID)
	end
	if not texture then
		if not isDamage then
			return nil
		end
		if not self.config.canUseAutoAttackFallback(
			now,
			self.lastAutoAttackTime
		) then
			return nil
		end
		spellID = self.config.autoAttackSpellID
		texture = self.config.getSpellTexture(spellID)
	end
	return spellID, texture
end

function OutgoingCombat:QueueDamage(
	spellID,
	amount,
	isCrit,
	texture,
	schoolMask
)
	local forceIsSpell = spellID == self.config.autoAttackSpellID
		and self.config.isLikelySpellSchool(schoolMask)
		or nil
	if spellID == self.config.autoAttackSpellID then
		self.lastAutoAttackTime = self.config.getTime()
	end
	self.config.batcher:Queue(
		spellID,
		amount,
		isCrit,
		texture,
		forceIsSpell
	)
end

function OutgoingCombat:Emit(parserEvent)
	if self.config.emit then
		self.config.emit(parserEvent)
	end
end

function OutgoingCombat:HandleHostileUnitCombat(unitTarget, action, flagText, amount, schoolMask, owned, eventTime)
	if not owned and (not self.config.inCombat() or not self.config.isHostileUnit(unitTarget)) then
		return true
	end

	local isDamage = action == "WOUND"
	if not isDamage and not MISS_ACTIONS[action] then
		return true
	end

	local plainSchool = self.config.normalizeNumber(schoolMask)
	local isCrit = not IsSecret(flagText) and flagText == "CRITICAL"
	local now = eventTime or self.config.getTime()
	self.attributionTarget = NameKey(self.config.unitName(unitTarget))
	local spellID, texture
	if owned then
		spellID, texture = self:ResolveAttribution(now, true, plainSchool)
		if not spellID then
			spellID = self.lastSpellID and not self:IsRepeatShot(self.lastSpellID)
				and now - self.lastSpellTime <= self.config.ownedSpellWindow
				and self.lastSpellID or self.config.autoAttackSpellID
			texture = self.config.getSpellTexture(spellID)
		end
	else
		if not self:HasRecentSignal(now, plainSchool) then
			return true
		end

		local inGroup = self.config.isInGroup and self.config.isInGroup()
		if inGroup and self.config.getProfile().showGuessedOutgoingInGroup == false then
			return true
		end

		if inGroup then
			spellID, texture = self:ResolveStrictAttribution(now, plainSchool)
		else
			spellID, texture = self:ResolveAttribution(now, true, plainSchool)
		end
		if not spellID then
			return true
		end
	end

	if not isDamage then
		self:Emit({
			eventType = "miss",
			sourceUnit = "player",
			recipientName = self.config.unitName(unitTarget),
			skillID = spellID,
			skillName = self.config.getSpellName(spellID),
			missType = action,
			effectTexture = texture,
		})
		return true
	end

	if IsSecret(amount) then return true end

	local normalizedAmount = self.config.normalizeNumber(amount)
	if not normalizedAmount or normalizedAmount <= 0 then
		return true
	end
	if isCrit and self.config.recordCrit then
		self.config.recordCrit(normalizedAmount)
	end
	if self.config.isMeterOwning and self.config.isMeterOwning() then
		return true
	end
	self:QueueDamage(spellID, normalizedAmount, isCrit, texture, schoolMask)
	return true
end

function OutgoingCombat:HandleUnitCombat(unitTarget, action, flagText, amount, schoolMask, owned, kind, eventTime)
	kind = kind or self.config.classifyUnit(unitTarget)
	if kind and self.config.isCombatLogOwning and self.config.isCombatLogOwning() then
		return true
	end
	if kind == "hostile" then
		return self:HandleHostileUnitCombat(unitTarget, action, flagText, amount, schoolMask, owned, eventTime)
	end
	return false
end

MikSBT.Components = MikSBT.Components or {}
MikSBT.Components.OutgoingCombat = OutgoingCombat

return OutgoingCombat
