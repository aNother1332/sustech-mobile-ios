# Windows 安装到 iPhone / iPad

本流程：GitHub 云端 macOS 编译 → 下载真机 IPA → Windows 本地重新签名和安装。
无需拥有 Mac；首次个人试用可使用普通 Apple 账号。Apple 的账号/设备限制仍适用。

## 1. 下载云端构建产物

1. 打开自己的 GitHub 仓库 → Actions → **Build iPhone and iPad IPA**。
2. 点击 **Run workflow**，选择 main 分支并运行。
3. 等待整次运行绿色成功，进入该次运行下方 **Artifacts**。
4. 下载 `SUSTech-iPhone-iPad-数字`，解压下载的 ZIP。
5. 找到 **SUSTech-unsigned.ipa**；不要将外层 ZIP 改名成 IPA。

同目录还有 SHA-256 校验文件与构建元数据。IPA 是 iPhoneOS arm64 真机程序，
没有 Apple 签名；当前不能直接从 Files 点开安装，也不是 TestFlight 包。
应用最低需要 iOS / iPadOS 17。

校验下载内容（PowerShell，在解压目录中）：

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath .\SUSTech-unsigned.ipa
Get-Content -LiteralPath .\SUSTech-unsigned.sha256
```

## 2. 本机已验证的 iLoader 安装路线

本会话中 AltServer 认证失败后，使用基于 iLoader 2.4.0 源码的本地修补构建，用户已确认登录并完成 0.1.0 安装。

1. 打开 `D:\Altstore\iLoader-Patched\iLoader-local23782.exe`。
2. 如会话过期，由本人在工具中登录 Apple 账号；不要将密码、验证码放入聊天或 GitHub。
3. USB 连接并解锁设备，信任电脑，在设备列表选择 iPhone 或 iPad。
4. 点击“导入 IPA / Import IPA”，直接选择电脑上的新版本 `SUSTech-unsigned.ipa`，等待重新签名和安装。
5. 用原先的同一 Apple 账号覆盖安装同一应用；iPad 需要另行安装。不要为升级先卸载原应用。
6. 按设备提示信任开发者并启用开发者模式。免费签名有效期与设备限制仍适用，iLoader 不等于自动续签服务。

新安装 0.2.0 后：我的 → 学校服务 → 登录学校账号；再到学习页同步课表、成绩、BB 课程。
详情见 `RELEASE_0_2.md`。密码认证和真实学校接口验证由用户本人完成。

## AltStore Classic 备用参考（本机当前未采用）

以下为历史路线；本机 AltServer 已卸载，不要为了更新本项目再次安装它。



按官方文档操作，不需要把 Apple 账号发到聊天或配置进 GitHub：

- [AltStore Classic Windows 安装步骤](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltStore Classic 使用与有效期](https://faq.altstore.io/altstore-classic/your-altstore)

概览：

1. 安装官方要求的 Apple 设备支持组件、iTunes / iCloud，以及 AltServer for Windows。
   组件版本与来源要求以官方教程为准。
2. 用 USB 连接 iPhone，解锁并信任这台电脑。
3. 按教程启用同步，再通过 AltServer 安装 AltStore 到该设备。
4. 由本人在工具中完成 Apple 账号认证及必要的双重认证。
5. 按系统提示信任个人开发者身份；iOS 16+ 需要开发者模式，可能重启设备。

## 3. 安装本项目 IPA

1. 将 `SUSTech-unsigned.ipa` 通过自己选择的文件传输方式放进 iPhone 的 Files 中。
2. 保持 Windows AltServer 运行，设备通过 USB 或其支持的同一网络方式可达。
3. 在 AltStore 的 **My Apps** 页面点击 **+**，选择 IPA。
4. 等待本地重新签名与安装，之后打开“南科·日常”。
5. iPad 需要分别安装；同一个 IPA 支持 iPhone / iPad，但不绕过账号和设备限制。

本项目当前没有需要付费权限的 App Groups、APNs 等 entitlement。
后续增加小组件或分享扩展时，需要重新验证免费签名下的能力。

## 4. 第一次试用

先打开“我的”→“演示模式”，确认界面能运行。
再切回学校服务模式，由本人在原生界面登录；验证码等情况使用完整学校网页备用入口。
本次云构建只证明源码可编译，不能证明学校登录、权限或网络已经实测通过。

## 5. 续签与更新

免费账号侧载的应用通常 7 天过期，需要使用所选签名工具续签；本机使用 iLoader 重新签名安装。
免费侧载也有同时启用应用数量限制，AltStore 本身会占用名额。
这是一条个人开发试用路线，不是无需维护的全校分发方案。

后续版本从新的成功构建下载，尽量使用同一 Apple 账号和 bundle ID 安装覆盖。
覆盖升级的数据行为仍需实测；不要为了更新随意卸载而丢失应用数据。

## 常见问题

| 现象 | 检查 |
| --- | --- |
| GitHub 没有下载产物 | 运行是否全部成功，是否在 7 天保留期内，是否已登录有权限的账号 |
| 下载后只有一个 ZIP | 解压 Artifacts 外层 ZIP，再选择里面的 IPA |
| IPA 不可直接点开安装 | 这是未签名包，交给 AltStore 重签后安装 |
| 无法找到 AltServer | 先用 USB；检查官方要求的组件、同步、网络访问与信任状态 |
| 应用提示不受信任 / 开发者模式 | 按官方教程在系统设置完成信任及开发者模式 |
| 7 天后无法打开 | 刷新个人签名；无需因此重建完全相同的源码 |
| 安装成功但学校同步失败 | 属于真实接口/会话/校园网络验收，记录错误提示继续排查 |

工作流仅手动触发，不因每次推送自动反复构建。云端用量按 GitHub 的额度与计费政策处理；
不自动开通付费服务或调整预算。Apple 账号、校园账号和证书均不进入本流程的云端构建。
