local ns = MikSBT.CombatEngine
local GearProcs = {
    items = {
        { item = 17705, spell = 21919, name = "Thrash Blade",
            event = "NOTIFICATION_GEAR_THRASH_BLADE" },
        { item = 11684, spell = 15494, name = "Ironfoe",
            event = "NOTIFICATION_GEAR_IRONFOE" },
        { item = 11815, spell = 15601, name = "Hand of Justice",
            event = "NOTIFICATION_GEAR_HAND_OF_JUSTICE" },
    },
    bySpell = {},
}

for _, rule in ipairs(GearProcs.items) do
    GearProcs.bySpell[rule.spell] = rule
end

function GearProcs.IsEquipped(rule)
    local client = MikSBT.Compatibility and MikSBT.Compatibility.Client
    if not (client and client.isForever and C_Item and C_Item.IsEquippedItem) then return false end
    local equipped = C_Item.IsEquippedItem(rule.item)
    return ns.Bool(equipped) and equipped
end

function GearProcs.Name(rule)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(rule.item)
    return ns.Text(name) and name or rule.name
end

ns.GearProcs = GearProcs
