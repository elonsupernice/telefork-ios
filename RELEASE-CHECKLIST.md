# TaleFork 独立发布清单

该清单用于确保首次正式发布全程只使用新开发者账号的资产。

## Apple 资产

- [ ] 新 Apple Developer Program 团队已开通
- [ ] App ID 为 `com.talefork.storypaths`
- [ ] Apple Distribution 证书由新 Team 签发
- [ ] App Store Provisioning Profile 由新 Team 签发
- [ ] Xcode `DEVELOPMENT_TEAM` 只选择新 Team
- [ ] Archive 的 Team ID、Bundle ID、签名证书和描述文件已核对

## App Store Connect

- [ ] 使用新 Team 创建全新 App 记录
- [ ] 名称、副标题、描述、关键词和截图均为 TaleFork 原创内容
- [ ] 类别为 Books 或 Entertainment，根据最终上架策略确认
- [ ] 价格为免费，无 App 内购
- [ ] App Privacy 与实际功能一致：不追踪、不收集数据
- [ ] 隐私政策、技术支持和营销 URL 使用新品牌站点
- [ ] 年龄分级根据三个故事的实际文字内容如实填写

## 技术验证

- [ ] Release Archive 成功
- [ ] Validate App 无错误
- [ ] TestFlight 安装后三套语言、深色模式和进度保存正常
- [ ] App Store 图标在构建处理后正常显示
- [ ] 审核备注说明：产品为离线分支互动阅读，无登录、无支付、无网络依赖
