import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"
PIPELINE_FILE = REPOSITORY_ROOT / "Services" / "EventPipeline.lua"


# Describe: batcher service integration
class BatcherIntegrationTests(unittest.TestCase):
    def test_main_delegates_event_merging_to_batcher(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8-sig")
        pipeline_source = PIPELINE_FILE.read_text(encoding="utf-8-sig")

        # When / Then
        self.assertIn("local Batcher = MikSBT.Services.Batcher", source)
        self.assertIn("Batcher:Configure({", source)
        self.assertIn("batcher = Batcher", source)
        self.assertIn(
            "self.config.batcher:Merge(self.pending, self.merged",
            pipeline_source,
        )
        self.assertNotIn("local function MergeEvents", source)

    def test_batcher_loads_before_main(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        self.assertLess(
            toc_lines.index("Services\\Batcher.lua"),
            toc_lines.index("MSBTMain.lua"),
        )


if __name__ == "__main__":
    unittest.main()
