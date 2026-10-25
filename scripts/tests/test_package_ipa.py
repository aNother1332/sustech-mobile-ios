"""Boundary tests with synthetic Mach-O headers; no actual Apple binary included."""
import hashlib
import importlib.util
import plistlib
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "package_ipa.py"
SPEC = importlib.util.spec_from_file_location("package_ipa", MODULE_PATH)
packager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packager)


class IPATests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "SUSTech.app"
        self.app.mkdir()
        self.info = {
            "CFBundleExecutable": "SUSTech", "CFBundleIdentifier": "cn.example.test",
            "CFBundleSupportedPlatforms": ["iPhoneOS"], "MinimumOSVersion": "17.0",
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
        }
        self.write_info()
        self.write_binary(platform=2)
        self.output = self.root / "dist/test.ipa"

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def write_binary(self, platform):
        header = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 24, 0, 0)
        command = struct.pack("<6I", 0x32, 24, platform, 17 << 16, 26 << 16, 0)
        executable = self.app / "SUSTech"
        executable.write_bytes(header + command)
        executable.chmod(0o755)

    def test_device_payload_and_checksum(self):
        metadata = packager.package(self.app, self.output, "test-commit")
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(set(archive.namelist()), {"Payload/SUSTech.app/Info.plist", "Payload/SUSTech.app/SUSTech"})
        self.assertEqual(metadata["sha256"], hashlib.sha256(self.output.read_bytes()).hexdigest())
        self.assertEqual(metadata["commit"], "test-commit")
        self.assertTrue(self.output.with_suffix(".sha256").is_file())

    def test_arm64_simulator_is_rejected_even_with_device_plist(self):
        self.write_binary(platform=7)
        with self.assertRaisesRegex(ValueError, "not an iOS device"):
            packager.package(self.app, self.output)
        self.assertFalse(self.output.exists())

    def test_simulator_plist_is_rejected(self):
        self.info["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.write_info()
        with self.assertRaisesRegex(ValueError, "iPhoneOS"):
            packager.package(self.app, self.output)

    def test_truncated_binary_is_rejected(self):
        (self.app / "SUSTech").write_bytes(b"invalid")
        with self.assertRaisesRegex(ValueError, "header"):
            packager.package(self.app, self.output)

    def test_executable_cannot_escape_bundle(self):
        self.info["CFBundleExecutable"] = "../another-app"
        self.write_info()
        with self.assertRaisesRegex(ValueError, "CFBundleExecutable"):
            packager.package(self.app, self.output)

    def test_output_cannot_be_packaged_into_itself(self):
        with self.assertRaisesRegex(ValueError, "inside"):
            packager.package(self.app, self.app / "recursive.ipa")

    def test_standard_package_excludes_optional_share_extension(self):
        extension = self.app / "PlugIns/CampusPrintShare.appex"
        extension.mkdir(parents=True)
        (extension / "marker").write_bytes(b"extension")
        metadata = packager.package(self.app, self.output, include_extensions=False)
        with zipfile.ZipFile(self.output) as archive:
            self.assertFalse(any("PlugIns" in name for name in archive.namelist()))
        self.assertFalse(metadata["share_extension"])

    def test_existing_ipa_is_not_overwritten(self):
        self.output.parent.mkdir()
        self.output.write_bytes(b"keep")
        with self.assertRaises(FileExistsError):
            packager.package(self.app, self.output)
        self.assertEqual(self.output.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()
