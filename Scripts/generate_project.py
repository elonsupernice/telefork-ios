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
ui_test_sources = sorted((ROOT / "TaleForkUITests").rglob("*.swift"))

app_files = [(path, path.relative_to(ROOT / "TaleFork").as_posix()) for path in app_sources]
test_files = [(path, path.relative_to(ROOT / "TaleForkTests").as_posix()) for path in test_sources]
ui_test_files = [(path, path.relative_to(ROOT / "TaleForkUITests").as_posix()) for path in ui_test_sources]

resources = [
    ("Assets.xcassets", "Resources/Assets.xcassets", "folder.assetcatalog"),
    ("PrivacyInfo.xcprivacy", "Resources/PrivacyInfo.xcprivacy", "text.xml"),
    ("privacy-policy.html", "Resources/Legal/privacy-policy.html", "text.html"),
    ("terms-of-use.html", "Resources/Legal/terms-of-use.html", "text.html"),
]

languages = ["en", "ja", "zh-Hans", "zh-Hant"]
variant_names = ["Localizable.strings", "InfoPlist.strings"]

project_id = oid("project")
main_group = oid("group.main")
app_group = oid("group.app")
resources_group = oid("group.app.resources")
tests_group = oid("group.tests")
ui_tests_group = oid("group.ui-tests")
products_group = oid("group.products")
localizations_group = oid("group.localizations")

app_product = oid("product.app")
tests_product = oid("product.tests")
ui_tests_product = oid("product.ui-tests")
app_target = oid("target.app")
tests_target = oid("target.tests")
ui_tests_target = oid("target.ui-tests")

app_sources_phase = oid("phase.app.sources")
app_resources_phase = oid("phase.app.resources")
app_frameworks_phase = oid("phase.app.frameworks")
tests_sources_phase = oid("phase.tests.sources")
tests_resources_phase = oid("phase.tests.resources")
tests_frameworks_phase = oid("phase.tests.frameworks")
ui_tests_sources_phase = oid("phase.ui-tests.sources")
ui_tests_resources_phase = oid("phase.ui-tests.resources")
ui_tests_frameworks_phase = oid("phase.ui-tests.frameworks")

container_proxy = oid("container.proxy.tests.app")
target_dependency = oid("target.dependency.tests.app")
ui_container_proxy = oid("container.proxy.ui-tests.app")
ui_target_dependency = oid("target.dependency.ui-tests.app")

project_debug = oid("config.project.debug")
project_release = oid("config.project.release")
app_debug = oid("config.app.debug")
app_release = oid("config.app.release")
tests_debug = oid("config.tests.debug")
tests_release = oid("config.tests.release")
ui_tests_debug = oid("config.ui-tests.debug")
ui_tests_release = oid("config.ui-tests.release")
project_config_list = oid("configlist.project")
app_config_list = oid("configlist.app")
tests_config_list = oid("configlist.tests")
ui_tests_config_list = oid("configlist.ui-tests")

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
    add(ref, name, f"\t\t\tisa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(name)}; sourceTree = \"<group>\";")
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

ui_test_source_refs: list[str] = []
ui_test_source_builds: list[str] = []
for _, relative in ui_test_files:
    ref = oid(f"fileref.ui-tests.{relative}")
    build = oid(f"build.ui-tests.{relative}")
    name = Path(relative).name
    ui_test_source_refs.append(ref)
    ui_test_source_builds.append(build)
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

storekit_config_ref = oid("fileref.resource.Resources/StoreKit/TaleFork.storekit")
storekit_test_build = oid("build.tests.Resources/StoreKit/TaleFork.storekit")
add(
    storekit_config_ref,
    "TaleFork.storekit",
    "\t\t\tisa = PBXFileReference; lastKnownFileType = text.json; path = Resources/StoreKit/TaleFork.storekit; sourceTree = \"<group>\";",
)
add(
    storekit_test_build,
    "TaleFork.storekit in Resources",
    f"\t\t\tisa = PBXBuildFile; fileRef = {storekit_config_ref} /* TaleFork.storekit */;",
)

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
add(ui_tests_product, "TaleForkUITests.xctest", "\t\t\tisa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TaleForkUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;")


def child_lines(items: list[tuple[str, str]]) -> str:
    return "\n".join(f"\t\t\t\t{identifier} /* {comment} */," for identifier, comment in items)


source_refs_by_parent: dict[str, list[tuple[str, str]]] = {}
for ref, (_, relative) in zip(app_source_refs, app_files):
    parent = Path(relative).parent.as_posix()
    source_refs_by_parent.setdefault(parent, []).append((ref, Path(relative).name))

source_group_path_set: set[str] = set()
for source_parent in source_refs_by_parent:
    current = source_parent
    while current != ".":
        source_group_path_set.add(current)
        current = Path(current).parent.as_posix()

source_group_paths = sorted(
    source_group_path_set,
    key=lambda path: (path.count("/"), path),
    reverse=True,
)
source_group_ids = {path: oid(f"group.app.sources.{path}") for path in source_group_paths}

for path in source_group_paths:
    children = list(source_refs_by_parent.get(path, []))
    children += [
        (identifier, child.rsplit("/", 1)[-1])
        for child, identifier in source_group_ids.items()
        if Path(child).parent.as_posix() == path
    ]
    add(
        source_group_ids[path],
        path.rsplit("/", 1)[-1],
        f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines(children)}\n\t\t\t);\n\t\t\tpath = {quote(path.rsplit('/', 1)[-1])};\n\t\t\tsourceTree = \"<group>\";",
    )

top_source_groups = [
    (identifier, path)
    for path, identifier in sorted(source_group_ids.items())
    if "/" not in path
]
app_group_children = list(source_refs_by_parent.get(".", []))
app_group_children += top_source_groups
app_group_children += [(resources_group, "Resources")]
add(
    app_group,
    "TaleFork",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines(app_group_children)}\n\t\t\t);\n\t\t\tpath = TaleFork;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    resources_group,
    "Resources",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(ref, name) for ref, (name, _, _) in zip(resource_refs, resources)] + [(storekit_config_ref, 'TaleFork.storekit'), (localizations_group, 'Localizations')])}\n\t\t\t);\n\t\t\tname = Resources;\n\t\t\tsourceTree = \"<group>\";",
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
    ui_tests_group,
    "TaleForkUITests",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(ref, Path(relative).name) for ref, (_, relative) in zip(ui_test_source_refs, ui_test_files)])}\n\t\t\t);\n\t\t\tpath = TaleForkUITests;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    products_group,
    "Products",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(app_product, 'TaleFork.app'), (tests_product, 'TaleForkTests.xctest'), (ui_tests_product, 'TaleForkUITests.xctest')])}\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";",
)
add(
    main_group,
    "Main Group",
    f"\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines([(app_group, 'TaleFork'), (tests_group, 'TaleForkTests'), (ui_tests_group, 'TaleForkUITests'), (products_group, 'Products')])}\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";",
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
build_phase(tests_resources_phase, "Resources", "PBXResourcesBuildPhase", [(storekit_test_build, "TaleFork.storekit in Resources")])
build_phase(tests_frameworks_phase, "Frameworks", "PBXFrameworksBuildPhase", [])
build_phase(ui_tests_sources_phase, "Sources", "PBXSourcesBuildPhase", [(item, f"{Path(relative).name} in Sources") for item, (_, relative) in zip(ui_test_source_builds, ui_test_files)])
build_phase(ui_tests_resources_phase, "Resources", "PBXResourcesBuildPhase", [])
build_phase(ui_tests_frameworks_phase, "Frameworks", "PBXFrameworksBuildPhase", [])

add(container_proxy, "PBXContainerItemProxy", f"\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {project_id} /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {app_target};\n\t\t\tremoteInfo = TaleFork;")
add(target_dependency, "PBXTargetDependency", f"\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {app_target} /* TaleFork */;\n\t\t\ttargetProxy = {container_proxy} /* PBXContainerItemProxy */;")
add(ui_container_proxy, "PBXContainerItemProxy", f"\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {project_id} /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {app_target};\n\t\t\tremoteInfo = TaleFork;")
add(ui_target_dependency, "PBXTargetDependency", f"\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {app_target} /* TaleFork */;\n\t\t\ttargetProxy = {ui_container_proxy} /* PBXContainerItemProxy */;")

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
    ui_tests_target,
    "TaleForkUITests",
    f"\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = {ui_tests_config_list} /* Build configuration list for PBXNativeTarget \"TaleForkUITests\" */;\n\t\t\tbuildPhases = (\n{child_lines([(ui_tests_sources_phase, 'Sources'), (ui_tests_frameworks_phase, 'Frameworks'), (ui_tests_resources_phase, 'Resources')])}\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = (\n\t\t\t\t{ui_target_dependency} /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tname = TaleForkUITests;\n\t\t\tproductName = TaleForkUITests;\n\t\t\tproductReference = {ui_tests_product} /* TaleForkUITests.xctest */;\n\t\t\tproductType = \"com.apple.product-type.bundle.ui-testing\";",
)

add(
    project_id,
    "Project object",
    f"\t\t\tisa = PBXProject;\n\t\t\tattributes = {{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 2660;\n\t\t\t\tLastUpgradeCheck = 2660;\n\t\t\t\tTargetAttributes = {{\n\t\t\t\t\t{app_target} = {{ CreatedOnToolsVersion = 26.6; }};\n\t\t\t\t\t{tests_target} = {{ CreatedOnToolsVersion = 26.6; TestTargetID = {app_target}; }};\n\t\t\t\t\t{ui_tests_target} = {{ CreatedOnToolsVersion = 26.6; TestTargetID = {app_target}; }};\n\t\t\t\t}};\n\t\t\t}};\n\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"TaleFork\" */;\n\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n\t\t\tdevelopmentRegion = \"zh-Hant\";\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (en, ja, \"zh-Hans\", \"zh-Hant\", Base);\n\t\t\tmainGroup = {main_group};\n\t\t\tproductRefGroup = {products_group} /* Products */;\n\t\t\tprojectDirPath = \"\";\n\t\t\tprojectRoot = \"\";\n\t\t\ttargets = (\n\t\t\t\t{app_target} /* TaleFork */,\n\t\t\t\t{tests_target} /* TaleForkTests */,\n\t\t\t\t{ui_tests_target} /* TaleForkUITests */,\n\t\t\t);",
)


def settings(values: list[tuple[str, str]]) -> str:
    return "\n".join(f"\t\t\t\t{key} = {value};" for key, value in values)


project_common = [
    ("ALWAYS_SEARCH_USER_PATHS", "NO"),
    ("CLANG_ENABLE_MODULES", "YES"),
    ("CLANG_ENABLE_OBJC_ARC", "YES"),
    ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
    ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
    ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
    ("IPHONEOS_DEPLOYMENT_TARGET", "18.0"),
    ("SDKROOT", "iphoneos"),
    ("SWIFT_VERSION", "6.0"),
]

target_common = [
    ("ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME", "AccentColor"),
    ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
    ("ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS", "YES"),
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
    ("SWIFT_STRICT_CONCURRENCY", "complete"),
    ("SWIFT_VERSION", "6.0"),
    ("TARGETED_DEVICE_FAMILY", "1"),
    ("VERSIONING_SYSTEM", quote("apple-generic")),
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
    ("VERSIONING_SYSTEM", quote("apple-generic")),
]

ui_tests_common = [
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CURRENT_PROJECT_VERSION", "1"),
    ("DEVELOPMENT_TEAM", quote("")),
    ("GENERATE_INFOPLIST_FILE", "YES"),
    ("IPHONEOS_DEPLOYMENT_TARGET", "18.0"),
    ("MARKETING_VERSION", "1.0.0"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.talefork.storypaths.uitests"),
    ("PRODUCT_NAME", quote("$(TARGET_NAME)")),
    ("SWIFT_VERSION", "6.0"),
    ("TARGETED_DEVICE_FAMILY", "1"),
    ("TEST_TARGET_NAME", "TaleFork"),
    ("VERSIONING_SYSTEM", quote("apple-generic")),
]

for identifier, name, values in [
    (project_debug, "Debug", project_common + [("DEBUG_INFORMATION_FORMAT", "dwarf"), ("ENABLE_TESTABILITY", "YES"), ("GCC_OPTIMIZATION_LEVEL", "0"), ("ONLY_ACTIVE_ARCH", "YES"), ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"), ("SWIFT_OPTIMIZATION_LEVEL", quote("-Onone"))]),
    (project_release, "Release", project_common + [("DEBUG_INFORMATION_FORMAT", quote("dwarf-with-dsym")), ("SWIFT_COMPILATION_MODE", "wholemodule"), ("SWIFT_OPTIMIZATION_LEVEL", quote("-O")), ("VALIDATE_PRODUCT", "YES")]),
    (app_debug, "Debug", target_common),
    (app_release, "Release", target_common),
    (tests_debug, "Debug", tests_common),
    (tests_release, "Release", tests_common),
    (ui_tests_debug, "Debug", ui_tests_common),
    (ui_tests_release, "Release", ui_tests_common),
]:
    add(identifier, name, f"\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{settings(values)}\n\t\t\t}};\n\t\t\tname = {name};")


def config_list(identifier: str, comment: str, debug: str, release: str) -> None:
    add(identifier, comment, f"\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{debug} /* Debug */,\n\t\t\t\t{release} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;")


config_list(project_config_list, 'Build configuration list for PBXProject "TaleFork"', project_debug, project_release)
config_list(app_config_list, 'Build configuration list for PBXNativeTarget "TaleFork"', app_debug, app_release)
config_list(tests_config_list, 'Build configuration list for PBXNativeTarget "TaleForkTests"', tests_debug, tests_release)
config_list(ui_tests_config_list, 'Build configuration list for PBXNativeTarget "TaleForkUITests"', ui_tests_debug, ui_tests_release)

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
      <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_tests_target}" BuildableName="TaleForkUITests.xctest" BlueprintName="TaleForkUITests" ReferencedContainer="container:TaleFork.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>
      <TestableReference skipped="NO" parallelizable="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests_target}" BuildableName="TaleForkTests.xctest" BlueprintName="TaleForkTests" ReferencedContainer="container:TaleFork.xcodeproj"/>
      </TestableReference>
      <TestableReference skipped="NO" parallelizable="NO">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_tests_target}" BuildableName="TaleForkUITests.xctest" BlueprintName="TaleForkUITests" ReferencedContainer="container:TaleFork.xcodeproj"/>
      </TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="TaleFork.app" BlueprintName="TaleFork" ReferencedContainer="container:TaleFork.xcodeproj"/>
    </BuildableProductRunnable>
    <StoreKitConfigurationFileReference identifier="../../TaleFork/Resources/StoreKit/TaleFork.storekit"/>
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
print(f"App Swift files: {len(app_sources)}; unit test Swift files: {len(test_sources)}; UI test Swift files: {len(ui_test_sources)}")
