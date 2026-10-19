import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class CurseForgeMetadataTests(unittest.TestCase):
    def test_build_metadata_includes_explicit_game_versions(self):
        # Given
        from scripts.build_curseforge_metadata import build_metadata

        version = "v12.022"
        changelog = "## v12.022\n\n- Fix release metadata."

        # When
        metadata = build_metadata(
            version=version,
            changelog=changelog,
            game_version_names=["Retail", "12.1.5", "12.1.0"],
        )

        # Then
        self.assertEqual(metadata["displayName"], "MikScrollingBattleText v12.022")
        self.assertEqual(metadata["changelog"], changelog)
        self.assertEqual(metadata["changelogType"], "markdown")
        self.assertEqual(metadata["releaseType"], "release")
        self.assertEqual(
            metadata["gameVersionNames"], ["Retail", "12.1.5", "12.1.0"],
        )

    def test_release_workflow_marks_the_archive_for_forever(self):
        # Given
        workflow_path = REPOSITORY_ROOT / ".github/workflows/curseforge-release.yml"

        # When
        workflow = workflow_path.read_text(encoding="utf-8")

        # Then
        self.assertIn("--game-version 12.1.5", workflow)
        self.assertIn("--game-version 12.1.0", workflow)
        self.assertIn("--game-version 1.60.1", workflow)

    def test_retail_manifest_supports_the_latest_interface(self):
        # Given
        toc_path = REPOSITORY_ROOT / "MikScrollingBattleText.toc"

        # When
        toc = toc_path.read_text(encoding="utf-8")

        # Then
        interface_line = next(
            line for line in toc.splitlines()
            if line.startswith("## Interface:")
        )
        self.assertIn("120105", interface_line)


if __name__ == "__main__":
    unittest.main()
