import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


ROOT = Path(__file__).resolve().parents[1]


# Describe: runtime manifests and modules contain only supported paths.
class StaleRuntimeRemovalTests(unittest.TestCase):
    def test_clients_do_not_load_unused_framework_and_api_files(self):
        # Given both supported addon manifests.
        manifests = list(ROOT.glob("MikScrollingBattleText*.toc"))
        unused_files = (
            "Core/Addon.lua",
            "Core/Diagnostics.lua",
            "Core/EventBus.lua",
            "Core/ComponentRegistry.lua",
            "API/Combat.lua",
            "API/BlizzardCombatText.lua",
            "Services/Batcher.lua",
            "Services/Throttler.lua",
            "Services/EventPipeline.lua",
            "Components/SelfHealTracker.lua",
        )

        # When inspecting the shipped runtime files.
        for manifest in manifests:
            lines = manifest.read_text(encoding="utf-8-sig").replace("\\", "/")

            # Then unused infrastructure is neither loaded nor shipped.
            for relative_path in unused_files:
                self.assertTrue(relative_path not in lines, relative_path)
                self.assertFalse((ROOT / relative_path).exists())

    def test_options_keep_active_editors_without_unreachable_editors(self):
        # Given the popup module used by the registered options tabs.
        source = (ROOT / "MSBTOptions/MSBTOptionsPopups.lua").read_text(
            encoding="utf-8-sig"
        )

        # When inspecting its editor entry points.
        removed_editors = ("ShowTrigger", "ShowSkillList", "CreateMainEvent")
        active_editors = ("ShowItemList", "ShowEvent", "ShowScrollAreaConfig")

        # Then unreachable editors are absent and active editors remain.
        for name in removed_editors:
            self.assertTrue(name not in source, name)
        for name in active_editors:
            self.assertIn("module." + name, source)

    def test_bootstrap_leaves_api_compatibility_to_the_legacy_facade(self):
        # Given namespace initialization before the API files load.
        source = (ROOT / "MikSBT.lua").read_text(encoding="utf-8-sig")

        # When inspecting compatibility exports.
        superseded_helpers = (
            "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown",
            "HasAura", "GetSkillName",
        )

        # Then bootstrap does not install implementations replaced later.
        for name in superseded_helpers:
            self.assertTrue("mod." + name not in source, name)

    def test_unit_adapter_only_exposes_the_aura_lookup_used_at_runtime(self):
        # Given the unit API used by the legacy aura facade.
        source = (ROOT / "API/Units.lua").read_text(encoding="utf-8-sig")

        # When inspecting its unused unit-query methods.
        unused_methods = (
            "GetGUID", "GetName", "GetClass", "Exists", "CanAttack",
            "AffectingCombat", "GetPower", "GetPowerMax", "GetAttackSpeed",
        )

        # Then only the supported aura-query surface remains.
        self.assertIn("function Units:HasAura", source)
        for name in unused_methods:
            self.assertTrue("function Units:" + name not in source, name)

    def test_item_completion_needs_only_its_notification_dependencies(self):
        # Given an item tracker without the obsolete trigger callback.
        script_name = "item_cooldown_tracker.lua"

        # When the tracked item finishes cooling down.
        result = run_lua_test(script_name)

        # Then the same item name and icon are displayed.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_private_helpers_without_callers_are_removed(self):
        # Given the modules containing helpers left by removed features.
        unused_helpers = {
            "MSBTMain.lua": ("SafeStringKey",),
            "MSBTParser.lua": ("SafeRegisterEvent", "deferredRegisterTicker"),
            "MSBTOptions/MSBTOptionsTabs.lua": (
                "GeneralTab_SetBlizzardCombatTextV2Enabled",
                "GeneralTab_IsBlizzardCombatTextV2Enabled",
                "GenerelTab_ValidateProfileName",
            ),
            "MSBTOptions/MSBTOptionsPopups.lua": ("PairsByKeys",),
            "Services/Formatter.lua": ("FormatPartialEffects",),
        }

        # When inspecting their remaining helper declarations.
        for relative, names in unused_helpers.items():
            source = (ROOT / relative).read_text(encoding="utf-8-sig")

            # Then helpers with no callers have no runtime implementation.
            for name in names:
                self.assertTrue(name not in source, name)

    def test_unregistered_combat_log_paths_are_removed(self):
        # Given the parser, main routing and trigger modules.
        modules = ("MSBTParser.lua", "MSBTMain.lua", "MSBTTriggers.lua")
        obsolete_paths = (
            "ParseLogMessage", "HandleCombatLogTriggers",
            "local function DamageHandler", "local function HealHandler",
            "COMBAT_LOG_EVENT_UNFILTERED", "CombatLogGetCurrentEventInfo",
        )

        # When inspecting the runtime code behind registered event sources.
        for relative in modules:
            source = (ROOT / relative).read_text(encoding="utf-8-sig")

            # Then unavailable combat-log processing has no runtime path.
            for name in obsolete_paths:
                self.assertTrue(name not in source, relative + ": " + name)


if __name__ == "__main__":
    unittest.main()
