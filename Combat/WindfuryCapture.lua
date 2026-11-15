-- Opt-in, development-only Windfury diagnostics. Not loaded by release TOCs.
local Capture = { generation = 0 }
MikSBT.WindfuryCapture = Capture
local RV = MikSBT.API.RestrictedValue
local COOLDOWN_EVENT = "SPELL_UPDATE_COOLDOWN"
local ACCOUNTING_RESULT_FIELDS = {
    who = "string", spell = "number", procSpell = "number",
    tick = "boolean", melee = "boolean", extra = "boolean", ambiguous = "boolean",
}
local ACCOUNTING_INFO_FIELDS = {
    at = "number", key = "string", confirmed = "boolean", restrict = "string",
    receipt = "table", evidence = "table",
}

local function PublicFields(info, fields)
    if not RV:Table(info) then return false end
    for field, expectedType in pairs(fields) do
        local value = rawget(info, field)
        if not RV:CanAccess(value)
            or (value ~= nil and type(value) ~= expectedType) then return false end
    end
    return true
end

local function Pack(...) return { n = select("#", ...), ... } end
local function Metadata(value)
    return RV:String(value) or RV:Number(value) or RV:Boolean(value)
end

function Capture:EnableAccounting()
    if not self.ledger then return end
    local mine = MikSBT.CombatEngine.mine
    if self.accountingMine == mine then return end
    if self.accountingMine then
        self.accountingMine.accountingEnabled = self.previousAccounting
        self.accountingMine.lastOutcomeReceipt = nil
    end
    self.accountingMine = mine
    self.previousAccounting = mine and mine.accountingEnabled or nil
    if mine then mine.accountingEnabled = true end
end

function Capture:AccountingOutcome(record)
    if not self.ledger or (record.event ~= "damage"
        and record.event ~= "miss") then return end
    local result = record.result or {}
    local info = record.accounting or self.model:Lookup(record) or {}
    if not PublicFields(result, ACCOUNTING_RESULT_FIELDS)
        or not PublicFields(info, ACCOUNTING_INFO_FIELDS) then return end
    local id = self.accountingIDs[record]
    if not id then
        self.accountingNextID = self.accountingNextID + 1
        id = self.accountingNextID
        self.accountingIDs[record] = id
    end
    local spell = RV:Number(result.spell or result.procSpell)
    local facts = spell and MikSBT.CombatEngine.SpellFacts
        and MikSBT.CombatEngine.SpellFacts(spell)
    self.ledger:Outcome({
        id = id, at = RV:Number(info.at), key = RV:String(info.key),
        who = RV:String(result.who), event = RV:String(record.event),
        school = RV:Number(record.school), spell = spell,
        tick = RV:Boolean(result.tick), melee = RV:Boolean(result.melee),
        extra = RV:Boolean(result.extra), ambiguous = RV:Boolean(result.ambiguous),
        periodicOnly = facts and facts.direct == false and facts.ticks == true,
        confirmed = RV:Boolean(info.confirmed), restrict = RV:String(info.restrict),
        receipt = info.receipt, evidence = info.evidence,
    })
end

function Capture:AccountingChecks(record)
    local entry = self.model:Lookup(record)
    if entry then
        local marker = RV:Number(record.inferredWindfuryIcon)
        entry.inferredIcon = marker == 8232 and marker or nil
    end
    if not self.ledger then return end
    local metadata = RV:Table(record.accounting)
    local checks = metadata and RV:Table(metadata.swingChecks)
    if not entry or not checks then return end
    entry.swingChecks = {}
    for index = 1, math.min(#checks, 8) do
        local check = RV:Table(checks[index])
        if check then
            entry.swingChecks[#entry.swingChecks + 1] = {
                at = RV:Number(check.at), hand = RV:String(check.hand),
                age = RV:Number(check.age), early = RV:Number(check.early),
                late = RV:Number(check.late),
                delayedEarly = RV:Number(check.delayedEarly),
                delayedLate = RV:Number(check.delayedLate),
                used = RV:Boolean(check.used), eligible = RV:Boolean(check.eligible),
                reason = RV:String(check.reason),
            }
        end
    end
end

-- Restore correlation context even if the observed method raises an error.
function Capture:Wrap(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        if not self.active then return original(...) end
        local previous = self.ids
        local args = Pack(...)
        local result
        local ok, err = pcall(function()
            result = Pack(callback(original, unpack(args, 1, args.n)))
        end)
        self.ids = previous
        if not ok then error(err, 0) end
        return unpack(result, 1, result.n)
    end
end

function Capture:Observe(stage, hit, info)
    if not self.active then return end
    if stage == "rekey" then
        self.model:Rekey(info.old, info.new)
        if self.ledger then self.ledger:Rekey(info.old, info.new) end
        return
    end
    local record = hit.record
    if stage == "report" then
        if record.event ~= "damage" and record.event ~= "miss" then return end
        self.model:Report(record, { at = hit.at, key = hit.key,
            unit = hit.unit, event = record.event,
            school = RV:Number(record.school), outcome = RV:String(record.missWord) })
    elseif stage == "decision" then
        self.model:Decision(record, record.result or {})
        self:AccountingChecks(record)
        if info then self.model:Candidate(record, info) end
    elseif stage == "candidate" then
        self.model:Candidate(record, info)
    end
end

function Capture:Event(event, duration, hand, spell)
    local ns = MikSBT.CombatEngine
    local key = ns.TargetKey()
    if event == "PLAYER_SWING" then
        local burst = self.model:Swing(GetTime(), key, Metadata(hand),
            ns.ActiveWindfurySpell(1) == 8232, RV:Number(duration))
        if self.ledger then
            local hands = { [0] = "main", [1] = "off", [2] = "ranged" }
            local swingType = RV:Number(hand)
            self.ledger:Swing({ at = GetTime(), key = RV:String(key),
                hand = swingType and hands[swingType] or nil })
        end
        local generation, model = self.generation, self.model
        C_Timer.After(3.1, function()
            if not self.active or self.generation ~= generation then return end
            if model:NeedsAttention(burst) then
                self:Stop()
                self:ShowReport()
                MikSBT.Print("Windfury capture paused: candidate outcomes or " ..
                    "display dispatches need review. Copy the report.")
            end
        end)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = RV:Number(spell)
        if RV:String(duration) == "player" and spellID then
            local facts = ns.SpellFacts and ns.SpellFacts(spellID)
            local weaponTrigger = facts and facts.direct == true
                and facts.school == 1 and facts.helpful ~= true
                and not facts.weaponProc
            local recipient = ns.reader and ns.reader.lastCastTarget
            local observed = recipient and recipient.unit == "player"
                and recipient.spell == spellID and recipient.at == GetTime()
            local recipientObserved
            if observed then recipientObserved = RV:Boolean(recipient.observed) end
            local target = {
                key = observed and RV:String(recipient.key) or nil,
                uncertain = not observed or recipientObserved ~= true
                    or recipient.uncertain == true,
                observed = recipientObserved,
                guidReadable = RV:String(hand) ~= nil,
            }
            self.model:Cast(GetTime(), key, spellID, weaponTrigger, target)
            if self.ledger and spellID == 17364 then
                local reservationKey
                if not target.uncertain then reservationKey = target.key end
                self.ledger:Cast({ at = GetTime(),
                    key = reservationKey, spell = spellID, count = 1,
                    guid = RV:String(hand), uncertain = target.uncertain })
            end
        end
    elseif event == "COMBAT_LOG_MESSAGE" then
        local lines = ns.reader and ns.reader.logLines
        local line = lines and lines[#lines]
        if line and line.at == GetTime() then self.model:Log(line, key) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if self.ledger then self.ledger:Reset() end
        self:EnableAccounting()
    end
end

function Capture:Cooldown(spellID, baseSpellID, category,
    startRecoveryCategory, itemID)
    if not self.active then return end
    if self.ledger then
        self.ledger:Signal({ at = GetTime(), spell = RV:Number(spellID) })
    end
    self.model:Cooldown(GetTime(), RV:String(MikSBT.CombatEngine.TargetKey()), {
        spellID = RV:Number(spellID), baseSpellID = RV:Number(baseSpellID),
        category = RV:Number(category),
        startRecoveryCategory = RV:Number(startRecoveryCategory),
        itemID = RV:Number(itemID),
    })
end

function Capture:StartCooldownEvents()
    local available = MikSBT.CombatEngine.EventAvailable
    if not C_EventUtils or type(C_EventUtils.IsEventValid) ~= "function"
        or type(available) ~= "function" then return end
    local ok, supported = pcall(available, COOLDOWN_EVENT)
    if not ok or RV:Boolean(supported) ~= true then return end
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == COOLDOWN_EVENT then self:Cooldown(...) end
        end)
    end
    self.eventFrame:RegisterEvent(COOLDOWN_EVENT)
end

function Capture:Gate(service, settings)
    local config = service.config
    if settings.disabled then return "event disabled" end
    if config.isModDisabled() then return "addon disabled" end
    local profile = config.getProfile()
    local category = settings.textCategory or "Notifications"
    if profile["msbt" .. category .. "Disabled"] then return "category disabled" end
    local area = config.scrollAreas:Resolve(settings.scrollArea or config.defaultArea)
    if not area then return "area missing" end
    if area.disabled then return "area disabled" end
end

function Capture:Install()
    if self.installed then return end
    self.installed = true
    local components = MikSBT.Components
    hooksecurefunc(components.CombatEngine, "HandleEvent", function(_, ...)
        if self.active then self:Event(...) end
    end)
    if type(components.CombatEngine.Stop) == "function" then
        hooksecurefunc(components.CombatEngine, "Stop", function()
            if self.active then self:Stop() end
        end)
    end
    self:Wrap(components.CombatPresentation, "Out", function(original, object, record)
        self.model:Decision(record, record.result or {})
        self:AccountingChecks(record)
        self:AccountingOutcome(record)
        local entry = self.model:Lookup(record)
        self.ids = entry and { entry.id } or nil
        return original(object, record)
    end)
    self:Wrap(components.OutgoingBatcher, "DisplayRestricted",
        function(original, object, ...)
            local ids = self.ids or {}
            self.model:Forward(ids, "restricted")
            self.model:Attempt(ids, "no display request (settings or presentation)")
            return original(object, ...)
        end)
    self:Wrap(components.OutgoingBatcher, "Queue", function(original, object, ...)
        local ids = self.ids or {}
        local counts = {}
        for _, batch in pairs(object.batches) do counts[batch] = batch.hitCount end
        local result = Pack(original(object, ...))
        local found
        for _, batch in pairs(object.batches) do
            if batch.hitCount ~= counts[batch] then
                found = true
                local batchIDs = self.batchIDs[batch] or {}
                self.batchIDs[batch] = batchIDs
                for _, id in ipairs(ids) do
                    if #batchIDs < 256 then batchIDs[#batchIDs + 1] = id end
                end
            end
        end
        if found then self.model:Forward(ids, "batch")
        else self.model:Attempt(ids, "queue declined public amount") end
        return unpack(result, 1, result.n)
    end)
    self:Wrap(components.OutgoingBatcher, "Flush", function(original, object, key)
        local batch = object.batches[key]
        self.ids = batch and self.batchIDs[batch] or nil
        self.model:Attempt(self.ids or {}, "batch settings unavailable")
        if batch then self.batchIDs[batch] = nil end
        return original(object, key)
    end)
    local service = MikSBT.Display.Service
    self:Wrap(service, "DisplayEvent", function(original, object, settings, ...)
        self.model:Attempt(self.ids or {}, self:Gate(object, settings)
            or "display requested without animation dispatch")
        return original(object, settings, ...)
    end)
    self:Wrap(service.config, "display", function(original, message, area, sticky,
        red, green, blue, size, font, outline, alpha, ...)
        self.model:Dispatch(self.ids or {}, {
            area = RV:String(area.name) or RV:String(area.id) or "resolved area",
            alpha = RV:Number(alpha),
        })
        return original(message, area, sticky, red, green, blue, size, font,
            outline, alpha, ...)
    end)
end

function Capture:Start()
    local client = MikSBT.Compatibility and MikSBT.Compatibility.Client
    if not (client and client.isForever) then
        MikSBT.Print("Windfury capture requires the Forever combat reader.")
        return
    end
    self:Stop()
    self.model = MikSBT.WindfuryTraceModel:New()
    self.ledger = MikSBT.SwingAccounting and MikSBT.SwingAccounting:New() or nil
    self.model.accounting = self.ledger
    self.accountingIDs = setmetatable({}, { __mode = "k" })
    self.accountingNextID = 0
    self:EnableAccounting()
    self.batchIDs = setmetatable({}, { __mode = "k" })
    self:Install()
    self.observer = function(...) self:Observe(...) end
    MikSBT.CombatEngine.traceCombat = self.observer
    self.active = true
    self:StartCooldownEvents()
    if self.frame then self.frame:Hide() end
    MikSBT.Print("Windfury capture armed: fight normally. It pauses on a " ..
        "candidate needing review. /msbttrace report opens it.")
end

function Capture:Stop()
    self.active = false
    if self.accountingMine then
        self.accountingMine.accountingEnabled = self.previousAccounting
        self.accountingMine.lastOutcomeReceipt = nil
        self.accountingMine = nil
    end
    if self.eventFrame then self.eventFrame:UnregisterEvent(COOLDOWN_EVENT) end
    self.generation = self.generation + 1
    local ns = MikSBT.CombatEngine
    if self.observer and ns.traceCombat == self.observer then ns.traceCombat = nil end
    self.ids = nil
end

function Capture:ShowReport()
    if not self.model then
        MikSBT.Print("Start a Windfury capture with /msbttrace wf first.")
        return
    end
    if not self.frame then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(850, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        frame:SetBackdropColor(0, 0, 0, 0.95)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -12)
        title:SetText("Windfury report | Ctrl+A, Ctrl+C to copy | Escape to close")
        local scroll = CreateFrame("ScrollFrame", nil, frame,
            "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -40)
        scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(790)
        edit:SetScript("OnEscapePressed", function() edit:ClearFocus(); frame:Hide() end)
        scroll:SetScrollChild(edit)
        self.frame, self.edit = frame, edit
    end
    self.edit:SetText(self.model:ReportText())
    self.frame:Show()
    self.edit:SetFocus()
    self.edit:HighlightText()
end

return Capture
