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
		lastAutoAttackTime = 0,
		criticalCandidate = nil,
	}, self)
end

function OutgoingCombat:GetLastSpell()
	return self.lastSpellID, self.lastSpellTime
end

function OutgoingCombat:Reset()
	self:ResetCombatState()
	self.config.batcher:Reset()
end

function OutgoingCombat:ResetCombatState()
	self.dotSpellID = nil
	self.dotAuraIDs = nil
	self.dotRequiresAura = true
	self.dotExpires = 0
	self.lastAutoAttackTime = 0
	self.criticalCandidate = nil
	if self.config.damageMeter then
		self.config.damageMeter:Reset()
	end
end

function OutgoingCombat:Start()
	if self.config.damageMeter then
		self.config.damageMeter:Start()
	end
end

function OutgoingCombat:Stop()
	if self.config.damageMeter then
		self.config.damageMeter:Stop()
	end
end

function OutgoingCombat:HandleSpellcastSucceeded(unitID, spellID)
	if unitID ~= "player" or not spellID then
		return false
	end

	self.lastSpellID = spellID
	self.lastSpellTime = self.config.getTime()
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
	if self:IsDotFallbackActive(now) then
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

function OutgoingCombat:ResolveAttribution(now, isDamage)
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
	if not texture and isDamage and self:IsDotFallbackActive(now) then
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

function OutgoingCombat:RecordCriticalCandidate(
	unitTarget,
	action,
	flagText,
	amount,
	schoolMask
)
	if unitTarget ~= "target" or action ~= "WOUND"
		or flagText ~= "CRITICAL" then
		return false
	end
	if not self.config.inCombat() or not self.config.isTargetValid() then
		return false
	end

	local normalizedAmount = self.config.normalizeNumber(amount)
	if not normalizedAmount or normalizedAmount <= 0 then
		return false
	end

	local now = self.config.getTime()
	if not self:HasRecentSignal(now, schoolMask) then
		return false
	end

	local spellID = self:ResolveAttribution(now, true)
	if not spellID then
		return false
	end

	self.criticalCandidate = {
		spellID = spellID,
		amount = normalizedAmount,
		time = now,
	}
	return true
end

function OutgoingCombat:ConsumeCriticalCandidate(spellID, amount, now)
	local candidate = self.criticalCandidate
	if not candidate then
		return false
	end
	if now - candidate.time > self.config.critMatchWindow then
		self.criticalCandidate = nil
		return false
	end
	if spellID ~= candidate.spellID then
		return false
	end

	local amountDifference = math.abs(amount - candidate.amount)
	local allowedDifference = candidate.amount
		* self.config.critMatchTolerance
	if amountDifference > allowedDifference then
		return false
	end

	self.criticalCandidate = nil
	return true
end

MikSBT.Components = MikSBT.Components or {}
MikSBT.Components.OutgoingCombat = OutgoingCombat

return OutgoingCombat
