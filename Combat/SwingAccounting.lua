-- Opt-in diagnostic accounting. Observations never change combat decisions.
local Accounting = {}
Accounting.__index = Accounting
MikSBT.SwingAccounting = Accounting

local Restricted = MikSBT.API and MikSBT.API.RestrictedValue
local FRAME_WINDOW, SOURCE_LIFETIME, HELD_WINDOW = 0.001, 3, 0.35
local MAX_FRAMES, MAX_OUTCOMES, MAX_SIGNALS = 32, 256, 128
local MAX_RESERVATIONS = 32
local STORMSTRIKE, WEAPON, TOTEM = 17364, 439440, 10610

local function PublicTable(value)
    return Restricted and Restricted:Table(value)
end

local function Number(value)
    value = Restricted and Restricted:Number(value)
    if value and value == value and math.abs(value) < math.huge then
        return value
    end
end

local function Text(value)
    value = Restricted and Restricted:String(value)
    if value and #value > 0 and #value <= 160 then return value end
end

local function Boolean(value)
    return Restricted and Restricted:Boolean(value)
end

local function ReadableFields(info, fields)
    for _, field in ipairs(fields) do
        if not Restricted:CanAccess(rawget(info, field)) then return false end
    end
    return true
end

local function BooleanFields(info, fields)
    for _, field in ipairs(fields) do
        local value = rawget(info, field)
        if not Restricted:CanAccess(value) then return false end
        if value ~= nil and type(value) ~= "boolean" then return false end
    end
    return true
end

local function TextFields(info, fields)
    for _, field in ipairs(fields) do
        local value = rawget(info, field)
        if not Restricted:CanAccess(value) then return false end
        if value ~= nil and not Text(value) then return false end
    end
    return true
end

local function OptionalNumber(info, field)
    local value = rawget(info, field)
    if not Restricted:CanAccess(value) then return false end
    return value == nil or Number(value) ~= nil
end

local function SameFrame(first, second)
    return math.abs(first - second) <= FRAME_WINDOW
end

local function Append(list, value, limit)
    list[#list + 1] = value
    if #list > limit then table.remove(list, 1) end
end

local function Header(info, allowUntargeted)
    info = PublicTable(info)
    if not info then return end
    local at, keyValue = Number(rawget(info, "at")), rawget(info, "key")
    if not at or at < 0 or not Restricted:CanAccess(keyValue) then return end
    local key = Text(keyValue)
    if key or (allowUntargeted and keyValue == nil) then
        return info, at, key
    end
end

local function Reservation(frame, value)
    if #frame.reservations < MAX_RESERVATIONS then
        frame.reservations[#frame.reservations + 1] = value
    else
        frame.truncated = true
    end
end

function Accounting:New()
    return setmetatable({ frames = {}, outcomes = {}, signals = {} }, self)
end

local function SourceFrame(self, at, key, kind)
    kind = kind or "trigger"
    for _, frame in ipairs(self.frames) do
        if frame.key == key and SameFrame(frame.at, at) then
            if kind == "trigger" then
                frame.kind, frame.rangedOnly = kind, nil
            elseif kind == "confirmation" and frame.rangedOnly then
                frame.kind = kind
            end
            return frame
        end
    end
    local frame = { at = at, key = key,
        kind = kind == "ranged" and "trigger" or kind,
        rangedOnly = kind == "ranged", reservations = {} }
    Append(self.frames, frame, MAX_FRAMES)
    return frame
end

function Accounting:Swing(info)
    local input, at, key = Header(info)
    if not input then return end
    local hand = Text(rawget(input, "hand"))
    if hand ~= "main" and hand ~= "off" and hand ~= "ranged" then return end
    local kind = hand == "ranged" and "ranged" or "trigger"
    local frame = SourceFrame(self, at, key, kind)
    Reservation(frame, { kind = "swing", at = at, hand = hand })
end

function Accounting:Cast(info)
    local input, at, key = Header(info, true)
    if not input or Number(rawget(input, "spell")) ~= STORMSTRIKE then
        return
    end
    local guid = Text(rawget(input, "guid"))
    if not OptionalNumber(input, "count") then return end
    local count = Number(rawget(input, "count")) or 1
    if count < 1 or count > MAX_RESERVATIONS or count % 1 ~= 0 then return end
    if guid then
        for _, frame in ipairs(self.frames) do
            for _, entry in ipairs(frame.reservations) do
                if entry.guid == guid then return end
            end
        end
    end
    local frame = SourceFrame(self, at, key)
    for _, entry in ipairs(frame.reservations) do
        if entry.kind == "cast" and (not guid or not entry.guid) then
            frame.duplicateCast = true
            return
        end
    end
    local uncertain = not key or not BooleanFields(input, { "uncertain" })
        or Boolean(rawget(input, "uncertain")) == true
    for ordinal = 1, count do
        Reservation(frame, { kind = "cast", at = at, spell = STORMSTRIKE,
            guid = guid, ordinal = ordinal, uncertain = uncertain })
    end
end

function Accounting:Signal(info)
    info = PublicTable(info)
    if not info then return end
    local at = Number(rawget(info, "at"))
    local spell = Number(rawget(info, "spell"))
    if not at or at < 0 or (spell ~= WEAPON and spell ~= TOTEM) then return end
    for _, signal in ipairs(self.signals) do
        if signal.spell == spell and SameFrame(signal.at, at) then return end
    end
    Append(self.signals, { at = at, spell = spell }, MAX_SIGNALS)
end

local RECEIPT_FIELDS = { "kind", "at", "key", "sourceKey", "hand",
    "spell", "ordinal", "who", "uncertain" }
local EVIDENCE_FIELDS = { "at", "source", "kind", "shared", "capacity",
    "ambiguous" }

local function Receipt(info)
    info = PublicTable(info)
    if not info or not ReadableFields(info, RECEIPT_FIELDS)
        or not BooleanFields(info, { "uncertain" }) then return end
    return {
        kind = Text(rawget(info, "kind")), at = Number(rawget(info, "at")),
        key = Text(rawget(info, "key")),
        sourceKey = Text(rawget(info, "sourceKey")),
        hand = Text(rawget(info, "hand")),
        spell = Number(rawget(info, "spell")),
        ordinal = Number(rawget(info, "ordinal")),
        who = Text(rawget(info, "who")),
        uncertain = Boolean(rawget(info, "uncertain")) == true,
    }
end

local function Evidence(info)
    info = PublicTable(info)
    if not info or not ReadableFields(info, EVIDENCE_FIELDS)
        or not BooleanFields(info, { "shared", "ambiguous" }) then return end
    return {
        at = Number(rawget(info, "at")),
        source = Text(rawget(info, "source")),
        kind = Text(rawget(info, "kind")),
        shared = Boolean(rawget(info, "shared")) == true,
        capacity = Number(rawget(info, "capacity")),
        ambiguous = Boolean(rawget(info, "ambiguous")) == true,
    }
end

local BOOLEAN_FIELDS = { "tick", "melee", "extra", "ambiguous",
    "periodicOnly", "confirmed" }
local TEXT_FIELDS = { "who", "event", "restrict" }
local DirectEvidence, CandidateOutcome

function Accounting:Outcome(info)
    local input, at, key = Header(info)
    if not input then return end
    local id = Number(rawget(input, "id"))
    if not id or id < 1 or id % 1 ~= 0 then return end
    for _, outcome in ipairs(self.outcomes) do
        if outcome.id == id then return end
    end
    if not BooleanFields(input, BOOLEAN_FIELDS)
        or not TextFields(input, TEXT_FIELDS)
        or not OptionalNumber(input, "school")
        or not OptionalNumber(input, "spell")
        or not ReadableFields(input, { "receipt", "evidence" }) then return end
    local restrict = rawget(input, "restrict")
    if restrict ~= nil and restrict ~= "direct" and restrict ~= "tick"
        and restrict ~= "swing" and restrict ~= "shot" then return end
    local receiptValue, evidenceValue = rawget(input, "receipt"),
        rawget(input, "evidence")
    local receipt, evidence = Receipt(receiptValue), Evidence(evidenceValue)
    if (receiptValue ~= nil and not receipt)
        or (evidenceValue ~= nil and not evidence) then return end
    local outcome = { id = id, at = at, key = key,
        school = Number(rawget(input, "school")),
        spell = Number(rawget(input, "spell")),
        receipt = receipt, evidence = evidence }
    for _, field in ipairs(BOOLEAN_FIELDS) do
        local value = rawget(input, field)
        if not Restricted:CanAccess(value) then return end
        outcome[field] = Boolean(value)
    end
    for _, field in ipairs(TEXT_FIELDS) do
        outcome[field] = Text(rawget(input, field))
    end
    Append(self.outcomes, outcome, MAX_OUTCOMES)
    local evidence = outcome.evidence
    if not outcome.receipt and CandidateOutcome(outcome) then
        local age = outcome.at - evidence.at
        if evidence.at >= 0 and age >= -HELD_WINDOW and age <= SOURCE_LIFETIME then
            SourceFrame(self, evidence.at, key, "confirmation")
        end
    end
end

local function MergeFrames(target, source)
    local hadCast = false
    for _, entry in ipairs(target.reservations) do
        if entry.kind == "cast" then hadCast = true end
    end
    for _, entry in ipairs(source.reservations) do
        local competingCast = false
        if hadCast and entry.kind == "cast" then
            for _, other in ipairs(target.reservations) do
                if other.kind == "cast" and (not entry.guid or not other.guid) then
                    competingCast = true
                    target.duplicateCast = true
                end
            end
        end
        if not competingCast then Reservation(target, entry) end
    end
    if source.kind == "trigger" and not source.rangedOnly then
        target.kind, target.rangedOnly = "trigger", nil
    elseif source.kind == "confirmation" and target.rangedOnly then
        target.kind = "confirmation"
    end
    target.truncated = target.truncated or source.truncated
    target.duplicateCast = target.duplicateCast or source.duplicateCast
end

function Accounting:Rekey(old, new)
    old, new = Text(old), Text(new)
    if not old or not new or old == new then return end
    for _, frame in ipairs(self.frames) do
        if frame.key == old then frame.key = new end
    end
    for first = 1, #self.frames do
        local frame = self.frames[first]
        if frame and frame.key == new then
            for second = #self.frames, first + 1, -1 do
                local alias = self.frames[second]
                if alias.key == new and SameFrame(frame.at, alias.at) then
                    MergeFrames(frame, alias)
                    table.remove(self.frames, second)
                end
            end
        end
    end
    for _, outcome in ipairs(self.outcomes) do
        if outcome.key == old then outcome.key = new end
        local receipt = outcome.receipt
        if receipt then
            if receipt.key == old then receipt.key = new end
            if receipt.sourceKey == old then receipt.sourceKey = new end
        end
    end
end

function Accounting:Reset()
    self.frames, self.outcomes, self.signals = {}, {}, {}
end

local function Summary(frame)
    local summary = { at = frame.at, key = frame.key, frameKind = frame.kind,
        normalObserved = 0, normalMatched = 0, normalUnresolved = 0,
        ssObserved = 0, ssReserved = 0, ssMatched = 0, targetUnresolved = 0,
        excludedPeriodic = 0,
        excludedKnown = 0, ownedPhysicalExtras = 0, unownedPhysical = 0,
        ownedPhysicalUnassigned = 0,
        parentUnresolvedFrames = frame.kind == "confirmation" and 1 or 0,
        physicalObserved = 0, ambiguous = 0, unknownSource = 0,
        sourceAmbiguous = 0, sharedEvidence = 0, unlinked = 0,
        weaponSignals = 0, totemSignals = 0,
        weaponCapacity = 0, totemCapacity = 0 }
    for _, entry in ipairs(frame.reservations or {}) do
        if entry.kind == "swing" and entry.hand ~= "ranged" then
            summary.normalObserved = summary.normalObserved + 1
        elseif entry.kind == "cast" then
            summary.ssObserved = summary.ssObserved + 1
            summary.ssReserved = summary.ssReserved + 1
            if not frame.key or entry.uncertain then
                summary.targetUnresolved = summary.targetUnresolved + 1
            end
        end
        if entry.uncertain then summary.ambiguous = summary.ambiguous + 1 end
    end
    if frame.duplicateCast or frame.truncated then
        summary.ambiguous = summary.ambiguous + 1
    end
    return summary
end

local function PhysicalTrigger(summary)
    return summary.normalObserved > 0 or summary.ssReserved > 0
end

local function SourceMatches(frame, at, key, reportAt)
    local age = reportAt - frame.at
    return frame.key == key and SameFrame(frame.at, at)
        and age >= -HELD_WINDOW and age <= SOURCE_LIFETIME
end

local function FindFrame(self, outcome)
    local receipt, evidence = outcome.receipt, outcome.evidence
    local at, key
    if receipt and receipt.at then
        at, key = receipt.at, receipt.sourceKey or receipt.key
    elseif evidence and evidence.source == "mine" and not evidence.ambiguous then
        at, key = evidence.at, outcome.key
    end
    if not at or key ~= outcome.key then return end
    local found
    for index, frame in ipairs(self.frames) do
        if SourceMatches(frame, at, key, outcome.at) then
            if found then return end
            found = index
        end
    end
    return found
end

local function MatchReceipt(frame, receipt, used)
    if not receipt.at or receipt.uncertain
        or (receipt.who and receipt.who ~= "you") then
        return
    end
    local found
    for index, entry in ipairs(frame.reservations) do
        local matches = entry.kind == receipt.kind
            and SameFrame(entry.at, receipt.at) and not entry.uncertain
        if entry.kind == "swing" then
            matches = matches and entry.hand == receipt.hand
                and entry.hand ~= "ranged"
        else
            matches = matches and entry.spell == receipt.spell
                and (not receipt.ordinal or entry.ordinal == receipt.ordinal)
        end
        if matches then
            if found then return end
            found = index
        end
    end
    if found and not used[found] then
        used[found] = true
        return frame.reservations[found].kind
    end
end

DirectEvidence = function(outcome)
    local evidence = outcome.evidence
    if not evidence or evidence.source ~= "mine" or evidence.ambiguous
        or not evidence.at then return false end
    local direct = evidence.kind == "spell" or evidence.kind == "spellMiss"
        or evidence.kind == "direct"
    local extraSwing = outcome.extra == true and
        (evidence.kind == "swing" or evidence.kind == "swingMiss")
    if not direct and not extraSwing then return false end
    if outcome.restrict and outcome.restrict ~= "direct"
        and not (extraSwing and outcome.restrict == "swing") then return false end
    return not evidence.shared or (evidence.capacity and evidence.capacity > 0)
end

CandidateOutcome = function(outcome)
    return outcome.who == "you" and outcome.confirmed
        and outcome.school == 1 and not outcome.spell
        and (outcome.event == "damage" or outcome.event == "miss")
        and not outcome.tick and not outcome.periodicOnly and not outcome.ambiguous
        and (not outcome.melee or outcome.extra) and DirectEvidence(outcome)
end

local function Observe(frame, summary, outcome, used)
    local physical = outcome.school == 1
        and (outcome.event == "damage" or outcome.event == "miss")
    if physical then summary.physicalObserved = summary.physicalObserved + 1 end
    if outcome.ambiguous then
        summary.ambiguous = summary.ambiguous + 1
    elseif outcome.tick or outcome.periodicOnly or outcome.spell == 21949 then
        summary.excludedPeriodic = summary.excludedPeriodic + 1
    elseif outcome.spell and outcome.spell ~= STORMSTRIKE then
        summary.excludedKnown = summary.excludedKnown + 1
    elseif outcome.who ~= "you" then
        if physical then summary.unownedPhysical = summary.unownedPhysical + 1 end
    elseif outcome.receipt then
        local kind = MatchReceipt(frame, outcome.receipt, used)
        if kind == "swing" then
            summary.normalMatched = summary.normalMatched + 1
        elseif kind == "cast" then
            summary.ssMatched = summary.ssMatched + 1
        else
            summary.ambiguous = summary.ambiguous + 1
        end
    elseif CandidateOutcome(outcome) then
        if summary.frameKind == "confirmation" then
            summary.ownedPhysicalUnassigned = summary.ownedPhysicalUnassigned + 1
        elseif PhysicalTrigger(summary) then
            summary.ownedPhysicalExtras = summary.ownedPhysicalExtras + 1
        else
            summary.unknownSource = summary.unknownSource + 1
            return
        end
        local evidence = outcome.evidence
        if evidence.shared then
            summary.sharedEvidence = summary.sharedEvidence + 1
            summary.sharedCapacity = math.min(
                summary.sharedCapacity or evidence.capacity, evidence.capacity)
        end
    elseif physical then
        summary.unknownSource = summary.unknownSource + 1
    end
end

local function Verdict(summary)
    summary.normalUnresolved = summary.normalObserved - summary.normalMatched
    summary.weaponCapacity = summary.weaponSignals * 2
    summary.totemCapacity = summary.totemSignals
    local capacity = summary.weaponCapacity + summary.totemCapacity
    if summary.ownedPhysicalExtras + summary.ownedPhysicalUnassigned > 0 then
        if summary.weaponSignals > 0 and summary.totemSignals > 0 then
            summary.familyCandidate = "weapon+totem"
        elseif summary.weaponSignals > 0 then
            summary.familyCandidate = "weapon"
        elseif summary.totemSignals > 0 then
            summary.familyCandidate = "totem"
        end
    end
    summary.verdict, summary.reason = "unresolved", "no-source-frame"
    if summary.unlinked > 0 then return end
    if summary.targetUnresolved > 0 then
        summary.reason = "unknown-target"
        return
    end
    if summary.key == nil then return end
    if summary.sourceAmbiguous > 0 then
        summary.reason = "ambiguous-source"
    elseif summary.ambiguous > 0 then
        summary.reason = "ambiguous-outcome"
    elseif summary.unknownSource > 0 then
        summary.reason = "missing-source-evidence"
    elseif summary.parentUnresolvedFrames > 0 then
        summary.reason = "parent-unresolved"
    elseif summary.normalUnresolved > 0 or summary.ssMatched < summary.ssReserved then
        summary.reason = "missing-reservation-outcome"
    elseif summary.sharedCapacity and summary.sharedEvidence > summary.sharedCapacity then
        summary.reason = "shared-evidence-capacity"
    elseif summary.ownedPhysicalExtras == 0 then
        summary.verdict = "none"
        summary.reason = summary.physicalObserved == 0
            and "no-physical-reports" or "no-physical-extras"
    elseif capacity == 0 then
        summary.reason = "no-signal"
    elseif summary.ownedPhysicalExtras > capacity then
        summary.reason = "capacity-exceeded"
    else
        summary.verdict = "candidate"
        if summary.weaponSignals > 0 and summary.totemSignals > 0 then
            summary.reason = "weapon-totem-ambiguous"
        else
            summary.reason = summary.weaponSignals > 0
                and "weapon-policy" or "totem-policy"
        end
    end
end

function Accounting:Summaries()
    local summaries, used = {}, {}
    local orphan = Summary({})
    for index, frame in ipairs(self.frames) do
        summaries[index], used[index] = Summary(frame), {}
    end
    for _, signal in ipairs(self.signals) do
        local candidates = {}
        for index, frame in ipairs(self.frames) do
            local eligible = PhysicalTrigger(summaries[index])
                or frame.kind == "confirmation"
            if eligible and SameFrame(frame.at, signal.at) then
                candidates[#candidates + 1] = index
            end
        end
        if #candidates == 1 then
            local summary = summaries[candidates[1]]
            local field = signal.spell == WEAPON and "weaponSignals" or "totemSignals"
            summary[field] = summary[field] + 1
        else
            local field = signal.spell == WEAPON and "weaponSignals" or "totemSignals"
            orphan[field] = orphan[field] + 1
            for _, index in ipairs(candidates) do
                summaries[index].sourceAmbiguous = summaries[index].sourceAmbiguous + 1
            end
        end
    end
    for _, outcome in ipairs(self.outcomes) do
        local index = FindFrame(self, outcome)
        if index then
            Observe(self.frames[index], summaries[index], outcome, used[index])
        else
            orphan.unlinked = orphan.unlinked + 1
        end
    end
    for _, summary in ipairs(summaries) do Verdict(summary) end
    if orphan.unlinked > 0 or orphan.weaponSignals > 0 or orphan.totemSignals > 0 then
        Verdict(orphan)
        summaries[#summaries + 1] = orphan
    end
    return summaries
end

function Accounting:Rows()
    local rows = {}
    for _, summary in ipairs(self:Summaries()) do
        local row = string.format(
            "accounting at=%s key=%s normal=%d/%d unresolved=%d SS=%d/%d " ..
            "physical=%d extra=%d unowned=%d excluded-periodic=%d known=%d " ..
            "ambiguous=%d source-ambiguous=%d unknown-source=%d unlinked=%d " ..
            "Weapon=%d(hint=%d) Totem=%d(hint=%d) verdict=%s:%s",
            summary.at and string.format("%.3f", summary.at) or "?",
            summary.key or "?", summary.normalMatched, summary.normalObserved,
            summary.normalUnresolved, summary.ssMatched, summary.ssReserved,
            summary.physicalObserved, summary.ownedPhysicalExtras,
            summary.unownedPhysical, summary.excludedPeriodic,
            summary.excludedKnown, summary.ambiguous, summary.sourceAmbiguous,
            summary.unknownSource, summary.unlinked, summary.weaponSignals,
            summary.weaponCapacity, summary.totemSignals, summary.totemCapacity,
            summary.verdict, summary.reason)
        if summary.frameKind == "confirmation" then
            row = row .. string.format(" frame=confirmation unassigned=%d",
                summary.ownedPhysicalUnassigned)
        end
        if summary.targetUnresolved > 0 then
            row = row .. " target-unresolved=" .. summary.targetUnresolved
        end
        if summary.familyCandidate then
            row = row .. " family-candidate=" .. summary.familyCandidate
        end
        rows[#rows + 1] = row
    end
    return rows
end

return Accounting
