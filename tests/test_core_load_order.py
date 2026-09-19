import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: core runtime load order
class CoreLoadOrderTests(unittest.TestCase):
    def test_core_loads_after_namespace_and_before_legacy_modules(self):
        # Given
        toc_lines = [
            line.strip()
            for line in TOC_FILE.read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.startswith("##")
        ]
        expected_core = [
            "Core\\Diagnostics.lua",
            "Core\\EventBus.lua",
            "Core\\ComponentRegistry.lua",
            "Core\\Addon.lua",
        ]

        # When
        namespace_index = toc_lines.index("MikSBT.lua")
        compatibility_line = toc_lines[namespace_index + 1]
        core_lines = toc_lines[namespace_index + 2 : namespace_index + 6]

        # Then
        self.assertEqual(compatibility_line, "Compatibility\\Client.lua")
        self.assertEqual(core_lines, expected_core)
        self.assertLess(
            toc_lines.index("Core\\Addon.lua"),
            toc_lines.index("MSBTProfiles.lua"),
        )


if __name__ == "__main__":
    unittest.main()
