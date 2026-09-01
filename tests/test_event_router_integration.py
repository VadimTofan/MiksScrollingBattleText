import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: parser event router integration
class EventRouterIntegrationTests(unittest.TestCase):
    def test_main_delegates_parser_event_dispatch(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("local EventRouter = MikSBT.Services.EventRouter", source)
        self.assertIn("local eventRouter = EventRouter:New()", source)
        self.assertIn("eventRouter:Resolve(parserEvent, currentProfile)", source)
        self.assertNotIn("local eventHandlers = {}", source)

    def test_router_loads_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Services\\EventRouter.lua"),
            toc_lines.index("MSBTMain.lua"),
        )


if __name__ == "__main__":
    unittest.main()
