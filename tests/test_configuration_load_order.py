import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: configuration runtime load order
class ConfigurationLoadOrderTests(unittest.TestCase):
    def test_configuration_loads_after_core_and_before_profile_facades(self):
        # Given
        toc_lines = [
            line.strip()
            for line in TOC_FILE.read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.startswith("##")
        ]
        expected_configuration = [
            "Configuration\\ProfileStore.lua",
            "Configuration\\MediaRegistry.lua",
            "Configuration\\RuntimeController.lua",
        ]

        # When
        configuration_index = toc_lines.index(expected_configuration[0])
        configuration_lines = toc_lines[
            configuration_index : configuration_index + len(expected_configuration)
        ]

        # Then
        self.assertEqual(configuration_lines, expected_configuration)
        self.assertLess(
            toc_lines.index("Core\\Addon.lua"),
            configuration_index,
        )
        self.assertLess(
            configuration_index,
            toc_lines.index("MSBTProfiles.lua"),
        )


if __name__ == "__main__":
    unittest.main()
