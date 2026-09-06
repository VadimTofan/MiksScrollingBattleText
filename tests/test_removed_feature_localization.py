import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCALIZATION = ROOT / "MSBTOptions" / "Localization"


class RemovedFeatureLocalizationTests(unittest.TestCase):
    def test_removed_legacy_features_are_not_localized(self):
        # Given
        removed_keys = (
            "L.SOUNDS",
            "MSG_CUSTOM_SOUNDS",
            '["cooldowns"]',
            '["enablePlayerCooldowns"]',
            '["enablePetCooldowns"]',
            '["enableItemCooldowns"]',
            '["cooldownExclusions"]',
            '["ignoreCooldownThreshold"]',
            '["cooldownThreshold"]',
            '["ITEM_COOLDOWN_NAME"]',
            '["SKILL_COOLDOWN"]',
            '["PET_COOLDOWN"]',
            '["ITEM_COOLDOWN"]',
            "obj = L.SOUNDS",
            '["MSBT Low Mana"]',
            '["MSBT Low Health"]',
            '["MSBT Cooldown"]',
            '["customMedia"]',
            '["triggers"]',
            '["spamControl"]',
            '["skillIcons"]',
            '["enableBlizzardDamage"]',
            '["enableBlizzardHealing"]',
            '["textShadowing"]',
            '["exclusiveSkills"]',
            '["addCustomFont"]',
            '["editCustomFont"]',
            '["deleteCustomFont"]',
            '["editCustomSound"]',
            '["deleteCustomSound"]',
            '["customFontName"]',
            '["customFontPath"]',
            '["COOLDOWN_NAME"]',
            "MSG_CUSTOM_FONTS",
            "MSG_INVALID_CUSTOM_FONT_NAME",
            "MSG_FONT_NAME_ALREADY_EXISTS",
            "MSG_INVALID_CUSTOM_FONT_PATH",
            "MSG_UNABLE_TO_SET_FONT",
            "MSG_TESTING_FONT",
        )

        # When
        sources = {
            path.name: path.read_text(encoding="utf-8-sig")
            for path in LOCALIZATION.glob("*.lua")
        }

        # Then
        for filename, source in sources.items():
            for key in removed_keys:
                self.assertNotIn(key, source, f"{filename}: {key}")


if __name__ == "__main__":
    unittest.main()
