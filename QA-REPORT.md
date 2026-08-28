# TaleFork 1.0.0 验证报告

检查日期：2026-08-29

## 结论

TaleFork 已完成客户端侧 App Store 4.3 差异化改造，并在 iPhone 17 / iOS 26.5 模拟器上跑通完整离线 Unit/UI 套件。产品、顶层导航、播放器一级操作、本地数据模型、工程分组和测试 target 已转为 TaleFork 的“故事场记”表达。

客户端功能回归没有发现失败项。生产 API 已同步 TaleFork Mobile Contract v2：`/tale-gateway/v2` 路由、设备通行证请求头、统一响应包、screenings DTO 和 stories/reels 媒体路径均已进入生产代码与 Release 产物；服务端任务报告 v2 已部署，但本 iOS 任务未重复线上调用。仍不能表述为“已经可上架”，因为内容权利、服务端隐私行为、真机、签名和 App Store Connect 尚未完整验证。

## 2026-08-27 VIP 增量验证

- 第 1～10 集免费、第 11 集起锁定的纯规则测试通过；播放器加载、选集、自动下一集、详情选集、续看与场记恢复均接入统一会员校验。
- StoreKit 2 购买页仅配置一个 `P1W` 自动续费产品 `com.talefork.storypaths.vip.weekly`；本地测试价为 US$9.90，正式界面价格由 Apple 本地化展示。
- 购买页提供恢复购买、取消订阅、隐私政策和使用条款；pending、未验证和失败结果不会解锁内容。
- Debug Simulator build、11 项离线单元测试、5 项 UI 测试和 Release iPhoneOS 无签名构建通过；1 项线上 opt-in 测试保持跳过，未访问线上 API、未注册游客或播放线上内容。
- 仍需在 App Store Connect 建立并随 App 版本提交该订阅，完成价格点、税务/银行协议、区域、本地化与审核截图；当前证据不是 Sandbox/TestFlight 真实购买成功证明。

## 仓库与边界

- 实际仓库：`origin=https://gitee.com/aolinuoke_1/telefork-ios-2.git`，分支 `main`，改造起点 HEAD `5d5630df3727188ea5cd3033d3c42fbf090fbf74`。
- 保留用户未跟踪的 `CODEX-TASK-APP-STORE-4.3.md`；DRAMILE 与 LanGuoNext 仅只读对比。
- 验证阶段未访问线上 API、未注册访客、未播放线上视频、未签名、未 Archive 或打包；Git 提交与推送只发布已验证源码和文档。
- 生产 API Base URL 已切换为 `https://app.duanjufafafa.fun/`；移除全局 `NSAllowsArbitraryLoads`，Debug 仍可通过 `TALEFORK_SERVICE_BASE_URL` 做显式离线覆盖。
- UI 自动化使用 `#if DEBUG` 的本地目录和 `talefork-preview` 合成播放时钟；这些 fixture 字符串未进入 Release 可执行文件。

## 构建与自动化证据

- 工具：Xcode 26.6（Build 17F113）、iOS 26.5 SDK、Swift 6.3.3。
- 工程：1 个 application target + Unit/UI test target，Swift 6、iOS 18.0、iPhone-only，Team 留空。
- iPhone 17 模拟器 `B9D3D88A-4433-4A06-9BF3-8D8142F35076`，iOS 26.5。
- Unit：`/tmp/talefork-push-tests/Logs/Test/Test-TaleFork-2026.08.28_23-59-23-+0800.xcresult`，11 passed、1 skipped、0 failed。跳过项是必须显式设置 `TALEFORK_RUN_LIVE_TESTS=1` 的线上目录/访客/播放测试。
- UI：同一 `.xcresult`，5 passed、0 failed。覆盖四个一级 Tab、场记保存/重启恢复、界面宽度适配，以及首页隐藏单集短剧。
- UI 测试第一次暴露半屏表单输入项在屏外，已将测试改为真实滚动后输入；最终完整套件重新通过。
- Xcode 输出过 `IDELaunchParametersSnapshot: no debugger version` 和系统 WebKit accessibility 重复类警告，最终 `.xcresult` 无失败；这是当前 Xcode/Simulator 环境警告，不是 App 断言失败。
- Release iPhoneOS 无签名构建成功：`/tmp/talefork-push-release/Build/Products/Release-iphoneos/TaleFork.app`。
- Release 信息：arm64、Bundle ID `com.talefork.storypaths`、版本 1.0.0 (1)、`UIDeviceFamily=[1]`；只链接 Apple 系统框架。
- Release 二进制未命中 Debug fixture、DRAMILE、LanGuo、蓝果、`com.dramile` 或 `com.lah` 字符串。
- Mobile Contract v2 追加验证：Debug Simulator 无签名构建成功，DerivedData 为 `/tmp/codex-talefork-v2-debug`；Release iPhoneOS 无签名构建成功，App 为 `/tmp/codex-talefork-v2-release/Build/Products/Release-iphoneos/TaleFork.app`。
- Unit/UI 测试包通过 `build-for-testing` 编译，DerivedData 为 `/tmp/codex-talefork-v2-tests`；为遵守“不安装”边界，本轮未执行测试。
- Release 可执行文件为 arm64；可提取字符串检出五条 `/tale-gateway/v2` 路由、`X-TaleFork-Edition`、`outcome/detail/content`、`stories` 和新故事字段。编译器未保证每个短字符串独立保存，因此该结果只证明已检出的字符串，不把未检出字段误报为缺失。
- 对生产 Swift 的旧 wire-contract 路径/请求头/字段字面量扫描和 Release 可提取字符串扫描均为 0：`api/telefokr/v1`、`X-Telefokr-Client`、`Authorization`、旧设备/会话/媒体/列表/短剧字段以及 `journeys/chapters/stream.mp4` 均未命中。App 自身通用语法和业务模型不作为旧 DTO 命中；为消除 Release 中可提取的同名歧义，内部 `name/synopsis/query/appVersion` 也已机械改名。
- 生产 Swift 和测试 fixture 均使用 `{assetRoot}stories/{storyKey}/reels/{chapter}/playback.mp4`；封面直接消费服务端 `artworkLink`。

## 静态与视觉证据

- 四套 `Localizable.strings` 各 132 个键、无重复且键集一致；plist、privacy manifest 和 strings 已通过 lint。
- 全量代码/字段/工程/资源结果见 `APP-STORE-4.3-FULL-AUDIT.md` 和机器可复验的 `QA/APP-STORE-4.3-FULL-AUDIT.json`。
- 生产代码 48-token 克隆覆盖率：对 DRAMILE 0.00%，对 LanGuoNext 0.00%；跨 App 精确字节重复资源均为 0。
- 人工并排检查三个 1024 图标：TaleFork 为交叉故事路径 + 播放门，DRAMILE 为发光分叉节点，LanGuoNext 为蓝色 D 形滑轨；构图、色彩和符号不同。
- 模拟器截图人工检查了播放器、场记列表和 Studio；未见控件溢出或 Tab 遮挡。该检查只覆盖一种设备/系统/英文/浅色环境。

## 未验证与外部阻塞

- **中风险、外部证据边界**：客户端当前使用 `https://app.duanjufafafa.fun/` 和 `/tale-gateway/v2` 独立契约；静态对比未发现共有服务 URL/API 路由。服务端任务已报告新 heartbeat 200、旧 API/旧媒体 404、新视频 Range 206、新封面 200，但本 iOS 任务未复验真实目录和播放，运营方仍需提供商业关系与内容权利证据。
- **中高风险**：客户端发送 `deviceSeed`、release 名称/Build、语言标签和硬件类别；必须与服务端存储、关联、保留和 App Privacy 回答逐项对账。
- 未运行真实线上目录、搜索、匿名访客、视频可达性或真实播放。
- 未验证服务端永久删除、剧目/封面/视频版权、公开 URL、运营主体或 App Store Connect 元数据。
- 未运行真机、小屏/Pro Max、深色、最大辅助字体、VoiceOver、弱网、Archive、Validate 或 TestFlight。

## 审核边界

当前结果证明客户端离线主流程、正式路径编译和无签名构建通过，并提供低长片段代码重合的静态证据。服务端部署结果来自服务端任务的独立证据层；所有证据都只能降低 Guideline 4.3(a)/(b) 风险，不能替代 Apple 对内容、账户、主体、服务和商店素材的审核，也不承诺过审。
