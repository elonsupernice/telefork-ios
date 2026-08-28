# TaleFork / DRAMILE / LanGuoNext 全量相似度摘要

生成日期：2026-08-29

本文件是结论摘要。完整文件级结果、全部共有字符串、Swift 类型/函数/属性/枚举名、PBX/Schema/plist/privacy manifest、资源目录和 SHA-256 证据见：

- `APP-STORE-4.3-FULL-AUDIT.md`
- `QA/APP-STORE-4.3-FULL-AUDIT.json`
- 可复验脚本：`Scripts/audit_app_store_43.py`

## 范围

TaleFork 纳入 App 源码、Unit/UI Tests、Scripts、Xcode project/scheme、plist/privacy manifest、本地化、HTML/JSON 和二进制资源。对比仓库只读；排除 Git、DerivedData/Build、xcuserdata 和 vendored dependencies。

连续 token 覆盖率忽略注释和格式。工程文件会把随机 24 位 PBX object ID 归一化，避免随机 ID 虚假降低结构重合。它是克隆线索，不是 Apple 的审核算法。

## 结果

| 对比 | 全部代码 12 / 24 / 48 token | 生产代码 12 / 24 / 48 token | 工程 8 / 16 / 32 token | 声明名 Jaccard | 精确重复资源 |
| --- | --- | --- | --- | ---: | ---: |
| DRAMILE | 7.46% / 0.80% / 0.00% | 10.84% / 1.18% / 0.00% | 80.43% / 61.54% / 22.57% | 5.65% | 0 |
| LanGuoNext | 5.77% / 0.51% / 0.00% | 8.36% / 0.75% / 0.00% | 80.38% / 61.51% / 24.02% | 8.08% | 0 |

工程短 token 重合主要来自 Xcode schema、Info.plist 和 PrivacyInfo 标准键；32-token 文件级明细显示 TaleFork `project.pbxproj` 与对比工程的覆盖率明显低于标准 plist/privacy 文件。TaleFork 本身使用 Swift 6、iOS 18、App + Unit + UI 三 target、自有嵌套 PBXGroup 和独立 Bundle ID。

内部重复感较强的 `AppShellView`、`AppTab`、`DramaPlayerView.swift`、`SettingsView.swift` 和通用目录 DTO 已改为 TaleFork 语义的 workspace、Moment Player、Story Studio 和 screenings 类型。最终与 LanGuoNext 的共有代码文件名只剩法律页 `privacy-policy.html`；与 DRAMILE 同样只剩该通用法律文件名。

## 客户端服务契约与外部证据边界

TaleFork 客户端当前使用独立生产端点：

- `https://app.duanjufafafa.fun/`
- `GET /tale-gateway/v2/heartbeat`（契约路由，不在 App 启动时主动调用）
- `POST /tale-gateway/v2/identity/device-pass`
- `POST /tale-gateway/v2/launch/manifest`
- `POST /tale-gateway/v2/screenings/lineup`
- `POST /tale-gateway/v2/screenings/search`
- `DELETE /tale-gateway/v2/identity/device-pass`
- 鉴权头：`X-TaleFork-Edition: talefork-ios-r2`；建立通行证后的请求使用 `X-TaleFork-Pass`
- 媒体公开路径：`{assetRoot}stories/{storyKey}/reels/{chapter}/playback.mp4`
- 封面：服务端 `artworkLink`（`/tale-assets/artwork/...`）

本轮静态审计未发现 TaleFork 与 DRAMILE/LanGuoNext 共有的服务 URL 或 API 路由。服务端任务另行报告新域名和正式路径已部署；该证据与客户端静态结果都不能证明目录和内容权利独立。正式提审前仍需保留服务端部署/数据边界证据、内容权利材料和三款 App 关系说明。

## 证据边界

48-token 生产代码为 0、资源哈希不同、工程和声明名不同，都不能证明商业主体、剧目版权、封面权利、服务端行为或 App Store 元数据独立。视觉近似也不能仅由 SHA-256 排除；仍需设计与法务人工复核。
