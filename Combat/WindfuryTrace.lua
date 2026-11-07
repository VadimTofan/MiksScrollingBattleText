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
        active = active, reports = {}, lines = {} }
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
    local summary = { expected = 0, damage = 0, misses = 0, normal = 0,
        rawDamage = 0, rawMisses = 0, rejected = 0, forwarded = 0,
        displays = 0, merged = false, confirmations = 0 }
    for _, line in ipairs(burst.lines) do
        if burst.active and line.source == "mine" and line.kind == "extra" then
            summary.expected = 2
        end
        if line.source == "mine" and (line.kind == "spell"
            or line.kind == "spellMiss") and line.at - burst.at <= 0.5 then
            summary.confirmations = summary.confirmations + 1
        end
    end
    if burst.active and summary.confirmations >= 2 then summary.expected = 2 end
    local dispatches = {}
    for _, id in ipairs(burst.reports) do
        local entry = self.records[id]
        if entry.event == "damage" then summary.rawDamage = summary.rawDamage + 1 end
        if entry.event == "miss" then summary.rawMisses = summary.rawMisses + 1 end
        if entry.who == "other" then summary.rejected = summary.rejected + 1 end
        if entry.who == "you" and entry.melee then summary.normal = summary.normal + 1 end
        if entry.who == "you" and entry.procSpell == 8232 then
            summary.expected = 2
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
    return summary.expected == 2 and (summary.damage < 2
        or summary.displays < summary.damage or summary.merged)
end

local function Value(value)
    if value == nil then return "-" end
    return tostring(value)
end

function Tracker:ReportText()
    local rows = {
        "MSBT Windfury timeline (metadata only; no damage amounts)",
        "Expected: 2 extra outcomes per candidate proc, plus the normal swing.",
        "Candidate evidence is timing/enchant based, not proof of spell identity.",
        "Dispatch means animation requested, not proof of visible pixels.",
    }
    for _, burst in ipairs(self.bursts) do
        local s = self:Summary(burst)
        rows[#rows + 1] = string.format(
            "Swing #%d %.3f key=%s hand=%s enchant=%s expected=%d " ..
            "WF damage=%d miss=%d normal=%d raw=%d/%d other=%d " ..
            "forwarded=%d dispatches=%d merged=%s truncated=%s",
            burst.id, burst.at, Value(burst.key), Value(burst.hand),
            Value(burst.active), s.expected, s.damage, s.misses, s.normal,
            s.rawDamage, s.rawMisses, s.rejected, s.forwarded, s.displays,
            Value(s.merged), Value(burst.truncated))
        for _, line in ipairs(burst.lines) do
            rows[#rows + 1] = string.format("  log +%.3f %s %s",
                line.at - burst.at, Value(line.kind), Value(line.source))
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
                "melee=%s WF=%s held=%s path=%s attempted=%s " ..
                "blocked=%s area=%s alpha=%s dispatchIDs=%s", id, e.at - burst.at,
                Value(e.event), Value(e.school), Value(e.outcome),
                Value(e.who), Value(e.melee), Value(e.procSpell == 8232),
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
    return table.concat(rows, "\n")
end

return Tracker
