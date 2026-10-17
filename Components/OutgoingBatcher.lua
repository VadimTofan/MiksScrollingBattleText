local OutgoingBatcher = {}
OutgoingBatcher.__index = OutgoingBatcher

function OutgoingBatcher:New(config)
	return setmetatable({
		config = config,
		batches = {},
	}, self)
end

function OutgoingBatcher:Reset()
	for key in pairs(self.batches) do
		self.batches[key] = nil
	end
end

function OutgoingBatcher:BuildMessage(amount, hitCount)
	local profile = self.config.getProfile()
	local formattedAmount = self.config.formatAmount(amount, profile)
	if not profile.stackSimilarHits then
		return formattedAmount
	end
	if hitCount == 1 then
		return formattedAmount
	end

	local translations = MikSBT.translations
	return string.format("%s [%d %s]", formattedAmount, hitCount,
		translations and translations.MSG_HITS or "Hits")
end

function OutgoingBatcher:ResolveSettings(isSpell)
	local profile = self.config.getProfile()
	local primaryKey = isSpell
		and "OUTGOING_SPELL_DAMAGE"
		or "OUTGOING_DAMAGE"
	local secondaryKey = isSpell
		and "OUTGOING_DAMAGE"
		or "OUTGOING_SPELL_DAMAGE"
	local settings = profile.events[primaryKey]
	if settings and not settings.disabled then
		return primaryKey, settings
	end

	settings = profile.events[secondaryKey]
	if settings and not settings.disabled then
		return secondaryKey, settings
	end
	return nil
end

function OutgoingBatcher:Flush(batchKey)
	local batch = self.batches[batchKey]
	if not batch then
		return
	end
	self.batches[batchKey] = nil

	local eventKey, settings = self:ResolveSettings(batch.isSpell)
	if not settings then
		return
	end
	local profile = self.config.getProfile()
	local critSettings = profile.events[eventKey .. "_CRIT"]
	local displaySettings = settings
	if batch.isCrit and critSettings and not critSettings.disabled then
		displaySettings = critSettings
	end
	self.config.display(
		displaySettings,
		self:BuildMessage(batch.totalAmount, batch.hitCount),
		batch.effectTexture
	)
end

function OutgoingBatcher:Queue(
	spellID,
	amount,
	isCrit,
	effectTexture,
	forceIsSpell
)
	if not amount or amount <= 0 then
		return
	end

	if not effectTexture then
		effectTexture = self.config.getSpellTexture(
			spellID or self.config.autoAttackSpellID
		)
	end
	if not effectTexture then
		spellID = self.config.autoAttackSpellID
		effectTexture = self.config.getSpellTexture(spellID)
	end

	local batchKey = tostring(spellID or 0) .. (isCrit and ":crit" or "")
	local batch = self.batches[batchKey]
	if not batch then
		batch = {
			hitCount = 0,
			isCrit = not not isCrit,
			totalAmount = 0,
			isSpell = forceIsSpell ~= nil
				and forceIsSpell
				or not self.config.isAutoAttack(spellID),
			effectTexture = effectTexture,
		}
		self.batches[batchKey] = batch
		self.config.after(self.config.delay, function()
			if self.batches[batchKey] == batch then
				self:Flush(batchKey)
			end
		end)
	end
	if forceIsSpell then
		batch.isSpell = true
	end

	batch.hitCount = batch.hitCount + 1
	batch.totalAmount = batch.totalAmount + amount
	if effectTexture and not batch.effectTexture then
		batch.effectTexture = effectTexture
	end
end

MikSBT.Components = MikSBT.Components or {}
MikSBT.Components.OutgoingBatcher = OutgoingBatcher

return OutgoingBatcher
