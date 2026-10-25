"""Package an unsigned arm64 iOS device app for local re-signing.

Does not sign, export provisioning profiles or contact Apple. A simulator .app
is rejected, even on Apple silicon where it also has an arm64 executable.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import struct
import zipfile
from pathlib import Path

MH_MAGIC_64 = 0xFEEDFACF
CPU_TYPE_ARM64 = 0x0100000C
MH_EXECUTE = 2
LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2


def device_binary(path: Path) -> None:
    data = path.read_bytes()
    if len(data) < 32:
        raise ValueError("Executable has no complete Mach-O header")
    magic, cpu, _, kind, count, commands_size, _, _ = struct.unpack_from("<8I", data)
    if (magic, cpu, kind) != (MH_MAGIC_64, CPU_TYPE_ARM64, MH_EXECUTE):
        raise ValueError("Expected a thin arm64 Mach-O executable for an iOS device")
    if 32 + commands_size > len(data):
        raise ValueError("Mach-O load commands are truncated")
    cursor = 32
    platforms = []
    for _ in range(count):
        if cursor + 8 > 32 + commands_size:
            raise ValueError("Incomplete Mach-O load command")
        command, size = struct.unpack_from("<2I", data, cursor)
        if size < 8 or cursor + size > 32 + commands_size:
            raise ValueError("Invalid Mach-O load command size")
        if command == LC_BUILD_VERSION:
            if size < 24:
                raise ValueError("Incomplete LC_BUILD_VERSION")
            platforms.append(struct.unpack_from("<I", data, cursor + 8)[0])
        cursor += size
    if platforms != [PLATFORM_IOS]:
        raise ValueError("Executable is not an iOS device build (simulator apps cannot be sideloaded)")


def package(app: Path, output: Path, commit: str = "local", include_extensions: bool = True) -> dict:
    app = app.resolve(strict=True)
    if not app.is_dir() or app.suffix != ".app":
        raise ValueError("--app must be an existing .app directory")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    executable = info.get("CFBundleExecutable", "")
    if not executable or Path(executable).name != executable or "\\" in executable:
        raise ValueError("Invalid CFBundleExecutable")
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise ValueError("Info.plist must identify an iPhoneOS device build")
    if not info.get("CFBundleIdentifier"):
        raise ValueError("Missing bundle identifier")
    files = sorted(app.rglob("*"))
    if any(path.is_symlink() for path in files):
        raise ValueError("This packager requires a flat iOS app bundle without symbolic links")
    device_binary(app / executable)
    output = output.resolve()
    if output.is_relative_to(app):
        raise ValueError("Output must not be inside the app bundle")
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            if path.is_file() and (include_extensions or "PlugIns" not in path.relative_to(app).parts):
                archive.write(path, (Path("Payload") / app.name / path.relative_to(app)).as_posix())
    metadata = {
        "file": output.name,
        "share_extension": include_extensions and (app / "PlugIns").exists(),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "commit": commit,
        "bundle_identifier": info["CFBundleIdentifier"],
        "version": info.get("CFBundleShortVersionString"),
        "build": info.get("CFBundleVersion"),
        "minimum_os": info.get("MinimumOSVersion"),
        "architecture": "arm64",
        "platform": "iOS device",
        "signing": "unsigned; local re-signing required before installation",
    }
    output.with_suffix(".sha256").write_text(f"{metadata['sha256']}  {output.name}\n", encoding="utf-8")
    output.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--without-extensions", action="store_true")
    parser.add_argument("--commit", default="local")
    args = parser.parse_args()
    print(json.dumps(package(args.app, args.output, args.commit, not args.without_extensions), ensure_ascii=False, indent=2))
