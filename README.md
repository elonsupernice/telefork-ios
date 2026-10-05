# TaleFork

TaleFork 是一款把“看短剧”与“记住某个故事瞬间”放在同一条流程里的 iPhone 竖屏应用。用户可以在播放时暂停并建立“故事场记”，标记转折、台词、线索或待重看片段，随后从场记回到原剧集的精确秒数。

## 产品与工程身份

- App / Target / Scheme / Product：`TaleFork`
- Bundle Identifier：`com.talefork.storypaths`
- 定位：短剧放映与个人故事场记
- 平台：iPhone 竖屏，iOS 18.0+
- 版本：1.0.0（Build 1）
- 技术：Swift 6、SwiftUI、AVFoundation、Observation
- 顶层导航：放映台 / 场记 / 片单 / Studio

## 核心功能

- 线上短剧目录、搜索、详情、选集和竖屏播放。
- 播放位置、历史、收藏和自动连播。
- 故事场记：在播放器记录类型、剧集、秒数、快照信息和 120 字内的个人备注。
- 场记在本机持久化；目录可用时可返回对应剧集的精确时刻，目录不可用时仍保留文字记录。
- 本机数据清理同时删除场记、进度、收藏、历史和偏好。
- 繁体中文、简体中文、英文和日文界面。

## 数据与商业边界

第 1～10 集可免费观看，第 11 集起需要通过 Apple StoreKit 2 开通 TaleFork VIP 每周自动续费会员。后台通过现有 `/tale-gateway/v2` 的 `launch/manifest` 配置审核模式、归因和支付路由：审核模式始终只展示 Apple 内购；只有付费来源并带有效证据时，才允许显示后台返回的三方套餐。三方支付必须使用后台返回的短期 HTTPS 地址，并在 App 内 `WKWebView` 打开；客户端不保存卡号、商户密钥或 Meta CAPI 密钥。Apple 价格读取 StoreKit 返回的本地化价格，不在代码中硬编码。Meta SDK 用于安装、会话和归因；Firebase 用于安装与应用测量。三个业务转化事件的服务端链路仍待补齐与验证，不能把现有客户端事件转发当作真实业务结果。SDK 版本、私有配置方式与验收边界见 `QA/AdvertisingAttribution.md`。目录和视频依赖线上内容服务；场记、播放进度、收藏和偏好存储在设备上。实际申报必须与 `PrivacyInfo.xcprivacy`、公开隐私政策和服务端真实行为一致。

## 工程与验证

`Scripts/generate_project.py` 从 TaleFork 自身的 App、Data、Domain、DesignSystem、Features、Shared 和 Resources 分组生成 `TaleFork.xcodeproj`。工程包含 1 个 App target、Unit Tests 和 UI Tests，未绑定 Apple Developer Team。

当前生成脚本尚未覆盖工程中的广告 SDK 包依赖和 Analytics 分组；不要直接运行它覆盖已配置的工程。

模拟器覆盖安装使用 `rtk proxy bash Scripts/install_simulator.sh <模拟器 UDID>`。脚本先验证真实 Keychain 读写，再以 ad-hoc 签名重新构建并安装，不卸载、不清空账号数据。不要把 `CODE_SIGNING_ALLOWED=NO` 的构建用于模拟器安装：它可能丢失登录存储权限并报 `-34018`；无签名构建成功不代表登录可用。

2026-08-29 已在 iPhone 17 / iOS 26.5 模拟器运行完整离线测试：Unit 11 passed、1 个线上 opt-in 测试 skipped；UI 5 passed。Release iPhoneOS 无签名构建成功。验证过程没有请求线上 API、注册访客或播放线上内容，也没有签名、Archive 或打包。

详细的 4.3 证据、元数据方案和外部阻塞见 `APP-STORE-4.3-DIFFERENTIATION.md`；全量代码/字段/工程对比见 `APP-STORE-4.3-FULL-AUDIT.md`。这些工作只能降低 Guideline 4.3(a)/(b) 风险，不代表 Apple 会批准上架。
