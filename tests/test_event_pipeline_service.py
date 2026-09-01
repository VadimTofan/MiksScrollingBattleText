import unittest

from tests.lua_test_runner import run_lua_test


# Describe: queued event delivery pipeline
class EventPipelineServiceTests(unittest.TestCase):
    def test_pipeline_batches_formats_displays_and_recycles_events(self):
        # Given
        script_name = "event_pipeline_service.lua"

        # When
        result = run_lua_test(script_name)

        # Then
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)


if __name__ == "__main__":
    unittest.main()
