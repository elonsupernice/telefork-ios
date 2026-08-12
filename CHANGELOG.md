# TaleFork 更新日志

> Gitee 仓库展示名称按交付要求使用“Telefork短剧ios-2”；App 代码、工程和品牌的正式名称为 **TaleFork**。

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

### 本次仓库基线

- 已完成 iOS 18+ iPhone 竖屏适配
- 已验证 iPhone SE（第 3 代）、标准全面屏 iPhone 17e 和 iPhone 17 Pro Max
- 已适配刘海、灵动岛、Home Indicator、小屏与最大辅助字体
- 9 项自动化测试通过，包含线上目录与真实视频播放检查
- iOS 18.0 无签名 Release 设备构建通过
- 本轮源码基线：`1d46453`

### 发布前仍需完成

- 使用新的独立 Apple Developer Team 创建 App ID、签名证书和描述文件
- 在真实 iPhone 和 TestFlight 上完成回归
- 核对 App Store Connect 隐私问卷、年龄分级、审核账号与服务端注销能力
- Archive 前将 Build 改为当次打包的北京时间十四位数字

