# TaleFork 更新日志

> Gitee 仓库展示名称按交付要求使用“Telefork短剧ios-2”；App 代码、工程和品牌的正式名称为 **TaleFork**。

## 2026-08-27 · TaleFork VIP 周订阅（未发布）

- 第 1～10 集免费，第 11 集起统一显示 VIP 锁并阻止播放。
- 详情选集、续看、场记恢复、播放器选集、自动下一集和播放加载共用同一访问规则。
- 新增 StoreKit 2 单一每周自动续费套餐 `com.talefork.storypaths.vip.weekly`，购买页使用 Apple 本地化价格，提供恢复购买、取消订阅、隐私政策和使用条款入口。
- 本地 StoreKit 配置按 US$9.90/周验证；正式价格仍须在 App Store Connect 选择对应价格点。
- 订阅权益只依据经 StoreKit 验证且未撤销的当前 entitlement，不把会员布尔值写入本机偏好。

## 2026-08-26 · App Store 4.3 差异化改造（未发布）

- 将产品核心从通用“观看进度”改为“短剧放映 + 个人故事场记”。
- 新增播放时标记转折/台词/线索/待重看、本机持久化、单条删除和恢复精确剧集/秒数。
- 将顶层信息架构改为放映台 / 场记 / 片单 / Studio，删除旧 `PathsView`。
- 改写四套本地化文案和首次启动表达，清理旧 Paths 键。
- 工程生成器现在产生真实的 App / Data / Domain / DesignSystem / Features / Shared / Resources 嵌套分组，并启用用户脚本沙盒、资源符号扩展和 Swift 严格并发。
- 新增 Debug-only 离线目录与 UI Test target；场记保存/重启读取/精确回跳和四个一级入口已在模拟器自动化通过。
- 将生产 API 切换为 `https://app.duanjufafafa.fun/` 和 TaleFork Mobile Contract v2 `/tale-gateway/v2` 独立契约，移除 `NSAllowsArbitraryLoads`；线上部署与内容独立性仍由服务端提供证据。
- 将设备通行证、启动清单、放映队列、搜索和身份删除切换为 v2 字段与 `X-TaleFork-Edition` / `X-TaleFork-Pass` 请求头；本机随机设备种子延续既有安装身份。
- 将视频公开路径切换为 `{assetRoot}stories/{storyKey}/reels/{chapter}/playback.mp4`，封面直接使用服务端 `artworkLink`；剧集编号和播放器业务逻辑保持不变。
- 补充覆盖全部代码、字段/声明名、工程文件、配置和资源哈希的可复验相似度审计；审计脚本根据当前端点动态判断共用 URL/API 路由。

## 2026-08-13 · Gitee 首次私有仓库交付

### App 与构建身份

- App 名称：`TaleFork`
- Xcode 工程：`TaleFork.xcodeproj`
- Target：`TaleFork`
- 主 App Bundle Identifier：`com.talefork.storypaths`
- 测试 Target Bundle Identifier：`com.talefork.storypaths.tests`
- 版本：`1.0.0`
- Build：`1`
- 最低系统：`iOS 18.0`
- 设备范围：仅 iPhone，`TARGETED_DEVICE_FAMILY = 1`
- 屏幕方向：竖屏
- 支持平台：`iphoneos` 和 `iphonesimulator`
- 开发语言与框架：Swift 6、SwiftUI、AVFoundation、Observation
- 开发者 Team：工程当前留空，未绑定 Apple Developer Team
- 签名状态：仓库不包含证书私钥、描述文件密钥或证书密码；正式发布时由独立开发者账号配置

### 产品与语言

- 产品形态：iPhone 竖屏短剧 App
- 主要功能：线上剧目、搜索、详情、播放、选集、续播、观看进度、收藏、设置、用户 ID 和注销账户
- App 界面语言：繁体中文、英文、日文
- 默认语言：简体中文系统及未支持语言回退为繁体中文
- 服务端内容：剧名、剧情、剧集文案等服务端字段保持原文，App 不自动翻译
- 协议：隐私政策和使用条款为 App 本地文档

### 商业与数据边界

- 当前版本免费
- 不含会员、内购、广告、支付宝、微信支付或其他第三方支付
- 不含广告归因或分析 SDK
- 剧目目录和视频需要联网
- 观看进度、收藏和偏好保存在设备本地
- 隐私申报应以 `PrivacyInfo.xcprivacy`、App 内隐私政策和实际网络请求为准

### 2026-08-13 历史交付记录（非本轮复验）

- 已完成 iOS 18+ iPhone 竖屏适配
- 已验证 iPhone SE（第 3 代）、标准全面屏 iPhone 17e 和 iPhone 17 Pro Max
- 已适配刘海、灵动岛、Home Indicator、小屏与最大辅助字体
- 当时文档记录过线上目录与真实视频检查；2026-08-26 本轮禁止线上请求，不将该旧记录作为当前证据
- iOS 18.0 无签名 Release 设备构建通过
- 本轮源码基线：`1d46453`

### 发布前仍需完成

- 使用新的独立 Apple Developer Team 创建 App ID、签名证书和描述文件
- 在真实 iPhone 和 TestFlight 上完成回归
- 核对 App Store Connect 隐私问卷、年龄分级、审核账号与服务端注销能力
- Archive 前将 Build 改为当次打包的北京时间十四位数字
