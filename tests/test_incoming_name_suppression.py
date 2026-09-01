import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MAIN_FILE = REPOSITORY_ROOT / "MSBTMain.lua"
PIPELINE_FILE = REPOSITORY_ROOT / "Services" / "EventPipeline.lua"
INCOMING_FILE = REPOSITORY_ROOT / "Components" / "IncomingCombat.lua"


# Describe: incoming combat event name suppression
class IncomingNameSuppressionTests(unittest.TestCase):
    def test_incoming_damage_and_healing_force_name_hiding(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8")
        handler_start = source.index("local function ParserEventsHandler")
        handler_end = source.index("local function OnUpdateEventFrame", handler_start)

        # When
        parser_handler = source[handler_start:handler_end]
        incoming_name_guard = (
            'local hideIncomingNames = (eventType == "damage" '
            'or eventType == "heal")'
        )

        # Then
        self.assertIn(incoming_name_guard, parser_handler)
        self.assertIn("hideIncomingNames, true)", parser_handler)

    def test_merged_incoming_events_keep_name_hiding(self):
        # Given
        source = MAIN_FILE.read_text(encoding="utf-8")
        pipeline_source = PIPELINE_FILE.read_text(encoding="utf-8")

        # When
        stored_name_setting = "combatEvent.hideNames = hideIncomingNames"
        merged_name_setting = "profile.hideNames or event.hideNames"

        # Then
        self.assertIn(stored_name_setting, source)
        self.assertIn(merged_name_setting, pipeline_source)

    def test_unit_combat_healing_does_not_append_guessed_source_name(self):
        # Given
        source = INCOMING_FILE.read_text(encoding="utf-8")

        # When
        incoming_heal_batch = source

        # Then
        self.assertNotIn(
            'string_format("%s - %s", critMessageOnly, queued.sourceName)',
            incoming_heal_batch,
        )
        self.assertNotIn(
            'string_format("%s - %s", nonCritMessage, queued.sourceName)',
            incoming_heal_batch,
        )
        self.assertNotIn(
            'string_format("%s - %s", critMessage, queued.sourceName)',
            incoming_heal_batch,
        )
        self.assertNotIn(
            'string_format("%s - %s", message, queued.sourceName)',
            incoming_heal_batch,
        )


if __name__ == "__main__":
    unittest.main()
