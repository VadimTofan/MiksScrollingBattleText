import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
INCOMING_FILE = REPOSITORY_ROOT / "Components" / "IncomingCombat.lua"


# Describe: incoming combat event name suppression
class IncomingNameSuppressionTests(unittest.TestCase):
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
