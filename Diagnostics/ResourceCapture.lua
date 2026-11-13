-- Opt-in source investigation. Excluded from release manifests and packages.
local Capture = { rows = {}, generation = 0, gains = 0, logs = 0 }
MikSBT.ResourceCapture = Capture
local RV = MikSBT.API.RestrictedValue
local MAX_ROWS = 120

local function Describe(value)
    if RV:IsRestricted(value) then return "<secret>" end
    local kind = type(value)
    if kind == "string" then
        -- Do not copy protected strings into the exportable report.
        if value:find("|K", 1, true) then return "<protected-text>" end
        return value:gsub("[\r\n]", " "):sub(1, 80)
    end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    return kind
end

function Capture:Write(text)
    if #self.rows == MAX_ROWS then table.remove(self.rows, 1) end
    self.rows[#self.rows + 1] = string.format("%.3f %s",
        GetTime() - self.startedAt, text)
end

function Capture:Resource(kind, ...)
    local count, fields = select("#", ...), {}
    for index = 1, count do
        fields[index] = index .. "=" .. Describe(select(index, ...))
    end
    self:Write(kind .. " argc=" .. count .. " " .. table.concat(fields, " "))
end

function Capture:Log(...)
    self.logs = self.logs + 1
    -- Log traffic must not displace the resource payloads being investigated.
    if self.logs > 20 then return end
    local text = select(1, ...)
    local textKind = RV:IsRestricted(text) and "<secret>" or "<formatted-text>"
    self:Write("log argc=" .. select("#", ...) .. " text=" .. textKind)
end

function Capture:OnEvent(event, ...)
    if not self.active then return end
    if event == "COMBAT_TEXT_UPDATE" then
        local kind = RV:String((...))
        if kind ~= "ENERGIZE" and kind ~= "PERIODIC_ENERGIZE" then return end
        self.gains = self.gains + 1
        local getter = C_CombatText and C_CombatText.GetCurrentEventInfo
        local ok = type(getter) == "function" and pcall(function()
            self:Resource(kind, getter())
        end)
        if not ok then self:Write(kind .. " payload unavailable") end
    elseif event == "COMBAT_LOG_MESSAGE" then
        self:Log(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if RV:Equals(unit, "player") then
            self:Write("player cast spellID=" .. Describe(spellID)
                .. " (context only)")
        end
    end
end

function Capture:Stop()
    self.active = false
    self.generation = self.generation + 1
    if self.listener then self.listener:UnregisterAllEvents() end
end

function Capture:Start()
    self:Stop()
    local client = MikSBT.Compatibility and MikSBT.Compatibility.Client
    if not (client and client.isForever) then
        MikSBT.Print("Resource capture requires the Forever client.")
        return
    end
    if not self.listener then
        self.listener = CreateFrame("Frame")
        self.listener:SetScript("OnEvent", function(_, event, ...)
            self:OnEvent(event, ...)
        end)
    end
    self.rows, self.gains, self.logs = {}, 0, 0
    self.startedAt, self.active = GetTime(), true
    if self.frame then self.frame:Hide() end
    for _, event in ipairs({ "COMBAT_TEXT_UPDATE", "COMBAT_LOG_MESSAGE",
        "UNIT_SPELLCAST_SUCCEEDED" }) do
        local ok = pcall(self.listener.RegisterEvent, self.listener, event)
        if not ok then self:Write(event .. " registration unavailable") end
    end
    local generation = self.generation
    C_Timer.After(30, function()
        if self.active and self.generation == generation then
            self:Stop()
            MikSBT.Print("Resource capture stopped. /msbtresources report opens it.")
        end
    end)
    MikSBT.Print("Resource capture started for 30 seconds. Trigger one mana "
        .. "source, then use /msbtresources report.")
end

function Capture:ReportText()
    local build = type(GetBuildInfo) == "function" and GetBuildInfo() or "unknown"
    return table.concat({
        "MSBT resource source capture | client=" .. Describe(build),
        "Resource events=" .. self.gains .. " | log events=" .. self.logs,
        "Latest 120 rows; first 20 log samples. Hidden values/text omitted.",
        "Cast timing is context only; it does not establish a gain's source.",
        "No log events can mean Blizzard's combat log is hidden or filtered.",
        table.concat(self.rows, "\n"),
    }, "\n")
end

function Capture:ShowReport()
    self:Stop()
    if not self.frame then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(850, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        frame:SetBackdropColor(0, 0, 0, 0.95)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -12)
        title:SetText("Resource report | Ctrl+A, Ctrl+C to copy | Escape to close")
        local scroll = CreateFrame("ScrollFrame", nil, frame,
            "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -40)
        scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(790)
        edit:SetScript("OnEscapePressed", function()
            edit:ClearFocus()
            frame:Hide()
        end)
        scroll:SetScrollChild(edit)
        self.frame, self.edit = frame, edit
    end
    self.edit:SetText(self:ReportText())
    self.frame:Show()
    self.edit:SetFocus()
    self.edit:HighlightText()
end

SLASH_MSBTRESOURCES1 = "/msbtresources"
SlashCmdList.MSBTRESOURCES = function(command)
    if command == "start" then
        Capture:Start()
    elseif command == "report" then
        Capture:ShowReport()
    elseif command == "stop" then
        Capture:Stop()
        MikSBT.Print("Resource capture stopped. /msbtresources report opens it.")
    else
        MikSBT.Print("/msbtresources start | report | stop")
    end
end

return Capture
