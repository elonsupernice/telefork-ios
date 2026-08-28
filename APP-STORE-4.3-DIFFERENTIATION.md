# TaleFork App Store 4.3 差异化证据与提审方案

检查日期：2026-08-29

## 规则边界

Apple [App Review Guidelines 4.3](https://developer.apple.com/app-store/review/guidelines/#spam) 将同一 App 以多个 Bundle ID 提交和与已有 App 缺乏明显差异的同质产品列为风险。本轮工作是为 TaleFork 建立可证明的独立产品表达，不是对审核结果的承诺。

提交时还必须使用 Apple 当时接受的 Xcode / SDK；Apple 的 [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) 页面要求自 2026-04-28 起上传使用 Xcode 26 及 iOS 26 SDK 或更高版本。

## 静态对比与本轮改造

| 维度 | TaleFork | DRAMILE 静态观察 | LanGuoNext 静态观察 |
| --- | --- | --- | --- |
| 产品概念 | 短剧放映 + 个人故事场记 | 故事旅程/回顾与通行证表达 | 短剧首页/剧场/个人与 VIP 表达 |
| 顶层导航 | 放映台 / 场记 / 片单 / Studio | Journey / Explore / Pass | Home / Theater / Mine |
| 一级独有功能 | 播放中记录类型、备注和精确秒数，随后回看 | 未将 TaleFork 场记流程作为主导航 | 未将 TaleFork 场记流程作为主导航 |
| 播放器周边 | “标记这一幕”是底部主操作，收藏留在详情 | 不复制其页面或交互 | 不复制其页面或交互 |
| 本地数据 | `SceneMark`、`DramaRun`、片单、历史和偏好 | 不引入其类型/存储代码 | 不引入其类型/存储代码 |
| 工程身份 | Swift 6、iOS 18、`com.talefork.storypaths`、自有嵌套 PBX 分组 | Swift 5.0、`com.dramile.app.ai` | Swift 5.0、`com.lah.jhs` |
| 视觉概念 | Ink/Paper 放映厅与场记簿，金色播放、薄荷反馈与蓝紫线索 | 不使用其品牌、通行证、素材 | 不使用其品牌、视觉素材 |

改造实际修改了 Xcode 工程生成器和 `project.pbxproj`，不是仅换名/换色：源码现按 App、Data、Domain、DesignSystem、Features、Shared 和 Resources 建立真实嵌套 PBXGroup；新增 `Features/SceneNotes`，删除通用 `Features/Paths`，加入独立 UI Test target，并启用 Swift 严格并发、脚本沙盒和资源符号扩展。通用内部名也已改为 TaleFork 的 Workspace、Moment Player、Story Studio 和 Catalog Discovery 语义。

## 代码、资源与隐私证据

- 生产代码 12 / 24 / 48-token 克隆覆盖率：DRAMILE 10.84% / 1.18% / 0.00%，LanGuoNext 8.36% / 0.75% / 0.00%。工程、字段和文件级明细见 `APP-STORE-4.3-FULL-AUDIT.md`。
- TaleFork / DRAMILE / LanGuoNext 的 Bundle ID 不同；TaleFork App Icon 字节哈希与 DRAMILE、LanGuoNext 和 LegacyBaseline 均不同。
- 未检出旧品牌类名、StoreKit、广告/跟踪 SDK、第三方支付、URL Scheme、Associated Domains、App Group、Push 或 Background Modes。
- `PrivacyInfo.xcprivacy` 声明非跟踪、非关联 Device ID 用于 App Functionality，并为 UserDefaults 声明 `CA92.1`。正式提交前应再按 Apple [Required Reason API 文档](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) 和最终二进制重新核对。
- iPhone 17 / iOS 26.5 离线自动化最终结果：Unit 11 passed、1 个线上 opt-in 测试 skipped；UI 5 passed，覆盖场记保存、重启读取、精确回跳、四个一级入口、界面宽度适配和首页单集过滤。

## 服务契约独立化与仍待验证风险

TaleFork 客户端生产地址为 `https://app.duanjufafafa.fun/`，Mobile Contract v2 使用 `/tale-gateway/v2` 下的设备通行证、启动清单、放映队列、搜索、身份删除和心跳路由。会话头为 `X-TaleFork-Edition: talefork-ios-r2` 与 `X-TaleFork-Pass`，响应统一解码 `outcome/detail/content`。视频由启动清单返回的 `assetRoot` 组合为 `stories/{storyKey}/reels/{chapter}/playback.mp4`，封面直接使用服务端 `artworkLink`。客户端已移除允许任意 HTTP 的 ATS 全局豁免。本轮静态对比未发现与 DRAMILE/LanGuoNext 共有的服务 URL 或 API 路由。

服务端交接记录显示 Mobile Contract v2 已上线：新 heartbeat 为 200、旧 API 与旧媒体为 404、新视频 Range 为 206、新封面为 200；本 iOS 任务不重复访问线上接口。该服务端证据仍不能代替 TaleFork 独立目录边界、三款 App 的主体/账户/内容关系说明、剧目/封面/视频权利链，以及设备字段的服务端收集/关联/保留说明，不能据此表述为 4.3 风险已消除。

## App Store 元数据初稿

### 名称与副标题

- App 名称：`TaleFork`
- 简体中文副标题：`短剧场记与精准回看`
- 繁体中文副标题：`短劇場記與精準回看`
- 英文副标题：`Short Drama Scene Notes`
- 日文副标题：`ショートドラマのシーンノート`
- 主类别：Entertainment（最终以 App Store Connect 可选类别与实际内容为准）

### 简体中文描述初稿

> TaleFork 把短剧放映和你自己的故事场记放在一起。从放映台找到想看的故事，在播放中记下转折、台词、线索或想再看一遍的瞬间。每条场记保留剧集、时码和可选备注，让你稍后回到原剧集的准确位置。你也可以通过片单管理收藏与观看历史，并按自己的习惯调整外观、触感、动效和自动连播。场记、进度、收藏和偏好保存在当前设备上。第 1～10 集免费，第 11 集起通过 Apple 应用内购买开通 TaleFork VIP；无广告、无第三方支付。

### 关键词原则

只使用与真实功能相关的词，例如“短剧,场记,台词,线索,剧集,回看,片单,观看记录”。不写 DRAMILE、蓝果、其他 App 名称、无法证实的“独家/最全/免费全集”或与实际内容不符的品类词。

## 截图与审核路径

Apple 当前的 [Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 允许每个尺寸 1–10 张；iPhone 6.9 英寸截图可作为主套。TaleFork 只支持 iPhone，因此当前方案不生成 iPad 截图。

建议首组截图：

1. 放映台：“从放映开始，不从模板首页开始”。
2. 播放器：突出“标记这一幕”操作。
3. 场记编辑器：展示转折/台词/线索/待重看和备注。
4. 场记列表：展示剧集、时码和“回到这一幕”。
5. 片单/Studio：展示收藏、播放偏好与本机数据边界。

审核备注应说明：启动时使用匿名访客访问线上目录；第 1～10 集免费，场记只存在本机；审核人员无需购买即可按“放映台 → 播放第 1～10 集 → 标记这一幕 → 场记 → 回到这一幕”验证核心功能。第 11 集起显示锁并进入 Apple 的单一周订阅购买页，购买页包含恢复购买和隐私/条款入口。

## 必须在客户端之外完成

### 服务端/内容

- 提供永久删除匿名账户和关联数据的 API，定义失败、重试、保留期与审计日志。
- 出具剧目、封面、视频、字幕、音乐和宣传素材的授权证据。
- 说明 TaleFork 与其他 App 的内容重合、公司/账户关系、后端共用和为何仍是独立产品。
- 在 `app.duanjufafafa.fun` 后实际部署 TaleFork 独立服务、数据和目录边界；不能只做 DNS/域名替换。
- 确保审核期间目录和视频稳定可用，无地域/IP/时段造成的空壳体验。

### 设计

- 确认 App Icon、启动背景和品牌标记的最终原创权利，完成真机尺寸和深/浅色质量检查。
- 从 TaleFork 最终构建重新制作四个语言的截图和必要的预览，不使用其他 App 的素材或相框模板。

### App Store Connect / 发布

- 独立团队、App ID、证书、描述文件和全新 App Store Connect 记录。
- 完成 App Privacy、年龄分级、内容权利、加密、审核联系人、支持 URL、隐私 URL 和营销 URL。
- 使用最终签名产物重做二进制、Privacy Manifest、Entitlements、Archive、Validate App、TestFlight 和真机检查。

## 结论

TaleFork 已从通用短剧进度页转为以“故事场记”为一级产品能力的独立客户端，且工程文件、源码分组、数据模型、交互和文案都有实质修改；离线模拟器主流程已通过，客户端接口域名和正式路径也已独立。内容关系与权利链、服务端删除实测、设计产权、独立开发者资产和商店资料仍是正式提审前的必须条件。
