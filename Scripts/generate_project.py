#!/usr/bin/env python3
"""Generate TaleFork.xcodeproj without external project-generator dependencies."""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "TaleFork.xcodeproj"


def oid(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest().upper()[:24]


def quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


app_sources = sorted((ROOT / "TaleFork").rglob("*.swift"))
test_sources = sorted((ROOT / "TaleForkTests").rglob("*.swift"))

app_files = [(path, path.relative_to(ROOT / "TaleFork").as_posix()) for path in app_sources]
test_files = [(path, path.relative_to(ROOT / "TaleForkTests").as_posix()) for path in test_sources]

resources = [
    ("Assets.xcassets", "Resources/Assets.xcassets", "folder.assetcatalog"),
    ("PrivacyInfo.xcprivacy", "Resources/PrivacyInfo.xcprivacy", "text.xml"),
    ("privacy-policy.html", "Resources/Legal/privacy-policy.html", "text.html"),
    ("terms-of-use.html", "Resources/Legal/terms-of-use.html", "text.html"),
]

languages = ["en", "ja", "zh-Hant"]
variant_names = ["Localizable.strings", "InfoPlist.strings"]

project_id = oid("project")
main_group = oid("group.main")
app_group = oid("group.app")
tests_group = oid("group.tests")
products_group = oid("group.products")
localizations_group = oid("group.localizations")

app_product = oid("product.app")
tests_product = oid("product.tests")
app_target = oid("target.app")
tests_target = oid("target.tests")

app_sources_phase = oid("phase.app.sources")
app_resources_phase = oid("phase.app.resources")
app_frameworks_phase = oid("phase.app.frameworks")
tests_sources_phase = oid("phase.tests.sources")
tests_resources_phase = oid("phase.tests.resources")
tests_frameworks_phase = oid("phase.tests.frameworks")

container_proxy = oid("container.proxy.tests.app")
target_dependency = oid("target.dependency.tests.app")

project_debug = oid("config.project.debug")
project_release = oid("config.project.release")
app_debug = oid("config.app.debug")
app_release = oid("config.app.release")
tests_debug = oid("config.tests.debug")
tests_release = oid("config.tests.release")
project_config_list = oid("configlist.project")
app_config_list = oid("configlist.app")
tests_config_list = oid("configlist.tests")

objects: list[str] = []


def add(object_id: str, comment: str, body: str) -> None:
    objects.append(f"\t\t{object_id} /* {comment} */ = {{\n{body}\n\t\t}};")


app_source_refs: list[str] = []
app_source_builds: list[str] = []
for _, relative in app_files:
    ref = oid(f"fileref.app.{relative}")
    build = oid(f"build.app.{relative}")
    name = Path(relative).name
    app_source_refs.append(ref)
    app_source_builds.append(build)
    add(ref, name, f"\t\t\tisa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(relative)}; sourceTree = \"<group>\";")
    add(build, f"{name} in Sources", f"\t\t\tisa = PBXBuildFile; fileRef = {ref} /* {name} */;")

test_source_refs: list[str] = []
test_source_builds: list[str] = []
for _, relative in test_files:
    ref = oid(f"fileref.tests.{relative}")
    build = oid(f"build.tests.{relative}")
    name = Path(relative).name
    test_source_refs.append(ref)
    test_source_builds.append(build)
    add(ref, name, f"\t\t\tisa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(relative)}; sourceTree = \"<group>\";")
    add(build, f"{name} in Sources", f"\t\t\tisa = PBXBuildFile; fileRef = {ref} /* {name} */;")

resource_refs: list[str] = []
resource_builds: list[str] = []
for name, relative, file_type in resources:
    ref = oid(f"fileref.resource.{relative}")
    build = oid(f"build.resource.{relative}")
    resource_refs.append(ref)
    resource_builds.append(build)
    add(ref, name, f"\t\t\tisa = PBXFileReference; lastKnownFileType = {file_type}; path = {quote(relative)}; sourceTree = \"<group>\";")
    add(build, f"{name} in Resources", f"\t\t\tisa = PBXBuildFile; fileRef = {ref} /* {name} */;")

variant_group_ids: list[str] = []
variant_build_ids: list[str] = []
for variant_name in variant_names:
    child_ids: list[str] = []
    for language in languages:
        child = oid(f"fileref.localization.{variant_name}.{language}")
        child_ids.append(child)
        child_path = f"{language}.lproj/{variant_name}"
        add(child, language, f"\t\t\tisa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {quote(language)}; path = {quote(child_path)}; sourceTree = \"<group>\";")
    group = oid(f"variant.{variant_name}")
    build = oid(f"build.variant.{variant_name}")
    variant_group_ids.append(group)
    variant_build_ids.append(build)
    children = "\n".join(f"\t\t\t\t{child} /* {language} */," for child, language in zip(child_ids, languages))
    add(group, variant_name, f"\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = (\n{children}\n\t\t\t);\n\t\t\tname = {quote(variant_name)};\n\t\t\tsourceTree = \"<group>\";")
    add(build, f"{variant_name} in Resources", f"\t\t\tisa = PBXBuildFile; fileRef = {group} /* {variant_name} */;")

add(app_product, "TaleFork.app", "\t\t\tisa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TaleFork.app; sourceTree = BUILT_PRODUCTS_DIR;")
add(tests_product, "TaleForkTests.xctest", "\t\t\tisa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TaleForkTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;")


def child_lines(items: list[tuple[str, str]]) -> str:
    return "\n".join(f"\t\t\t\t{identifier} /* {comment} */," for identifier, comment in items)


app_group_children = [(ref, Path(relative).name) for ref, (_, relative) in zip(app_source_refs, app_files)]
app_group_children += [(ref, name) for ref, (name, _, _) in zip(resource_refs, resources)]
app_group_children += [(localizations_group, "Localizations")]
add(
    app_group,
    "TaleFork",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines(app_group_children)}\n\t\t\t);\n\t\t\tpath = TaleFork;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    localizations_group,
    "Localizations",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(item, name) for item, name in zip(variant_group_ids, variant_names)])}\n\t\t\t);\n\t\t\tpath = Resources/Localizations;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    tests_group,
    "TaleForkTests",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(ref, Path(relative).name) for ref, (_, relative) in zip(test_source_refs, test_files)])}\n\t\t\t);\n\t\t\tpath = TaleForkTests;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    products_group,
    "Products",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(app_product, 'TaleFork.app'), (tests_product, 'TaleForkTests.xctest')])}\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    main_group,
    "Main Group",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(app_group, 'TaleFork'), (tests_group, 'TaleForkTests'), (products_group, 'Products')])}\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";",
)


def build_phase(identifier: str, comment: str, isa: str, files: list[tuple[str, str]]) -> None:
    add(
        identifier,
        comment,
        f"\t\t\tisa = {isa};\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{child_lines(files)}\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    )


build_phase(app_sources_phase, "Sources", "PBXSourcesBuildPhase", [(item, f"{Path(relative).name} in Sources") for item, (_, relative) in zip(app_source_builds, app_files)])
build_phase(app_resources_phase, "Resources", "PBXResourcesBuildPhase", [(item, f"{name} in Resources") for item, (name, _, _) in zip(resource_builds, resources)] + [(item, f"{name} in Resources") for item, name in zip(variant_build_ids, variant_names)])
build_phase(app_frameworks_phase, "Frameworks", "PBXFrameworksBuildPhase", [])
build_phase(tests_sources_phase, "Sources", "PBXSourcesBuildPhase", [(item, f"{Path(relative).name} in Sources") for item, (_, relative) in zip(test_source_builds, test_files)])
build_phase(tests_resources_phase, "Resources", "PBXResourcesBuildPhase", [])
build_phase(tests_frameworks_phase, "Frameworks", "PBXFrameworksBuildPhase", [])

add(container_proxy, "PBXContainerItemProxy", f"\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {project_id} /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {app_target};\n\t\t\tremoteInfo = TaleFork;")
add(target_dependency, "PBXTargetDependency", f"\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {app_target} /* TaleFork */;\n\t\t\ttargetProxy = {container_proxy} /* PBXContainerItemProxy */;")

add(
    app_target,
    "TaleFork",
    f"\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {app_config_list} /* Build configuration list for PBXNativeTarget \"TaleFork\" */;\n\t\t\tbuildPhases = (\n{child_lines([(app_sources_phase, 'Sources'), (app_frameworks_phase, 'Frameworks'), (app_resources_phase, 'Resources')])}\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = ();\n\t\t\tname = TaleFork;\n\t\t\tproductName = TaleFork;\n\t\t\tproductReference = {app_product} /* TaleFork.app */;\n\t\t\tproductType = \"com.apple.product-type.application\";",
)
add(
    tests_target,
    "TaleForkTests",
    f"\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {tests_config_list} /* Build configuration list for PBXNativeTarget \"TaleForkTests\" */;\n\t\t\tbuildPhases = (\n{child_lines([(tests_sources_phase, 'Sources'), (tests_frameworks_phase, 'Frameworks'), (tests_resources_phase, 'Resources')])}\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = (\n\t\t\t\t{target_dependency} /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tname = TaleForkTests;\n\t\t\tproductName = TaleForkTests;\n\t\t\tproductReference = {tests_product} /* TaleForkTests.xctest */;\n\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";",
)

add(
    project_id,
    "Project object",
    f"\t\t\tisa = PBXProject;\n\t\t\tattributes = {{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 2660;\n\t\t\t\tLastUpgradeCheck = 2660;\n\t\t\t\tTargetAttributes = {{\n\t\t\t\t\t{app_target} = {{ CreatedOnToolsVersion = 26.6; }};\n\t\t\t\t\t{tests_target} = {{ CreatedOnToolsVersion = 26.6; TestTargetID = {app_target}; }};\n\t\t\t\t}};\n\t\t\t}};\n\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"TaleFork\" */;\n\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n\t\t\tdevelopmentRegion = en;\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (en, ja, \"zh-Hant\", Base);\n\t\t\tmainGroup = {main_group};\n\t\t\tproductRefGroup = {products_group} /* Products */;\n\t\t\tprojectDirPath = \"\";\n\t\t\tprojectRoot = \"\";\n\t\t\ttargets = (\n\t\t\t\t{app_target} /* TaleFork */,\n\t\t\t\t{tests_target} /* TaleForkTests */,\n\t\t\t);",
)


def settings(values: list[tuple[str, str]]) -> str:
    return "\n".join(f"\t\t\t\t{key} = {value};" for key, value in values)


project_common = [
    ("ALWAYS_SEARCH_USER_PATHS", "NO"),
    ("CLANG_ENABLE_MODULES", "YES"),
    ("CLANG_ENABLE_OBJC_ARC", "YES"),
    ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
    ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
    ("IPHONEOS_DEPLOYMENT_TARGET", "18.0"),
    ("SDKROOT", "iphoneos"),
    ("SWIFT_VERSION", "6.0"),
]

target_common = [
    ("ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME", "AccentColor"),
    ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CURRENT_PROJECT_VERSION", "1"),
    ("DEVELOPMENT_TEAM", quote("")),
    ("ENABLE_PREVIEWS", "YES"),
    ("GENERATE_INFOPLIST_FILE", "NO"),
    ("INFOPLIST_FILE", "TaleFork/Resources/Info.plist"),
    ("MARKETING_VERSION", "1.0.0"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.talefork.storypaths"),
    ("PRODUCT_NAME", quote("$(TARGET_NAME)")),
    ("SUPPORTED_PLATFORMS", quote("iphoneos iphonesimulator")),
    ("SUPPORTS_MACCATALYST", "NO"),
    ("SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD", "NO"),
    ("SWIFT_EMIT_LOC_STRINGS", "YES"),
    ("SWIFT_VERSION", "6.0"),
    ("TARGETED_DEVICE_FAMILY", "1"),
]

tests_common = [
    ("BUNDLE_LOADER", quote("$(TEST_HOST)")),
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CURRENT_PROJECT_VERSION", "1"),
    ("DEVELOPMENT_TEAM", quote("")),
    ("GENERATE_INFOPLIST_FILE", "YES"),
    ("IPHONEOS_DEPLOYMENT_TARGET", "18.0"),
    ("MARKETING_VERSION", "1.0.0"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.talefork.storypaths.tests"),
    ("PRODUCT_NAME", quote("$(TARGET_NAME)")),
    ("SWIFT_VERSION", "6.0"),
    ("TARGETED_DEVICE_FAMILY", "1"),
    ("TEST_HOST", quote("$(BUILT_PRODUCTS_DIR)/TaleFork.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TaleFork")),
]

for identifier, name, values in [
    (project_debug, "Debug", project_common + [("DEBUG_INFORMATION_FORMAT", "dwarf"), ("ENABLE_TESTABILITY", "YES"), ("GCC_OPTIMIZATION_LEVEL", "0"), ("ONLY_ACTIVE_ARCH", "YES"), ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"), ("SWIFT_OPTIMIZATION_LEVEL", quote("-Onone"))]),
    (project_release, "Release", project_common + [("DEBUG_INFORMATION_FORMAT", quote("dwarf-with-dsym")), ("SWIFT_COMPILATION_MODE", "wholemodule"), ("SWIFT_OPTIMIZATION_LEVEL", quote("-O")), ("VALIDATE_PRODUCT", "YES")]),
    (app_debug, "Debug", target_common),
    (app_release, "Release", target_common),
    (tests_debug, "Debug", tests_common),
    (tests_release, "Release", tests_common),
]:
    add(identifier, name, f"\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{settings(values)}\n\t\t\t}};\n\t\t\tname = {name};")


def config_list(identifier: str, comment: str, debug: str, release: str) -> None:
    add(identifier, comment, f"\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{debug} /* Debug */,\n\t\t\t\t{release} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;")


config_list(project_config_list, 'Build configuration list for PBXProject "TaleFork"', project_debug, project_release)
config_list(app_config_list, 'Build configuration list for PBXNativeTarget "TaleFork"', app_debug, app_release)
config_list(tests_config_list, 'Build configuration list for PBXNativeTarget "TaleForkTests"', tests_debug, tests_release)

pbxproj = """// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {};
\tobjectVersion = 56;
\tobjects = {
""" + "\n".join(objects) + f"""
\t}};
\trootObject = {project_id} /* Project object */;
}}
"""

PROJECT.mkdir(parents=True, exist_ok=True)
(PROJECT / "project.pbxproj").write_text(pbxproj, encoding="utf-8")

scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES" buildArchitectures="Automatic">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="TaleFork.app" BlueprintName="TaleFork" ReferencedContainer="container:TaleFork.xcodeproj"/>
      </BuildActionEntry>
      <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests_target}" BuildableName="TaleForkTests.xctest" BlueprintName="TaleForkTests" ReferencedContainer="container:TaleFork.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>
      <TestableReference skipped="NO" parallelizable="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests_target}" BuildableName="TaleForkTests.xctest" BlueprintName="TaleForkTests" ReferencedContainer="container:TaleFork.xcodeproj"/>
      </TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="TaleFork.app" BlueprintName="TaleFork" ReferencedContainer="container:TaleFork.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="TaleFork.app" BlueprintName="TaleFork" ReferencedContainer="container:TaleFork.xcodeproj"/>
    </BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
"""
(scheme_dir / "TaleFork.xcscheme").write_text(scheme, encoding="utf-8")
print(f"Generated {PROJECT}")
print(f"App Swift files: {len(app_sources)}; test Swift files: {len(test_sources)}")
