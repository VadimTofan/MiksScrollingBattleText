import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
OPTIONS_TABS_FILE = REPOSITORY_ROOT / "MSBTOptions" / "MSBTOptionsTabs.lua"


# Describe: General tab media controls
class GeneralMediaButtonTests(unittest.TestCase):
    def test_combat_text_checkboxes_change_independent_preferences(self):
        # Given the General controls and profile preferences.
        script_name = "general_combat_text_controls.lua"

        # When the checkboxes are clicked and General is refreshed.
        result = run_lua_test(script_name)

        # Then the controls preserve both preferences and appearance settings.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_only_the_two_main_combat_text_toggles_remain(self):
        # Given the General settings source.
        source = OPTIONS_TABS_FILE.read_text(encoding="utf-8-sig")

        # When inspecting its combat-text controls.
        general_tab = source.split(
            "local function GeneralTab_Create()", 1
        )[1].split("local function GeneralTab_OnShow()", 1)[0]

        # Then only the global MSBT and Blizzard damage controls remain.
        self.assertIn('L.CHECKBOXES["enableMSBT"]', general_tab)
        self.assertIn('L.CHECKBOXES["enableBlizzardDamage"]', general_tab)
        for removed in (
            "disableOutgoingInGroup", "disableIncomingInGroup",
            "disableNotificationInGroup", "disableStaticInGroup",
            "disableBlizzardIncoming", "enableBlizzardV2CombatText",
            "enableBlizzardV2InGroup",
        ):
            self.assertNotIn(removed, general_tab)

    def test_general_tab_offers_custom_sounds_without_custom_fonts(self):
        # Given
        source = OPTIONS_TABS_FILE.read_text(encoding="utf-8-sig")

        # When
        general_tab = source.split(
            "local function GeneralTab_Create()", 1
        )[1].split("local function GeneralTab_OnShow()", 1)[0]

        # Then
        self.assertNotIn('L.BUTTONS["addCustomFont"]', general_tab)
        self.assertIn('L.BUTTONS["addCustomSound"]', general_tab)
        self.assertIn(
            'controls.partialEffectsButton, "TOPLEFT", 0, 10',
            general_tab,
        )


if __name__ == "__main__":
    unittest.main()
