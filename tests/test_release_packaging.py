import os
import posixpath
import tempfile
import unittest
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree
from zipfile import ZipFile


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ADDON_NAME = "MikScrollingBattleText"
ARTWORK_NAMES = {
    "PlainBackdrop",
    "ConfigureIcon", "ConfigureIconDisable", "ConfigureIconHighlight",
    "DeleteIcon", "DeleteIconDisable", "DeleteIconHighlight",
    "FontSettingsIcon", "FontSettingsIconDisable", "FontSettingsIconHighlight",
}
DEVELOPMENT_DIRECTORIES = {
    "tests", "scripts", "dist", "docs", "skills", "Sounds", "Diagnostics",
    "__pycache__",
}


def assert_runtime_archive(test: unittest.TestCase, archive: ZipFile) -> set[str]:
    """Inspect an archive without recreating the packager or its ignore logic."""
    test.assertIsNone(archive.testzip())
    paths = [entry.filename for entry in archive.infolist() if not entry.is_dir()]
    test.assertEqual(len(paths), len(set(paths)), "Duplicate ZIP entries")
    files = set()
    for path in paths:
        test.assertTrue(path.startswith(f"{ADDON_NAME}/"), path)
        relative = path.removeprefix(f"{ADDON_NAME}/")
        parts = PurePosixPath(relative).parts
        test.assertFalse(any(part.startswith(".") for part in parts), path)
        test.assertNotIn(parts[0], DEVELOPMENT_DIRECTORIES, path)
        files.add(relative)

    # TOCs and nested XML includes must retain every loaded dependency.
    pending = [f"{ADDON_NAME}.toc", "MSBTOptions/MSBTOptions.toc"]
    loaded = set()
    while pending:
        path = posixpath.normpath(pending.pop())
        test.assertFalse(path.startswith(("../", "/")), path)
        test.assertIn(path, files, f"Missing runtime dependency: {path}")
        if path in loaded:
            continue
        loaded.add(path)
        dependencies = []
        suffix = PurePosixPath(path).suffix.lower()
        if suffix == ".toc":
            text = archive.read(f"{ADDON_NAME}/{path}").decode("utf-8-sig")
            dependencies = [
                line.strip() for line in text.splitlines()
                if line.strip() and not line.lstrip().startswith("#")
            ]
        elif suffix == ".xml":
            xml = ElementTree.fromstring(archive.read(f"{ADDON_NAME}/{path}"))
            dependencies = [
                element.attrib["file"] for element in xml.iter()
                if element.tag.rsplit("}", 1)[-1] in {"Include", "Script"}
                and element.get("file")
            ]
        for dependency in dependencies:
            pending.append(posixpath.join(
                posixpath.dirname(path), dependency.replace("\\", "/"),
            ))

    for name in files - loaded:
        path = PurePosixPath(name)
        is_font = path.parts[0] == "Fonts" and path.suffix in {".ttf", ".otf"}
        is_artwork = (
            path.parent == PurePosixPath("MSBTOptions/Artwork")
            and path.stem in ARTWORK_NAMES
            and path.suffix in {".blp", ".tga", ".dds"}
        )
        is_license = any(
            path.name.lower() == stem
            or path.name.lower().startswith((stem + ".", stem + "-"))
            for stem in ("license", "licence", "copying", "notice", "copyright", "ofl")
        )
        test.assertTrue(is_font or is_artwork or is_license,
                        f"Unexpected packaged file: {name}")
    return files


# Describe: packaging configuration and the read-only release archive gate.
class ReleasePackagingTests(unittest.TestCase):
    def setUp(self):
        self.runtime = {
            f"{ADDON_NAME}.toc": "\ufeff## Interface: 120100\nMain.lua\nLocale\\main.xml\n",
            "Main.lua": "-- Runtime\n",
            "Locale/main.xml": (
                '<Ui xmlns="http://www.blizzard.com/wow/ui/">'
                '<Include file="nested/more.xml"/></Ui>'
            ),
            "Locale/nested/more.xml": (
                '<Ui><Script file="../english.lua"/>'
                '<Include file="../main.xml"/></Ui>'
            ),
            "Locale/english.lua": "-- Locale\n",
            "MSBTOptions/MSBTOptions.toc": "Options.lua\n",
            "MSBTOptions/Options.lua": "-- Options\n",
            "Fonts/font.ttf": "Font bytes",
            "MSBTOptions/Artwork/ConfigureIcon.blp": "Texture bytes",
            "LICENSE": "Project license",
            "Libs/LICENSE.txt": "Library license",
            "Fonts/OFL.txt": "Font license",
        }

    def inspect_fixture(self, files):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.zip"
            with ZipFile(path, "w") as archive:
                for name, contents in files.items():
                    archive.writestr(f"{ADDON_NAME}/{name}", contents)
            with ZipFile(path) as archive:
                return assert_runtime_archive(self, archive)

    def test_pkgmeta_owns_release_exclusions(self):
        # Given
        path = REPOSITORY_ROOT / ".pkgmeta"

        # When / Then
        self.assertTrue(path.is_file(), "Release exclusions must live in .pkgmeta")
        pkgmeta = path.read_text(encoding="utf-8")
        self.assertIn(f"package-as: {ADDON_NAME}", pkgmeta)
        self.assertIn("manual-changelog:", pkgmeta)
        for excluded in (
            "tests", "scripts", ".github", ".vscode", ".agents", ".codex",
            ".release", "dist", "Sounds", "README.md", "CHANGELOG.md",
            "API.html", "Research.md",
            "MSBTOptions/Artwork/TriggerSettingsIcon*",
        ):
            self.assertIn(f"  - {excluded}\n", pkgmeta)

    def test_workflow_builds_with_bigwigs_then_checks_before_upload(self):
        # Given
        workflow_path = REPOSITORY_ROOT / ".github/workflows/curseforge-release.yml"

        # When
        workflow = workflow_path.read_text(encoding="utf-8")

        # Then
        self.assertIn("uses: BigWigsMods/packager@v2", workflow)
        self.assertIn("args: -d -e -l", workflow)
        self.assertIn("fetch-depth: 0", workflow)
        self.assertIn("MSBT_RELEASE_ZIP:", workflow)
        self.assertIn("python -m unittest tests.test_release_packaging", workflow)
        self.assertLess(workflow.index("uses: BigWigsMods/packager@v2"),
                        workflow.index("- name: Verify packaged archive"))
        self.assertLess(workflow.index("- name: Verify packaged archive"),
                        workflow.index("- name: Upload release zip to CurseForge"))
        self.assertNotIn("build_release_package.py", workflow)
        self.assertFalse((REPOSITORY_ROOT / "scripts/build_release_package.py").exists())

    def test_archive_gate_accepts_dependencies_media_and_license_notices(self):
        # Given
        files = self.runtime

        # When
        packaged = self.inspect_fixture(files)

        # Then
        self.assertEqual(packaged, set(files))

    def test_archive_gate_rejects_development_and_obsolete_files(self):
        # Given
        for unwanted in (
            "README.md", "CHANGELOG.md", "API.html", "Research.md",
            "tests/test.lua", "scripts/build.py", ".pkgmeta", ".git/config",
            ".github/workflows/release.yml", ".vscode/settings.json",
            "Main.lua.bak", "Unused.lua", "Sounds/personal.ogg",
            "Fonts/.DS_Store", "Fonts/Thumbs.db", "Fonts/font.ttf.bak",
            "MSBTOptions/Artwork/TriggerSettingsIcon.blp",
        ):
            with self.subTest(path=unwanted):
                files = self.runtime | {unwanted: "Not for release"}

                # When / Then
                with self.assertRaises(AssertionError):
                    self.inspect_fixture(files)

    def test_archive_gate_rejects_missing_xml_dependencies(self):
        # Given
        files = dict(self.runtime)
        del files["Locale/english.lua"]

        # When / Then
        with self.assertRaisesRegex(AssertionError, "Missing runtime dependency"):
            self.inspect_fixture(files)

    @unittest.skipUnless(os.environ.get("MSBT_RELEASE_ZIP"),
                         "Actual archive is checked after BigWigs builds it in CI")
    def test_bigwigs_release_archive(self):
        # Given: the real ZIP that the workflow is about to upload.
        archive_path = Path(os.environ["MSBT_RELEASE_ZIP"])

        # When
        with ZipFile(archive_path) as archive:
            files = assert_runtime_archive(self, archive)

            # Then: newly restored sounds and binary assets are retained.
            self.assertIn("API/Sounds.lua", files)
            self.assertIn("MSBTOptions/MSBTOptionsSounds.lua", files)
            assets = list((REPOSITORY_ROOT / "Fonts").glob("*.ttf"))
            assets += [
                path for path in (REPOSITORY_ROOT / "MSBTOptions/Artwork").glob("*.blp")
                if path.stem in ARTWORK_NAMES
            ]
            for path in assets:
                relative = path.relative_to(REPOSITORY_ROOT).as_posix()
                self.assertIn(relative, files)
                self.assertEqual(archive.read(f"{ADDON_NAME}/{relative}"),
                                 path.read_bytes())


if __name__ == "__main__":
    unittest.main()
