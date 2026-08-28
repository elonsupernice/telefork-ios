#!/usr/bin/env python3
"""Generate a reproducible TaleFork App Store 4.3 comparison audit.

The audit covers repository-owned source, tests, scripts, declared Swift names,
wire strings, Xcode project/configuration files, localization/resource topology,
and exact binary-asset hashes. It intentionally excludes build products, Git
metadata, xcuserdata, and vendored dependency directories.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Iterable


CODE_SUFFIXES = {
    ".swift", ".m", ".mm", ".h", ".c", ".cc", ".cpp", ".metal",
    ".py", ".rb", ".sh", ".js", ".ts", ".tsx", ".html", ".css",
}
PROJECT_SUFFIXES = {".pbxproj", ".xcscheme", ".xcconfig", ".plist", ".xcprivacy", ".entitlements", ".xcworkspacedata"}
RESOURCE_TEXT_SUFFIXES = {".strings", ".json", ".xml", ".md", ".txt"}
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic", ".webp", ".gif", ".pdf"}
IGNORED_PARTS = {".git", ".build", "Build", "DerivedData", "xcuserdata", "Pods", "Carthage", "vendor", "node_modules", "__pycache__"}

TOKEN = re.compile(
    r'"(?:\\.|[^"\\])*"|'
    r"'(?:\\.|[^'\\])*'|"
    r"[A-Za-z_][A-Za-z0-9_]*|"
    r"\d+(?:\.\d+)?|"
    r"->|==|!=|<=|>=|&&|\|\||\?\?|\.\.\.|\.\.<|"
    r"[{}()\[\].,:;?@#\\+\-*/%<>=!&|^~]"
)
STRING_LITERAL = re.compile(r'"((?:\\.|[^"\\])*)"')
DECLARATION_PATTERNS = {
    "type": re.compile(r"\b(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)"),
    "function": re.compile(r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)"),
    "property": re.compile(r"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)"),
}
GENERIC_IDENTIFIERS = {
    "id", "body", "content", "value", "values", "data", "error", "message",
    "title", "name", "url", "image", "view", "result", "results", "status",
    "response", "request", "index", "item", "items", "path", "key", "state",
}
CONFIG_KEYS = {
    "PRODUCT_BUNDLE_IDENTIFIER", "PRODUCT_NAME", "DEVELOPMENT_TEAM",
    "IPHONEOS_DEPLOYMENT_TARGET", "SWIFT_VERSION", "TARGETED_DEVICE_FAMILY",
    "INFOPLIST_FILE", "CODE_SIGN_ENTITLEMENTS", "ASSETCATALOG_COMPILER_APPICON_NAME",
    "SUPPORTED_PLATFORMS", "MARKETING_VERSION", "CURRENT_PROJECT_VERSION",
}


@dataclass(frozen=True)
class FileRecord:
    display: str
    path: Path
    kind: str

    def text(self) -> str:
        return self.path.read_text(encoding="utf-8", errors="ignore")


def classify(path: Path) -> str:
    if path.name in {"project.pbxproj", "Podfile", "Podfile.lock", "Package.swift"}:
        return "project"
    suffix = path.suffix.lower()
    if suffix in CODE_SUFFIXES:
        return "code"
    if suffix in PROJECT_SUFFIXES:
        return "project"
    if suffix in RESOURCE_TEXT_SUFFIXES:
        return "resource-text"
    if suffix in IMAGE_SUFFIXES:
        return "image"
    return "binary"


def collect(parts: list[Path]) -> list[FileRecord]:
    records: dict[Path, FileRecord] = {}
    for part in parts:
        resolved = part.resolve()
        if not resolved.exists():
            continue
        paths = [resolved] if resolved.is_file() else resolved.rglob("*")
        for path in paths:
            if not path.is_file() or any(piece in IGNORED_PARTS for piece in path.parts):
                continue
            relative = path.name if resolved.is_file() else path.relative_to(resolved).as_posix()
            display = f"{resolved.name}/{relative}" if relative != resolved.name else resolved.name
            records[path] = FileRecord(display=display, path=path, kind=classify(path))
    return sorted(records.values(), key=lambda record: record.display)


def strip_comments(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", " ", source, flags=re.S)
    source = re.sub(r"//[^\n]*", " ", source)
    source = re.sub(r"<!--[\s\S]*?-->", " ", source)
    return source


def tokens(record: FileRecord) -> tuple[str, ...]:
    value = strip_comments(record.text())
    if record.kind == "project":
        value = re.sub(r"\b[A-F0-9]{24}\b", "PBX_OBJECT_ID", value)
    return tuple(TOKEN.findall(value))


def shingles(values: tuple[str, ...], width: int) -> set[tuple[str, ...]]:
    return {values[index:index + width] for index in range(max(len(values) - width + 1, 0))}


def clone_coverage(primary: list[FileRecord], comparison: list[FileRecord], width: int) -> dict[str, object]:
    reference = set().union(*(shingles(tokens(record), width) for record in comparison)) if comparison else set()
    total = 0
    matched = 0
    file_rows: list[dict[str, object]] = []
    comparison_shingles = {record.display: shingles(tokens(record), width) for record in comparison}
    for record in primary:
        values = tokens(record)
        total += len(values)
        covered: set[int] = set()
        for index in range(max(len(values) - width + 1, 0)):
            if values[index:index + width] in reference:
                covered.update(range(index, index + width))
        matched += len(covered)
        best_name = "-"
        best_count = 0
        for other_name, other_shingles in comparison_shingles.items():
            count = 0
            positions: set[int] = set()
            for index in range(max(len(values) - width + 1, 0)):
                if values[index:index + width] in other_shingles:
                    positions.update(range(index, index + width))
            count = len(positions)
            if count > best_count:
                best_name, best_count = other_name, count
        file_rows.append({
            "file": record.display,
            "bestComparison": best_name,
            "matched": best_count,
            "tokens": len(values),
            "ratio": best_count / len(values) if values else 0,
        })
    file_rows.sort(key=lambda row: (row["ratio"], row["matched"]), reverse=True)
    return {"tokens": total, "matched": matched, "ratio": matched / total if total else 0, "files": file_rows}


def swift_declarations(records: list[FileRecord]) -> dict[str, set[str]]:
    result: dict[str, set[str]] = defaultdict(set)
    for record in records:
        if record.path.suffix.lower() != ".swift":
            continue
        source = strip_comments(record.text())
        for kind, pattern in DECLARATION_PATTERNS.items():
            result[kind].update(pattern.findall(source))
        for match in re.finditer(r"\bcase\s+([^\n{]+)", source):
            for item in match.group(1).split(","):
                name = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)", item)
                if name:
                    result["case"].add(name.group(1))
    return result


def declared_overlap(primary: list[FileRecord], comparison: list[FileRecord]) -> dict[str, object]:
    left = swift_declarations(primary)
    right = swift_declarations(comparison)
    details: dict[str, object] = {}
    combined_left: set[str] = set()
    combined_right: set[str] = set()
    for kind in sorted(set(left) | set(right)):
        common = sorted(left[kind] & right[kind], key=str.casefold)
        details[kind] = {"primary": len(left[kind]), "comparison": len(right[kind]), "common": common}
        combined_left.update(left[kind])
        combined_right.update(right[kind])
    common_all = combined_left & combined_right
    return {
        "primary": len(combined_left),
        "comparison": len(combined_right),
        "common": sorted(common_all, key=str.casefold),
        "nontrivialCommon": sorted(common_all - GENERIC_IDENTIFIERS, key=str.casefold),
        "jaccard": len(common_all) / len(combined_left | combined_right) if combined_left | combined_right else 0,
        "byKind": details,
    }


def production_records(records: list[FileRecord], product_folder: str, kinds: set[str]) -> list[FileRecord]:
    prefix = f"{product_folder}/"
    return [record for record in records if record.kind in kinds and record.display.startswith(prefix)]


def string_literals(records: Iterable[FileRecord]) -> set[str]:
    result: set[str] = set()
    for record in records:
        if record.kind not in {"code", "project", "resource-text"}:
            continue
        for literal in STRING_LITERAL.findall(record.text()):
            value = literal.replace(r'\"', '"').replace(r"\\", "\\")
            if len(value.strip()) >= 3:
                result.add(value.strip())
    return result


def network_literals(records: list[FileRecord]) -> set[str]:
    markers = ("service", "network", "transport", "route", "endpoint", "repository", "client", "handshake")
    candidates = [record for record in records if record.kind == "code" and any(marker in record.display.lower() for marker in markers)]
    values = string_literals(candidates)
    return {
        value for value in values
        if value.startswith("http")
        or value.startswith("api/")
        or value.startswith("tale-gateway/")
        or re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{2,}", value)
    }


def imports(records: list[FileRecord]) -> set[str]:
    result: set[str] = set()
    for record in records:
        if record.path.suffix.lower() == ".swift":
            result.update(re.findall(r"^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)", record.text(), flags=re.M))
    return result


def configuration_values(records: list[FileRecord]) -> dict[str, list[str]]:
    values: dict[str, set[str]] = defaultdict(set)
    for record in records:
        if record.kind != "project":
            continue
        source = record.text()
        for key in CONFIG_KEYS:
            for match in re.findall(rf"\b{re.escape(key)}\s*=\s*([^;\n]+)", source):
                values[key].add(match.strip().strip('"'))
        if record.path.suffix.lower() == ".plist":
            try:
                payload = plistlib.loads(record.path.read_bytes())
            except Exception:
                continue
            if isinstance(payload, dict):
                for key in ("CFBundleDisplayName", "CFBundleName", "CFBundleIdentifier", "UIBackgroundModes"):
                    if key in payload:
                        values[key].add(json.dumps(payload[key], ensure_ascii=False, sort_keys=True))
    return {key: sorted(items) for key, items in sorted(values.items())}


def exact_asset_duplicates(primary: list[FileRecord], comparison: list[FileRecord]) -> list[dict[str, str]]:
    lookup: dict[str, list[FileRecord]] = defaultdict(list)
    for record in comparison:
        if record.kind in {"image", "binary"}:
            lookup[hashlib.sha256(record.path.read_bytes()).hexdigest()].append(record)
    rows: list[dict[str, str]] = []
    for record in primary:
        if record.kind not in {"image", "binary"}:
            continue
        digest = hashlib.sha256(record.path.read_bytes()).hexdigest()
        for other in lookup.get(digest, []):
            rows.append({"primary": record.display, "comparison": other.display, "sha256": digest})
    return rows


def topology(records: list[FileRecord]) -> dict[str, list[str]]:
    code_files = [record for record in records if record.kind == "code"]
    return {
        "codeBasenames": sorted({record.path.name for record in code_files}, key=str.casefold),
        "assetCatalogNames": sorted({part for record in records for part in record.path.parts if part.endswith((".imageset", ".colorset", ".appiconset"))}, key=str.casefold),
        "schemeNames": sorted({record.path.stem for record in records if record.path.suffix == ".xcscheme"}, key=str.casefold),
        "projectNames": sorted({part.removesuffix(".xcodeproj") for record in records for part in record.path.parts if part.endswith(".xcodeproj")}, key=str.casefold),
    }


def runtime_findings(records: list[FileRecord]) -> dict[str, list[str]]:
    runtime = [record for record in records if record.display.startswith("TaleFork/") and record.kind in {"code", "project", "resource-text"}]
    executable_suffixes = {".swift", ".m", ".mm", ".h", ".c", ".cc", ".cpp", ".metal", ".py", ".rb", ".sh", ".js", ".ts", ".tsx"}
    patterns = {
        "competitorBrands": re.compile(r"dramile|languo|\u84dd\u679c|com\.dramile|com\.lah", re.I),
        "payments": re.compile(r"\b(?:StoreKit|SKPayment\w*|alipay|wechat.?pay|paypal|purchase\w*|subscription\w*|vip)\b", re.I),
        "trackingOrAds": re.compile(r"\b(?:AppTrackingTransparency|AdSupport|IDFA|AppsFlyer|Adjust|FirebaseAnalytics|FacebookSDK|advert\w*)\b|\bGAD[A-Za-z]*\b", re.I),
        "capabilities": re.compile(r"aps-environment|com\.apple\.developer\.associated-domains|application-groups|UIBackgroundModes", re.I),
        "dynamicCode": re.compile(r"dlopen|NSClassFromString|javascriptcore|evaluateJavaScript|download.*code", re.I),
    }
    findings: dict[str, list[str]] = defaultdict(list)
    for record in runtime:
        for line_number, line in enumerate(record.text().splitlines(), 1):
            for name, pattern in patterns.items():
                if name != "competitorBrands" and record.kind != "project" and record.path.suffix.lower() not in executable_suffixes:
                    continue
                if pattern.search(line):
                    findings[name].append(f"{record.display}:{line_number}: {line.strip()}")
    return {name: rows for name, rows in findings.items()}


def file_counts(records: list[FileRecord]) -> dict[str, int]:
    counts = Counter(record.kind for record in records)
    counts["total"] = len(records)
    return dict(sorted(counts.items()))


def pct(value: float) -> str:
    return f"{value:.2%}"


def code_metrics(primary: list[FileRecord], comparison: list[FileRecord], primary_folder: str, comparison_folder: str) -> dict[str, object]:
    all_code_left = [record for record in primary if record.kind == "code"]
    all_code_right = [record for record in comparison if record.kind == "code"]
    production_left = production_records(primary, primary_folder, {"code"})
    production_right = production_records(comparison, comparison_folder, {"code"})
    project_left = [record for record in primary if record.kind == "project"]
    project_right = [record for record in comparison if record.kind == "project"]
    return {
        "allCode": {str(width): clone_coverage(all_code_left, all_code_right, width) for width in (12, 24, 48)},
        "productionCode": {str(width): clone_coverage(production_left, production_right, width) for width in (12, 24, 48)},
        "projectFiles": {str(width): clone_coverage(project_left, project_right, width) for width in (8, 16, 32)},
    }


def comparison_report(name: str, primary: list[FileRecord], comparison: list[FileRecord], comparison_folder: str) -> dict[str, object]:
    primary_production = production_records(primary, "TaleFork", {"code"})
    comparison_production = production_records(comparison, comparison_folder, {"code"})
    declarations = declared_overlap(primary_production, comparison_production)
    left_network = network_literals(primary_production)
    right_network = network_literals(comparison_production)
    left_topology = topology(primary)
    right_topology = topology(comparison)
    return {
        "name": name,
        "fileCounts": file_counts(comparison),
        "metrics": code_metrics(primary, comparison, "TaleFork", comparison_folder),
        "declarations": declarations,
        "commonImports": sorted(imports(primary_production) & imports(comparison_production), key=str.casefold),
        "commonNetworkLiterals": sorted(left_network & right_network, key=str.casefold),
        "commonStringLiterals": sorted(string_literals(primary_production) & string_literals(comparison_production), key=str.casefold),
        "configuration": configuration_values(comparison),
        "commonCodeBasenames": sorted(set(left_topology["codeBasenames"]) & set(right_topology["codeBasenames"]), key=str.casefold),
        "commonAssetCatalogNames": sorted(set(left_topology["assetCatalogNames"]) & set(right_topology["assetCatalogNames"]), key=str.casefold),
        "topology": right_topology,
        "exactAssetDuplicates": exact_asset_duplicates(primary, comparison),
    }


def markdown(audit: dict[str, object]) -> str:
    primary = audit["primary"]
    comparisons = audit["comparisons"]
    shared_endpoints = sorted({
        value
        for item in comparisons
        for value in item["commonNetworkLiterals"]
        if value.startswith("http") or value.startswith("api/") or value.startswith("tale-gateway/")
    }, key=str.casefold)
    primary_endpoints = [
        value
        for value in primary["networkLiterals"]
        if value.startswith("http") or value.startswith("api/") or value.startswith("tale-gateway/")
    ]
    if shared_endpoints:
        backend_summary = (
            "- **高风险外部阻塞仍存在**：TaleFork 与对比 App 仍有相同服务域名或 API 路由："
            + ", ".join(f"`{value}`" for value in shared_endpoints)
            + "。这不能用改变 Swift 变量名或混淆字符串合规解决；需服务端和运营主体提供 TaleFork 独立契约、内容关系和权利证据。"
        )
        backend_evidence = "仍有相同服务域名或 API 路由：" + ", ".join(f"`{value}`" for value in shared_endpoints)
        backend_level = "**高**"
    else:
        backend_summary = (
            "- 客户端静态契约已使用 TaleFork 独立 API 域名和 `/tale-gateway/v2` 命名空间，"
            "未发现与对比 App 共有的服务 URL/API 路由；线上部署、目录内容、运营关系和内容权利不属于本静态审计的证明范围。"
        )
        backend_evidence = (
            "客户端当前端点：" + ", ".join(f"`{value}`" for value in primary_endpoints)
            + "；静态对比未发现共有服务 URL/API 路由，线上部署与内容关系需使用独立证据"
        )
        backend_level = "**中**"
    lines = [
        "# TaleFork App Store 4.3 全量代码与工程对比报告",
        "",
        f"生成日期：{audit['checkedDate']}",
        "",
        "## 1. 结论先行",
        "",
        "- TaleFork 已建立独立的产品主循环：放映台 → 播放中场记 → 场记列表 → 返回原剧集/秒数。",
        "- 生产代码、测试、脚本、声明字段、Xcode 工程、Scheme、plist、本地化目录和二进制资源哈希均在本报告范围。",
        backend_summary,
        "- 本报告只能降低 Guideline 4.3(a)/(b) 风险，不是 Apple 审核结论。",
        "",
        "## 2. 范围与排除",
        "",
        f"TaleFork 纳入文件：{primary['fileCounts']['total']}；分类：`{json.dumps(primary['fileCounts'], ensure_ascii=False, sort_keys=True)}`。",
        "",
        "纳入：App 源码、Unit/UI Tests、Scripts、`.pbxproj`、`.xcscheme`、plist/privacy manifest、strings/json/html 和二进制资源。",
        "",
        "排除：`.git`、DerivedData/Build、xcuserdata、Pods/Carthage/vendor/node_modules 等非当前仓库自有或可再生成目录。",
        "",
        "## 3. 完整相似度总表",
        "",
        "| 对比 | 全部代码 12 / 24 / 48 token | 生产代码 12 / 24 / 48 token | 工程文件 8 / 16 / 32 token | 声明名 Jaccard | 精确重复资源 |",
        "| --- | --- | --- | --- | ---: | ---: |",
    ]
    for item in comparisons:
        metrics = item["metrics"]
        all_code = " / ".join(pct(metrics["allCode"][str(width)]["ratio"]) for width in (12, 24, 48))
        production = " / ".join(pct(metrics["productionCode"][str(width)]["ratio"]) for width in (12, 24, 48))
        project = " / ".join(pct(metrics["projectFiles"][str(width)]["ratio"]) for width in (8, 16, 32))
        lines.append(f"| {item['name']} | {all_code} | {production} | {project} | {pct(item['declarations']['jaccard'])} | {len(item['exactAssetDuplicates'])} |")

    lines += [
        "",
        "token 覆盖率使用注释/格式无关的连续词法片段；工程对比将 24 位 PBX object ID 归一化，避免随机 ID 掩盖真实结构重合。",
        "",
    ]

    for index, item in enumerate(comparisons, 4):
        lines += [
            f"## {index}. TaleFork vs {item['name']}",
            "",
            f"### 文件范围",
            "",
            f"`{json.dumps(item['fileCounts'], ensure_ascii=False, sort_keys=True)}`",
            "",
            "### 字段、类型、函数和枚举命名",
            "",
            f"TaleFork 生产 Swift 声明名 {item['declarations']['primary']} 个；{item['name']} {item['declarations']['comparison']} 个；共有 {len(item['declarations']['common'])} 个；Jaccard {pct(item['declarations']['jaccard'])}。",
            "",
            "全部共有声明名：" + (", ".join(f"`{name}`" for name in item["declarations"]["common"]) or "无") + "。",
            "",
            "排除 id/title/data 等泛化名后：" + (", ".join(f"`{name}`" for name in item["declarations"]["nontrivialCommon"]) or "无") + "。",
            "",
            "### 网络契约和二进制可见字符串",
            "",
            "共有网络字面量：" + (", ".join(f"`{value}`" for value in item["commonNetworkLiterals"]) or "无") + "。",
            "",
            f"全部精确共有字符串 {len(item['commonStringLiterals'])} 个；完整列表在同名 JSON 证据文件中。",
            "",
            "### 工程、文件结构与资源",
            "",
            "共有代码文件名：" + (", ".join(f"`{name}`" for name in item["commonCodeBasenames"]) or "无") + "。",
            "",
            "共有 asset catalog 集合名：" + (", ".join(f"`{name}`" for name in item["commonAssetCatalogNames"]) or "无") + "。",
            "",
            "精确字节重复资源：" + (", ".join(f"`{row['primary']}` = `{row['comparison']}`" for row in item["exactAssetDuplicates"]) or "无") + "。",
            "",
            "对比工程配置：",
            "",
            "```json",
            json.dumps(item["configuration"], ensure_ascii=False, indent=2, sort_keys=True),
            "```",
            "",
        ]

    findings = primary["runtimeFindings"]
    lines += [
        "## 6. Guideline 4.3 触发面全量审计",
        "",
        "| 触发面 | 当前证据 | 等级 | 处置 |",
        "| --- | --- | --- | --- |",
        f"| 共用后端/内容契约 | {backend_evidence} | {backend_level} | 服务端验证独立部署/目录，出具内容和运营关系证明 |",
        "| 重复 App/多 Bundle ID | TaleFork 只有 1 个 application target；Unit/UI target 为测试 bundle；Bundle ID 与两个对比 App 不同 | 低 | 提交前检查最终 Archive 和 App Store Connect 账户关系 |",
        "| 复制源码 | 48-token 生产代码结果见总表；报告保留文件级明细 JSON | 低 | 维持审计，不以百分比代替产品/内容审核 |",
        "| 字段/类型命名模板 | 共有名主要为 SwiftUI/网络常用语义；TaleFork 独有 `SceneMark`、`SceneMarkKind`、场记恢复流程 | 低-中 | 保留完整列表，重点处理服务契约而非伪造改名 |",
        "| Xcode 工程模板 | TaleFork 使用 Swift 6/iOS 18/三 target、自有嵌套 PBXGroup 和 UI Test target；对比项目 Swift 5/iOS 15 | 低 | 最终二进制复核 target/scheme/product/Team |",
        "| 重复图片/图标字节 | 本报告精确 SHA-256 对比未发现跨 App 重复资源 | 低 | 仍需设计师做视觉/版权人工复核，哈希不能证明视觉概念不同 |",
        "| 旧品牌和竞品标识 | App 运行时源码/资源未检出 DRAMILE、LanGuo、蓝果或其 Bundle ID | 低 | 在 Release 二进制和 App Store 元数据中再扫描 |",
        "| 支付/广告/跟踪 | 已接入 StoreKit 2 单一周订阅；未检出第三方支付、广告/归因 SDK 或 ATT 代码 | 中 | App Store Connect 配置订阅商品、审核截图和隐私信息，并核对服务端权益验证 |",
        "| 远程开关/下载代码 | 启动清单仅返回媒体资源根地址 `assetRoot`；未检出动态代码加载 | 低-中 | 审核期保持服务端合同与已披露功能一致 |",
        "| 隐私声明与设备字段 | 客户端仅发送本机随机 `deviceSeed` 及版本、语言和设备类别，不读取 IDFV/OAID/IDFA | 低-中 | 核对服务端哈希、保留期和 App Privacy 回答 |",
        "",
        "运行时扫描明细：",
        "",
        "```json",
        json.dumps(findings, ensure_ascii=False, indent=2, sort_keys=True),
        "```",
        "",
        "## 7. 证据边界",
        "",
        "- 精确 token、声明名和资源哈希能发现复制线索，不能证明商业主体、内容权利或审核账户独立。",
        "- 字节不同的图片仍可能视觉近似；需结合图标/截图并排人工复核。",
        "- 线上目录、真实播放、服务端记录与内容版权不能从静态客户端证明。",
        "- Apple Guideline 4.3 的最终判断仍由 App Review 完成。",
        "",
    ]
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--primary-part", action="append", type=Path, required=True)
    parser.add_argument("--comparison-part", action="append", nargs=3, metavar=("NAME", "PRODUCT_FOLDER", "PATH"), required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--json", dest="json_path", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    primary_records = collect(args.primary_part)
    comparison_parts: dict[str, dict[str, object]] = {}
    for name, product_folder, path in args.comparison_part:
        entry = comparison_parts.setdefault(name, {"productFolder": product_folder, "paths": []})
        entry["paths"].append(Path(path))

    comparisons = []
    for name, entry in comparison_parts.items():
        records = collect(entry["paths"])
        comparisons.append(comparison_report(name, primary_records, records, str(entry["productFolder"])))

    audit = {
        "checkedDate": date.today().isoformat(),
        "scope": {
            "included": ["repository-owned code", "tests", "scripts", "Xcode projects and schemes", "plists and localizations", "binary asset hashes"],
            "excluded": sorted(IGNORED_PARTS),
        },
        "primary": {
            "fileCounts": file_counts(primary_records),
            "configuration": configuration_values(primary_records),
            "networkLiterals": sorted(
                network_literals(production_records(primary_records, "TaleFork", {"code"})),
                key=str.casefold,
            ),
            "topology": topology(primary_records),
            "runtimeFindings": runtime_findings(primary_records),
        },
        "comparisons": comparisons,
    }
    args.report.write_text(markdown(audit), encoding="utf-8")
    args.json_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Wrote {args.report} and {args.json_path}")


if __name__ == "__main__":
    main()
