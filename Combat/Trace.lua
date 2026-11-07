-- Temporary, opt-in tracing for queued strikes. Amounts are rendered by the
-- client immediately; Lua never reads, compares, or saves opaque hit values.
local Trace = { rows = {}, sequence = 0 }
MikSBT.CombatTrace = Trace

local RestrictedValue = MikSBT.API.RestrictedValue
local MAX_ROWS = 18

function Trace:CreatePanel()
    if self.frame then return end
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(760, 430)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -80)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("MSBT trace | ages: native/tracked/log seconds (-1 missing)")
    self.frame = frame
end

function Trace:Write(stage, spell, template, ...)
    if not self.active then return end
    self.sequence = self.sequence + 1
    local index = (self.sequence - 1) % MAX_ROWS + 1
    local row = self.rows[index]
    if not row then
        local label = self.frame:CreateFontString(
            nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 12, -42 - (index - 1) * 20)
        label:SetWidth(310)
        label:SetJustifyH("LEFT")
        local value = self.frame:CreateFontString(
            nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("LEFT", label, "RIGHT", 8, 0)
        value:SetWidth(420)
        value:SetJustifyH("LEFT")
        row = { label = label, value = value }
        self.rows[index] = row
    end
    local spellLabel = RestrictedValue:Number(spell)
        or RestrictedValue:String(spell) or "-"
    row.label:SetText(string.format("%03d %.3f %s [%s]",
        self.sequence, GetTime(), stage, spellLabel))
    row.value:SetFormattedText(template, ...)
end

function Trace:WriteMatch(record)
    local result = record.result or {}
    local kind = result.extra and " extra" or (result.proc and " proc" or "")
    local engine = MikSBT.CombatEngine
    local reader = engine and engine.reader
    local swings = reader and reader.swingTimes
    local swing = swings and swings[#swings]
    local line = self.lastMeleeLine
    local now = GetTime()
    local nativeAge = self.lastSwingAt and now - self.lastSwingAt or -1
    local trackedAge = swing and now - swing.at or -1
    local lineAge = line and now - line.at or -1
    local state = line and (line.claimed and "used" or "free") or "missing"
    self:Write("match " .. (result.who or "unknown") .. kind,
        result.spell or (result.melee and "auto"),
        "%s | ages %.2f/%.2f/%.2f %s", record.amount,
        nativeAge, trackedAge, lineAge, state)
end

function Trace:InstallHooks()
    if self.hooked then return end
    self.hooked = true
    local components = MikSBT.Components
    hooksecurefunc(components.CombatEngine, "HandleEvent",
        function(_, event, unit, action, flag, amount, school)
            if not self.active then return end
            if event == "UNIT_COMBAT"
                and RestrictedValue:Equals(unit, "target")
                and RestrictedValue:Equals(action, "WOUND") then
                self:Write("target hit", nil,
                    "%s (school %s, flag %s)", amount, school, flag)
            elseif event == "UNIT_SPELLCAST_SUCCEEDED"
                and RestrictedValue:Equals(unit, "player") then
                self:Write("cast", flag, "%s", "cast succeeded")
            elseif event == "PLAYER_SWING" then
                self.lastSwingAt = GetTime()
                self:Write("swing", action, "duration %s", unit)
            elseif event == "COMBAT_LOG_MESSAGE" then
                local engine = MikSBT.CombatEngine
                local reader = engine and engine.reader
                local lines = reader and reader.logLines
                local line = lines and lines[#lines]
                if line and line.at == GetTime() then
                    if (line.kind == "swing" or line.kind == "swingMiss")
                        and (line.source == "mine" or line.source == "unknown") then
                        self.lastMeleeLine = line
                    end
                    self:Write("log", line.kind, "%s", line.source)
                end
            end
        end)
    hooksecurefunc(components.CombatPresentation, "Out", function(_, record)
        if not self.active or record.event ~= "damage" then return end
        self:WriteMatch(record)
    end)
    hooksecurefunc(components.OutgoingBatcher, "Queue",
        function(_, spell, amount)
            self:Write("batch", spell, "%s", amount)
        end)
    hooksecurefunc(components.OutgoingBatcher, "DisplayRestricted",
        function(_, spell, amount)
            self:Write("opaque", spell, "%s", amount)
        end)
    hooksecurefunc(MikSBT.Display.Service, "DisplayEvent",
        function(_, settings, message, texture, mute, formatArg, ...)
            if not self.active then return end
            if RestrictedValue:IsRestricted(formatArg) or formatArg ~= nil then
                self:Write("render", nil, message, formatArg, ...)
            else
                self:Write("render", nil, "%s", message)
            end
        end)
end

function Trace:Toggle()
    if self.active then
        self.active = false
        self.frame:Hide()
        return
    end
    self:CreatePanel()
    self:InstallHooks()
    self.sequence = 0
    self.lastSwingAt, self.lastMeleeLine = nil, nil
    for _, row in ipairs(self.rows) do
        row.label:SetText("")
        row.value:SetText("")
    end
    self.active = true
    self.frame:Show()
end

SLASH_MSBTDAMAGETRACE1 = "/msbttrace"
SlashCmdList.MSBTDAMAGETRACE = function() Trace:Toggle() end
