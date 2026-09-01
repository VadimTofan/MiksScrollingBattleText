import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_FILE = REPOSITORY_ROOT / ".github" / "workflows" / "validate.yml"


# Describe: pull-request validation workflow
class ValidationWorkflowTests(unittest.TestCase):
    def test_workflow_runs_python_tests_with_lua_51(self):
        # Given
        expected_commands = [
            "sudo apt-get install --yes lua5.1",
            'python -m unittest discover -s tests -p "test_*.py"',
        ]

        # When
        workflow = WORKFLOW_FILE.read_text(encoding="utf-8")

        # Then
        self.assertIn("pull_request:", workflow)
        for command in expected_commands:
            self.assertIn(command, workflow)


if __name__ == "__main__":
    unittest.main()
