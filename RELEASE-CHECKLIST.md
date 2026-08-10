# TaleFork 独立发布清单

该清单用于确保 TaleFork 首次发布使用独立开发者资产，并真实描述在线短剧功能。技术差异只能降低 4.3 风险，不能保证审核结果。

## Apple 资产

- [ ] TaleFork 独立 Apple Developer Program 团队已开通
- [ ] 独立 Team 创建 App ID：`com.talefork.storypaths`
- [ ] Apple Distribution 证书和 App Store 描述文件均由独立 Team 签发
- [ ] Xcode `DEVELOPMENT_TEAM` 只选择独立 Team
- [ ] Archive 的 Team ID、Bundle ID、证书、描述文件和 Entitlements 已核对
- [ ] 未导入或使用 Dramile 团队的证书、私钥、描述文件或 App Store Connect 记录

## App Store Connect

- [ ] 使用独立 Team 创建全新 App 记录
- [ ] 名称、副标题、描述、关键词、图标和截图均为 TaleFork 内容
- [ ] 主类别按实际短剧内容选择 Entertainment
- [ ] 价格为免费，无 App 内购
- [ ] App Privacy 如实申报设备标识符和其他实际收集项；不得填写“不收集数据”
- [ ] 隐私政策、技术支持和营销 URL 使用 TaleFork 独立公开站点
- [ ] 隐私政策中的联系人、运营主体、删除流程和数据保留规则已填写，不使用占位文案
- [ ] 年龄分级按线上目录可能出现的暴力、恐怖、性暗示等内容如实填写

## 账号删除与隐私

- [ ] 设置页展示匿名用户 ID
- [ ] 本机删除流程能清除匿名身份、进度、收藏、历史和偏好
- [ ] 服务端已提供并接入永久删除接口，失败可重试且有明确结果
- [ ] 隐私清单、网络请求、App Store 隐私问卷和政策文本一致
- [ ] 已确认内容服务是否记录搜索词、IP、请求日志或播放行为，并据此更新申报

## 技术验证

- [ ] iOS 18+ Release Archive 成功并通过 Validate App
- [ ] TestFlight 在小屏、标准屏和 Pro Max iPhone 安装与播放正常
- [ ] 顶部物理安全区和底部 Home Indicator 与播放器控制背景连续
- [ ] 三套语言、深色模式、搜索、选集、续播、进度、收藏和删除本机资料正常
- [ ] App 图标在构建上传处理后正常显示
- [ ] 审核备注说明在线短剧、匿名访客机制、免费无支付，以及必要的测试步骤
- [ ] 审核人员无需手机号、短信验证码或付费即可验证首发内容

## 4.3 差异审计

- [ ] 名称、包名、图标、截图、商店文案和网站均为 TaleFork 独立资产
- [ ] 页面信息架构、视觉语言、播放器、进度模型和源码结构与 Dramile 明显不同
- [ ] 代码相似度报告已生成；必要的服务端协议字段与系统样板已单独说明
- [ ] 不通过简单改名、换色或复制旧商店素材来冒充新产品
