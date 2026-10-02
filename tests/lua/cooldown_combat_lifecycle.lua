local context = dofile("tests/lua/cooldown_lifecycle_setup.lua")
local frame = context.frame

-- Given an item was used before combat.
context.module.Enable()
frame.hooks.UseAction(1)

-- When combat starts before the item watch delay expires.
frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")

-- Then the pending item use remains scheduled.
assert(frame.visible, "combat entry erased the pending item watch")
context.now = 11
frame.scripts.OnUpdate(frame, 1)

-- Given its cooldown is now active, when combat ends before completion.
frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")

-- Then tracking survives and the ready alert fires once at completion.
assert(frame.visible, "combat exit erased the active item cooldown")
context.now = 15.1
frame.scripts.OnUpdate(frame, 4.1)
assert(#context.displayed == 1, "cooldown completion was lost or duplicated")
assert(context.displayed[1]:find("Potion", 1, true), "alert lost the item name")
assert(not frame.visible, "completed tracker kept polling")
