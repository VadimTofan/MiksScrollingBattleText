import unittest
from pathlib import Path

from tests.lua_test_runner import run_lua_test


# Describe: verified Forever metadata precedes optional description facts.
class SpellCatalogTests(unittest.TestCase):
    def test_production_manifests_load_catalog_before_spell_facts(self):
        # Given both supported addon manifests and the shipped attribution.
        root = Path(__file__).resolve().parents[1]
        manifests = (
            "MikScrollingBattleText.toc",
            "MikScrollingBattleText_Camelot.toc",
        )

        # When their runtime file order and license are read.
        for name in manifests:
            files = (root / name).read_text(encoding="utf-8").splitlines()

            # Then the catalog exists before either attribution consumer.
            self.assertLess(
                files.index("Combat\\SpellCatalog.lua"),
                files.index("Combat\\Mine.lua"),
            )
            self.assertLess(
                files.index("Combat\\SpellCatalog.lua"),
                files.index("Combat\\Spells.lua"),
            )
        license_text = (
            root / "Combat/LICENSE-NameplateSCTReforged"
        ).read_text(encoding="utf-8")
        self.assertIn("Copyright (c) 2020 Justwait", license_text)
        self.assertIn("Copyright (c) 2026 KidMoxie", license_text)
        self.assertIn("THE SOFTWARE IS PROVIDED", license_text)

    def test_verified_facts_keep_build_boundaries_and_tooltip_fallback(self):
        # Given known spells, an unknown bleed, and multiple client contexts.
        script = "spell_catalog.lua"

        # When the real catalog and spell facts are loaded together.
        result = run_lua_test(script)

        # Then authoritative facts survive without losing fallback behavior.
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
