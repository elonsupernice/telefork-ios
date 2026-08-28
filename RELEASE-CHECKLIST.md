# TaleFork 独立发布清单

> 客户端差异化只能降低 Guideline 4.3(a)/(b) 风险，不能保证 Apple 审核结果。

## 独立身份与签名

- [ ] TaleFork 独立 Apple Developer Program 团队已确定。
- [ ] 在该团队内创建 App ID `com.talefork.storypaths`。
- [ ] Distribution 证书、私钥、描述文件、Team ID 和 App Store Connect 记录均为 TaleFork 独立资产。
- [ ] Archive 中的 Product Name、Bundle ID、Team ID、Entitlements、URL Scheme、Associated Domains、App Groups 和 Push 能力逐项复核。
- [ ] 不导入 DRAMILE、蓝果或其他 App 的证书、私钥、描述文件或已建 App 记录。

## 产品与内容

- [ ] 场记作为真实主流程通过真机回归，不是截图用空壳页。
- [ ] 内容目录、每部剧、封面、视频、字幕和宣传素材的权利文件可追溯。
- [ ] 书面说明 TaleFork 内容与 DRAMILE/蓝果/其他已上架 App 是否重合、为何重合、授权主体与独立产品关系。
- [ ] 目录与 API 为 TaleFork 可维护的服务契约，不把更换 API 域名当作产品差异。

## 视觉与元数据

- [ ] App Icon、启动背景、站内品牌标记经设计最终确认，且权利归属清晰。
- [ ] 截图从本次 TaleFork 真实构建重新采集，不复用旧 App 截图、相框、文案或封面排版。
- [ ] 截图序列覆盖：放映台、播放中标记、场记编辑器、场记列表/精确回看、片单与本机隐私。
- [ ] 名称、副标题、描述、关键词、预览、审核备注、营销文案均以 TaleFork 当前功能重新制作。
- [ ] 支持 URL、隐私政策 URL、营销 URL、联系人和运营主体均独立、公开可访问且非占位。

## 隐私、账户和商业

- [ ] 服务端提供永久删除匿名账户与关联数据的契约，App 显示成功/失败/重试状态。
- [ ] `PrivacyInfo.xcprivacy`、Required Reason API、App Privacy 问卷、隐私政策和真实请求字段一致。
- [ ] 确认服务端对设备标识、IP、日志、搜索词和播放行为的收集/保留/关联方式。
- [ ] 第 1～10 集免费、第 11 集起需要 VIP，与客户端锁定规则及审核说明一致；无广告或第三方支付。
- [ ] App Store Connect 仅建立 `com.talefork.storypaths.vip.weekly` 一个自动续费订阅，周期 1 周，选择目标美元价格点并完成本地化、审核截图和可售区域。
- [ ] 购买页从 StoreKit 读取本地化价格，清楚说明每周自动续费，并提供恢复购买、隐私政策和使用条款入口。

## 构建、安装和审核

- [ ] 使用 Apple 提交时要求的 Xcode / SDK 完成 Archive 和 Validate App。
- [ ] 小屏、标准屏、Pro Max 真机及 TestFlight 完成主流程、弱网、VoiceOver 和动态字体回归。
- [ ] 审核服务可用，审核人员无需手机号、验证码或付费即可看到目录并验证场记。
- [ ] 审核备注清楚说明匿名访客、线上内容、场记本地存储、第 1～10 集免费、第 11 集起的 Apple 周订阅及完整测试路径。
