import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PRIMARY_TOC = REPOSITORY_ROOT / "MikScrollingBattleText.toc"
FOREVER_TOC = REPOSITORY_ROOT / "MikScrollingBattleText_Camelot.toc"


def runtime_files(toc_path):
    return [
        line.strip()
        for line in toc_path.read_text(encoding="utf-8-sig").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


# Describe: WoW Forever addon metadata and client classification
class ForeverCompatibilityTests(unittest.TestCase):
    def test_camelot_toc_targets_forever_with_primary_runtime_load_order(self):
        # Given
        primary_files = runtime_files(PRIMARY_TOC)

        # When
        forever_text = FOREVER_TOC.read_text(encoding="utf-8-sig")
        forever_files = runtime_files(FOREVER_TOC)

        # Then
        self.assertIn("## Interface: 16001", forever_text)
        self.assertEqual(forever_files, primary_files)

    def test_client_module_classifies_forever_as_modern_vanilla_content(self):
        # Given
        script_name = "client_compatibility.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_runtime_modules_use_explicit_client_classification(self):
        # Given
        expected_checks = {
            "MSBTProfiles.lua": (
                "Client.isClassicContent",
                "Client.isCataClassic",
            ),
            "MSBTMain.lua": (
                "Client.isMainline",
                "Client.isForever",
            ),
            "MSBTParser.lua": (
                "Client.isMainline",
            ),
            "MSBTOptions/MSBTOptionsPopups.lua": (
                "Client.isCataClassic",
                "Client.isVanillaContent",
            ),
        }

        # When / Then
        for relative_path, checks in expected_checks.items():
            with self.subTest(path=relative_path):
                source = (REPOSITORY_ROOT / relative_path).read_text(
                    encoding="utf-8-sig"
                )
                self.assertNotIn("WOW_PROJECT_ID", source)
                for check in checks:
                    self.assertIn(check, source)

    def test_forever_uses_modern_option_widget_paths(self):
        # Given
        option_files = (
            "MSBTOptions/MSBTOptionsMain.lua",
            "MSBTOptions/MSBTOptionsControls.lua",
        )

        # When / Then
        for relative_path in option_files:
            with self.subTest(path=relative_path):
                source = (REPOSITORY_ROOT / relative_path).read_text(
                    encoding="utf-8-sig"
                )
                self.assertIn("Client.hasModernAPI", source)
                self.assertNotIn("WOW_PROJECT_ID", source)


if __name__ == "__main__":
    unittest.main()
