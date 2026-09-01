import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
TOC_FILE = REPOSITORY_ROOT / "MikScrollingBattleText.toc"


# Describe: animation component packaging
class AnimationComponentIntegrationTests(unittest.TestCase):
    def test_animation_engine_and_styles_are_display_components(self):
        # Given
        toc_lines = TOC_FILE.read_text(encoding="utf-8-sig").splitlines()

        # When / Then
        engine_index = toc_lines.index("Display\\AnimationEngine.lua")
        styles_index = toc_lines.index("Display\\AnimationStyles.lua")
        self.assertLess(engine_index, styles_index)
        self.assertNotIn("MSBTAnimations.lua", toc_lines)
        self.assertNotIn("MSBTAnimationStyles.lua", toc_lines)

    def test_animation_engine_preserves_the_public_module(self):
        # Given
        engine_file = REPOSITORY_ROOT / "Display" / "AnimationEngine.lua"

        # When
        source = engine_file.read_text(encoding="utf-8-sig")

        # Then
        self.assertIn('local moduleName = "Animations"', source)
        self.assertIn("MikSBT[moduleName] = module", source)

    def test_api_documentation_uses_the_component_style_path(self):
        # Given
        api_file = REPOSITORY_ROOT / "API.html"

        # When
        source = api_file.read_text(encoding="utf-8-sig")

        # Then
        self.assertIn("Display/AnimationStyles.lua", source)
        self.assertNotIn("MSBTAnimationStyles.lua", source)


if __name__ == "__main__":
    unittest.main()
