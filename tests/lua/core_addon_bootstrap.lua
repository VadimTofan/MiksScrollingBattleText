MikSBT = {
	Print = function() end,
}

dofile("Core/Diagnostics.lua")
dofile("Core/EventBus.lua")
dofile("Core/ComponentRegistry.lua")

-- Given
local addon = dofile("Core/Addon.lua")
local component = { name = "Example" }

-- When
addon:RegisterComponent(component)

-- Then
assert(addon.context, "bootstrap omitted shared context")
assert(addon.context.diagnostics, "context omitted diagnostics")
assert(addon.context.events, "context omitted event bus")
assert(addon.context.components, "context omitted component registry")
assert(addon.context.api, "context omitted shared API adapters")
assert(addon.context.api == MikSBT.API, "context uses a different API table")
assert(addon.context.services, "context omitted shared services")
assert(addon.context.services == MikSBT.Services,
	"context uses a different services table")
assert(addon.context.display, "context omitted shared display services")
assert(addon.context.display == MikSBT.Display,
	"context uses a different display table")
assert(addon.context.components.components[1] == component,
	"component registration did not use shared registry")
