-- Opt-in, development-only Windfury diagnostics. Not loaded by release TOCs.
local Capture = { generation = 0 }
MikSBT.WindfuryCapture = Capture
local RV = MikSBT.API.RestrictedValue

local function Pack(...) return { n = select("#", ...), ... } end
local function Metadata(value)
    return RV:String(value) or RV:Number(value) or RV:Boolean(value)
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
        if info then self.model:Candidate(record, info) end
    elseif stage == "candidate" then
        self.model:Candidate(record, info)
    end
end

function Capture:BeginTimeline(hand, spell)
    local ns = MikSBT.CombatEngine
    local key = ns.TargetKey()
    local active = ns.ProcSpell(GetTime(), 1) == 8232
    local burst
    if spell then burst = self.model:Strike(GetTime(), key, spell, active)
    else burst = self.model:Swing(GetTime(), key, Metadata(hand), active) end
    local generation, model = self.generation, self.model
    C_Timer.After(3.1, function()
        if not self.active or self.generation ~= generation then return end
        if model:NeedsAttention(burst) then
            self:Stop()
            self:ShowReport()
            MikSBT.Print("Windfury capture paused: fewer than two damage " ..
                "numbers. Copy the report; misses and batching are listed.")
        end
    end)
end

function Capture:Event(event, first, second, third)
    local ns = MikSBT.CombatEngine
    if event == "PLAYER_SWING" then
        self:BeginTimeline(second)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED"
        and RV:Equals(first, "player") and RV:Equals(third, 17364) then
        self:BeginTimeline(nil, 17364)
    elseif event == "COMBAT_LOG_MESSAGE" then
        local lines = ns.reader and ns.reader.logLines
        local line = lines and lines[#lines]
        if line and line.at == GetTime() then
            self.model:Log(line, ns.TargetKey())
        end
    end
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
    self:Wrap(components.CombatPresentation, "Out", function(original, object, record)
        self.model:Decision(record, record.result or {})
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
    self.batchIDs = setmetatable({}, { __mode = "k" })
    self:Install()
    self.observer = function(...) self:Observe(...) end
    MikSBT.CombatEngine.traceCombat = self.observer
    self.active = true
    if self.frame then self.frame:Hide() end
    MikSBT.Print("Windfury capture armed: fight normally. It pauses on a " ..
        "candidate with fewer than two numbers. /msbttrace report opens it.")
end

function Capture:Stop()
    self.active = false
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
