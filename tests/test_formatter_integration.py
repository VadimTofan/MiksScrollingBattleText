import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: formatter service integration
class FormatterIntegrationTests(unittest.TestCase):
    def test_main_delegates_formatting_to_service(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When
        local_formatter_definitions = [
            "local function FormatDisplayAmount",
            "local function FormatEvent",
            "local function FormatPartialEffects",
        ]

        # Then
        self.assertIn("local Formatter = MikSBT.Services.Formatter", source)
        self.assertIn("Formatter:Configure({", source)
        self.assertIn("Formatter:FormatLegacyEvent(", source)
        for definition in local_formatter_definitions:
            self.assertNotIn(definition, source)

    def test_formatter_service_loads_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When
        formatter_index = toc_lines.index("Services\\Formatter.lua")
        main_index = toc_lines.index("MSBTMain.lua")

        # Then
        self.assertLess(formatter_index, main_index)


if __name__ == "__main__":
    unittest.main()
