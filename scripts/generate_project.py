"""Generate a deterministic Xcode project using only Python's standard library.

No Mac or XcodeGen is required to regenerate; actual iOS builds require Xcode.
Run from any working directory: python scripts/generate_project.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def object_id(name: str) -> str:
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def serialize(value: object, indent: int = 0) -> str:
    if isinstance(value, dict):
        lines = ["{"]
        for key, item in value.items():
            lines.append("\t" * (indent + 1) + json.dumps(key) + " = " + serialize(item, indent + 1) + ";")
        return "\n".join(lines) + "\n" + "\t" * indent + "}"
    if isinstance(value, list):
        return "(\n" + "".join("\t" * (indent + 1) + serialize(item, indent + 1) + ",\n" for item in value) + "\t" * indent + ")"
    return json.dumps(str(value), ensure_ascii=False)


def generate() -> None:
    objects: dict[str, dict] = {}

    def add(object_name: str, isa: str, **fields: object) -> str:
        identity = object_id(object_name)
        objects[identity] = {"isa": isa, **fields}
        return identity

    sources, resources, references = [], [], []
    # Path ordering on Windows is case-insensitive; use a stable string key so
    # the checked-in project is byte-identical on Windows and macOS.
    for path in sorted((ROOT / "App").rglob("*"), key=lambda p: p.relative_to(ROOT).as_posix()):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        if path.suffix == ".swift":
            file_type, phase = "sourcecode.swift", sources
        elif path.suffix in {".txt", ".xcprivacy"}:
            file_type, phase = "text" if path.suffix == ".txt" else "text.xml", resources
        else:
            continue
        reference = add(relative, "PBXFileReference", lastKnownFileType=file_type,
                        path=relative, sourceTree="SOURCE_ROOT")
        references.append(reference)
        phase.append(add(relative + ":build", "PBXBuildFile", fileRef=reference))

    for path in sorted((ROOT / "App").rglob("*.xcassets")):
        relative = path.relative_to(ROOT).as_posix()
        reference = add(relative, "PBXFileReference", lastKnownFileType="folder.assetcatalog",
                        path=relative, sourceTree="SOURCE_ROOT")
        references.append(reference)
        resources.append(add(relative + ":build", "PBXBuildFile", fileRef=reference))

    app = add("product", "PBXFileReference", explicitFileType="wrapper.application",
              path="SUSTech.app", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex="0")
    products = add("products", "PBXGroup", children=[app], name="Products", sourceTree="<group>")
    group = add("root-group", "PBXGroup", children=references + [products], sourceTree="<group>")
    package = add("core-package", "XCLocalSwiftPackageReference", relativePath=".")
    core = add("core-product", "XCSwiftPackageProductDependency", package=package, productName="CampusCore")
    framework = add("core-framework", "PBXBuildFile", productRef=core)
    source_phase = add("sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=sources,
                       runOnlyForDeploymentPostprocessing="0")
    resource_phase = add("resources", "PBXResourcesBuildPhase", buildActionMask="2147483647", files=resources,
                         runOnlyForDeploymentPostprocessing="0")
    framework_phase = add("frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=[framework],
                          runOnlyForDeploymentPostprocessing="0")
    common = {
        "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "6.0",
        "CLANG_ENABLE_MODULES": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    }
    target_settings = {
        "PRODUCT_NAME": "SUSTech", "PRODUCT_BUNDLE_IDENTIFIER": "cn.sustech.community.daily",
        "INFOPLIST_FILE": "Config/Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO", "CODE_SIGN_STYLE": "Automatic",
        "MARKETING_VERSION": "0.2.0", "CURRENT_PROJECT_VERSION": "4",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "SWIFT_STRICT_CONCURRENCY": "complete", "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor", "ENABLE_PREVIEWS": "YES",
    }
    project_configs, target_configs = [], []
    for name in ("Debug", "Release"):
        project_configs.append(add("project:" + name, "XCBuildConfiguration", name=name, buildSettings={
            **common, "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if name == "Debug" else "-O",
            "DEBUG_INFORMATION_FORMAT": "dwarf" if name == "Debug" else "dwarf-with-dsym",
        }))
        target_configs.append(add("target:" + name, "XCBuildConfiguration", name=name, buildSettings={
            **target_settings, **({"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"} if name == "Debug" else {}),
        }))
    project_list = add("project-configs", "XCConfigurationList", buildConfigurations=project_configs,
                       defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    target_list = add("target-configs", "XCConfigurationList", buildConfigurations=target_configs,
                      defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    target = add("app-target", "PBXNativeTarget", buildConfigurationList=target_list,
                 buildPhases=[source_phase, framework_phase, resource_phase], buildRules=[], dependencies=[],
                 name="SUSTech", productName="SUSTech", productReference=app,
                 productType="com.apple.product-type.application", packageProductDependencies=[core])
    project = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2600", "LastSwiftUpdateCheck": "2600"},
                  buildConfigurationList=project_list, compatibilityVersion="Xcode 14.0", developmentRegion="zh_CN",
                  hasScannedForEncodings="0", knownRegions=["zh_CN", "en", "Base"], mainGroup=group,
                  productRefGroup=products, projectDirPath="", projectRoot="", targets=[target], packageReferences=[package])
    output = ROOT / "SUSTech.xcodeproj"
    output.mkdir(exist_ok=True)
    document = {"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objects, "rootObject": project}
    (output / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize(document) + "\n", encoding="utf-8", newline="\n")

    scheme = ET.Element("Scheme", LastUpgradeVersion="2600", version="1.3")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", **{f"buildFor{x}": "YES" for x in ("Testing", "Running", "Profiling", "Archiving", "Analyzing")})
    ref_attrs = dict(BuildableIdentifier="primary", BlueprintIdentifier=target, BuildableName="SUSTech.app",
                     BlueprintName="SUSTech", ReferencedContainer="container:SUSTech.xcodeproj")
    ET.SubElement(entry, "BuildableReference", **ref_attrs)
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", allowLocationSimulation="YES")
    runnable = ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0")
    ET.SubElement(runnable, "BuildableReference", **ref_attrs)
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    ET.indent(scheme)
    schemes = output / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    with (schemes / "SUSTech.xcscheme").open("wb") as handle:
        ET.ElementTree(scheme).write(handle, encoding="utf-8", xml_declaration=True)
    print(f"Generated {output.name}: {len(sources)} Swift files, {len(resources)} resources.")


if __name__ == "__main__":
    generate()
