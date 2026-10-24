# 云构建验收记录

日期：2026-10-24。仓库为私有，查看运行或下载产物需要登录有权限的 GitHub 账号。

- 仓库：[aNother1332/sustech-apple](https://github.com/aNother1332/sustech-apple)
- 成功运行：[40096253259](https://github.com/aNother1332/sustech-apple/actions/runs/40096253259)
- 代码提交：`0fc4d4f`（异步 WebKit 导航代理修复）
- 环境：GitHub macOS runner，Xcode 26.0.1。
- 下载：[SUSTech-iPhone-iPad-3](https://github.com/aNother1332/sustech-apple/actions/runs/40096253259/artifacts/12561142003)
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
