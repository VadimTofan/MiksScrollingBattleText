-- Adapted from Forever Combat Text 0.6.8 (Tarolg, MIT).
-- See Combat/LICENSE-ForeverCombatText. MSBT uses its own presentation.
local ns = MikSBT.CombatEngine

-- What each happening becomes on screen: which lane, which icon, joined with
-- others or not, how big and what colour, by the player's settings. The
-- lanes on screen and the settings page's previews both draw through a
-- router, the previews with their sample fight (Sample.lua) and settings
-- that may show a choice being hovered, so the two cannot differ.
--
-- A router is made with get(path), the settings to follow, and views:
-- out, inc, alert, gain (Lines.lua views) and plate(token), the view over an
-- enemy's nameplate for Your hits on other enemies (nil when there is none).

local C = {
    physical = { 1, 1, 1 }, holy = { 1, 0.9, 0.5 }, fire = { 1, 0.56, 0.2 }, nature = { 0.5, 1, 0.45 },
    frost = { 0.55, 0.85, 1 }, shadow = { 0.72, 0.57, 1 }, arcane = { 1, 0.55, 0.92 },
    plain = { 1, 0.85, 0.3 }, hurt = { 1, 0.33, 0.28 }, heal = { 0.38, 0.92, 0.42 }, power = { 0.41, 0.8, 0.94 },
    word = { 0.68, 0.69, 0.72 }, grey = { 0.56, 0.56, 0.58 }, pet = { 0.85, 0.82, 0.76 },
    cc = { 1, 0.42, 0.37 }, gold = { 0.95, 0.76, 0.35 }, light = { 0.92, 0.92, 0.92 }, debuff = { 1, 0.45, 0.4 },
}
ns.COLORS = C

-- School masks, first match wins for mixed schools.
local SCHOOLS = { { 32, "shadow" }, { 4, "fire" }, { 16, "frost" }, { 8, "nature" }, { 64, "arcane" }, { 2, "holy" }, { 1, "physical" } }
local function HasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end
function ns.SchoolName(mask)
    if not ns.Number(mask, 1, 255) then return nil end
    for _, school in ipairs(SCHOOLS) do
        if HasBit(mask, school[1]) then return school[2] end
    end
end
local SCHOOL_WORDS = { shadow = "shadow", fire = "fire", frost = "frost", nature = "nature", arcane = "arcane", holy = "holy" }

-- Numbers: 1240, 1,240 or 1.2k; anything over 10,000 is short.
local function Short(n) return (string.format("%.1f", n / 1000):gsub("%.0$", "")) .. "k" end
function ns.FormatNumber(n, style)
    if not ns.Number(n) then return n end
    n = math.floor(n + 0.5)
    if n >= 10000 or (style == "short" and n >= 1000) then return Short(n) end
    if style == "comma" and n >= 1000 then
        local text = tostring(n)
        return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
    end
    return tostring(n)
end

-- The words for misses, from the game's own strings (CombatFeedback.lua's).
local WORDS = { MISS = "MISS", DODGE = "DODGE", PARRY = "PARRY", BLOCK = "BLOCK", RESIST = "RESIST", EVADE = "EVADE",
    IMMUNE = "IMMUNE", DEFLECT = "DEFLECT", ABSORB = "ABSORB", REFLECT = "REFLECT" }
local FALLBACK = { MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", RESIST = "Resist", EVADE = "Evade",
    IMMUNE = "Immune", DEFLECT = "Deflect", ABSORB = "Absorb", REFLECT = "Reflect" }
function ns.MissWord(event)
    local global = WORDS[event] and _G[WORDS[event]]
    if ns.Text(global) then return global end
    return FALLBACK[event] or event
end

-- Icons: a spell's own, else the auto attack's or the wand's.
local AUTO_ATTACK, SHOOT = 6603, 5019
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
function ns.SpellIcon(spell)
    if ns.Text(spell) then return spell end
    if not ns.Number(spell) or not C_Spell or not C_Spell.GetSpellTexture then return nil end
    local icon = C_Spell.GetSpellTexture(spell)
    if ns.Public(icon) and icon then return icon end
    return nil
end
local function MeleeIcon(hand)
    return ns.SpellIcon(hand == "ranged" and SHOOT or AUTO_ATTACK) or FALLBACK_ICON
end
ns.MeleeIcon = MeleeIcon
ns.KILLING_BLOW = "Killing blow"

-- 0.3.51 (the user, 15 October 2026: "the touch of the grave thing that we
-- know should get its own icon"): an Undead's drain that no cast explains.
-- Its spell ID on Forever is not known (5227 is Underwater Breathing here),
-- so the game is asked by name, which finds it while it is in your
-- spellbook; otherwise the Undead's other racial, Will of the Forsaken
-- (Blizzard_CooldownBroadcaster's RacialCooldowns.Scourge), stands in so the
-- hit is still told apart. Other races keep no icon. Asked once, at the first
-- such hit.
local GRAVE_NAME, FORSAKEN = "Touch of the Grave", 7744
local grave
local function Grave()
    if grave then return grave end
    grave = {}
    local race
    if UnitRace then race = select(2, UnitRace("player")) end
    if not ns.Text(race) or race ~= "Scourge" then return grave end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(GRAVE_NAME)
    if type(info) == "table" and ns.Public(info) and ns.Number(info.iconID, 1) then
        grave.icon = info.iconID
        if ns.Text(info.name) then grave.name = info.name end
    else
        grave.icon = ns.SpellIcon(FORSAKEN)
    end
    return grave
end
function ns.GraveIcon() return Grave().icon end
function ns.GraveName() return Grave().name end
-- For the tests: ask again at the next hit.
function ns.ForgetGrave() grave = nil end

-- Names (0.3.21, the user, 14 October 2026: Busy "should write the name
-- with the icon"): a spell of yours by its ID, your swings and shots by the
-- game's own names (Auto Attack, Shoot), your pet's swings by its name.
function ns.SpellName(spell)
    if not ns.Number(spell, 1) or not C_Spell or not C_Spell.GetSpellName then return nil end
    local name = C_Spell.GetSpellName(spell)
    if ns.Text(name) then return name end
    return nil
end
local function PetName()
    local name = UnitName and UnitName("pet")
    if ns.Text(name) then return name end
    return nil
end
local function HitName(record, result)
    if record.name then return record.name end
    if result.spell then return ns.SpellName(result.spell) end
    if result.procSpell then return ns.SpellName(result.procSpell) end
    if result.drain then return ns.GraveName() end
    if result.melee then
        if result.who == "pet" then return PetName() end
        return ns.SpellName(result.hand == "ranged" and SHOOT or AUTO_ATTACK)
    end
end
ns.HitName = HitName

