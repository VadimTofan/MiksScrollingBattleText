import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test

ROOT = Path(__file__).resolve().parents[1]


# Describe: the new options window, its page host and its change tracking.
class OptionsWindowTests(unittest.TestCase):
    def test_manifests_list_the_design_files_in_their_folder(self):
        # Given
        manifests = {
            "MikScrollingBattleText.toc": "",
            "MikScrollingBattleText_Camelot.toc": "",
            "MSBTOptions/MSBTOptions.toc": "MSBTOptions/",
        }

        for name, folder in manifests.items():
            with self.subTest(manifest=name):
                # When
                lines = (ROOT / name).read_text(encoding="utf-8-sig").splitlines()
                listed = [line.strip().replace("\\", "/") for line in lines if "Designs\\Forever\\" in line]

                # Then
                self.assertEqual(len(listed), 4)
                for path in listed:
                    self.assertTrue((ROOT / folder / path).is_file(), path)

    def test_window_hosts_pages_and_tracks_changes(self):
        # Given
        script_name = "options_window.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
