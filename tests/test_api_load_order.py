import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: API adapter runtime load order
class ApiLoadOrderTests(unittest.TestCase):
    def test_api_adapters_load_before_legacy_modules(self):
        # Given
        toc_lines = [
            line.strip()
            for line in TOC_FILE.read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.startswith("##")
        ]
        expected_api = [
            "API\\RestrictedValue.lua",
            "API\\Spells.lua",
            "API\\Units.lua",
            "API\\Combat.lua",
            "API\\Cooldowns.lua",
            "API\\BlizzardCombatText.lua",
            "Compatibility\\LegacyAPI.lua",
        ]

        # When
        api_index = toc_lines.index("API\\RestrictedValue.lua")
        api_lines = toc_lines[api_index : api_index + len(expected_api)]

        # Then
        self.assertEqual(api_lines, expected_api)
        self.assertLess(
            toc_lines.index("Compatibility\\LegacyAPI.lua"),
            toc_lines.index("MSBTProfiles.lua"),
        )


if __name__ == "__main__":
    unittest.main()
