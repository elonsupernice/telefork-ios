# TaleFork 测试计划

## 测试分层

1. **静态检查**：工程标识、资源、隐私清单、本地化键、运行时风险词和全量相似度。
2. **无签名构建**：Debug iPhone Simulator、Release iPhoneOS、Unit/UI test bundle。
3. **离线单元测试**：只使用 fixture、fake service 和独立 UserDefaults suite。
4. **离线 UI 测试**：Debug 本地目录、合成播放时钟和自动重置的本机状态，不连接线上服务。
5. **线上服务测试**：会注册匿名访客、请求目录和视频，必须显式设置 `TALEFORK_RUN_LIVE_TESTS=1`；本轮禁止运行。
6. **真机/TestFlight**：需要独立签名资产，本轮未运行。

## 已自动化覆盖

- iPhone 宽度与横向边距边界。
- fixture 剧集顺序、ID 唯一性、入口剧集和 `stories/{storyKey}/reels/{chapter}/playback.mp4` 媒体路径。
- `en` / `ja` / `zh-Hans` / `zh-Hant` 本地化键集一致。
- 目录刷新失败时保留既有数据；取消的旧搜索不能覆盖新结果。
- 播放位置、历史、收藏、场记和偏好持久化。
- 选集不误记为已看，播放达到阈值后才记录。
- 场记类型、剧集、备注和精确秒数保存；恢复后设置原剧集/秒数。
- 删除本机账户同时清除场记、进度、收藏、历史和引导状态。
- 第 10 集保持免费，第 11 集及之后需要 VIP；四套会员本地化键集一致。
- 放映台 / 场记 / 片单 / Studio 四个一级入口可达。
- 播放器保存场记，重启 App 后读取并返回对应瞬间。

## 最终结果（2026-08-26）

- iPhone 17 Pro / iOS 26.5 模拟器。
- Unit：9 passed、1 个线上 opt-in 测试 skipped、0 failed。
- UI：2 passed、0 failed。
- Release iPhoneOS、`CODE_SIGNING_ALLOWED=NO`：build succeeded。
- 结果包：`/tmp/codex-talefork-unit-final2.xcresult`、`/tmp/codex-talefork-ui-final4.xcresult`。
- 2026-08-26 媒体路径切换后：Debug/Release build succeeded，Unit/UI `build-for-testing` succeeded；遵守“不安装”边界，未重跑测试。
- 2026-08-26 Mobile Contract v2 切换后：Debug Simulator、Release iPhoneOS 无签名构建和 Unit/UI `build-for-testing` 均成功；遵守“不安装、不访问线上 API”边界，未执行测试。

## VIP 增量结果（2026-08-27）

- Debug Simulator build succeeded。
- Unit：10 passed、1 个必须显式开启的线上测试 skipped、0 failed；未访问线上 API、未注册游客、未播放线上内容。
- Release iPhoneOS、`CODE_SIGNING_ALLOWED=NO`：build succeeded。
- StoreKit 静态配置：1 个产品、周期 `P1W`、本地测试价 `9.9`、产品 ID `com.talefork.storypaths.vip.weekly`。
- Release App 未包含 `.storekit` 测试配置；Swift 未硬编码显示价格，未命中 WKWebView、支付宝或 checkout 支付实现。

## 推送前完整结果（2026-08-29）

- iPhone 17 / iOS 26.5：Unit 11 passed、1 个线上 opt-in 测试 skipped、0 failed；UI 5 passed、0 failed。
- UI 追加覆盖界面宽度适配和首页隐藏单集短剧；搜索范围不受首页过滤影响。
- Release iPhoneOS 无签名构建成功；未访问线上 API、未注册游客、未签名、未 Archive 或打包。
- 结果包：`/tmp/talefork-push-tests/Logs/Test/Test-TaleFork-2026.08.28_23-59-23-+0800.xcresult`。

## 发布前仍需人工矩阵

- 小屏、标准屏、Pro Max；浅色、深色、最大辅助字体、减少动画。
- VoiceOver 完整走查放映台、播放器、场记编辑器、场记列表和删除流程。
- 弱网/断网、目录更新后剧集缺失、视频无效和服务恢复。
- 真实 iPhone、线上目录/视频（获授权后）、Archive、Validate App、TestFlight 和审核环境。
