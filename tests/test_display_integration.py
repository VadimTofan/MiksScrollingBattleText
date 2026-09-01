import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ANIMATIONS_FILE = REPOSITORY_ROOT / "Display" / "AnimationEngine.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: display-service integration
class DisplayIntegrationTests(unittest.TestCase):
    def test_animations_delegate_display_policy(self):
        # Given
        source = ANIMATIONS_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("local DisplayService = MikSBT.Display.Service", source)
        self.assertIn("DisplayService:Configure({", source)
        self.assertNotIn("local function DisplayEvent", source)
        self.assertNotIn("local function DisplayMessage", source)
        self.assertIn("DisplayService:DisplayEvent(", source)
        self.assertIn("DisplayService:DisplayMessage(", source)

    def test_display_service_loads_before_animations(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Display\\DisplayService.lua"),
            toc_lines.index("Display\\AnimationEngine.lua"),
        )


if __name__ == "__main__":
    unittest.main()
