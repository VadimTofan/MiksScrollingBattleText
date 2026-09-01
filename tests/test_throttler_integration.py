import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: throttler service integration
class ThrottlerIntegrationTests(unittest.TestCase):
    def test_main_delegates_throttle_state_to_service(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("local Throttler = MikSBT.Services.Throttler", source)
        self.assertIn("Throttler:Configure({", source)
        self.assertIn("Throttler:Queue(", source)
        self.assertIn("Throttler:Tick(", source)
        self.assertNotIn("local throttledAbilities", source)

    def test_throttler_loads_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Services\\Throttler.lua"),
            toc_lines.index("MSBTMain.lua"),
        )


if __name__ == "__main__":
    unittest.main()
