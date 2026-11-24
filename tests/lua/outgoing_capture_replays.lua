-- Captured timings are relative to the native swing/application, in seconds.
-- No numeric damage values or unsupported server hit-count facts are assumed.
MikSBT = { Components = {},
    Compatibility = { Client = { isForever = true } } }
dofile("API/RestrictedValue.lua")
for _, file in ipairs({ "Context", "Classes/Mage", "Classes/Paladin", "Classes/Shaman",
    "Helpers", "SpellCatalog", "Mine",
    "Spells", "Healing", "Reader" }) do
    dofile("Combat/" .. file .. ".lua")
end
local Log = dofile("Components/CombatLogFilter.lua")
local Engine = dofile("Components/CombatEngine.lua")
local Presentation = dofile("Components/CombatPresentation.lua")
local Batcher = dofile("Components/OutgoingBatcher.lua")
local ns = MikSBT.CombatEngine
dofile("Combat/WindfuryInference.lua")
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
    NOTIFICATION_PROC = { disabled = true },
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
    getProfile = function() return profile end,
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
        In = function() end,
        Alert = function(_, record) presentation:Alert(record) end,
        Aura = function() end,
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
    profile.inferredWindfuryIcons = nil
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

Replay("baseline clean Windfury extras receive icons after full accounting", function()
    for _, stacking in ipairs({ false, true }) do
        -- Given a clean Weapon source with two owned extras before its normal.
        local start = Start()
        ns.mine.accountingEnabled = false
        profile.stackSimilarHits = stacking
        local first, second, normal = Amount(), Amount(), Amount()
        Event("PLAYER_SWING", 3.2, 0)
        Line("swing")
        Line("spell")
        Line("spell")
        Event("SPELL_UPDATE_COOLDOWN", 439440)
        Hit(first)
        At(start + 0.216)
        Hit(second)
        At(start + 0.3)

        -- Then early candidates wait for the still-unresolved normal swing.
        assert(Displayed(first) == 0 and Displayed(second) == 0,
            "early inferred candidates escaped before normal accounting")

        -- When the ordinary swing arrives within its existing window.
        At(start + 0.585)
        Hit(normal)
        At(start + 0.8)

        -- Then both extras retain their amounts and gain only inferred icons.
        for _, amount in ipairs({ first, second }) do
            assert(Displayed(amount) == 1,
                "clean inferred extra did not reach output exactly once")
            local icon
            for _, output in ipairs(displayed) do
                if output.amount == amount then icon = output.icon end
            end
            assert(icon == "icon-8232", "clean inferred WF icon is missing")
            assert(Record(amount).spell == nil and Record(amount).procSpell == nil)
        end
        assert(Record(normal).melee and Displayed(normal) == 1)
        profile.stackSimilarHits = true
    end
end)

Replay("an unconfirmed hit cannot undo two accounted Windfury extras", function()
    -- Given a Weapon burst whose two direct lines already match both extras.
    local start = Start()
    local first, second, unconfirmed, normal = Amount(), Amount(), Amount(), Amount()
    Event("PLAYER_SWING", 3.2, 0)
    Line("swing")
    Line("spell")
    Line("spell")
    Event("SPELL_UPDATE_COOLDOWN", 439440)
    Hit(first)
    At(start + 0.216)
    Hit(second)

    -- When another hit has no confirmation and the ordinary swing arrives later.
    At(start + 0.24)
    Hit(unconfirmed)
    At(start + 0.3)
    assert(Displayed(first) == 0 and Displayed(second) == 0,
        "extras escaped before the ordinary swing matched")
    At(start + 0.585)
    Hit(normal)
    At(start + 2)

    -- Then only the two accounted extras get Windfury icons.
    assert(Record(unconfirmed).who == "unknown" and Displayed(unconfirmed) == 0)
    assert(Record(normal).melee and Displayed(normal) == 1)
    assert(Displayed(first) == 1 and Displayed(second) == 1)
    for _, output in ipairs(displayed) do
        if output.amount == first or output.amount == second then
            assert(output.icon == "icon-8232", "unconfirmed hit canceled Windfury icons")
        end
    end
end)

Replay("a nearby Weapon cooldown can corroborate one complete swing", function()
    for _, scenario in ipairs({
        { name = "cooldown first", offset = -0.035, icons = true },
        { name = "swing first", offset = 0.035, icons = true },
        { name = "competing frame", offset = 0.035, rival = true },
        { name = "outside window", offset = 0.09 },
    }) do
        -- Given one native swing with two typed direct confirmations.
        local start = Start() + 0.1
        local first, second, normal = Amount(), Amount(), Amount()
        if scenario.offset < 0 then
            At(start + scenario.offset)
            Event("SPELL_UPDATE_COOLDOWN", 439440)
        end
        At(start)
        Event("PLAYER_SWING", 3.2, 0)
        Line("swing")
        Line("spell")
        Line("spell")
        Hit(first)

        -- When the Weapon update sits in a separate frame.
        if scenario.offset > 0 then
            At(start + scenario.offset)
            Event("SPELL_UPDATE_COOLDOWN", 439440)
        end
        if scenario.rival then
            At(start + 0.06)
            Event("PLAYER_SWING", 3.2, 1)
        end
        At(start + 0.216)
        Hit(second)
        At(start + 0.585)
        Hit(normal)
        At(start + 2)

        -- Then only an unambiguous nearby source gets both inferred icons.
        assert(Record(normal).melee and Displayed(normal) == 1, scenario.name)
        assert(Displayed(first) == 1 and Displayed(second) == 1, scenario.name)
        local expected = scenario.icons and "icon-8232" or nil
        for _, output in ipairs(displayed) do
            if output.amount == first or output.amount == second then
                assert(output.icon == expected, scenario.name)
            end
        end
    end
end)

Replay("captured Windfury accounts across swing, cooldown, and spell frames", function()
    for _, scenario in ipairs({
        { name = "captured sequence", cooldown = 0.023, icons = true },
        { name = "cooldown with swing", cooldown = 0, icons = true },
        { name = "cooldown with spell lines", cooldown = 0.039, icons = true },
        { name = "ordinary hit absent", cooldown = 0.023, missingNormal = true },
    }) do
        -- Given the captured swing at 33.873 and the two spell lines
        -- at 33.912, with the cooldown in or between those frames.
        local start = Start()
        local first, normal, second = Amount(), Amount(), Amount()
        Event("PLAYER_SWING", 2.242, 0)
        Line("swing")
        if scenario.cooldown < 0.039 then
            At(start + scenario.cooldown)
            Event("SPELL_UPDATE_COOLDOWN", 439440)
        end
        At(start + 0.039)
        Line("spell")
        Line("spell")
        if scenario.cooldown == 0.039 then Event("SPELL_UPDATE_COOLDOWN", 439440) end

        -- When the extra reports use the separate spell frame and the
        -- ordinary hit uses its original swing frame.
        At(start + 0.237)
        Hit(first)
        if not scenario.missingNormal then
            At(start + 0.607)
            Hit(normal)
        end
        At(start + 0.963)
        Hit(second)
        At(start + 2)

        -- Then both owned extras show once, with icons only if the full
        -- burst includes the ordinary hit.
        for _, extra in ipairs({ first, second }) do
            assert(Record(extra).who == "you" and Displayed(extra) == 1)
            for _, output in ipairs(displayed) do
                if output.amount == extra then
                    assert((output.icon == "icon-8232") == (scenario.icons == true),
                        "incorrect Windfury icon for " .. scenario.name)
                end
            end
        end
        if not scenario.missingNormal then
            assert(Record(normal).melee and Displayed(normal) == 1)
        end
    end
end)

Replay("explicit player Windfury casts help identify clean extra hits", function()
    for _, scenario in ipairs({ "clean", "pet-cast", "both-signals",
        "duplicate-cast" }) do
        -- Given a swing and two extra reports with Ability Procs disabled.
        local start = Start()
        local first, second, normal = Amount(), Amount(), Amount()
        if scenario == "duplicate-cast" then
            Event("UNIT_SPELLCAST_SUCCEEDED", "player", "windfury-cast", 439440)
            At(start + 0.05)
        end
        Event("PLAYER_SWING", 3.2, 0)
        Line("swing")
        Line("spell")
        Line("spell")

        -- When the cast arrives without a Weapon cooldown update.
        local unit = scenario == "pet-cast" and "pet" or "player"
        Event("UNIT_SPELLCAST_SUCCEEDED", unit, "windfury-cast", 439440)
        if scenario == "both-signals" then
            Event("SPELL_UPDATE_COOLDOWN", 10610)
        end
        Hit(first)
        At(start + 0.216)
        Hit(second)
        At(start + 0.585)
        Hit(normal)
        At(start + 1.7)

        -- Then only the clean player burst gets inferred icons.
        local expectedIcon = scenario == "clean" and "icon-8232" or nil
        for _, amount in ipairs({ first, second }) do
            assert(Displayed(amount) == 1,
                scenario .. " did not display the extra exactly once")
            for _, output in ipairs(displayed) do
                if output.amount == amount then
                    assert(output.icon == expectedIcon,
                        scenario .. " displayed the wrong Windfury icon")
                end
            end
            assert(Record(amount).spell == nil and Record(amount).procSpell == nil)
        end
        assert(Record(normal).melee and Displayed(normal) == 1)
    end
end)

Replay("profile changes release pending inferred numbers without icons", function()
    -- Given one owned extra waiting in an enabled profile's incomplete burst.
    local start = Start()
    profile.stackSimilarHits = false
    local first = Amount()
    Event("PLAYER_SWING", 3.2, 0)
    Line("swing")
    Line("spell")
    Line("spell")
    Event("SPELL_UPDATE_COOLDOWN", 439440)
    Hit(first)
    At(start + 0.1)
    assert(Displayed(first) == 0)

    -- When another enabled profile replaces it before the burst completes.
    profile = { events = profile.events, stackSimilarHits = false }
    Event("PLAYER_REGEN_ENABLED")
    At(start + 0.2)

    -- Then the old profile's amount is released once with no inferred icon.
    assert(Displayed(first) == 1, "profile change kept an old inference pending")
    for _, output in ipairs(displayed) do
        if output.amount == first then assert(output.icon == nil) end
    end
    At(start + 3)
    assert(Displayed(first) == 1, "stale profile callback repeated an amount")
    profile.stackSimilarHits = true
end)

Replay("queued callbacks cannot infer icons across an enabled profile switch", function()
    -- Given a complete Stormstrike/Weapon frame awaiting its frame callbacks.
    local start = Start()
    profile.stackSimilarHits = false
    local strike, first, second = Amount(), Amount(), Amount()
    Event("UNIT_SPELLCAST_SENT", "player", nil, "profile-race-strike", 17364)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "profile-race-strike", 17364)
    for _ = 1, 3 do Line("spell") end
    Event("SPELL_UPDATE_COOLDOWN", 439440)
    Hit(strike)
    Hit(first)
    Hit(second)

    -- When an enabled replacement profile arrives before any new reader event.
    profile = { events = profile.events, stackSimilarHits = false }
    At(start + 0.2)

    -- Then callbacks release old amounts without crossing the profile boundary.
    for _, amount in ipairs({ strike, first, second }) do
        assert(Displayed(amount) == 1)
        for _, output in ipairs(displayed) do
            if output.amount == amount then
                assert(output.icon ~= "icon-8232",
                    "old callback inferred damage under a replacement profile")
            end
        end
    end
    profile.stackSimilarHits = true
end)

Replay("incomplete and conflicting inferred bursts keep their plain output", function()
    for _, scenario in ipairs({ "one-extra", "missing-normal", "no-signal",
        "both-signals", "bleed-application" }) do
        -- Given an incomplete or conflicting source with owned physical extras.
        local start = Start()
        profile.stackSimilarHits = true
        local first, second, normal = Amount(), Amount(), Amount()
        Event("PLAYER_SWING", 3.2, 0)
        Line("swing")
        Line("spell")
        Line("spell")
        if scenario ~= "no-signal" then Event("SPELL_UPDATE_COOLDOWN", 439440) end
        if scenario == "both-signals" then Event("SPELL_UPDATE_COOLDOWN", 10610) end
        if scenario == "bleed-application" then
            Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 21949)
        end

        -- When its available reports arrive and the bounded check expires.
        At(start + 0.216)
        Hit(first)
        if scenario ~= "one-extra" then
            At(start + 0.252)
            Hit(second)
        end
        if scenario ~= "missing-normal" then
            At(start + 0.585)
            Hit(normal)
        end
        At(start + 1.7)

        -- Then no icon is guessed and no owned amount is lost or delayed twice.
        assert(Displayed(first) == 1, scenario .. " lost its first plain extra")
        if scenario ~= "one-extra" then assert(Displayed(second) == 1) end
        for _, output in ipairs(displayed) do
            assert(output.icon ~= "icon-8232", scenario .. " inferred an unsafe icon")
        end
        At(start + 3)
        assert(Displayed(first) == 1)
    end
end)

Replay("retired disabled setting keeps baseline inference active", function()
    -- Given an owned extra whose clean source has not completed.
    local start = Start()
    profile.stackSimilarHits = false
    local first = Amount()
    Event("PLAYER_SWING", 3.2, 0)
    Line("swing")
    Line("spell")
    Line("spell")
    Event("SPELL_UPDATE_COOLDOWN", 439440)
    Hit(first)
    At(start + 0.1)

    -- When an old disabled setting is present while combat remains active.
    profile.inferredWindfuryIcons = false
    Event("PLAYER_REGEN_ENABLED")
    At(start + 0.2)

    -- Then inference stays active and retains its ordinary bounded wait.
    assert(Displayed(first) == 0 and ns.mine.inferredWindfuryEnabled)
    for _, output in ipairs(displayed) do assert(output.icon == nil) end
    At(start + 3)
    assert(Displayed(first) == 1)
    profile.stackSimilarHits = true
end)

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

Replay("a same-frame direct cast distinguishes two due periodic schools", function()
    for _, scenario in ipairs({
        { name = "direct first" },
        { name = "periodic first", reverse = true },
        { name = "grouped", grouped = true },
        { name = "competing direct cast", rival = 686 },
    }) do
        -- Given Immolate and Corruption are both due on the current target.
        local start = Start()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 348)
        Line("spell")
        Hit(Amount(), "target", 4)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 172)

        -- When Searing Pain lands with a Corruption tick in the same frame.
        At(start + 3)
        local direct, tick = Amount(), Amount()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 5676)
        if scenario.rival then
            Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, scenario.rival)
        end
        if scenario.reverse then
            Line("tick")
            Hit(tick, "target", 32)
            Line("spell")
            Hit(direct, "target", 4)
        else
            Line("spell")
            Hit(direct, "target", 4)
            Line("tick")
            Hit(tick, "target", 32)
        end
        local previousIsInGroup = IsInGroup
        IsInGroup = function() return scenario.grouped == true end
        At(start + 3.25)
        IsInGroup = previousIsInGroup

        -- Then both amounts display once, with icons only for the solo,
        -- uniquely assigned pair.
        local directResult, tickResult = Record(direct), Record(tick)
        assert(directResult.who == "you" and tickResult.who == "you", scenario.name)
        assert(Displayed(direct) == 1 and Displayed(tick) == 1, scenario.name)
        local directIcon, tickIcon
        if scenario.grouped or scenario.rival then
            assert(directResult.spell == nil and tickResult.spell == nil, scenario.name)
        else
            assert(directResult.spell == 5676 and not directResult.tick, scenario.name)
            assert(tickResult.spell == 172 and tickResult.tick, scenario.name)
            local directEvidence = forwarded[direct].accounting.evidence
            local tickEvidence = forwarded[tick].accounting.evidence
            assert(not directEvidence.shared and directEvidence.kind == "spell")
            assert(not tickEvidence.shared and tickEvidence.kind == "tick")
            directIcon, tickIcon = "icon-5676", "icon-172"
        end
        for _, output in ipairs(displayed) do
            if output.amount == direct then assert(output.icon == directIcon, scenario.name) end
            if output.amount == tick then assert(output.icon == tickIcon, scenario.name) end
        end
    end
end)

Replay("battleground direct confirmations recover icons for unresolved casts", function()
    for _, spell in ipairs({
        { id = 17364, school = 1, flight = 0 },
        { id = 10414, school = 8, flight = 0 },
        { id = 403, school = 8, flight = 0.2 },
    }) do
        -- Given a successful cast whose recipient is hidden.
        local start = Start()
        local hit, later = Amount(), Amount()
        local previousInstance = IsInInstance
        IsInInstance = function() return true, "pvp" end
        Event("UNIT_SPELLCAST_SENT", "player", Amount(), "pvp-cast", spell.id)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-cast", spell.id)

        -- When an isolated typed line confirms a same-school hit.
        At(start + spell.flight)
        Line("spell")
        Hit(hit, "target", spell.school)
        At(start + 0.4)
        Line("spell")
        Hit(later, "target", spell.school)
        At(start + 4)
        IsInInstance = previousInstance

        -- Then the first amount has its icon and the cast stays untargeted.
        local cast = ns.mine.casts[spell.id][1]
        assert(cast.targetUncertain and cast.key == nil)
        assert(Record(hit).who == "you" and Record(hit).spell == spell.id,
            "confirmed battleground hit lost its icon for spell " .. spell.id)
        assert(Record(later).who == "you" and Record(later).spell == nil,
            "an unresolved cast named two hits")
        assert(Displayed(hit) == 1 and Displayed(later) == 1)
        for _, output in ipairs(displayed) do
            if output.amount == hit then assert(output.icon == "icon-" .. spell.id) end
            if output.amount == later then assert(output.icon == nil) end
        end
    end
end)

Replay("battleground reports keep competing direct spells unresolved", function()
    -- Given two Nature spells in flight with hidden cast targets.
    local previousInstance = IsInInstance
    IsInInstance = function() return true, "pvp" end
    local start, hit = Start(), Amount()
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "pvp-bolt", 403)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-bolt", 403)
    At(start + 0.2)
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "pvp-shock", 10414)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-shock", 10414)

    -- When a typed line confirms one matching report.
    Line("spell")
    Hit(hit, "target", 8)
    At(start + 1)
    IsInInstance = previousInstance

    -- Then it shows once without choosing a spell.
    assert(Record(hit).who == "you" and Record(hit).spell == nil)
    assert(Displayed(hit) == 1)
end)

Replay("a battleground icon can be contested by a cast on another target", function()
    -- Given Lightning Bolt traveling to a different selected target.
    local start, hit = Start(), Amount()
    local previousInstance = IsInInstance
    IsInInstance = function() return true, "pvp" end
    local firstTarget = ns.TargetKey()
    Event("UNIT_SPELLCAST_SENT", "player", nil, "pvp-bolt", 403)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-bolt", 403)
    At(start + 0.3)
    Event("PLAYER_TARGET_CHANGED")
    assert(ns.TargetKey() ~= firstTarget)

    -- When an untargeted Earth Shock overlaps a spell line and a Nature hit.
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "pvp-shock", 10414)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-shock", 10414)
    Line("spell")
    Hit(hit, "target", 8)
    At(start + 2)
    IsInInstance = previousInstance

    -- Then the line can still belong to the Lightning Bolt on the old target.
    assert(Displayed(hit) == 1 and Record(hit).spell == nil,
        "an off-target Lightning Bolt line gave the hit an Earth Shock icon")
end)

Replay("a battleground drain cannot borrow a non-draining cast's icon", function()
    -- Given one Earth Shock with an unreadable recipient.
    local start, damage = Start(), 37
    local previousInstance = IsInInstance
    IsInInstance = function() return true, "pvp" end
    local previousDisplay = batcher.config.display
    local previousFormat = batcher.config.formatEventMessage
    batcher.config.display = function() end
    batcher.config.formatEventMessage = function() return "" end
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "pvp-shock", 10414)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-shock", 10414)

    -- When an owned Nature hit also heals the player for its amount.
    Event("UNIT_COMBAT", "player", "HEAL", "", damage, 8)
    Line("spell")
    Hit(damage, "target", 8)
    At(start + 2)
    IsInInstance = previousInstance
    batcher.config.display = previousDisplay
    batcher.config.formatEventMessage = previousFormat

    -- Then the received healing rules out Earth Shock.
    local result = Record(damage)
    assert(result.who == "you" and result.spell == nil,
        "a non-draining cast supplied the icon for a confirmed drain")
end)

Replay("unresolved battleground casts need an isolated spell confirmation", function()
    for _, typed in ipairs({ false, true }) do
        -- Given one Earth Shock with a hidden recipient.
        local start = Start()
        local hit, rival = Amount(), Amount()
        local previousInstance = IsInInstance
        IsInInstance = function() return true, "pvp" end
        Event("UNIT_SPELLCAST_SENT", "player", Amount(), "pvp-shock", 10414)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "pvp-shock", 10414)

        -- When either no line confirms the report, or two hits compete.
        if typed then
            Line("spell")
            Line("spell")
            Hit(rival, "target", 8)
        end
        Hit(hit, "target", 8)
        At(start + 1)
        IsInInstance = previousInstance

        -- Then the cast supplies no identity to either report.
        assert(Record(hit).spell == nil)
        if typed then
            assert(Record(rival).spell == nil)
            assert(Displayed(hit) == 1 and Displayed(rival) == 1)
        else
            assert(Record(hit).who == "unknown" and Displayed(hit) == 0)
        end
    end
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

Replay("dungeon direct confirmation names hidden-target spells", function()
    for _, example in ipairs({
        { spell = 116, school = 16, gap = 0 },
        { spell = 116, school = 16, gap = 0.06 },
        { spell = 116, school = 16, gap = -0.02 },
        { spell = 1240044, school = 16, gap = 0.06 },
        { spell = 1326079, school = 64, gap = 0.06 },
    }) do
        -- Given a catalogue spell whose cast recipient is hidden in a dungeon.
        local start, impact = Start(), Amount()
        local previousInstance = IsInInstance
        IsInInstance = function() return true, "party" end
        Event("UNIT_SPELLCAST_SENT", "player", Amount(), "dungeon-cast", example.spell)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", "dungeon-cast", example.spell)

        -- When the typed confirmation arrives before, with, or after the hit.
        At(start + 2)
        if example.gap >= 0 then Line("spell") end
        At(start + 2 + math.max(0, example.gap))
        Hit(impact, "target", example.school)
        if example.gap < 0 then
            At(start + 2 - example.gap)
            Line("spell")
        end
        At(start + 2.6)
        IsInInstance = previousInstance

        -- Then this one confirmed amount gets its own spell identity and icon.
        assert(Displayed(impact) == 1 and Record(impact).spell == example.spell,
            "dungeon spell lost its confirmed identity: " .. example.spell)
        for _, output in ipairs(displayed) do
            if output.amount == impact then assert(output.icon == "icon-" .. example.spell) end
        end
    end
end)

Replay("dungeon fallback leaves competing reports unnamed", function()
    -- Given an untargeted Frostbolt and a typed line outside the hit frame.
    local start = Start()
    local previousInstance = IsInInstance
    IsInInstance = function() return true, "party" end
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "dungeon-bolt", 116)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "dungeon-bolt", 116)
    At(start + 2)
    Line("spell")

    -- When two reports could belong to the line.
    local first, second = Amount(), Amount()
    At(start + 2.06)
    Hit(first, "target", 16)
    At(start + 2.08)
    Hit(second, "target", 16)
    At(start + 2.6)
    IsInInstance = previousInstance

    -- Then the fallback assigns neither report to the player.
    assert(Displayed(first) == 0 and Displayed(second) == 0,
        "a competing dungeon report took the player's confirmation")
end)

Replay("a later dungeon report can still contest the confirmation", function()
    -- Given a hidden-target bolt and two equally plausible reports.
    local start, first, second = Start(), Amount(), Amount()
    local previousInstance = IsInInstance
    IsInInstance = function() return true, "party" end
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "dungeon-race", 116)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "dungeon-race", 116)

    -- When the second report arrives within the line's matching window.
    At(start + 2)
    Hit(first, "target", 16)
    At(start + 2.02)
    Line("spell")
    At(start + 2.13)
    Hit(second, "target", 16)
    At(start + 2.6)
    IsInInstance = previousInstance

    -- Then neither report gets assigned to the player.
    assert(Displayed(first) == 0 and Displayed(second) == 0,
        "the first report spent the line before the second could contest it")
end)

Replay("isolated dungeon confirmations name hidden-target Arcane Missiles", function()
    -- Given a channel whose selected recipient cannot be read.
    local start = Start()
    local previousInstance, previousDescription = IsInInstance, C_Spell.GetSpellDescription
    IsInInstance = function() return true, "party" end
    C_Spell.GetSpellDescription = function(id)
        if id == 5143 then
            return "Launches Arcane Missiles at the enemy, causing 26 Arcane damage each second for 3 sec."
        end
        return previousDescription(id)
    end
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "missiles", 5143)
    Event("UNIT_SPELLCAST_CHANNEL_START", "player", "missiles", 5143)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "missiles", 5143)

    -- When separate typed lines confirm hits during the channel.
    local first, later, unconfirmed = Amount(), Amount(), Amount()
    At(start + 1)
    Line("spell")
    Hit(first, "target", 64)
    At(start + 2)
    Line("spell")
    At(start + 2.06)
    Hit(later, "target", 64)
    At(start + 2.6)
    Hit(unconfirmed, "target", 64)
    At(start + 3.2)
    IsInInstance, C_Spell.GetSpellDescription = previousInstance, previousDescription

    -- Then both confirmed hits get the icon without spending the channel.
    assert(Displayed(first) == 1 and Record(first).spell == 5143,
        "the same-frame confirmation left Arcane Missiles unnamed")
    assert(Displayed(later) == 1 and Record(later).spell == 5143,
        "the cross-frame confirmation left Arcane Missiles unnamed")
    assert(Displayed(unconfirmed) == 0)
    for _, output in ipairs(displayed) do
        if output.amount == first or output.amount == later then
            assert(output.icon == "icon-5143")
        end
    end
end)

Replay("an unrelated dodge cannot contest a dungeon damage line", function()
    -- Given a hidden-target Frostbolt and its isolated direct confirmation.
    local start, impact = Start(), Amount()
    local previousInstance = IsInInstance
    IsInInstance = function() return true, "party" end
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "dungeon-dodge", 116)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "dungeon-dodge", 116)
    At(start + 2)
    Line("spell")

    -- When another attacker is dodged shortly before the damage report.
    At(start + 2.01)
    Event("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
    At(start + 2.06)
    Hit(impact, "target", 16)
    At(start + 2.6)
    IsInInstance = previousInstance

    -- Then the typed damage line still identifies the confirmed hit.
    assert(Displayed(impact) == 1 and Record(impact).spell == 116,
        "a dodge contested a direct damage confirmation")
end)

Replay("replacing a channel preserves its last buffered hit", function()
    -- Given an Arcane Missiles channel with a hidden target.
    local start, final, first = Start(), Amount(), Amount()
    local previousInstance, previousDescription = IsInInstance, C_Spell.GetSpellDescription
    IsInInstance = function() return true, "party" end
    C_Spell.GetSpellDescription = function(id)
        if id == 5143 or id == 5144 then
            return "Launches Arcane Missiles at the enemy, causing 26 Arcane damage each second for 3 sec."
        end
        return previousDescription(id)
    end
    local function StartMissiles(guid, spell)
        Event("UNIT_SPELLCAST_SENT", "player", Amount(), guid, spell)
        Event("UNIT_SPELLCAST_CHANNEL_START", "player", guid, spell)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spell)
    end
    StartMissiles("first", 5143)

    -- When the player starts another channel before the first hit settles.
    At(start + 2)
    Line("spell")
    At(start + 2.06)
    Hit(final, "target", 64)
    At(start + 2.10)
    Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "first", 5143)
    At(start + 2.11)
    StartMissiles("second", 5144)
    At(start + 3.05)
    Line("spell")
    Hit(first, "target", 64)
    At(start + 3.6)
    IsInInstance, C_Spell.GetSpellDescription = previousInstance, previousDescription

    -- Then each hit retains the identity of its own channel.
    assert(Displayed(final) == 1 and Record(final).spell == 5143,
        "the replacement discarded the old channel's buffered hit")
    assert(Displayed(first) == 1 and Record(first).spell == 5144,
        "the old channel took the replacement's hit")
end)

Replay("localized Arcane Missiles keeps the icon without English spell text", function()
    -- Given a Chinese-client tooltip and a hidden-target max-rank cast.
    local start, impact = Start(), Amount()
    local previousInstance, previousLocale = IsInInstance, GetLocale
    local previousDescription, previousSchool = C_Spell.GetSpellDescription, STRING_SCHOOL_ARCANE
    IsInInstance = function() return true, "party" end
    GetLocale = function() return "zhCN" end
    STRING_SCHOOL_ARCANE = "奥术"
    C_Spell.GetSpellDescription = function()
        return "向敌人发射奥术飞弹，每秒造成209点奥术伤害。"
    end
    Event("UNIT_SPELLCAST_SENT", "player", Amount(), "localized", 25345)
    Event("UNIT_SPELLCAST_CHANNEL_START", "player", "localized", 25345)
    Event("UNIT_SPELLCAST_SUCCEEDED", "player", "localized", 25345)

    -- When the typed direct line confirms a hit.
    At(start + 1)
    Line("spell")
    Hit(impact, "target", 64)
    At(start + 1.5)
    IsInInstance, GetLocale = previousInstance, previousLocale
    C_Spell.GetSpellDescription, STRING_SCHOOL_ARCANE = previousDescription, previousSchool

    -- Then the real spell rank reaches the icon display.
    assert(Displayed(impact) == 1 and Record(impact).spell == 25345,
        "localized Arcane Missiles lost its spell identity")
    assert(displayed[1].icon == "icon-25345")
end)

Replay("a seal application cannot name an Unsealed Wrath damage report", function()
    local previousClass, previousEnchant = UnitClass, GetWeaponEnchantInfo
    local previousDescription = C_Spell.GetSpellDescription
    UnitClass = function() return "Paladin", "PALADIN" end
    GetWeaponEnchantInfo = function() return false end
    C_Spell.GetSpellDescription = function(spell)
        if spell == 20375 then
            return "Gives your melee attacks a chance to deal additional Holy damage. Only one Seal can be active."
        elseif spell == 20154 then
            return "Adds Holy damage to each melee attack. Only one Seal can be active."
        end
        return previousDescription(spell)
    end
    for _, example in ipairs({ { 20375, 20154 }, { 20154, 20375 } }) do
        -- Given a Paladin who swaps seals before a melee swing.
        local start = Start()
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, example[1])
        At(start + 4)
        Event("UNIT_SPELLCAST_SUCCEEDED", "player", nil, example[2])

        -- When four Holy hits share identical public timing and confirmation.
        local swing, holy = Amount(), {}
        At(start + 4.1)
        Event("PLAYER_SWING", 2.8, 0)
        Line("swing")
        for index = 1, 4 do Line("spell") end
        for index = 1, 4 do
            holy[index] = Amount()
            Hit(holy[index], "target", 2)
        end
        At(start + 4.5)
        Hit(swing, "target", 1)
        At(start + 5)

        -- Then every amount survives and the seal cast supplies no false icon.
        assert(Displayed(swing) == 1 and Record(swing).melee)
        for _, amount in ipairs(holy) do
            local result = Record(amount)
            assert(Displayed(amount) == 1 and result.who == "you")
            assert(result.spell == nil and result.procSpell == nil,
                "the active seal was treated as the damage cast")
        end
        for _, output in ipairs(displayed) do
            if output.amount ~= swing then
                assert(output.icon == nil, "an unidentifiable seal hit got an icon")
            end
        end
    end
    UnitClass, GetWeaponEnchantInfo = previousClass, previousEnchant
    C_Spell.GetSpellDescription = previousDescription
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Outgoing capture replay tests passed")
