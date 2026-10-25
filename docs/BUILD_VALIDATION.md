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
