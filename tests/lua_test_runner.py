import os
import shutil
import subprocess
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


def find_lua_51():
    configured_path = os.environ.get("LUA51")
    candidates = [
        configured_path,
        shutil.which("lua5.1"),
        shutil.which("lua51"),
        shutil.which("lua"),
        Path(os.environ.get("TEMP", ""))
        / "lua515-msbt-check"
        / "lua5.1.exe",
    ]

    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)

    raise RuntimeError("Lua 5.1 was not found; set LUA51 to its executable")


def find_luac_51():
    configured_path = os.environ.get("LUAC51")
    candidates = [
        configured_path,
        shutil.which("luac5.1"),
        shutil.which("luac51"),
        shutil.which("luac"),
        Path(os.environ.get("TEMP", ""))
        / "lua515-msbt-check"
        / "luac5.1.exe",
    ]

    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)

    raise RuntimeError("Lua 5.1 compiler was not found; set LUAC51 to its executable")


def run_lua_test(script_name):
    script_path = REPOSITORY_ROOT / "tests" / "lua" / script_name

    return subprocess.run(
        [find_lua_51(), str(script_path)],
        cwd=REPOSITORY_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
