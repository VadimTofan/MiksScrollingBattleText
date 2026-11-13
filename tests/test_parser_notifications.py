import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


# Describe: parser notification routes
class ParserNotificationsTests(unittest.TestCase):
    def test_chat_notifications_survive_without_legacy_combat_processing(self):
        # Given real parser, routing, formatting and notification modules.
        script_name = "notification_runtime.lua"

        # When chat events arrive with enabled and disabled settings.
        result = run_lua_test(script_name)

        # Then display output and loot payloads keep their existing behavior.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_routes_supported_chat_notifications_for_the_player(self):
        # Given
        script_name = "parser_notifications.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_skill_gains_take_their_skill_line_icon(self):
        # Given
        from scripts import generate_skill_line_icons as generator

        root = Path(__file__).resolve().parents[1]
        main = (root / "MSBTMain.lua").read_text(encoding="utf-8-sig")
        table = (root / "Components" / "SkillLineIcons.lua").read_text(encoding="utf-8")
        rows = [
            {"ID": "165", "SpellIconFileID": "136247"},
            {"ID": "173", "SpellIconFileID": "136235"},
            {"ID": "185", "SpellIconFileID": "133971"},
            {"ID": "753", "SpellIconFileID": "0"},
        ]

        # When
        found = generator.icons(rows)

        # Then
        self.assertEqual(found, {165: 136247, 185: 133971})
        self.assertIn("\t[165]=136247, [185]=133971,\n", generator.render(found, "test"))
        self.assertIn("[165]=136247,", table)
        self.assertIn("effectTexture = parserNotifications:SkillIcon(effectName)", main)
        for toc in ("MikScrollingBattleText.toc", "MikScrollingBattleText_Camelot.toc"):
            lines = (root / toc).read_text(encoding="utf-8-sig").splitlines()
            self.assertEqual(
                lines.index("Components\\SkillLineIcons.lua") + 1,
                lines.index("Components\\ParserNotifications.lua"),
            )


if __name__ == "__main__":
    unittest.main()
