import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
OPTIONS = ROOT / "MSBTOptions"


class RemovedDeadOptionsCodeTests(unittest.TestCase):
    def test_unregistered_tab_implementations_are_removed(self):
        # Given
        source = (OPTIONS / "MSBTOptionsTabs.lua").read_text(encoding="utf-8-sig")

        # When
        removed_functions = (
            "TriggersTab_Create",
            "TriggersTab_OnShow",
            "SpamTab_Create",
            "SpamTab_OnShow",
            "SkillIconsTab_Create",
            "SkillIconsTab_OnShow",
        )

        # Then
        for function_name in removed_functions:
            self.assertNotIn(function_name, source)
        self.assertNotIn("tabFrames.media", source)
        self.assertNotIn("local MSBTTriggers", source)
        self.assertNotIn("local function PairsByKeys", source)

    def test_options_code_has_no_commented_out_statements(self):
        # Given
        sources = [
            (OPTIONS / "MSBTOptionsMain.lua").read_text(encoding="utf-8-sig"),
            (OPTIONS / "MSBTOptionsPopups.lua").read_text(encoding="utf-8-sig"),
        ]

        # When
        commented_statement = re.compile(
            r"^\s*--(?:\[\[)?\s*(?:local\s+\w+\s*=|\w+:Set)",
            re.MULTILINE,
        )

        # Then
        for source in sources:
            self.assertIsNone(commented_statement.search(source))
            self.assertNotIn("AI_POLICY_NOTICE", source)

    def test_localizations_have_no_commented_out_assignments(self):
        # Given
        localization_dir = OPTIONS / "Localization"

        # When
        sources = [
            path.read_text(encoding="utf-8-sig")
            for path in localization_dir.glob("*.lua")
        ]
        commented_assignment = re.compile(
            r"^\s*--\s*(?:L\.[A-Z_]+|obj\[[^]]+\])\s*=",
            re.MULTILINE,
        )

        # Then
        for source in sources:
            self.assertIsNone(commented_assignment.search(source))


if __name__ == "__main__":
    unittest.main()
