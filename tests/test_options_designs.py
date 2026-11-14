import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test

ROOT = Path(__file__).resolve().parents[1]


# Describe: the options window comes in designs, chosen in the General tab.
class OptionsDesignsTests(unittest.TestCase):
    def test_designs_are_chosen_and_open_one_at_a_time(self):
        # Given
        script = "options_designs.lua"

        # When
        result = run_lua_test(script)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_registry_loads_before_the_classic_window(self):
        # Given
        manifests = {
            "MikScrollingBattleText.toc": "MSBTOptions\\",
            "MikScrollingBattleText_Camelot.toc": "MSBTOptions\\",
            "MSBTOptions/MSBTOptions.toc": "",
        }

        for name, prefix in manifests.items():
            with self.subTest(manifest=name):
                # When
                lines = (ROOT / name).read_text(encoding="utf-8-sig").splitlines()

                # Then
                self.assertLess(
                    lines.index(prefix + "MSBTOptionsDesigns.lua"),
                    lines.index(prefix + "MSBTOptionsMain.lua"),
                )
