"""Check project consistency, fixtures and optionally Swift syntax on Windows.

Default: standard library only. --syntax additionally needs tree-sitter,
tree-sitter-swift and openstep-parser. This is NOT a Swift typecheck or iOS build.
"""
from __future__ import annotations

import argparse
import json
import plistlib
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def verify_project() -> None:
    generated = [ROOT / "SUSTech.xcodeproj/project.pbxproj",
                 ROOT / "SUSTech.xcodeproj/xcshareddata/xcschemes/SUSTech.xcscheme"]
    before = {path: path.read_bytes() for path in generated}
    subprocess.run([sys.executable, str(ROOT / "scripts/generate_project.py")], check=True)
    for path in generated:
        if before[path] != path.read_bytes():
            raise RuntimeError(f"Generated file was stale: {path.relative_to(ROOT)}; review and rerun checks.")
    info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
    assert "NSAppTransportSecurity" not in info, "Do not silently disable HTTPS requirements"
    privacy = plistlib.loads((ROOT / "App/Resources/PrivacyInfo.xcprivacy").read_bytes())
    assert privacy["NSPrivacyTracking"] is False
    scheme = ET.parse(generated[1]).getroot()
    assert scheme.find("BuildAction/BuildActionEntries/BuildActionEntry/BuildableReference") is not None
    for path in (ROOT / "Tests/CampusCoreTests/Fixtures").glob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))
    assert (ROOT / "LICENSE").read_bytes() == (ROOT / "App/Resources/UpstreamLicense.txt").read_bytes()
    print("PASS: deterministic project, plists, scheme, JSON fixtures, bundled license")


def verify_syntax() -> None:
    from openstep_parser import OpenStepDecoder
    import tree_sitter
    import tree_sitter_swift

    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
    errors = []
    paths = [ROOT / "Package.swift"]
    for directory in ("App", "Sources", "Tests"):
        paths.extend(sorted((ROOT / directory).rglob("*.swift")))
    for path in paths:
        root = parser.parse(path.read_bytes()).root_node
        if root.has_error:
            stack = [root]
            while stack:
                node = stack.pop()
                if node.type == "ERROR" or node.is_missing:
                    errors.append(f"{path.relative_to(ROOT)}:{node.start_point.row + 1}:{node.start_point.column + 1}: {node.type}")
                stack.extend(reversed(node.children))
    if errors:
        raise RuntimeError("Swift syntax errors:\n" + "\n".join(errors))
    document = OpenStepDecoder.ParseFromString((ROOT / "SUSTech.xcodeproj/project.pbxproj").read_text(encoding="utf-8"))
    objects = document["objects"]
    assert document["rootObject"] in objects
    for value in objects.values():
        for key in ("mainGroup", "productRefGroup", "buildConfigurationList", "productReference", "fileRef", "productRef", "package"):
            if key in value:
                assert value[key] in objects, f"Dangling {key}: {value[key]}"
        for key in ("children", "files", "targets", "buildPhases", "buildConfigurations", "packageReferences", "packageProductDependencies"):
            for reference in value.get(key, []):
                assert reference in objects, f"Dangling {key}: {reference}"
        if value["isa"] == "PBXFileReference" and value.get("sourceTree") == "SOURCE_ROOT":
            assert (ROOT / value["path"]).is_file(), value["path"]
    print(f"PASS: {len(paths)} Swift syntax trees and Xcode project object references")


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser(description=__doc__)
    argument_parser.add_argument("--syntax", action="store_true")
    arguments = argument_parser.parse_args()
    verify_project()
    if arguments.syntax:
        verify_syntax()
    print("NOTE: Swift typechecking, tests and iOS builds must run with a Swift/Xcode toolchain.")
