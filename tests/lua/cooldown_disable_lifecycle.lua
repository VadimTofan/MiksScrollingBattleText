local context = dofile("tests/lua/cooldown_lifecycle_setup.lua")
local frame = context.frame

-- Given item tracking was enabled and then the addon was disabled.
context.module.Enable()
context.module.Disable()

-- When an item-use hook runs while disabled.
frame.hooks.UseAction(1)

-- Then polling remains stopped.
assert(not frame.visible, "item hook restarted polling after disable")

-- Given the disabled addon receives a combat transition.
frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")

-- When an item is used after that event.
frame.hooks.UseAction(1)

-- Then the event cannot re-enable the disabled tracker.
assert(not frame.visible, "combat event re-enabled disabled item tracking")

-- Given the user explicitly enables the addon again.
context.module.Enable()

-- When an item is used.
frame.hooks.UseAction(1)

-- Then polling resumes normally.
assert(frame.visible, "re-enabled tracker ignored an item use")
