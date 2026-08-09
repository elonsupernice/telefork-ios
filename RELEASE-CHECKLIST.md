# TaleFork 独立发布清单

该清单用于确保 TaleFork 首次正式发布只使用新的开发者账号资产。完成工程并不保证通过 App Store 4.3 审核，最终结果仍由 Apple 审核决定。

## Apple 资产

- [ ] 新 Apple Developer Program 团队已开通
- [ ] 新 Team 创建 App ID：`com.talefork.storypaths`
- [ ] Apple Distribution 证书由新 Team 签发
- [ ] App Store 描述文件由新 Team 签发
- [ ] Xcode `DEVELOPMENT_TEAM` 只选择新 Team
- [ ] Archive 的 Team ID、Bundle ID、证书和描述文件已核对

## App Store Connect

- [ ] 使用新 Team 创建全新 App 记录
- [ ] 名称、副标题、描述、关键词、图标和截图均为 TaleFork 内容
- [ ] 主类别建议 Entertainment，次类别可选 Photo & Video 或不选
- [ ] 价格为免费，无 App 内购
- [ ] App Privacy 按实际功能填写：不追踪、不收集数据
- [ ] 隐私政策、技术支持和营销 URL 使用 TaleFork 独立站点
- [ ] 年龄分级按短剧画面实际内容如实填写

## 技术验证

- [ ] Release Archive 成功并通过 Validate App
- [ ] TestFlight 在小屏与大屏 iPhone 安装、播放、分支和续播正常
- [ ] 三套语言、深色模式、进度保存与清空数据正常
- [ ] App 图标在构建上传处理后正常显示
- [ ] 审核备注说明：原创离线互动短剧，无登录、无支付、无网络依赖
- [ ] App 审核人员无需账号即可观看全部首发内容
