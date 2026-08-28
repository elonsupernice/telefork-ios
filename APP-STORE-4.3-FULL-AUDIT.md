# TaleFork App Store 4.3 全量代码与工程对比报告

生成日期：2026-08-29

## 1. 结论先行

- TaleFork 已建立独立的产品主循环：放映台 → 播放中场记 → 场记列表 → 返回原剧集/秒数。
- 生产代码、测试、脚本、声明字段、Xcode 工程、Scheme、plist、本地化目录和二进制资源哈希均在本报告范围。
- 客户端静态契约已使用 TaleFork 独立 API 域名和 `/tale-gateway/v2` 命名空间，未发现与对比 App 共有的服务 URL/API 路由；线上部署、目录内容、运营关系和内容权利不属于本静态审计的证明范围。
- 本报告只能降低 Guideline 4.3(a)/(b) 风险，不是 Apple 审核结论。

## 2. 范围与排除

TaleFork 纳入文件：50；分类：`{"binary": 1, "code": 30, "image": 2, "project": 4, "resource-text": 13, "total": 50}`。

纳入：App 源码、Unit/UI Tests、Scripts、`.pbxproj`、`.xcscheme`、plist/privacy manifest、strings/json/html 和二进制资源。

排除：`.git`、DerivedData/Build、xcuserdata、Pods/Carthage/vendor/node_modules 等非当前仓库自有或可再生成目录。

## 3. 完整相似度总表

| 对比 | 全部代码 12 / 24 / 48 token | 生产代码 12 / 24 / 48 token | 工程文件 8 / 16 / 32 token | 声明名 Jaccard | 精确重复资源 |
| --- | --- | --- | --- | ---: | ---: |
| DRAMILE | 7.68% / 0.87% / 0.00% | 11.12% / 1.28% / 0.00% | 80.88% / 61.53% / 22.32% | 6.55% | 0 |
| LanGuoNext | 5.54% / 0.46% / 0.00% | 7.99% / 0.68% / 0.00% | 80.58% / 61.51% / 23.02% | 8.57% | 0 |

token 覆盖率使用注释/格式无关的连续词法片段；工程对比将 24 位 PBX object ID 归一化，避免随机 ID 掩盖真实结构重合。

## 4. TaleFork vs DRAMILE

### 文件范围

`{"binary": 1, "code": 63, "image": 4, "project": 4, "resource-text": 24, "total": 96}`

### 字段、类型、函数和枚举命名

TaleFork 生产 Swift 声明名 390 个；DRAMILE 879 个；共有 78 个；Jaccard 6.55%。

全部共有声明名：`asset`, `available`, `benefit`, `body`, `build`, `cardRadius`, `catalog`, `CodingKeys`, `content`, `continueWatching`, `data`, `defaults`, `deleteLocalAccount`, `detail`, `dismiss`, `document`, `drama`, `dramaID`, `dramas`, `episode`, `error`, `errorDescription`, `errorMessage`, `featured`, `header`, `height`, `history`, `http`, `id`, `identity`, `index`, `ink`, `invalidResponse`, `item`, `let`, `load`, `makeUIViewController`, `membership`, `minutes`, `number`, `onExit`, `outcome`, `page`, `player`, `privacy`, `refreshEntitlements`, `rejected`, `request`, `resolved`, `restorePurchases`, `result`, `retry`, `scenePhase`, `search`, `searchResults`, `seconds`, `seek`, `selectedEpisode`, `self`, `service`, `size`, `state`, `store`, `stored`, `stories`, `symbol`, `terms`, `timeText`, `title`, `togglePlayback`, `totalDuration`, `transaction`, `transactionListener`, `updateUIViewController`, `url`, `value`, `values`, `videoURL`。

排除 id/title/data 等泛化名后：`asset`, `available`, `benefit`, `build`, `cardRadius`, `catalog`, `CodingKeys`, `continueWatching`, `defaults`, `deleteLocalAccount`, `detail`, `dismiss`, `document`, `drama`, `dramaID`, `dramas`, `episode`, `errorDescription`, `errorMessage`, `featured`, `header`, `height`, `history`, `http`, `identity`, `ink`, `invalidResponse`, `let`, `load`, `makeUIViewController`, `membership`, `minutes`, `number`, `onExit`, `outcome`, `page`, `player`, `privacy`, `refreshEntitlements`, `rejected`, `resolved`, `restorePurchases`, `retry`, `scenePhase`, `search`, `searchResults`, `seconds`, `seek`, `selectedEpisode`, `self`, `service`, `size`, `store`, `stored`, `stories`, `symbol`, `terms`, `timeText`, `togglePlayback`, `totalDuration`, `transaction`, `transactionListener`, `updateUIViewController`, `videoURL`。

### 网络契约和二进制可见字符串

共有网络字面量：`CFBundleShortVersionString`, `CFBundleVersion`, `Content-Type`, `POST`。

全部精确共有字符串 36 个；完整列表在同名 JSON 证据文件中。

### 工程、文件结构与资源

共有代码文件名：`privacy-policy.html`。

共有 asset catalog 集合名：`AccentColor.colorset`, `AppIcon.appiconset`。

精确字节重复资源：无。

对比工程配置：

```json
{
  "ASSETCATALOG_COMPILER_APPICON_NAME": [
    "AppIcon"
  ],
  "CFBundleDisplayName": [
    "\"Dramile\""
  ],
  "CFBundleIdentifier": [
    "\"$(PRODUCT_BUNDLE_IDENTIFIER)\""
  ],
  "CFBundleName": [
    "\"$(PRODUCT_NAME)\""
  ],
  "CURRENT_PROJECT_VERSION": [
    "20260825223001"
  ],
  "INFOPLIST_FILE": [
    "Dramile/Resources/Info.plist"
  ],
  "IPHONEOS_DEPLOYMENT_TARGET": [
    "15.0"
  ],
  "MARKETING_VERSION": [
    "1.0.0"
  ],
  "PRODUCT_BUNDLE_IDENTIFIER": [
    "com.dramile.app.ai",
    "com.dramile.app.ai.tests"
  ],
  "PRODUCT_NAME": [
    "$(TARGET_NAME)"
  ],
  "SWIFT_VERSION": [
    "5.0"
  ],
  "TARGETED_DEVICE_FAMILY": [
    "1"
  ]
}
```

## 5. TaleFork vs LanGuoNext

### 文件范围

`{"code": 51, "image": 27, "project": 4, "resource-text": 24, "total": 106}`

### 字段、类型、函数和枚举命名

TaleFork 生产 Swift 声明名 390 个；LanGuoNext 509 个；共有 71 个；Jaccard 8.57%。

全部共有声明名：`appContent`, `asset`, `baseURL`, `benefit`, `body`, `cardRadius`, `CodingKeys`, `content`, `continueWatching`, `controlsVisible`, `coverURL`, `data`, `decoding`, `defaults`, `detail`, `document`, `drama`, `Drama`, `dramaID`, `dramas`, `emptyState`, `encode`, `envelope`, `episode`, `episodeStatus`, `error`, `errorDescription`, `featured`, `freeEpisodeCount`, `history`, `http`, `id`, `image`, `ink`, `invalidResponse`, `item`, `let`, `load`, `makeUIViewController`, `page`, `paper`, `player`, `post`, `request`, `restore`, `restorePurchases`, `result`, `results`, `retry`, `scenePhase`, `search`, `seconds`, `seek`, `selectedEpisode`, `selectEpisode`, `selection`, `self`, `server`, `size`, `start`, `state`, `store`, `stored`, `title`, `toggleControls`, `togglePlayback`, `updateUIViewController`, `url`, `value`, `values`, `videoURL`。

排除 id/title/data 等泛化名后：`appContent`, `asset`, `baseURL`, `benefit`, `cardRadius`, `CodingKeys`, `continueWatching`, `controlsVisible`, `coverURL`, `decoding`, `defaults`, `detail`, `document`, `drama`, `Drama`, `dramaID`, `dramas`, `emptyState`, `encode`, `envelope`, `episode`, `episodeStatus`, `errorDescription`, `featured`, `freeEpisodeCount`, `history`, `http`, `ink`, `invalidResponse`, `let`, `load`, `makeUIViewController`, `page`, `paper`, `player`, `post`, `restore`, `restorePurchases`, `retry`, `scenePhase`, `search`, `seconds`, `seek`, `selectedEpisode`, `selectEpisode`, `selection`, `self`, `server`, `size`, `start`, `store`, `stored`, `toggleControls`, `togglePlayback`, `updateUIViewController`, `videoURL`。

### 网络契约和二进制可见字符串

共有网络字面量：`CFBundleShortVersionString`, `CFBundleVersion`, `Content-Type`, `fil`, `POST`, `zh-Hans`, `zh-Hant`。

全部精确共有字符串 37 个；完整列表在同名 JSON 证据文件中。

### 工程、文件结构与资源

共有代码文件名：`privacy-policy.html`。

共有 asset catalog 集合名：`AccentColor.colorset`, `AppIcon.appiconset`。

精确字节重复资源：无。

对比工程配置：

```json
{
  "ASSETCATALOG_COMPILER_APPICON_NAME": [
    "AppIcon"
  ],
  "CFBundleDisplayName": [
    "\"DRAMILE\""
  ],
  "CFBundleIdentifier": [
    "\"$(PRODUCT_BUNDLE_IDENTIFIER)\""
  ],
  "CFBundleName": [
    "\"$(PRODUCT_NAME)\""
  ],
  "CURRENT_PROJECT_VERSION": [
    "1"
  ],
  "INFOPLIST_FILE": [
    "LanGuoNext/Resources/Info.plist"
  ],
  "IPHONEOS_DEPLOYMENT_TARGET": [
    "15.0"
  ],
  "MARKETING_VERSION": [
    "1.0.0"
  ],
  "PRODUCT_BUNDLE_IDENTIFIER": [
    "com.lah.jhs",
    "com.lah.jhs.tests"
  ],
  "PRODUCT_NAME": [
    "$(TARGET_NAME)"
  ],
  "SWIFT_VERSION": [
    "5.0"
  ],
  "TARGETED_DEVICE_FAMILY": [
    "1"
  ]
}
```

## 6. Guideline 4.3 触发面全量审计

| 触发面 | 当前证据 | 等级 | 处置 |
| --- | --- | --- | --- |
| 共用后端/内容契约 | 客户端当前端点：`https://app.duanjufafafa.fun/`, `tale-gateway/v2/heartbeat`, `tale-gateway/v2/identity/device-pass`, `tale-gateway/v2/launch/manifest`, `tale-gateway/v2/screenings/lineup`, `tale-gateway/v2/screenings/search`；静态对比未发现共有服务 URL/API 路由，线上部署与内容关系需使用独立证据 | **中** | 服务端验证独立部署/目录，出具内容和运营关系证明 |
| 重复 App/多 Bundle ID | TaleFork 只有 1 个 application target；Unit/UI target 为测试 bundle；Bundle ID 与两个对比 App 不同 | 低 | 提交前检查最终 Archive 和 App Store Connect 账户关系 |
| 复制源码 | 48-token 生产代码结果见总表；报告保留文件级明细 JSON | 低 | 维持审计，不以百分比代替产品/内容审核 |
| 字段/类型命名模板 | 共有名主要为 SwiftUI/网络常用语义；TaleFork 独有 `SceneMark`、`SceneMarkKind`、场记恢复流程 | 低-中 | 保留完整列表，重点处理服务契约而非伪造改名 |
| Xcode 工程模板 | TaleFork 使用 Swift 6/iOS 18/三 target、自有嵌套 PBXGroup 和 UI Test target；对比项目 Swift 5/iOS 15 | 低 | 最终二进制复核 target/scheme/product/Team |
| 重复图片/图标字节 | 本报告精确 SHA-256 对比未发现跨 App 重复资源 | 低 | 仍需设计师做视觉/版权人工复核，哈希不能证明视觉概念不同 |
| 旧品牌和竞品标识 | App 运行时源码/资源未检出 DRAMILE、LanGuo、蓝果或其 Bundle ID | 低 | 在 Release 二进制和 App Store 元数据中再扫描 |
| 支付/广告/跟踪 | 已接入 StoreKit 2 单一周订阅；未检出第三方支付、广告/归因 SDK 或 ATT 代码 | 中 | App Store Connect 配置订阅商品、审核截图和隐私信息，并核对服务端权益验证 |
| 远程开关/下载代码 | 启动清单仅返回媒体资源根地址 `assetRoot`；未检出动态代码加载 | 低-中 | 审核期保持服务端合同与已披露功能一致 |
| 隐私声明与设备字段 | 客户端仅发送本机随机 `deviceSeed` 及版本、语言和设备类别，不读取 IDFV/OAID/IDFA | 低-中 | 核对服务端哈希、保留期和 App Privacy 回答 |

运行时扫描明细：

```json
{
  "payments": [
    "TaleFork/Features/Explore/ExploreView.swift:342: : Text(\"membership.vip.badge\")",
    "TaleFork/Features/Explore/ExploreView.swift:367: Label(\"membership.vip.badge\", systemImage: \"lock.fill\")",
    "TaleFork/Features/Membership/MembershipAccess.swift:4: static let weeklyProductID = \"com.talefork.storypaths.vip.weekly\"",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:1: import StoreKit",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:7: @State private var purchaseMessage: LocalizedStringKey?",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:14: SubscriptionStoreView(productIDs: [MembershipAccess.weeklyProductID])",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:15: .subscriptionStoreControlStyle(.buttons)",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:16: .subscriptionStoreButtonLabel(.multiline)",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:20: .subscriptionStorePolicyDestination(for: .privacyPolicy) {",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:23: .subscriptionStorePolicyDestination(for: .termsOfService) {",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:32: purchaseMessage = \"membership.purchase.pending\"",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:36: purchaseMessage = \"membership.purchase.unverified\"",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:38: purchaseMessage = \"membership.purchase.failed\"",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:40: purchaseMessage = \"membership.purchase.failed\"",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:57: .alert(\"membership.purchase.status\", isPresented: purchaseMessageBinding) {",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:58: Button(\"common.done\") { purchaseMessage = nil }",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:60: if let purchaseMessage { Text(purchaseMessage) }",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:92: private var purchaseMessageBinding: Binding<Bool> {",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:94: get: { purchaseMessage != nil },",
    "TaleFork/Features/Membership/MembershipPaywallView.swift:95: set: { if !$0 { purchaseMessage = nil } }",
    "TaleFork/Features/Membership/MembershipStore.swift:2: import StoreKit",
    "TaleFork/Features/Player/MomentPlayerView.swift:587: Label(\"membership.vip.badge\", systemImage: \"lock.fill\")"
  ]
}
```

## 7. 证据边界

- 精确 token、声明名和资源哈希能发现复制线索，不能证明商业主体、内容权利或审核账户独立。
- 字节不同的图片仍可能视觉近似；需结合图标/截图并排人工复核。
- 线上目录、真实播放、服务端记录与内容版权不能从静态客户端证明。
- Apple Guideline 4.3 的最终判断仍由 App Review 完成。
