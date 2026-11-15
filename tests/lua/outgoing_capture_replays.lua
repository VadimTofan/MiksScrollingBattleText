-- Captured timings are relative to the native swing/application, in seconds.
-- No numeric damage values or unsupported server hit-count facts are assumed.
MikSBT = { Components = {},
    Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
for _, file in ipairs({ "Context", "Helpers", "SpellCatalog", "Mine",
    "Spells", "Healing", "Reader" }) do
    dofile("Combat/" .. file .. ".lua")
end
local Log = dofile("Components/CombatLogFilter.lua")
local Engine = dofile("Components/CombatEngine.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local Batcher = dofile("Components/OutgoingBatcher.lua")
local ns = MikSBT.CombatEngine
local now, timers, records, displayed = 100, {}, {}, {}
local forwarded = {}
local targetExists = true
local opaque = setmetatable({}, { __mode = "k" })
local function Amount()
    local amount = setmetatable({}, {
        __add = function() error("added an opaque capture amount") end,
        __le = function() error("compared an opaque capture amount") end,
        __lt = function() error("ordered an opaque capture amount") end,
        __tostring = function() error("read an opaque capture amount") end,
    })
    opaque[amount] = true
    return amount
end
issecretvalue = function(value) return opaque[value] == true end
GetTime = function() return now end
GetLocale = function() return "enUS" end
UnitExists = function(unit) return unit == "target" and targetExists end
UnitIsUnit = function(a, b)
    return a == b or (targetExists and
        ((a == "target" and b == "nameplate1")
        or (a == "nameplate1" and b == "target")))
end
UnitGUID = function(unit) return unit == "player" and "Player-Replay" end
UnitName = function() return "Replay" end
UnitClass = function() return "Shaman", "SHAMAN" end
GetWeaponEnchantInfo = function() return true, 10000, 0, 283 end
UnitHealthMax = function() return 1000 end
Enum = { CombatLogMessageOrder = { Newest = 0, Oldest = 1 },
    PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
C_EventUtils = { IsEventValid = function() return true end }
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    NewTicker = function() return { Cancel = function() end } end,
}
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        RegisterUnitEvent = function() end,
        UnregisterAllEvents = function() end,
        SetScript = function() end,
    }
end
C_Spell = {
    GetSpellDescription = function(id)
        if id == 21949 then
            return "Wounds the target causing them to bleed for 210 damage over 7 sec."
        end
        -- Known casts must obtain identity facts from the production catalog.
        return nil
    end,
    IsSpellHelpful = function() return false end,
    GetSpellTexture = function(id) return "icon-" .. id end,
    GetSpellName = function(id) return "Spell " .. id end,
}
COMBATLOG_FILTER_MINE, COMBATLOG_FILTER_MY_PET = 1, 2
Blizzard_CombatLog_Filters = { filters = {} }
local log = Log:New({
    getSaved = function() return Blizzard_CombatLog_Filters end,
    mineFlag = 1, petFlag = 2,
})
assert(log:WriteSettings())
local profile = { stackSimilarHits = true, events = {
    OUTGOING_DAMAGE = {}, OUTGOING_SPELL_DAMAGE = {}, OUTGOING_SPELL_DOT = {},
} }
local batcher = Batcher:New({
    getProfile = function() return profile end,
    getSpellTexture = C_Spell.GetSpellTexture,
    isAutoAttack = function(id) return id == 6603 or id == 5019 end,
    autoAttackSpellID = 6603,
    after = C_Timer.After, delay = 0.12,
    displayRestricted = function(_, amount, icon, _, _, _, spell)
        displayed[#displayed + 1] = { amount = amount, icon = icon, spell = spell }
    end,
    displayRestrictedGroup = function(_, amounts, icon, _, spell)
        for _, amount in ipairs(amounts) do
            displayed[#displayed + 1] = {
                amount = amount, icon = icon, spell = spell,
            }
        end
    end,
    display = function() error("opaque capture reached readable formatting") end,
})
local presentation = Presentation:New({
    batcher = batcher, getSpellTexture = C_Spell.GetSpellTexture,
    getProfile = function() return profile end,
})
local engine = Engine:New({
    log = log, getSaved = function() return nil end,
    setSaved = function() end, notify = function() end,
    presentation = {
        Out = function(_, record)
            records[#records + 1] = record
            -- Snapshot fields at dispatch: later mutation cannot repair batching.
            if record.amount ~= nil then
                forwarded[record.amount] = {
                    spell = record.result.spell,
                    procCandidate = record.result.procCandidate,
                    candidateSpell = record.result.candidateSpell,
                    accounting = record.accounting,
                }
            end
            presentation:Out(record)
        end,
        In = function() end, Alert = function() end, Aura = function() end,
        Healer = function() end, Resource = function() end,
        ComboPoints = function() end,
    },
})
local function Event(event, ...) engine:HandleEvent(event, ...) end
local function Line(kind)
    local event = ({ swing = "SWING_DAMAGE", spell = "SPELL_DAMAGE",
        spellMiss = "SPELL_MISSED", tick = "SPELL_PERIODIC_DAMAGE" })[kind]
    local rgb = Blizzard_CombatLog_Filters.filters[1].colors.eventColoring[event]
    Event("COMBAT_LOG_MESSAGE", "opaque combat-log text",
        rgb.r, rgb.g, rgb.b, Enum.CombatLogMessageOrder.Newest)
end
local function At(time)
    assert(time >= now, "capture events must be chronological")
    while true do
        local earliest
        for index, timer in ipairs(timers) do
            if timer.at <= time and
                (not earliest or timer.at < timers[earliest].at) then
                earliest = index
            end
        end
        if not earliest then break end
        local timer = table.remove(timers, earliest)
        now = timer.at
        timer.callback()
    end
    now = time
end
local function Hit(amount, unit, school)
    Event("UNIT_COMBAT", unit or "target", "WOUND", "", amount, school or 1)
end
local function Start()
    if engine.active then engine:Stop() end
    now, timers, records, displayed = now + 10, {}, {}, {}
    forwarded = {}
    targetExists = true
    batcher:Reset()
    engine:Start()
    Event("PLAYER_ENTERING_WORLD")
    ns.mine.accountingEnabled = true
    assert(ns.SpellFacts(17364).source == "nameplatesct-reforged")
    return now
end
local function Record(amount)
    local found
    for _, record in ipairs(records) do
        if record.amount == amount then
            assert(not found, "capture amount produced duplicate decisions")
            found = record
        end
    end
    assert(found, "capture report never reached the outgoing decision router")
    return found.result
end
local function Displayed(amount)
    local count = 0
    for _, output in ipairs(displayed) do
        if output.amount == amount then count = count + 1 end
    end
    return count
end
local failures = {}
local function Replay(name, test)
    local ok, failure = pcall(test)
    if not ok then failures[#failures + 1] = name .. ": " .. failure end
end

Replay("captured Stormstrike-triggered delayed physical reports", function()
    -- Given a native swing and its captured normal impact at +0.429 seconds.
    local start = Start()
    local normal, strike, first, second = Amount(), Amount(), Amount(), Amount()
    Event("PLAYER_SWING", 3.8, 0)
    Line("swing")
    At(start + 0.429)
    Hit(normal)
    At(start + 1.047)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
    for _ = 1, 3 do Line("spell") end
    Hit(strike)

    -- When spare confirmations match the two later captured physical reports.
    At(start + 1.293)
    Hit(first)
    At(start + 1.632)
    Hit(second)
    -- A third report still lies inside the trigger's timing window.
    At(start + 1.7)
    local unconfirmed = Amount()
    Hit(unconfirmed)
    At(start + 3)

    -- Then all four amounts survive, with evidence separate from identity.
    for _, amount in ipairs({ normal, strike, first, second }) do
        assert(Record(amount).who == "you", "captured owned hit was rejected")
        assert(Displayed(amount) == 1, "owned opaque amount was lost or duplicated")
    end
    assert(Record(normal).melee and Record(strike).spell == 17364)
    local normalAccounting = forwarded[normal].accounting
    assert(normalAccounting and normalAccounting.receipt,
        "normal swing outcome lost its accounting receipt before dispatch")
    assert(normalAccounting.receipt.kind == "swing"
        and normalAccounting.receipt.at == start)
    local strikeAccounting = forwarded[strike].accounting
    assert(strikeAccounting and strikeAccounting.receipt
        and strikeAccounting.receipt.kind == "cast"
        and strikeAccounting.receipt.spell == 17364
        and strikeAccounting.receipt.at == start + 1.047,
        "Stormstrike outcome lost its spent cast reservation")
    for _, amount in ipairs({ first, second }) do
        local result = Record(amount)
        assert(result.procCandidate and result.candidateSpell == 8232)
        assert(result.spell == nil and result.procSpell == nil)
        assert(forwarded[amount].procCandidate
            and forwarded[amount].candidateSpell == 8232,
            "late candidate metadata was unavailable at presentation dispatch")
        local accounting = forwarded[amount].accounting
        assert(accounting and accounting.confirmed
            and accounting.restrict == "direct" and accounting.evidence
            and accounting.evidence.at == start + 1.047,
            "delayed report was grouped by arrival instead of its confirmation")
    end

    -- Then the third report cannot reuse either consumed confirmation.
    assert(Record(unconfirmed).who == "unknown")
    assert(Displayed(unconfirmed) == 0)
end)

Replay("mixed reports cannot assume the normal swing already arrived", function()
    for _, physicalFirst in ipairs({ false, true }) do
        -- Given the captured swing and one earlier confirmed physical extra.
        now = 22504.612
        local start = Start()
        local extra, physical, fire, normal =
            Amount(), Amount(), Amount(), Amount()
        local strike, laterExtra, surplus = Amount(), Amount(), Amount()
        Event("PLAYER_SWING", 3.2, 0)
        Line("swing")
        Line("spell")
        At(start + 0.216)
        Hit(extra)

        -- When one spell line accompanies two reports of unresolved ownership.
        At(start + 1.076)
        Line("spell")
        if physicalFirst then Hit(physical) end
        Hit(fire, "target", 4)
        if not physicalFirst then Hit(physical) end

        -- A later normal is a valid alternative to assigning the earlier pair.
        At(start + 1.2)
        Hit(normal)

        -- When the later Stormstrike and extra have two new confirmations.
        At(start + 1.321)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
        Line("spell")
        Line("spell")
        Hit(strike)
        Hit(laterExtra)
        At(start + 1.5)
        Hit(surplus)
        At(start + 3)

        -- Then ambiguous reports cannot consume the actual normal's evidence.
        assert(Record(physical).who == "unknown" and Displayed(physical) == 0,
            "mixed physical report consumed an unproven swing reservation")
        assert(Record(fire).who == "unknown" and Displayed(fire) == 0,
            "one spell line proved two mixed reports' ownership")
        assert(Record(normal).who == "you" and Record(normal).melee)
        local receipt = forwarded[normal].accounting.receipt
        assert(receipt and receipt.kind == "swing" and receipt.at == start)
        assert(Record(strike).spell == 17364)
        for _, amount in ipairs({ extra, normal, strike, laterExtra }) do
            assert(Record(amount).who == "you" and Displayed(amount) == 1)
        end
        assert(Record(surplus).who == "unknown" and Displayed(surplus) == 0)
    end
end)

Replay("early unknown reports expose the existing native swing window", function()
    -- Given a native swing and its own typed swing line.
    local start = Start()
    local amount = Amount()
    Event("PLAYER_SWING", 3.8, 0)
    Line("swing")

    -- When a physical report arrives just before the existing 0.250 floor.
    At(start + 0.247)
    Hit(amount)
    At(start + 1.2)

    -- Then ownership stays unknown and the diagnostic explains the boundary.
    assert(Record(amount).who == "unknown" and Displayed(amount) == 0)
    local info = forwarded[amount].accounting
    local check = info and info.swingChecks and info.swingChecks[1]
    assert(check and check.at == start and check.reason == "before-window"
        and check.early == 0.25 and not check.eligible,
        "unmatched report lost its native swing eligibility reason")
end)

Replay("axe bleed application and typed periodic confirmations", function()
    -- Given the captured application and exact seven-second bleed tooltip.
    local start = Start()
    local application, normal = Amount(), Amount()
    Event("PLAYER_SWING", 3.8, 0)
    Line("swing")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 21949)
    Line("spell")
    Hit(application)
    At(start + 0.52)
    Hit(normal)

    -- When the first periodic report arrives at +1 second and later ticks follow.
    local ticks = { Amount(), Amount(), Amount() }
    for index, amount in ipairs(ticks) do
        At(start + index)
        Line("tick")
        -- Concurrent direct confirmations cannot replace the typed tick line.
        Line("spell")
        Hit(amount)
        At(start + index + 0.2)
    end
    At(start + 5)

    -- Then application stays unnamed and every confirmed bleed tick keeps its ID.
    local applied = Record(application)
    assert(applied.who == "you" and applied.procSpell == nil)
    assert(applied.spell ~= 8232, "bleed application acquired Windfury identity")
    assert(Displayed(application) == 1)
    for _, amount in ipairs(ticks) do
        local result = Record(amount)
        assert(result.who == "you" and result.tick and result.spell == 21949)
        assert(result.procSpell == nil and Displayed(amount) == 1)
    end
end)

Replay("same-frame Stormstrike reports exhaust one cast identity", function()
    -- Given one catalogued Stormstrike cast and two confirmed physical reports.
    local start = Start()
    local first, second = Amount(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
    Line("spell")
    Line("spell")

    -- When both opaque reports arrive in the same frame.
    Hit(first)
    Hit(second)
    At(start + 2)

    -- Then both remain owned but the cast is not named repeatedly.
    local named = 0
    for _, amount in ipairs({ first, second }) do
        local result = Record(amount)
        assert(result.who == "you" and Displayed(amount) == 1)
        if result.spell == 17364 then named = named + 1 end
        assert(result.procSpell == nil)
    end
    assert(named <= 1, "one Stormstrike cast named multiple physical reports")
    assert(forwarded[first].spell == 17364)
    assert(forwarded[second].spell == nil
        and forwarded[second].procCandidate == true
        and forwarded[second].candidateSpell == 8232,
        "same-frame unnamed report reached presentation before candidate tagging")
end)

Replay("confirmed hits do not reserve a second spare confirmation", function()
    for _, accountingEnabled in ipairs({ false, true }) do
        -- Given the captured clock and four own direct confirmations.
        now = 18056.290
        local start = Start()
        ns.mine.accountingEnabled = accountingEnabled
        local first, fire, second = Amount(), Amount(), Amount()
        local normal, late, surplus, strike =
            Amount(), Amount(), Amount(), Amount()
        Event("PLAYER_SWING", 3.8, 0)
        Line("swing")
        Line("spell")
        Line("spell")
        local earlierSpare = ns.reader.logLines[#ns.reader.logLines - 1]

        -- When the first hit consumes its own later-frame confirmation.
        At(start + 0.100)
        Line("spell")
        Line("spell")
        Hit(first)
        At(start + 0.101)

        -- Then timing bookkeeping leaves the older spare free.
        assert(Record(first).who == "you")
        assert(not earlierSpare.claimed and not earlierSpare.hit,
            "confirmed hit reserved another frame's spare line")

        -- When the remaining reports and an unsupported surplus arrive.
        At(start + 0.187)
        Hit(fire, "target", 4)
        At(start + 0.214)
        Hit(second)
        At(start + 0.585)
        Hit(normal)
        At(start + 0.905)
        Hit(late)
        At(start + 0.930)
        Hit(surplus)
        At(start + 0.953)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player",
            "Cast-independent-strike", 17364)
        Line("spell")
        Hit(strike)
        At(start + 2)

        -- Then each supported report survives once without reusing evidence.
        for _, amount in ipairs({ first, fire, second, normal, late, strike }) do
            assert(Record(amount).who == "you")
            assert(Displayed(amount) == 1)
        end
        assert(Record(normal).melee and Record(strike).spell == 17364)
        assert(Record(surplus).who == "unknown" and Displayed(surplus) == 0)
        local bindings = {}
        for _, line in ipairs(ns.reader.logLines) do
            local record = line.hit and line.hit.record
            if record and record.amount then
                local amount = record.amount
                bindings[amount] = (bindings[amount] or 0) + 1
                assert(bindings[amount] <= 1,
                    "one report occupied multiple confirmations")
            end
        end
    end
end)

Replay("shared confirmations do not reserve a later combat-log line", function()
    for _, accountingEnabled in ipairs({ false, true }) do
        -- Given two owned reports confirmed collectively in their own frame.
        local start, first, second = Start(), Amount(), Amount()
        ns.mine.accountingEnabled = accountingEnabled
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
        Line("spell")
        Line("spell")
        Hit(first)
        Hit(second)
        At(start + 0.01)
        assert(Record(first).who == "you" and Record(second).who == "you")
        for _, hit in ipairs(ns.reader.yourHits) do
            assert(hit.line == nil,
                "a shared pool invented an individual confirmation binding")
        end

        -- When another own line arrives inside the timing association window.
        At(start + 0.05)
        Line("spell")
        local laterLine = ns.reader.logLines[#ns.reader.logLines]
        At(start + 2)

        -- Then resolved reports cannot reserve that later confirmation.
        assert(not laterLine.hit and not laterLine.claimed,
            "a collectively confirmed report occupied a later line")
        assert(Displayed(first) == 1 and Displayed(second) == 1)
    end
end)

Replay("applied bleed cannot take a later Stormstrike miss", function()
    -- Given a bleed whose owned tick already confirms its application.
    local start, tick = Start(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 21949)
    At(start + 0.761)
    Line("tick")
    Hit(tick)
    At(start + 1)
    assert(Record(tick).spell == 21949 and Record(tick).tick)

    -- When the captured certain Stormstrike cast and direct miss arrive.
    At(start + 1.746)
    Event("UNIT_SPELLCAST_SENT", "player", nil, "strike-after-bleed", 17364)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "strike-after-bleed", 17364)
    Line("spellMiss")
    Event("UNIT_COMBAT", "target", "MISS", "", 0, 1)
    At(start + 2)

    -- Then the miss spends Stormstrike once without becoming a WF candidate.
    local result = Record(nil)
    assert(result.who == "you" and result.spell == 17364,
        "already-applied bleed kept the Stormstrike miss ambiguous")
    assert(not result.ambiguous and not result.procCandidate)
    assert(result.candidateSpell == nil)
    assert(ns.mine.lastOutcomeReceipt
        and ns.mine.lastOutcomeReceipt.kind == "cast"
        and ns.mine.lastOutcomeReceipt.spell == 17364,
        "Stormstrike miss did not retain its spent cast receipt")
end)

Replay("ambiguous Stormstrike miss never becomes a Windfury candidate", function()
    -- Given the captured earlier totem cast and a confirmed normal swing.
    local start, normal = Start(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 3599)
    At(start + 0.462)
    Event("PLAYER_SWING", 3.2, 0)
    Line("swing")
    At(start + 0.892)
    Hit(normal)

    -- When a certain Stormstrike cast overlaps another possible miss source.
    At(start + 2.208)
    Event("UNIT_SPELLCAST_SENT", "player", nil, "stormstrike-miss", 17364)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "stormstrike-miss", 17364)
    Line("spellMiss")
    Event("UNIT_COMBAT", "target", "MISS", "", 0, 1)
    At(start + 2.5)

    -- Then ownership survives, but ambiguous identity cannot imply a proc.
    local result = Record(nil)
    assert(result.who == "you" and result.ambiguous,
        "captured overlapping miss did not preserve its identity ambiguity")
    assert(result.spell == nil and result.procSpell == nil)
    assert(not result.procCandidate and result.candidateSpell == nil,
        "ambiguous Stormstrike miss acquired a Windfury candidate")
    assert(not result.proc,
        "ambiguous direct miss was promoted to unexplained proc damage")
end)

Replay("hostile report without own confirmation stays hidden", function()
    -- Given a recent physical cast but no own combat-log confirmation.
    local start, foreign = Start(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)

    -- When an opaque hostile-unit damage report arrives.
    At(start + 0.2)
    Hit(foreign)
    At(start + 1)

    -- Then unresolved ownership never produces outgoing text.
    assert(Record(foreign).who == "unknown",
        "unconfirmed recent-cast report was classified as " .. Record(foreign).who)
    assert(Displayed(foreign) == 0)
end)

Replay("wrong target cannot steal bounded physical-proc confirmation", function()
    -- Given a native swing and a later physical cast with one spare line.
    local start = Start()
    local normal, strike, wrong, late = Amount(), Amount(), Amount(), Amount()
    Event("PLAYER_SWING", 3.8, 0)
    Line("swing")
    At(start + 0.429)
    Hit(normal)
    At(start + 1.047)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 17364)
    Line("spell")
    Line("spell")
    Hit(strike)
    ns.reader.plates.nameplate2 = true

    -- When another target reports damage before the captured late own hit.
    At(start + 1.293)
    Hit(wrong, "nameplate2")
    At(start + 1.632)
    Hit(late)
    At(start + 3)

    -- Then only the original target consumes the retained confirmation.
    assert(Record(wrong).who == "unknown" and Displayed(wrong) == 0)
    assert(Record(late).who == "you" and Displayed(late) == 1)
    assert(Record(late).spell == nil and Record(late).procSpell == nil)
end)

Replay("late catalogued projectile survives target departure", function()
    -- Given a Frostbolt cast at a target with an observed nameplate alias.
    local start, amount = Start(), Amount()
    Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 116)

    -- When the target disappears before its final confirmed damage report.
    targetExists = false
    Event("PLAYER_TARGET_CHANGED")
    Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    At(start + 0.1)
    Line("spell")
    Hit(amount, "target", 16)
    At(start + 1)

    -- Then the retained target life delivers the exact opaque amount once.
    assert(Record(amount).who == "you" and Record(amount).spell == 116)
    assert(Displayed(amount) == 1)
    assert(ns.TargetKey() == nil)
end)

Replay("periodic-only initial zero report does not reject its application", function()
    -- Given a catalogued periodic-only Corruption application and no miss line.
    local start, tick = Start(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)

    -- When an empty public WOUND precedes the first confirmed periodic report.
    Hit(0, "target", 32)
    At(start + 3)
    Line("tick")
    Hit(tick, "target", 32)
    At(start + 4)

    -- Then zero is not damage or proof of failure, and the real tick survives.
    local result = Record(tick)
    assert(result.who == "you" and result.spell == 172 and result.tick,
        "initial empty report invalidated the periodic-only application")
    assert(Displayed(0) == 0 and Displayed(tick) == 1)
    for _, record in ipairs(records) do
        if record.amount == 0 then
            assert(record.result.procSpell == nil and record.result.spell ~= 8232)
        end
    end
end)

Replay("periodic-only refresh zero report keeps the replacement ticks", function()
    -- Given a Corruption application whose first confirmed tick established it.
    local start, first, refreshed = Start(), Amount(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)
    At(start + 3)
    Line("tick")
    Hit(first, "target", 32)
    At(start + 4)

    -- When its refresh has an empty WOUND but no own missed-application line.
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)
    Hit(0, "target", 32)
    At(start + 7)
    Line("tick")
    Hit(refreshed, "target", 32)
    At(start + 8)

    -- Then the replacement application retains its real periodic identity.
    for _, amount in ipairs({ first, refreshed }) do
        local result = Record(amount)
        assert(result.who == "you" and result.spell == 172 and result.tick,
            "empty refresh report invalidated subsequent Corruption ticks")
        assert(Displayed(amount) == 1)
    end
    assert(Displayed(0) == 0)
end)

Replay("catalogued Cleave next-swing ordering selects the real report", function()
    -- Given Cleave's catalog metadata, without a hardcoded queued-spell fixture.
    local start, empty, impact = Start(), Amount(), Amount()
    assert(ns.SpellFacts(845).nextSwing)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 845)

    -- When its opaque empty report precedes the line and actual impact follows.
    Hit(empty)
    Line("spell")
    Hit(impact)
    At(start + 2)

    -- Then only the actual impact receives the cast identity and renders.
    assert(Record(impact).who == "you" and Record(impact).spell == 845,
        "catalogued Cleave nextSwing ordering lost its real impact")
    assert(Displayed(impact) == 1 and Displayed(empty) == 0,
        "Cleave's empty report was displayed instead of its real impact")
end)

Replay("catalogued long-flight Frostbolt pairs its late own line", function()
    -- Given an actual catalogued Frostbolt cast at the current target.
    local start, impact = Start(), Amount()
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 116)

    -- When its own line precedes the observed long-flight opaque hit by 0.12s.
    At(start + 2.25)
    Line("spell")
    At(start + 2.37)
    Hit(impact, "target", 16)
    At(start + 2.57)

    -- Then in-flight/late-line pairing retains the cast and renders it once.
    local result = Record(impact)
    assert(result.who == "you" and result.spell == 116,
        "catalogued +2.37 second Frostbolt lost its confirmed identity")
    assert(Displayed(impact) == 1,
        "confirmed long-flight Frostbolt was not displayed exactly once")
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Outgoing capture replay tests passed")
