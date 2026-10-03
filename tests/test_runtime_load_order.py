import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test

ROOT = Path(__file__).resolve().parents[1]


# Describe: shipped addon files load after their runtime dependencies.
class RuntimeLoadOrderTests(unittest.TestCase):
    def test_actual_bootstrap_initializes_active_namespaces_without_framework(self):
        # Given the real addon namespace with no pre-created test tables.
        script_name = "runtime_bootstrap.lua"

        # When configuration, API and display modules load.
        result = run_lua_test(script_name)

        # Then they initialize without the retired component registry.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_both_clients_load_namespace_and_facade_before_consumers(self):
        # Given the retail and Camelot manifests.
        for manifest in ROOT.glob("MikScrollingBattleText*.toc"):
            lines = [
                line.strip().replace("\\", "/")
                for line in manifest.read_text(encoding="utf-8-sig").splitlines()
                if line.strip() and not line.startswith("##")
            ]

            # When resolving namespace and API initialization order.
            namespace = lines.index("MikSBT.lua")
            facade = lines.index("Compatibility/LegacyAPI.lua")
            profile = lines.index("MSBTProfiles.lua")

            # Then every entry exists and API consumers load afterward.
            self.assertEqual(lines[namespace + 1], "Compatibility/Client.lua")
            self.assertLess(namespace, lines.index("API/RestrictedValue.lua"))
            self.assertLess(lines.index("API/Cooldowns.lua"), facade)
            self.assertLess(facade, profile)
            for relative in lines:
                self.assertTrue((ROOT / relative).is_file(), relative)


if __name__ == "__main__":
    unittest.main()
