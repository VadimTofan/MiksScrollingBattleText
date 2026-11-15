-- Describe: accounting receipts describe existing spending without changing it.
MikSBT = { CombatEngine = {} }
dofile("Combat/Mine.lua")
local ns = MikSBT.CombatEngine
local failures = {}

local function Check(name, run)
    local ok, message = pcall(run)
    if not ok then failures[#failures + 1] = name .. ": " .. message end
end

local function Direct(hits)
    return { damages = true, direct = true, ticks = false,
        school = 1, directHits = hits }
end

local function New(facts, enabled)
    local mine = ns.NewMine(nil, nil, function(spell) return facts[spell] end)
    mine.accountingEnabled = enabled
    return mine
end

local function Hit(mine, at, kind, key, amount)
    return mine:Hit(key or "target1", kind or "damage", 1, at,
        false, true, amount, false, "direct", nil, "MISS")
end

local function Receipt(mine)
    local receipt = mine.lastOutcomeReceipt
    assert(type(receipt) == "table", "consumed outcome has no receipt")
    for _, value in pairs(receipt) do
        local kind = type(value)
        assert(kind == "number" or kind == "string" or kind == "boolean",
            "receipt retained a nonprimitive value")
    end
    assert(receipt.amount == nil and receipt.cast == nil
        and receipt.swing == nil and receipt.record == nil,
        "receipt retained outcome objects or damage")
    return receipt
end

Check("a native swing exposes its spent hand and target", function()
    -- Given one ordinary off-hand swing with accounting enabled.
    local mine = New({}, true)
    mine:Swing("off", "target1", 10)

    -- When its physical hit consumes the ordinary swing.
    local result = mine:Hit("target1", "damage", 1, 10.2,
        false, true, nil, false, "swing")

    -- Then the existing decision and one primitive receipt identify the swing.
    assert(result.who == "you" and result.melee and result.hand == "off")
    local receipt = Receipt(mine)
    assert(receipt.kind == "swing" and receipt.at == 10)
    assert(receipt.key == "target1" and receipt.hand == "off")
    assert(receipt.who == "you" and receipt.ordinal == 1)
    assert(mine.swings[1].used)

    -- When another confirmed report follows the spent swing.
    local extra = mine:Hit("target1", "damage", 1, 10.3,
        false, true, nil, false, "swing")

    -- Then neither attribution nor accounting spends that swing again.
    assert(not extra.melee and mine.lastOutcomeReceipt == nil)
end)

Check("a held report receives the later native swing receipt", function()
    -- Given an unidentified physical report before its swing event.
    local mine = New({}, true)
    local result = mine:Hit("target1", "damage", 1, 10,
        false, nil, nil, false, "swing")
    assert(result.hold and mine.lastOutcomeReceipt == nil)

    -- When the late main-hand swing claims that held report.
    local held = mine:Swing("main", "target1", 10.1)

    -- Then only the claimed entry carries its primitive accounting metadata.
    assert(held == result.held and held.claimed)
    local receipt = held.accountingReceipt
    assert(type(receipt) == "table", "held swing has no receipt")
    assert(receipt.kind == "swing" and receipt.at == 10.1)
    assert(receipt.key == "target1" and receipt.hand == "main")
    assert(receipt.who == "you" and receipt.ordinal == 1)
    assert(mine.lastOutcomeReceipt == nil and #mine.swings == 0)
    assert(mine:Swing("main", "target1", 10.2) == nil)
end)

Check("Stormstrike damage and avoidance spend the same ordinal", function()
    for _, firstKind in ipairs({ "damage", "miss" }) do
        -- Given a single-outcome Stormstrike cast.
        local mine = New({ [17364] = Direct() }, true)
        mine:Cast("player", 17364, "target1", 10)

        -- When that outcome lands or misses.
        local first = Hit(mine, 10.1, firstKind)

        -- Then its receipt reflects the cast's existing spent outcome.
        assert(first.spell == 17364 and first.who == "you")
        local receipt = Receipt(mine)
        assert(receipt.kind == "cast" and receipt.at == 10)
        assert(receipt.spell == 17364 and receipt.who == "you")
        assert(receipt.key == "target1" and receipt.sourceKey == "target1")
        assert(receipt.ordinal == 1 and receipt.uncertain == false)

        -- When another owned avoidance report follows.
        local second = Hit(mine, 10.2, "miss")

        -- Then no second spell outcome or receipt is manufactured.
        assert(second.spell == nil and second.who == "you")
        assert(mine.lastOutcomeReceipt == nil)
        assert(mine.casts[17364][1].outcomes.target1 == 1)
    end
end)

Check("supported direct components receive increasing ordinals", function()
    -- Given a cast explicitly supporting two direct components.
    local mine = New({ [17364] = Direct(2) }, true)
    mine:Cast("player", 17364, "target1", 10)

    -- When a miss and damage consume its two components.
    Hit(mine, 10.1, "miss")
    local first = Receipt(mine)
    Hit(mine, 10.2)
    local second = Receipt(mine)

    -- Then accounting reads each actual ordinal without spending again.
    assert(first.ordinal == 1 and second.ordinal == 2)
    assert(first ~= second and mine.casts[17364][1].outcomes.target1 == 2)
end)

Check("historical direct recovery reports its actual impact target", function()
    -- Given a known area cast recovered through history on another target.
    local facts = Direct()
    facts.area, facts.window = true, 1.5
    local mine = New({ [17364] = facts }, true)
    mine:Cast("player", 17364, "target1", 10)

    -- When the historical path spends the target2 impact.
    local result = mine:Likeliest(1, 10.5, "direct", "target2")

    -- Then source target and actual impact target remain distinguishable.
    assert(result and result.spell == 17364 and result.likely)
    local receipt = Receipt(mine)
    assert(receipt.key == "target2" and receipt.sourceKey == "target1")
    assert(receipt.ordinal == 1)
    assert(Hit(mine, 10.6, "damage", "target2").spell == nil)
    assert(mine.lastOutcomeReceipt == nil)
end)

Check("ambiguous and unidentified reports clear previous receipts", function()
    -- Given one consumed cast followed by two competing physical spells.
    local mine = New({ [17364] = Direct(), [2] = Direct(),
        [3] = Direct() }, true)
    mine:Cast("player", 17364, "target1", 10)
    Hit(mine, 10.1)
    Receipt(mine)
    mine:Cast("player", 2, "target1", 11)
    mine:Cast("player", 3, "target1", 11)

    -- When their shared direct confirmation cannot name a spell.
    local result = Hit(mine, 11.1)

    -- Then ambiguous capacity never exposes a stale receipt.
    assert(result.ambiguous and result.spell == nil)
    assert(mine.lastOutcomeReceipt == nil)

    -- Given a fresh receipt before an explicitly unidentified group.
    mine:Cast("player", 17364, "target1", 20)
    Hit(mine, 20.1)
    Receipt(mine)

    -- When the reader reserves that unidentified group.
    local unidentified = mine:ConfirmUnidentified("target1", 1, 20.2)

    -- Then its unresolved identity has no receipt.
    assert(unidentified.ambiguous and mine.lastOutcomeReceipt == nil)
end)

Check("a resolved historical outcome gets a fresh receipt after ambiguity", function()
    -- Given an earlier historical ambiguity whose casts have now expired.
    local mine = New({ [17364] = Direct(), [2] = Direct(),
        [3] = Direct() }, true)
    mine:Cast("player", 2, "target1", 10)
    mine:Cast("player", 3, "target1", 10)
    local ambiguous = mine:Likeliest(1, 10.1, "direct", "target1")
    assert(ambiguous.ambiguous and mine.lastOutcomeReceipt == nil)
    mine:Cast("player", 17364, "target1", 20)

    -- When a later historical decision consumes one unambiguous cast.
    local result = mine:Likeliest(1, 20.1, "direct", "target1")

    -- Then the earlier ambiguity cannot suppress this actual receipt.
    assert(result.spell == 17364 and not result.ambiguous)
    local receipt = Receipt(mine)
    assert(receipt.spell == 17364 and receipt.at == 20)
end)

Check("an unknown held report clears previous receipts", function()
    -- Given one successful cast and its receipt.
    local mine = New({ [17364] = Direct() }, true)
    mine:Cast("player", 17364, "target1", 10)
    Hit(mine, 10.1)
    Receipt(mine)

    -- When an unexplained hit on another target waits for a late swing.
    local result = mine:Hit("target2", "damage", 1, 12,
        false, nil, nil, false, "swing")

    -- Then its hold cannot inherit the earlier receipt.
    assert(result.hold and mine.lastOutcomeReceipt == nil)
end)

Check("a rejected historical leech candidate exposes no receipt", function()
    -- Given cast history whose nonleech direct spell has no pending entry.
    local mine = New({ [17364] = Direct() }, true)
    mine:Cast("player", 17364, "target1", 10)
    mine.pending = {}

    -- When an owned hit's leech evidence rejects that historical candidate.
    local result = mine:Hit("target1", "damage", 1, 10.5,
        false, true, nil, false, "direct", true)

    -- Then existing fallback semantics survive without a misleading receipt.
    assert(result.who == "you" and result.proc and result.drain)
    assert(result.spell == nil and mine.lastOutcomeReceipt == nil)
    assert(mine.casts[17364][1].outcomes.target1 == 1)
end)

Check("accounting remains optional and never inspects opaque damage", function()
    local opaque = setmetatable({}, {
        __eq = function() error("compared opaque amount") end,
        __lt = function() error("ordered opaque amount") end,
        __le = function() error("ordered opaque amount") end,
        __tostring = function() error("formatted opaque amount") end,
    })
    for _, enabled in ipairs({ false, true }) do
        -- Given the same opaque Stormstrike outcome in either mode.
        local mine = New({ [17364] = Direct() }, enabled)
        mine:Cast("player", 17364, "target1", 10)

        -- When the actual matcher consumes its outcome.
        local result = Hit(mine, 10.1, "damage", "target1", opaque)

        -- Then decisions and spent capacity match, with opt-in metadata only.
        assert(result.who == "you" and result.spell == 17364)
        assert(mine.casts[17364][1].outcomes.target1 == 1)
        if enabled then Receipt(mine)
        else assert(mine.lastOutcomeReceipt == nil) end
    end

    -- Given default-off accounting and a held report.
    local mine = New({})
    assert(mine.accountingEnabled == nil)
    local result = mine:Hit("target1", "damage", 1, 10,
        false, nil, nil, false, "swing")

    -- When the late native swing claims it.
    local held = mine:Swing("main", "target1", 10.1)

    -- Then the default behavior allocates no receipt.
    assert(held == result.held and held.accountingReceipt == nil)
    assert(mine.lastOutcomeReceipt == nil)
end)

assert(#failures == 0, table.concat(failures, "\n"))
print("Mine outcome receipt tests passed")
