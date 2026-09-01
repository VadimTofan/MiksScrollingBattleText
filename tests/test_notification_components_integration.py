import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: notification component integration
class NotificationComponentsIntegrationTests(unittest.TestCase):
    def test_main_delegates_parser_and_utility_notifications(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn(
            "local ParserNotifications = MikSBT.Components.ParserNotifications",
            source,
        )
        self.assertIn(
            "local UtilityNotifications = MikSBT.Components.UtilityNotifications",
            source,
        )
        self.assertIn("parserNotifications:HandlePower(", source)
        self.assertIn("utilityNotifications:HandlePowerUpdate(", source)
        self.assertIn("utilityNotifications:HandleCombatEnter()", source)
        self.assertIn("utilityNotifications:HandleCombatLeave()", source)
        self.assertIn("utilityNotifications:HandleMonsterEmote(", source)
        self.assertNotIn("local function PowerHandler", source)
        self.assertNotIn("local function KillHandler", source)
        self.assertNotIn("local function HandleMonsterEmotes", source)
        self.assertNotIn("local lastPowerAmounts = {}", source)
        self.assertNotIn("local recentEmotes = {}", source)
        self.assertNotIn("local math_abs = math.abs", source)

    def test_notification_components_load_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        main_index = toc_lines.index("MSBTMain.lua")
        self.assertLess(
            toc_lines.index("Components\\ParserNotifications.lua"),
            main_index,
        )
        self.assertLess(
            toc_lines.index("Components\\UtilityNotifications.lua"),
            main_index,
        )


if __name__ == "__main__":
    unittest.main()
