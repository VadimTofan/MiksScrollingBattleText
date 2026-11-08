-- Describe: health alerts use the native threshold path without a screen flash.
TEST_HEALTH_ALERTS = true
LowHealthFrame = nil
dofile("tests/lua/restricted_mana_alerts.lua")
