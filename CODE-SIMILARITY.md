# TaleFork / Dramile Swift 代码相似度审计

生成日期：2026-08-10

## 口径

- 比较对象：`TaleFork` 与 `/Users/apple/Downloads/触说项目/dramile/Dramile`
- 基础指标：连续 12 个 Swift 精确词法单元的克隆覆盖率，用于发现短代码复用
- 长片段指标：连续 24 个 Swift 精确词法单元的克隆覆盖率，用于识别更有意义的整段复用
- 深度指标：连续 48 个 Swift 精确词法单元的克隆覆盖率，用于定位接近整段复制的实现
- 忽略：注释、空格、换行、测试代码、构建产物
- 保留：类型名、变量名、方法名、字符串、数字、运算符与 Swift 关键字
- “产品层”另行排除双方网络请求、Endpoint 与 Repository 文件，用于隔离必要服务端协议
- 本报告只用于发现代码克隆，不代表 Apple 的 4.3 审核算法或审核结论

## 结果

| 范围 | TaleFork token 数 | 短片段命中/覆盖率 | 长片段命中/覆盖率 | 深度命中/覆盖率 |
| --- | ---: | ---: | ---: | ---: |
| 全部 App Swift 源码 | 16220 | 1666 / 10.27% | 199 / 1.23% | 58 / 0.36% |
| 排除必要网络协议层 | 13900 | 1290 / 9.28% | 39 / 0.28% | 0 / 0.00% |

## TaleFork 文件级最高匹配

| TaleFork 文件 | 最接近的 Dramile 文件 | 该文件精确覆盖率 | 命中/总 token |
| --- | --- | ---: | ---: |
| `Features/Onboarding/OnboardingView.swift` | `Features/Theater/TheaterView.swift` | 12.17% | 114/937 |
| `Data/TaleForkService.swift` | `Core/Networking/HTTPClient.swift` | 7.54% | 175/2320 |
| `Features/Paths/PathsView.swift` | `Features/Theater/TheaterView.swift` | 6.63% | 80/1206 |
| `Features/Settings/SettingsView.swift` | `Features/Theater/TheaterView.swift` | 6.41% | 81/1263 |
| `DesignSystem/TaleForkTheme.swift` | `Features/Shell/DramaCard.swift` | 5.39% | 68/1262 |
| `Features/Vault/VaultView.swift` | `Features/Profile/ProfileView.swift` | 5.05% | 38/753 |
| `Shared/LocalLegalView.swift` | `Features/Theater/TheaterView.swift` | 4.17% | 12/288 |
| `Features/Explore/ExploreView.swift` | `Features/Theater/TheaterView.swift` | 4.16% | 111/2671 |
| `Features/Player/DramaPlayerView.swift` | `Features/Home/ImmersiveFeedView.swift` | 3.21% | 115/3587 |
| `Data/ProgressStore.swift` | `Core/Persistence/AppStorageStore.swift` | 1.99% | 15/755 |
| `Domain/DramaModels.swift` | `-` | 0.00% | 0/456 |
| `App/AppRootView.swift` | `-` | 0.00% | 0/456 |

## 解读边界

服务端 URL、Endpoint 名称、JSON 字段、HTTP 请求头以及 Apple/SwiftUI/AVFoundation 固定 API 可能形成必要重合。产品差异还必须结合信息架构、视觉资产、交互流程、内容权利和商店资料人工核验，不能只看单一百分比。
