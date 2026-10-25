# 0.7.0（构建 11）验收

- 安装包源码：`d39516493d045adccc731bed692bdb5cc5ca5d93`。
- 成功构建：[40209710708](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40209710708)。94 项 Swift 测试与 8 项 Python 打包测试通过；iPhone/iPad 模拟器、arm64 iPhoneOS 主应用及两项扩展编译通过。
- 普通与扩展 IPA 均核对 ZIP 完整、SHA256、版本 0.7.0/11、最低 iOS 17、设备族 [1,2]、显示名 SUSTechMobile、Bundle ID 以及主程序/扩展 arm64 iPhoneOS Mach-O；普通包无扩展，实验包两项扩展。
- 文件位于 `D:/Altstore/App/SUSTechMobile-0.7.0`；逐包结果见该目录 `VERIFIED-PACKAGES.json`。普通包 2,491,478 字节，SHA256 `b71f298cf8bfab1948bc0a5f1e204565f0093470935ef3af8f6190c3561f8110`；扩展包 2,577,801 字节，SHA256 `9b57d04972270d33ebd2e7e2a1e550c84ef4f3d1a9be2655999934babbee0d0f`。
- 相同源码 UI 运行 [40210109524](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40210109524) 成功：12 组 iPhone/iPad 场景与两张桌面共 26 张截图；每次地图启动检查 4 条线路、351 个轨迹点、33 个站点、2 辆虚构车辆。已人工查看学习/个人信息/iPad、首页、预约、校巴默认图/车辆浮卡/时刻表。截图均为演示数据，精确来源见 `docs/screenshots/SOURCES.json`。
- Windows 本地仓库检查通过：91 个 Swift 语法树、确定性工程与资源检查、8 项 Python 打包测试。
- 未在本人设备安装或使用真实账号执行登录、预约、打印或支付；学校个人资料字段、真实车辆预测、定位对齐和底栏手感仍待设备验收。详情见 [设备清单](DEVICE_TESTING.md) 和 [版本说明](RELEASE_0_7.md)。

---

# 0.6.1（构建 10）验收

- 最终包源码：`58b5baf1efd690dd6d8a6f74200696608224276c`。
- 成功构建：[40191460527](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40191460527)。89 项 Swift 测试与 8 项 Python 打包测试通过；模拟器、arm64 iPhoneOS 主应用及两项扩展编译通过。
- iPhone/iPad 五个场景（巴士地图、原生登录、体育授权、打印站点、书院目录）实际启动并截图；两次地图自动检查均为 4 条线路、351 个轨迹点、33 个站点、2 辆虚构车辆。已查看关键 iPhone 截图与 iPad 登录截图。
- 普通 IPA 与扩展 IPA 的 ZIP、SHA256、版本 0.6.1/10、iOS 17、设备族 [1,2]、Bundle ID、显示名和 arm64 iPhoneOS Mach-O 全部核对。文件位于 `D:/Altstore/App/SUSTechMobile-0.6.1`。
- 公开打印接口无需 Cookie 实测 HTTP 200/code 0，返回 26 个有名称站点。
- 坐标转换有既定基准测试；实机国内底图对齐、钥匙串重启留存、真实账号自动补登、企业微信授权、书院目录/日程仍需本人设备验证。演示截图不代替校园业务验收。
- 本轮未执行真实预约、打印上传或支付；书院最终预约提交仍在官方页面。
- 完整日志：`D:/Altstore/Diagnostics/SUSTechMobile-0.6.1-final-build.log`。每张图库截图来源记录在 `docs/screenshots/SOURCES.json`。

- `SUSTechMobile-unsigned.ipa`：2315776 字节；SHA256 `cfec0e3581a3f0143435dbec3ac4be51779fb140b65e108368bfe69f23db946d`。

- `SUSTechMobile-with-extensions-unsigned.ipa`：2402093 字节；SHA256 `dbc94df13cafd4d2330c069b67b4819c2019a625b58c5ecd1907a6175ff481a9`。

---

# 0.6.0（构建 9）验收

- 最终包源码：`e07485d9c80f56d8e0c9043330e49e4f36ce3d60`，已在 main。
- 最终成功构建：[40178259028](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40178259028)。84 项 Swift 测试、8 项 Python 打包测试通过；模拟器与 arm64 iPhoneOS 主应用、分享和 Widget 扩展编译通过。使用临时验证分支，避免中断地图截图；最终周次徽标修正通过编译，未重复拍摄已有页面。
- 地图成功运行：[40177111042](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40177111042)，界面源码 `c284168`。iPhone/iPad 浅色、深色四次均检查到 4 条线路、351 个轨迹点、33 个站点、2 辆虚构车；检查截图可见轨迹、站点和新旧位置不同标记。包括桌面共 6 张。
- 教师详情/名录与首页来自运行 [40175903374](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40175903374)，源码 `e37b382`；只采用教师详情/名录图片，未采用该轮空示例地图。首页日期教学周已实际启动验证，最后进一步统一课程徽标与上海时区。
- 图库现有 70 张跨 0.5/0.6 的场景/设备截图，精确来源见 [SOURCES.json](screenshots/SOURCES.json)。地图和联系方式截图使用虚构车辆/教师联系方式；路线与站点为公开快照。
- 最终 IPA 的 ZIP、SHA256、版本 0.6.0/9、最低 iOS 17、设备族 [1,2]、名称 SUSTechMobile、Bundle ID、主程序和两个扩展 arm64 Mach-O 已核对。普通包不含 PlugIns。
- 文件位于 `D:/Altstore/App/SUSTechMobile-0.6.0`；日志 `D:/Altstore/Diagnostics/SUSTechMobile-0.6-final-build.log`、`SUSTechMobile-0.6-map-build.log`。

- `SUSTechMobile-unsigned.ipa`：2,257,912 字节，SHA256 `38631c4aa06f97d2acec2f278713fdc89beaa9d32d705f7dc22e4668c3eb586c`。
- `SUSTechMobile-with-extensions-unsigned.ipa`：2,344,234 字节，SHA256 `4fc36c687563c4b54ed540276f3b4d513ec9d22cadb1e04d607fbd79d26f3b58`。

公开接口只读检查确认 routes/vehicles 的返回字段和教师官网邮箱模板。未在真实设备使用校园账号或 Apple 签名；车辆真实上报延迟、校园内底图对齐、教师页面动态/失效链接、扩展签名仍需本人设备验收。办公室必须来自明确标签，未公开/未识别时保留缺失提示。

此前本地旧版本清理被自动审批拒绝，本次未重试或绕过，旧版目录仍保留。

说明：[0.6 发布说明](RELEASE_0_6.md)、[源与界面检查](REVIEW_0_6.md)、[设备清单](DEVICE_TESTING.md)。

---

# 0.5.0（构建 8）验收

- 最终安装包源码：`778d84205ec6781de4d2ad10d2d7f6c91ae97725`。
- 最终成功构建：[40173815553](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40173815553)。**78 项 Swift 测试、8 项 Python 打包测试通过**；iPhone/iPad 模拟器、arm64 iPhoneOS 主应用、分享扩展和 Widget 扩展编译通过。
- 完整界面运行 [40172533665](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40172533665)，提交 `6f752ef`，生成 64 张截图；最终源码另复查首页/周课表/交换项目/账户/小组件设置的两类设备截图与桌面，共 12 张。图库保留 64 个不同场景/设备文件，每个文件来源记录于 [SOURCES.json](screenshots/SOURCES.json)。
- 已人工核对：首页、办事、网格课表、校园卡、打印、教师目录、校历、校园码，以及深色和大字号。最终重点复查交换项目与首页。
- 版本号 0.5.0/8、iOS 17、设备族 [1,2]、名称 SUSTechMobile、主 Bundle ID `cn.sustech.community.daily` 已验证；IPA ZIP 完整、主程序和扩展为 arm64 Mach-O。普通包无 PlugIns，扩展包含 `CampusPrintShare.appex` 与 `CampusWidgets.appex`，两个扩展的 Bundle ID、构建号均核对。
- 下载目录：`D:/Altstore/App/SUSTechMobile-0.5.0`。日志：`D:/Altstore/Diagnostics/SUSTechMobile-0.5-final-build.log`。

- `SUSTechMobile-unsigned.ipa`：2,107,185 字节；SHA256 `15fe2f8ee1b9520c472762a5da3e0071ee7fc0c1e5ee87f9858453f11d2a5143`。
- `SUSTechMobile-with-extensions-unsigned.ipa`：2,193,504 字节；SHA256 `f3e7549d0ab439781906ae96594d88e0c29c247784a92ad852c67520ecdd2523`。

验证边界：测试使用离线夹具，不含真实校园或 Apple 账号。校园码终端识别、WS 会话、真实删除/打印/预约/续借/BB 提交均需本人真机验收。未创建充值订单、付款或消费；完整原生充值下单仍关闭。扩展包含不等于有效签名，App Groups 和 iLoader 兼容性未实测。普通包继续支持主应用直接导入 PDF。

此前旧版本递归清理被自动审批拒绝，本次未重试或绕过；旧版目录仍保留。

实现说明：[0.5 发布说明](RELEASE_0_5.md)、[设计来源](DESIGN_0_5.md)、[检查记录](REVIEW_0_5.md)、[扩展签名](SHARE_SIGNING.md)。

---

# 0.4.0（构建 7）验收

- 最终安装包源码：`e302728fc0242d0e64cc17632718084a138f1ffc`。
- 最终成功构建：[40168349920](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40168349920)。69 项 Swift 测试、8 项 Python 打包测试通过；iPhone/iPad 模拟器、arm64 iPhoneOS 主 App 与分享扩展编译通过。
- 界面成功运行：[40167331512](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40167331512)，界面提交 `a7f9a04`，共 48 张 iPhone/iPad 截图。已查看紧凑课表、办事页、图书馆与排课页。之后仅继续修正登录连续性、连接状态绑定与提示文字，最终构建未重复截图；这些后续状态变化仍需设备验收。
- 本地 59 个 Swift 语法树（含分享扩展）、工程生成一致性、配置与打包测试通过。生成器避免重复写相同工程文件，以适应 Windows 文件占用。
- 普通包：`D:/Altstore/App/SUSTechMobile-0.4.0/SUSTechMobile-unsigned.ipa`，1,750,388 字节。
- 普通包 SHA256：`b2b26e269e74e85d4827cc7c0b6ac2a2eaa64f4d0fbe119a42f02574aae339b8`。
- 分享扩展验证包：`D:/Altstore/App/SUSTechMobile-0.4.0/SUSTechMobile-with-share-unsigned.ipa`，1,780,065 字节。
- 扩展包 SHA256：`58dadd47a7fe56a872ab1918d886fac312392a831380dff436613eaad526c32e`。
- 两个包 ZIP 完整性、名称/Bundle ID、版本 0.4.0/构建 7、最低系统 17、设备族 [1,2]、元数据提交和 SHA256 已核对。普通包没有 PlugIns；扩展包包含唯一的 CampusPrintShare.appex，其 Bundle ID/构建号和 arm64 Mach-O 已核对。
- 本机日志：`D:/Altstore/Diagnostics/SUSTechMobile-0.4-final-build.log` 与 `SUSTechMobile-0.4-ui-build.log`。
- 独立协议测试覆盖 BB 表单/nonce、草稿/分组/外域/禁用字段拒绝，POST 响应丢失后回读且只有一次 POST，后续历史页 404、缺少本人归属、多个新增 attempt 均不误报成功；候选课程单双周/部分时段拒绝、取消预约过滤、充值身份/金额约束和关闭真实下单。
- 公开 NCES 搜索只读返回 HTTP 200，结构符合客户端。Primo 在 Windows Python/OpenSSL 遇到旧式 TLS 握手错误，未降低 TLS；iOS URLSession/WKWebView 的实际兼容性仍待设备实测。
- 真实校园登录、续借、打印、预约及 BB 提交没有用本人账号验收，本轮未执行真实写操作、订单创建或付款。69 项测试是离线/模拟协议测试，不能当作学校业务通过。
- 充值只读授权/身份校验及金额准备已实现，正式下单因授权交接、下单分支与订单状态查询未验证而关闭。分享扩展需要有效 App Groups 签名，免费账号/iLoader 兼容性未验证；普通包可继续主 App 导入 PDF。
- 未签名包需本地重新签名，本轮没有修复 Apple 证书申请限制，也未安装到本人设备。

操作见 [0.4.0 说明](RELEASE_0_4.md)，独立验收见 [设备清单](DEVICE_TESTING.md)，签名见 [分享扩展说明](SHARE_SIGNING.md)，审查修正见 [记录](REVIEW_0_4.md)。

---

# 0.3.1（构建 6）验收

- 应用名称 / Bundle ID：SUSTechMobile / `cn.sustech.community.daily`。
- 编译源码提交：`80cce8872ed853e11e110445ace400f757d41158`。
- 成功构建：https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40161165150
- 51 项 Swift 测试、7 项 IPA 打包测试通过；本地 41 个 Swift 语法树与工程一致性检查通过。
- iOS 模拟器与 arm64 iPhoneOS Release 编译成功；iPhone/iPad 38 张启动及界面截图完成，已人工查看两张新增充值渠道页截图。
- IPA ZIP 完整性、版本 0.3.1 / 构建 6、iOS 17、设备族 [1,2]、名称、Bundle ID 与 SHA256 对照元数据通过。
- IPA：`D:/Altstore/App/SUSTechMobile-0.3.1/SUSTechMobile-unsigned.ipa`，1,210,462 字节。
- SHA256：`c302607ee32e801113444794e34f2e54812e19ac4d22ac3c84dea63a3be86e9a`。
- 云端日志本地副本：`D:/Altstore/Diagnostics/SUSTechMobile-0.3.1-build.log`。
- 仅实现原生渠道页、外部入口交接与主动余额/账单查询；无原生充值下单、无自动付款、无已验证订单到账闭环。
- 未使用真实校园/Apple 账号进行云端验证，未创建充值订单或付款；支付宝/企业微信授权和实际到账仍待真机验收。
- 包为未签名产物，仍需 Windows 本地重新签名；没有修复或绕过 Apple 证书申请限制。

操作见 [0.3.1 说明](RELEASE_0_3_1.md)，证据见 [充值调研](RECHARGE_PAYMENT_RESEARCH.md)。

---

# 0.3.0（构建 5）最终验收

- 应用名称与 Bundle ID 保持 SUSTechMobile / `cn.sustech.community.daily`。
- 源码提交：`b5a26d1d9aecbcaaf2a84785633a10a2e8cb499b`。
- 成功构建：https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40117884086
- 51 项 Swift 测试通过；7 项 Python IPA 打包测试通过。
- 模拟器和 arm64 iPhoneOS 目标编译通过；最低系统 iOS/iPadOS 17，设备族 [1, 2]。
- iPhone/iPad 共 36 张启动与界面截图完成；已查看新功能汇总图、消费曲线、办事入口和 BB 折叠前后效果。
- 真实 CRA 公共校车接口只读探测：站点返回 33 项；到站返回包含 arrivals 的对象，字段与客户端一致。
- IPA ZIP 完整性、Info.plist、图标资源、版本、构建号、架构元数据与 SHA256 已核对。
- 当前 IPA：`D:/Altstore/App/SUSTechMobile-0.3.0/SUSTechMobile-unsigned.ipa`，1,187,985 字节。
- SHA256：`eaaf18cb91d82c97f556b900e8ca0a70a04f3e25656d34824207b391587e4330`。
- 本机日志：`D:/Altstore/Diagnostics/SUSTechMobile-0.3-final-build.log`。
- 未使用真实校园/Apple 凭据进行云端验证，未提交真实打印或预约；尚待本人真机接口验收和本地重新签名安装。
- 本轮不声称修复 iLoader 的 Apple 证书申请错误。

操作与边界见 [0.3.0 说明](RELEASE_0_3.md)。下方版本路径为历史记录；按用户清理约定，旧版安装包不保证在本地保留。

---

# 0.2.0（构建 4）最终验收

- 应用名称：SUSTechMobile；中央火炬图标，深青背景，无外围文字和圆环。
- 源码提交：`5e762f911b87300ea5dd0f5fe54bb771b7074871`。
- 成功构建：https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40110677869
- 34 项 Swift 测试通过；7 项 IPA 打包测试通过。
- iPhone/iPad 模拟器和 arm64 真机目标编译通过。
- iPhone/iPad 模拟器实际启动、演示首页、原生登录页与桌面截图完成并人工查看；名称、图标和空表单显示正常。
- 已下载最终 IPA，核对 SHA256、版本/构建号、iPhone/iPad 设备族、应用名称和编译后的 AppIcon/Assets.car。
- 最终 IPA：`D:/Altstore/App/SUSTechMobile-0.2.0/SUSTechMobile-unsigned.ipa`。
- SHA256：`35c48a6a7c8a50f9e1572784fd6aad384efd57f06ea020f586c806e15f698e09`。
- 本包仍需现有 iLoader 在 Windows 本地重新签名安装。0.2.0 尚待用户真机更新，真实 CAS/TIS/BB 及课件下载未通过本人账号验收；不把自动验证结果填写为学校接口已通过。

详细功能、使用路径和边界见 [0.2.0 说明](RELEASE_0_2.md)。

---

以下为初始版本的历史验收记录。

# 云构建验收记录

日期：2026-10-24。仓库现已公开；以下保留历史构建验收记录，下载 Actions 产物通常需要登录 GitHub。

- 仓库：[aNother1332/sustech-mobile-ios](https://github.com/aNother1332/sustech-mobile-ios)
- 成功运行：[40096253259](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40096253259)
- 代码提交：`0fc4d4f`（异步 WebKit 导航代理修复）
- 环境：GitHub macOS runner，Xcode 26.0.1。
- 下载：[SUSTech-iPhone-iPad-3](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40096253259/artifacts/12561142003)
- 云端产物保留 7 天，本地下载副本不受该保留期影响。

## 通过的检查

| 检查 | 结果 |
| --- | --- |
| Xcode 工程生成一致性、配置与接口样例 | 通过 |
| Python IPA 打包边界测试 | 7 项通过 |
| Swift Testing 解析与传输边界测试 | 18 项通过，包含参数化场景 |
| iPhone / iPad 模拟器目标编译 | BUILD SUCCEEDED |
| arm64 iPhoneOS Release 目标编译 | BUILD SUCCEEDED |
| 真机包检查、IPA 打包、Artifact 上传 | 通过 |

## 产物

下载产物 ZIP 并解压，实际安装时选择其中的 `SUSTech-unsigned.ipa`。
同时提供 SHA-256 文件和 JSON 元数据，记录源码提交、平台、最低系统版本等。
包内支持 iPhone 和 iPad，最低系统 17.0。没有 Apple 签名、证书或 provisioning profile；
需由 Windows AltServer / AltStore 使用用户自己的 Apple 账号本地重新签名。

没有校园账号、Apple 账号或签名凭据上传到构建机器，没有执行学校接口或真实业务写入。

## 尚未通过的环节

- 用户 iPhone / iPad 的实际侧载、启动、权限与交互验收。
- 模拟器界面运行与视觉验收（当前只编译，没有启动模拟器）。
- 学校交互登录、WebKit cookie 与原生请求的实机复用。
- 学校接口的真实可用性、权限、校内/校外网络覆盖。

按 [Windows 安装教程](WINDOWS_SIDELOAD.md) 安装后，再执行 [设备验收清单](DEVICE_TESTING.md)。
