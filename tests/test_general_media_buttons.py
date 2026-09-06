import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
OPTIONS_TABS_FILE = REPOSITORY_ROOT / "MSBTOptions" / "MSBTOptionsTabs.lua"


# Describe: General tab media controls
class GeneralMediaButtonTests(unittest.TestCase):
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
