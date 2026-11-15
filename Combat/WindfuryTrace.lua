-- Diagnostic metadata only. Never store damage values or combat-log text.
local Tracker = {}
Tracker.__index = Tracker
MikSBT.WindfuryTraceModel = Tracker

function Tracker:New()
    return setmetatable({ bursts = {}, records = {}, nextID = 0,
        recordIDs = setmetatable({}, { __mode = "k" }), dispatchID = 0,
        seenLines = setmetatable({}, { __mode = "k" }) }, self)
end

function Tracker:Swing(at, key, hand, active)
    self.nextID = self.nextID + 1
    local burst = { id = self.nextID, at = at, key = key, hand = hand,
        active = active, reports = {}, lines = {}, casts = {}, cooldowns = {} }
    self.bursts[#self.bursts + 1] = burst
    if #self.bursts > 8 then
        local expired = table.remove(self.bursts, 1)
        for _, id in ipairs(expired.reports) do self.records[id] = nil end
    end
    return burst
end

function Tracker:Find(at, key)
    for index = #self.bursts, 1, -1 do
        local burst = self.bursts[index]
        if burst.key == key and at >= burst.at - 0.01
            and at - burst.at <= 3 then return burst end
    end
end

function Tracker:Log(line, key)
    if self.seenLines[line] then return end
    self.seenLines[line] = true
    local burst = self:Find(line.at, key)
    if not burst or #burst.lines >= 32 then return end
    burst.lines[#burst.lines + 1] = {
        at = line.at, kind = line.kind, source = line.source,
    }
end

function Tracker:Cast(at, key, spell, weaponTrigger)
    local burst = self:Find(at, key)
    if not burst or #burst.casts >= 32 then return end
    burst.casts[#burst.casts + 1] = {
        at = at, spell = spell, weaponTrigger = weaponTrigger == true,
    }
end

function Tracker:Cooldown(at, targetContext, info)
    -- Cooldown payloads have no target or ownership field. Keep the latest
    -- swing's timing context without using the current target to match them.
    local burst = self.bursts[#self.bursts]
    if not burst or at < burst.at - 0.01 or at - burst.at > 3 then return end
    if #burst.cooldowns >= 32 then
        burst.cooldownsTruncated = true
        return
    end
    burst.cooldowns[#burst.cooldowns + 1] = {
        at = at, targetContext = targetContext,
        spellID = info.spellID, baseSpellID = info.baseSpellID,
        category = info.category,
        startRecoveryCategory = info.startRecoveryCategory,
        itemID = info.itemID,
    }
end

function Tracker:Report(record, info)
    local existing = self:Lookup(record)
    if existing then return existing.id end
    local burst = self:Find(info.at, info.key)
    if not burst then return end
    if #burst.reports >= 32 then burst.truncated = true; return end
    self.nextID = self.nextID + 1
    local id = self.nextID
    local entry = { id = id, burstID = burst.id, at = info.at,
        key = info.key, unit = info.unit, event = info.event,
        school = info.school, outcome = info.outcome, candidates = {},
        dispatches = {} }
    self.records[id], self.recordIDs[record] = entry, id
    burst.reports[#burst.reports + 1] = id
    return id
end

function Tracker:Lookup(record)
    return self.records[self.recordIDs[record]]
end

function Tracker:Decision(record, info)
    local entry = self:Lookup(record)
    if not entry then return end
    entry.who, entry.melee = info.who, info.melee
    entry.procSpell, entry.held = info.procSpell, info.hold or info.held
    entry.spell, entry.proc = info.spell, info.proc
    entry.procCandidate, entry.candidateSpell =
        info.procCandidate, info.candidateSpell
    entry.confirmed = info.confirmed
end

function Tracker:Candidate(record, info)
    local entry = self:Lookup(record)
    if not entry or #entry.candidates >= 32 then return end
    entry.candidates[#entry.candidates + 1] = info
end

function Tracker:Forward(ids, path)
    for _, id in ipairs(ids) do
        if self.records[id] then self.records[id].path = path end
    end
end

function Tracker:Attempt(ids, reason)
    for _, id in ipairs(ids) do
        local entry = self.records[id]
        if entry then
            entry.attempted, entry.blocked = true, reason
        end
    end
end

function Tracker:Dispatch(ids, info)
    self.dispatchID = self.dispatchID + 1
    for _, id in ipairs(ids) do
        local entry = self.records[id]
        if entry then
            entry.dispatches[self.dispatchID] = true
            entry.area, entry.alpha = info.area, info.alpha
            entry.blocked = nil
        end
    end
end

function Tracker:Rekey(old, new)
    for _, burst in ipairs(self.bursts) do
        if burst.key == old then burst.key = new end
    end
    for _, entry in pairs(self.records) do
        if entry.key == old then entry.key = new end
    end
end

function Tracker:Summary(burst)
    local summary = { expected = 0, estimated = 0,
        damage = 0, misses = 0, normal = 0,
        rawDamage = 0, rawMisses = 0, rejected = 0, forwarded = 0,
        displays = 0, merged = false, confirmations = 0, rejectedPhysical = 0,
        unknown = 0, unknownPhysical = 0 }
    for _, line in ipairs(burst.lines) do
        if burst.active and line.source == "mine" and line.kind == "extra" then
            summary.expected = 2
        end
        local nearTrigger = line.at - burst.at <= 0.5
        for _, cast in ipairs(burst.casts) do
            local age = line.at - cast.at
            if cast.weaponTrigger and age >= 0 and age <= 0.15 then
                nearTrigger = true
            end
        end
        if line.source == "mine" and (line.kind == "spell"
            or line.kind == "spellMiss") and nearTrigger then
            summary.confirmations = summary.confirmations + 1
        end
    end
    if burst.active and summary.confirmations >= 2 then summary.estimated = 2 end
    local dispatches = {}
    for _, id in ipairs(burst.reports) do
        local entry = self.records[id]
        if entry.event == "damage" then summary.rawDamage = summary.rawDamage + 1 end
        if entry.event == "miss" then summary.rawMisses = summary.rawMisses + 1 end
        if entry.who == "other" then summary.rejected = summary.rejected + 1 end
        if entry.who == "unknown" then summary.unknown = summary.unknown + 1 end
        if entry.who == "unknown" and entry.event == "damage"
            and entry.school == 1 then
            summary.unknownPhysical = summary.unknownPhysical + 1
        end
        if entry.who == "other" and entry.event == "damage"
            and entry.school == 1 then
            summary.rejectedPhysical = summary.rejectedPhysical + 1
        end
        if entry.who == "you" and entry.melee then summary.normal = summary.normal + 1 end
        local candidate = entry.procCandidate and entry.candidateSpell == 8232
        local identity = entry.spell == 8232 or entry.procSpell == 8232
        if entry.who == "you" and (candidate or identity) then
            summary.estimated = 2
            if entry.event == "damage" then summary.damage = summary.damage + 1 end
            if entry.event == "miss" then summary.misses = summary.misses + 1 end
            if entry.path then summary.forwarded = summary.forwarded + 1 end
            for dispatch in pairs(entry.dispatches) do
                if dispatches[dispatch] then summary.merged = true end
                dispatches[dispatch] = true
            end
        end
    end
    for _ in pairs(dispatches) do summary.displays = summary.displays + 1 end
    return summary
end

function Tracker:NeedsAttention(burst)
    local retained = false
    for _, current in ipairs(self.bursts) do
        if current == burst then retained = true; break end
    end
    if not retained then return false end
    local summary = self:Summary(burst)
    local missingGranted = summary.expected == 2
        and summary.damage + summary.misses < 2
    local rejectedCandidate = burst.active and summary.confirmations >= 2
        and summary.rejectedPhysical + summary.unknownPhysical > 0
    return missingGranted or rejectedCandidate
        or summary.displays < summary.damage or summary.merged
end

local function Value(value)
    if value == nil then return "-" end
    return tostring(value)
end

function Tracker:ReportText()
    local rows = {
        "MSBT Windfury timeline (metadata only; no damage amounts)",
        "Expected counts require an extra-attack grant; estimated counts are heuristic.",
        "Candidate grouping is separate from spell identity; identity=- means unnamed.",
        "Candidate evidence is timing/enchant based, not proof of spell identity.",
        "Cooldown updates are unconfirmed; targetContext is the current " ..
            "target, not a spell target or ownership evidence.",
        "Dispatch means animation requested, not proof of visible pixels.",
    }
    for _, burst in ipairs(self.bursts) do
        local s = self:Summary(burst)
        rows[#rows + 1] = string.format(
            "Swing #%d %.3f key=%s hand=%s enchant=%s expected=%d estimated=%d " ..
            "WF damage=%d miss=%d normal=%d raw=%d/%d other=%d unknown=%d " ..
            "forwarded=%d dispatches=%d merged=%s truncated=%s " ..
            "cooldowns=%d cooldownsTruncated=%s",
            burst.id, burst.at, Value(burst.key), Value(burst.hand),
            Value(burst.active), s.expected, s.estimated, s.damage, s.misses, s.normal,
            s.rawDamage, s.rawMisses, s.rejected, s.unknown,
            s.forwarded, s.displays,
            Value(s.merged), Value(burst.truncated),
            #burst.cooldowns, Value(burst.cooldownsTruncated))
        for _, line in ipairs(burst.lines) do
            rows[#rows + 1] = string.format("  log +%.3f %s %s",
                line.at - burst.at, Value(line.kind), Value(line.source))
        end
        for _, cast in ipairs(burst.casts) do
            rows[#rows + 1] = string.format(
                "  cast +%.3f spell=%d weaponTrigger=%s",
                cast.at - burst.at, cast.spell, Value(cast.weaponTrigger))
        end
        for _, cooldown in ipairs(burst.cooldowns) do
            rows[#rows + 1] = string.format(
                "  cooldown +%.3f spellID=%s baseSpellID=%s category=%s " ..
                "startRecoveryCategory=%s itemID=%s targetContext=%s",
                cooldown.at - burst.at, Value(cooldown.spellID),
                Value(cooldown.baseSpellID), Value(cooldown.category),
                Value(cooldown.startRecoveryCategory), Value(cooldown.itemID),
                Value(cooldown.targetContext))
        end
        for _, id in ipairs(burst.reports) do
            local e = self.records[id]
            local dispatches = {}
            for dispatch in pairs(e.dispatches) do
                dispatches[#dispatches + 1] = dispatch
            end
            table.sort(dispatches)
            rows[#rows + 1] = string.format(
                "  R%d +%.3f %s school=%s outcome=%s who=%s " ..
                "melee=%s WF=%s candidateSpell=%s identity=%s " ..
                "held=%s path=%s attempted=%s " ..
                "blocked=%s area=%s alpha=%s dispatchIDs=%s", id, e.at - burst.at,
                Value(e.event), Value(e.school), Value(e.outcome),
                Value(e.who), Value(e.melee), Value(e.procSpell == 8232),
                Value(e.procCandidate and e.candidateSpell or nil),
                Value(e.spell or e.procSpell),
                Value(e.held), Value(e.path), Value(e.attempted),
                Value(e.blocked), Value(e.area), Value(e.alpha),
                table.concat(dispatches, ","))
            for _, c in ipairs(e.candidates) do
                local fields = {}
                for key, value in pairs(c) do
                    fields[#fields + 1] = key .. "=" .. Value(value)
                end
                table.sort(fields)
                rows[#rows + 1] = "    " .. table.concat(fields, " ")
            end
        end
    end
    if self.accounting then
        rows[#rows + 1] = ""
        rows[#rows + 1] = "Experimental swing accounting (predictions only; " ..
            "no damage or display changes)"
        for _, row in ipairs(self.accounting:Rows()) do rows[#rows + 1] = row end
    end
    return table.concat(rows, "\n")
end

return Tracker
