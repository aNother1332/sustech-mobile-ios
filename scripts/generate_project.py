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
        if any(parent.suffix == ".xcassets" for parent in path.parents):
            continue
        if path.suffix == ".swift":
            file_type, phase = "sourcecode.swift", sources
        elif path.suffix in {".txt", ".xcprivacy", ".json"}:
            file_type, phase = "text.xml" if path.suffix == ".xcprivacy" else "text", resources
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
        "MARKETING_VERSION": "0.11.0", "CURRENT_PROJECT_VERSION": "16",
        "CODE_SIGN_ENTITLEMENTS": "Config/AppGroups.entitlements",
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
    share_product = add("share-product", "PBXFileReference", explicitFileType="wrapper.app-extension", path="CampusPrintShare.appex", sourceTree="BUILT_PRODUCTS_DIR")
    objects[products]["children"].append(share_product)
    share_ref = add("share-source", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="ShareExtension/ShareViewController.swift", sourceTree="SOURCE_ROOT")
    objects[group]["children"].append(share_ref)
    share_build = add("share-source-build", "PBXBuildFile", fileRef=share_ref)
    share_sources = add("share-sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=[share_build], runOnlyForDeploymentPostprocessing="0")
    share_configs = []
    for configuration in ("Debug", "Release"):
        share_configs.append(add("share-config:" + configuration, "XCBuildConfiguration", name=configuration, buildSettings={
            **common, "PRODUCT_NAME": "CampusPrintShare", "PRODUCT_BUNDLE_IDENTIFIER": "cn.sustech.community.daily.printshare",
            "INFOPLIST_FILE": "Config/Share-Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "SKIP_INSTALL": "YES",
            "APPLICATION_EXTENSION_API_ONLY": "YES", "TARGETED_DEVICE_FAMILY": "1,2",
            "SWIFT_STRICT_CONCURRENCY": "complete", "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
            "MARKETING_VERSION": "0.11.0", "CURRENT_PROJECT_VERSION": "16", "CODE_SIGN_ENTITLEMENTS": "Config/AppGroups.entitlements",
        }))
    share_config_list = add("share-config-list", "XCConfigurationList", buildConfigurations=share_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    share_target = add("share-target", "PBXNativeTarget", buildConfigurationList=share_config_list, buildPhases=[share_sources], buildRules=[], dependencies=[], name="CampusPrintShare", productName="CampusPrintShare", productReference=share_product, productType="com.apple.product-type.app-extension")
    proxy = add("share-proxy", "PBXContainerItemProxy", containerPortal=object_id("project"), proxyType="1", remoteGlobalIDString=share_target, remoteInfo="CampusPrintShare")
    dependency = add("share-dependency", "PBXTargetDependency", target=share_target, targetProxy=proxy)
    objects[target]["dependencies"].append(dependency)
    embed_build = add("share-embed-build", "PBXBuildFile", fileRef=share_product, settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
    embed_phase = add("share-embed", "PBXCopyFilesBuildPhase", buildActionMask="2147483647", dstPath="", dstSubfolderSpec="13", files=[embed_build], name="Embed App Extensions", runOnlyForDeploymentPostprocessing="0")
    objects[target]["buildPhases"].append(embed_phase)
    widget_product = add("widget-product", "PBXFileReference", explicitFileType="wrapper.app-extension", path="CampusWidgets.appex", sourceTree="BUILT_PRODUCTS_DIR")
    objects[products]["children"].append(widget_product)
    widget_ref = add("widget-source", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="WidgetExtension/CampusWidgets.swift", sourceTree="SOURCE_ROOT")
    objects[group]["children"].append(widget_ref)
    widget_source = add("widget-source-build", "PBXBuildFile", fileRef=widget_ref)
    widget_phase = add("widget-sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=[widget_source], runOnlyForDeploymentPostprocessing="0")
    widget_configs = []
    for configuration in ("Debug", "Release"):
        widget_configs.append(add("widget-config:" + configuration, "XCBuildConfiguration", name=configuration, buildSettings={
            **common, "PRODUCT_NAME": "CampusWidgets", "PRODUCT_BUNDLE_IDENTIFIER": "cn.sustech.community.daily.widgets",
            "INFOPLIST_FILE": "Config/Widget-Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "SKIP_INSTALL": "YES",
            "APPLICATION_EXTENSION_API_ONLY": "YES", "TARGETED_DEVICE_FAMILY": "1,2",
            "SWIFT_STRICT_CONCURRENCY": "complete", "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
            "MARKETING_VERSION": "0.11.0", "CURRENT_PROJECT_VERSION": "16", "CODE_SIGN_ENTITLEMENTS": "Config/AppGroups.entitlements",
        }))
    widget_config_list = add("widget-config-list", "XCConfigurationList", buildConfigurations=widget_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    widget_target = add("widget-target", "PBXNativeTarget", buildConfigurationList=widget_config_list, buildPhases=[widget_phase], buildRules=[], dependencies=[], name="CampusWidgets", productName="CampusWidgets", productReference=widget_product, productType="com.apple.product-type.app-extension")
    widget_proxy = add("widget-proxy", "PBXContainerItemProxy", containerPortal=object_id("project"), proxyType="1", remoteGlobalIDString=widget_target, remoteInfo="CampusWidgets")
    widget_dependency = add("widget-dependency", "PBXTargetDependency", target=widget_target, targetProxy=widget_proxy)
    objects[target]["dependencies"].append(widget_dependency)
    widget_embed = add("widget-embed-build", "PBXBuildFile", fileRef=widget_product, settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
    objects[embed_phase]["files"].append(widget_embed)
    ui_ref = add("ui-test-source", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="Tests/InteractionUITests/InteractionTests.swift", sourceTree="SOURCE_ROOT")
    objects[group]["children"].append(ui_ref)
    ui_build = add("ui-test-build", "PBXBuildFile", fileRef=ui_ref)
    ui_phase = add("ui-test-sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=[ui_build], runOnlyForDeploymentPostprocessing="0")
    ui_product = add("ui-test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="SUSTechUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    objects[products]["children"].append(ui_product)
    ui_configs = [add("ui-test:"+name, "XCBuildConfiguration", name=name, buildSettings={**common, "PRODUCT_NAME":"SUSTechUITests", "PRODUCT_BUNDLE_IDENTIFIER":"cn.sustech.community.daily.uitests", "GENERATE_INFOPLIST_FILE":"YES", "TEST_TARGET_NAME":"SUSTech", "TARGETED_DEVICE_FAMILY":"1,2", "SKIP_INSTALL":"YES"}) for name in ("Debug","Release")]
    ui_config_list = add("ui-test-configs", "XCConfigurationList", buildConfigurations=ui_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Debug")
    ui_proxy = add("ui-test-proxy", "PBXContainerItemProxy", containerPortal=object_id("project"), proxyType="1", remoteGlobalIDString=target, remoteInfo="SUSTech")
    ui_dependency = add("ui-test-dependency", "PBXTargetDependency", target=target, targetProxy=ui_proxy)
    ui_target = add("ui-test-target", "PBXNativeTarget", buildConfigurationList=ui_config_list, buildPhases=[ui_phase], buildRules=[], dependencies=[ui_dependency], name="SUSTechUITests", productName="SUSTechUITests", productReference=ui_product, productType="com.apple.product-type.bundle.ui-testing")
    project = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2600", "LastSwiftUpdateCheck": "2600", "TargetAttributes":{ui_target:{"TestTargetID":target}}},
                  buildConfigurationList=project_list, compatibilityVersion="Xcode 14.0", developmentRegion="zh_CN",
                  hasScannedForEncodings="0", knownRegions=["zh_CN", "en", "Base"], mainGroup=group,
                  productRefGroup=products, projectDirPath="", projectRoot="", targets=[target, share_target, widget_target, ui_target], packageReferences=[package])
    output = ROOT / "SUSTech.xcodeproj"
    output.mkdir(exist_ok=True)
    document = {"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objects, "rootObject": project}
    project_file = output / "project.pbxproj"
    project_bytes = ("// !$*UTF8*$!\n" + serialize(document) + "\n").encode("utf-8")
    if not project_file.exists() or project_file.read_bytes() != project_bytes:
        project_file.write_bytes(project_bytes)

    scheme = ET.Element("Scheme", LastUpgradeVersion="2600", version="1.3")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", **{f"buildFor{x}": "YES" for x in ("Testing", "Running", "Profiling", "Archiving", "Analyzing")})
    ref_attrs = dict(BuildableIdentifier="primary", BlueprintIdentifier=target, BuildableName="SUSTech.app",
                     BlueprintName="SUSTech", ReferencedContainer="container:SUSTech.xcodeproj")
    ET.SubElement(entry, "BuildableReference", **ref_attrs)
    test_action = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    testables = ET.SubElement(test_action,"Testables")
    testable = ET.SubElement(testables,"TestableReference",skipped="NO")
    ET.SubElement(testable,"BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=ui_target, BuildableName="SUSTechUITests.xctest", BlueprintName="SUSTechUITests", ReferencedContainer="container:SUSTech.xcodeproj")
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", allowLocationSimulation="YES")
    runnable = ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0")
    ET.SubElement(runnable, "BuildableReference", **ref_attrs)
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    ET.indent(scheme)
    schemes = output / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    scheme_file = schemes / "SUSTech.xcscheme"
    scheme_bytes = ET.tostring(scheme, encoding="utf-8", xml_declaration=True)
    if not scheme_file.exists() or scheme_file.read_bytes() != scheme_bytes:
        scheme_file.write_bytes(scheme_bytes)
    print(f"Generated {output.name}: {len(sources)} Swift files, {len(resources)} resources.")


if __name__ == "__main__":
    generate()
