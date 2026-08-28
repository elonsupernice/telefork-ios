#!/usr/bin/env python3
"""Measure exact Swift token-clone coverage between TaleFork and another source tree.

This is an engineering audit, not a prediction of App Review behavior. Comments and
formatting are ignored, while identifiers, literals, operators, and Swift keywords
remain significant. A token is counted as matched when it belongs to an exact token
shingle that also appears in the comparison tree.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
from dataclasses import dataclass
from pathlib import Path


TOKEN = re.compile(
    r'"(?:\\.|[^"\\])*"|'
    r"'(?:\\.|[^'\\])*'|"
    r"[A-Za-z_][A-Za-z0-9_]*|"
    r"\d+(?:\.\d+)?|"
    r"->|==|!=|<=|>=|&&|\|\||\?\?|\.\.\.|\.\.<|"
    r"[{}()\[\].,:;?@#\\+\-*/%<>=!&|^~]"
)


@dataclass(frozen=True)
class SourceUnit:
    path: Path
    tokens: tuple[str, ...]


def strip_comments(source: str) -> str:
    output: list[str] = []
    index = 0
    depth = 0
    while index < len(source):
        pair = source[index:index + 2]
        if depth:
            if pair == "/*":
                depth += 1
                index += 2
            elif pair == "*/":
                depth -= 1
                index += 2
            else:
                index += 1
            continue
        if pair == "//":
            newline = source.find("\n", index + 2)
            index = len(source) if newline < 0 else newline
            continue
        if pair == "/*":
            depth = 1
            index += 2
            continue
        if source[index] in {'"', "'"}:
            quote = source[index]
            start = index
            index += 1
            while index < len(source):
                if source[index] == "\\":
                    index += 2
                elif source[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            output.append(source[start:index])
            continue
        output.append(source[index])
        index += 1
    return "".join(output)


def units(root: Path) -> list[SourceUnit]:
    ignored = {"Tests", "Build", "DerivedData", ".build", ".git"}
    result: list[SourceUnit] = []
    for path in sorted(root.rglob("*.swift")):
        if any(part in ignored or part.endswith("Tests") for part in path.parts):
            continue
        content = path.read_text(encoding="utf-8", errors="ignore")
        result.append(SourceUnit(path.relative_to(root), tuple(TOKEN.findall(strip_comments(content)))))
    return result


def shingles(tokens: tuple[str, ...], width: int) -> set[tuple[str, ...]]:
    if len(tokens) < width:
        return set()
    return {tokens[index:index + width] for index in range(len(tokens) - width + 1)}


def covered_positions(tokens: tuple[str, ...], reference: set[tuple[str, ...]], width: int) -> set[int]:
    covered: set[int] = set()
    for index in range(max(len(tokens) - width + 1, 0)):
        if tokens[index:index + width] in reference:
            covered.update(range(index, index + width))
    return covered


def is_contract_file(path: Path) -> bool:
    value = path.as_posix().lower()
    return any(marker in value for marker in (
        "taleforkservice.swift",
        "/networking/",
        "/repositories/",
        "apiendpoint.swift",
        "httpclient.swift",
    ))


def analyze(primary: list[SourceUnit], comparison: list[SourceUnit], width: int) -> dict[str, object]:
    reference_by_file = {unit.path: shingles(unit.tokens, width) for unit in comparison}
    reference_all = set().union(*reference_by_file.values()) if reference_by_file else set()
    total_tokens = sum(len(unit.tokens) for unit in primary)
    matched_tokens = 0
    file_rows: list[tuple[float, int, int, Path, Path | None]] = []

    for unit in primary:
        covered = covered_positions(unit.tokens, reference_all, width)
        matched_tokens += len(covered)
        best_path: Path | None = None
        best_coverage = 0
        for other_path, other_shingles in reference_by_file.items():
            coverage = len(covered_positions(unit.tokens, other_shingles, width))
            if coverage > best_coverage:
                best_coverage = coverage
                best_path = other_path
        ratio = best_coverage / len(unit.tokens) if unit.tokens else 0
        file_rows.append((ratio, best_coverage, len(unit.tokens), unit.path, best_path))

    return {
        "tokens": total_tokens,
        "matched": matched_tokens,
        "ratio": matched_tokens / total_tokens if total_tokens else 0,
        "files": sorted(file_rows, reverse=True),
    }


def markdown_report(
    primary_root: Path,
    comparison_root: Path,
    primary_name: str,
    comparison_name: str,
    width: int,
    long_width: int,
    overall: dict[str, object],
    product: dict[str, object],
    long_overall: dict[str, object],
    long_product: dict[str, object],
    deep_overall: dict[str, object],
    deep_product: dict[str, object],
    deep_width: int,
) -> str:
    rows = overall["files"]
    assert isinstance(rows, list)
    lines = [
        f"# {primary_name} / {comparison_name} Swift 代码相似度审计",
        "",
        f"生成日期：{dt.date.today().isoformat()}",
        "",
        "## 口径",
        "",
        f"- 比较对象：`{primary_root}` 与 `{comparison_root}`",
        f"- 基础指标：连续 {width} 个 Swift 精确词法单元的克隆覆盖率，用于发现短代码复用",
        f"- 长片段指标：连续 {long_width} 个 Swift 精确词法单元的克隆覆盖率，用于识别更有意义的整段复用",
        f"- 深度指标：连续 {deep_width} 个 Swift 精确词法单元的克隆覆盖率，用于定位接近整段复制的实现",
        "- 忽略：注释、空格、换行、测试代码、构建产物",
        "- 保留：类型名、变量名、方法名、字符串、数字、运算符与 Swift 关键字",
        "- “产品层”另行排除双方网络请求、Endpoint 与 Repository 文件，用于隔离必要服务端协议",
        "- 本报告只用于发现代码克隆，不代表 Apple 的 4.3 审核算法或审核结论",
        "",
        "## 结果",
        "",
        f"| 范围 | {primary_name} token 数 | 短片段命中/覆盖率 | 长片段命中/覆盖率 | 深度命中/覆盖率 |",
        "| --- | ---: | ---: | ---: | ---: |",
        f"| 全部 App Swift 源码 | {overall['tokens']} | {overall['matched']} / {overall['ratio']:.2%} | {long_overall['matched']} / {long_overall['ratio']:.2%} | {deep_overall['matched']} / {deep_overall['ratio']:.2%} |",
        f"| 排除必要网络协议层 | {product['tokens']} | {product['matched']} / {product['ratio']:.2%} | {long_product['matched']} / {long_product['ratio']:.2%} | {deep_product['matched']} / {deep_product['ratio']:.2%} |",
        "",
        f"## {primary_name} 文件级最高匹配",
        "",
        f"| {primary_name} 文件 | 最接近的 {comparison_name} 文件 | 该文件精确覆盖率 | 命中/总 token |",
        "| --- | --- | ---: | ---: |",
    ]
    for ratio, matched, total, path, best in rows[:12]:
        lines.append(f"| `{path}` | `{best or '-'}` | {ratio:.2%} | {matched}/{total} |")
    lines += [
        "",
        "## 解读边界",
        "",
        "服务端 URL、Endpoint 名称、JSON 字段、HTTP 请求头以及 Apple/SwiftUI/AVFoundation 固定 API 可能形成必要重合。产品差异还必须结合信息架构、视觉资产、交互流程、内容权利和商店资料人工核验，不能只看单一百分比。",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("primary", type=Path, help="TaleFork Swift source root")
    parser.add_argument("comparison", type=Path, help="comparison Swift source root")
    parser.add_argument("--primary-name", default="TaleFork", help="primary product label used in the report")
    parser.add_argument("--comparison-name", default="Comparison", help="comparison product label used in the report")
    parser.add_argument("--width", type=int, default=12, help="exact token shingle width")
    parser.add_argument("--long-width", type=int, default=24, help="long exact token shingle width")
    parser.add_argument("--deep-width", type=int, default=48, help="deep exact token shingle width")
    parser.add_argument("--report", type=Path, help="optional Markdown report path")
    args = parser.parse_args()

    primary = units(args.primary.resolve())
    comparison = units(args.comparison.resolve())
    overall = analyze(primary, comparison, args.width)
    product = analyze(
        [unit for unit in primary if not is_contract_file(unit.path)],
        [unit for unit in comparison if not is_contract_file(unit.path)],
        args.width,
    )
    long_overall = analyze(primary, comparison, args.long_width)
    long_product = analyze(
        [unit for unit in primary if not is_contract_file(unit.path)],
        [unit for unit in comparison if not is_contract_file(unit.path)],
        args.long_width,
    )
    deep_overall = analyze(primary, comparison, args.deep_width)
    deep_product = analyze(
        [unit for unit in primary if not is_contract_file(unit.path)],
        [unit for unit in comparison if not is_contract_file(unit.path)],
        args.deep_width,
    )
    report = markdown_report(
        args.primary,
        args.comparison,
        args.primary_name,
        args.comparison_name,
        args.width,
        args.long_width,
        overall,
        product,
        long_overall,
        long_product,
        deep_overall,
        deep_product,
        args.deep_width,
    )
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()
