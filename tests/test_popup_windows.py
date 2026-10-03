import unittest

from tests.lua_test_runner import run_lua_test


# Describe: menu-styled popup windows preserve their existing actions.
class PopupWindowTests(unittest.TestCase):
    def test_popup_headers_layering_and_actions(self):
        # Given
        script_name = "popup_windows.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
