import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: queued event pipeline integration
class EventPipelineIntegrationTests(unittest.TestCase):
    def test_main_delegates_queued_event_delivery(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("local EventPipeline = MikSBT.Services.EventPipeline", source)
        self.assertIn("local eventPipeline = EventPipeline:New({", source)
        self.assertIn("eventPipeline:Acquire()", source)
        self.assertIn("eventPipeline:Queue(combatEvent)", source)
        self.assertIn("eventPipeline:Tick(elapsed)", source)
        self.assertNotIn("local unmergedEvents = {}", source)
        self.assertNotIn("local mergedEvents = {}", source)
        self.assertNotIn("local combatEventCache = {}", source)

    def test_pipeline_loads_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Services\\EventPipeline.lua"),
            toc_lines.index("MSBTMain.lua"),
        )


if __name__ == "__main__":
    unittest.main()
