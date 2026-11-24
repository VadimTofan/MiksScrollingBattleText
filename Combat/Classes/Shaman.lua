local engine = MikSBT.CombatEngine
local windfuryWeapon = {
    iconSpell = 8232,
    procSpell = 439440,
    triggerSpell = 17364, -- Stormstrike
    groupDelay = 1,
    enchants = { [283] = true, [284] = true, [525] = true, [1669] = true },
}

engine.classRules.SHAMAN = {
    windfuryWeapon = windfuryWeapon,
    spellReach = {
        [windfuryWeapon.triggerSpell] = "melee",
    },
}

-- Shared signal and display code uses the same class-owned spell data.
engine.WindfuryWeapon = windfuryWeapon
