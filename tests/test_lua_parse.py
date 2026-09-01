import subprocess
import tempfile
import unittest
from pathlib import Path

from tests.lua_test_runner import REPOSITORY_ROOT, find_luac_51


# Describe: packaged Lua compatibility
class LuaParseTests(unittest.TestCase):
    def test_all_packaged_lua_files_parse_with_lua_51(self):
        # Given
        lua_files = sorted(
            path
            for path in REPOSITORY_ROOT.rglob("*.lua")
            if "tests" not in path.parts and "scripts" not in path.parts
        )

        # When
        failures = []
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_root = Path(temporary_directory)

            for index, lua_file in enumerate(lua_files):
                source = lua_file.read_bytes()
                if source.startswith(b"\xef\xbb\xbf"):
                    source = source[3:]

                parse_file = temporary_root / f"{index}.lua"
                parse_file.write_bytes(source)
                result = subprocess.run(
                    [find_luac_51(), "-p", str(parse_file)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if result.returncode != 0:
                    relative_path = lua_file.relative_to(REPOSITORY_ROOT)
                    message = result.stderr or result.stdout
                    failures.append(f"{relative_path}: {message}")

        # Then
        self.assertTrue(lua_files, "no packaged Lua files were found")
        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
