import unittest
from pathlib import Path


class ReleasePackagingTests(unittest.TestCase):
    def test_workflow_excludes_non_runtime_files_from_zip(self):
        # Given
        workflow = Path(".github/workflows/curseforge-release.yml").read_text(
            encoding="utf-8"
        )

        # When
        expected_excludes = [
            "--exclude 'tests/'",
            "--exclude 'scripts/'",
            "--exclude 'README.md'",
            "--exclude 'CHANGELOG.md'",
            "--exclude 'API.html'",
        ]

        # Then
        for expected_exclude in expected_excludes:
            self.assertIn(expected_exclude, workflow)


if __name__ == "__main__":
    unittest.main()
