import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ANIMATIONS_FILE = REPOSITORY_ROOT / "Display" / "AnimationEngine.lua"
DISPLAY_SERVICE_FILE = REPOSITORY_ROOT / "Display" / "DisplayService.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: scroll-area integration
class ScrollAreasIntegrationTests(unittest.TestCase):
    def test_animations_delegate_scroll_area_ownership(self):
        # Given
        source = ANIMATIONS_FILE.read_text(encoding="utf-8-sig")
        display_source = DISPLAY_SERVICE_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("local ScrollAreas = MikSBT.Display.ScrollAreas", source)
        self.assertIn("ScrollAreas:Configure({", source)
        self.assertIn("scrollAreas:IsSuppressedInGroup(", display_source)
        self.assertNotIn("local externalScrollAreas", source)
        self.assertNotIn("local function UpdateScrollAreas", source)
        self.assertNotIn("local function IsScrollAreaSuppressedInGroup", source)

    def test_scroll_area_service_loads_before_animations(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Display\\ScrollAreas.lua"),
            toc_lines.index("Display\\AnimationEngine.lua"),
        )


if __name__ == "__main__":
    unittest.main()
