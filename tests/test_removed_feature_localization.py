import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCALIZATION = ROOT / "MSBTOptions" / "Localization"


class RemovedFeatureLocalizationTests(unittest.TestCase):
    def test_unreachable_editors_leave_no_translation_tables_or_artwork(self):
        # Given translations and artwork previously used by removed editors.
        sources = list(LOCALIZATION.glob("*.lua"))
        unused_keys = (
            "L.TRIGGER_DATA", "L.MSG_NEW_TRIGGER", "L.MSG_TRIGGER_CLASSES",
            "L.MSG_MAIN_EVENTS", "L.MSG_TRIGGER_EXCEPTIONS",
            "L.MSG_EVENT_CONDITIONS", "L.MSG_SKILLS",
            '["triggerCondition"]', '["addMainEvent"]', '["addSkill"]',
        )

        # When inspecting all translated editor resources.
        for path in sources:
            source = path.read_text(encoding="utf-8-sig")

            # Then translations for unreachable editors are absent.
            for key in unused_keys:
                self.assertTrue(key not in source, path.name + ": " + key)
        self.assertEqual(
            list((ROOT / "MSBTOptions/Artwork").glob("TriggerSettingsIcon*.blp")),
            [],
        )

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
