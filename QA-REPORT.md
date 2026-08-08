# TaleFork 1.0.0 验收报告

## 结论

当前源码已达到无签名的 iOS 发布候选状态：Debug、Release 模拟器构建及 Release iPhoneOS 构建全部成功，核心自动化测试全部通过。由于工程故意未绑定 Apple Team，当前不生成签名 IPA。

## 自动测试

- 原创故事库规模与结局数量
- 入口节点、选择目标和节点可达性
- 路线推进与本地持久化
- 重新开始后保留已解锁结局
- 句子收藏的增加、移除和重置
- 繁体中文、英文、日文键集一致性

结果：6/6 通过。

## 模拟器巡检

- iPhone SE 小屏：引导、发现页、阅读器已验证
- iPhone 17 Pro：自动测试宿主已验证
- iPhone 17 Pro Max：引导、发现页、阅读器已验证
- 浅色与深色外观已验证
- 小屏英文长标题已修正为可换行与自适应缩放

## 发布资产检查

- Bundle ID：`com.talefork.storypaths`
- App 图标：1024×1024，不含 Alpha，已编译进 App Bundle
- 隐私清单：已编译进 App Bundle
- 本地化：`en`、`ja`、`zh-Hant` 已编译进 App Bundle
- 本地隐私政策与使用条款：已编译进 App Bundle
- 第三方 SDK：无
- 支付、订阅、广告、追踪：无
- 服务端依赖：无

## 尚需新开发者账号完成

1. 在新 Team 中注册 `com.talefork.storypaths` App ID。
2. 使用新 Team 生成 Apple Distribution 证书与 App Store 描述文件。
3. 仅在该阶段把工程 Team 切换到新账号，然后 Archive、Validate 和 Upload。
4. 在全新 App Store Connect 记录中配置元数据、隐私回答与审核信息。
