# 南科 · 日常 — iPhone / iPad

南方科技大学校园事务聚合应用的 iOS 开发起点。目标是在原生 iOS 上逐步对齐
`dumixthestpd/sustech-mobile`，并加入学习待办、课件、日历、排课等能力。
非学校官方产品，按非商业用途开发。名称为工作名。

## 当前交付状态

已安装的 0.1.0 用户试用版验证了 Windows 签名安装路线，用户报告 CAS 网页显示不全。
当前源码为 **0.2.0**，已实现前三批范围，正在进行云端 Swift/Xcode 验证。

| 模块 | 0.2.0 源码实现 |
| --- | --- |
| 学校账号 | 原生 CAS 表单、受限跳转、教务/BB 分项验证，验证码官方网页备用 |
| 课表与考试 | 全学期课表、切周、学校节次时刻、当前周回退、考试 |
| 成绩 | 分页读取、分学期筛选、明确标注的 GPA 记录试算 |
| BB | 按课程读取任务和本人提交状态、公告、内容树及附件 |
| 本机离线 | 受保护缓存、最近同步时间、课件下载/预览/分享/删除 |
| 其他办事 | 保留校园卡、图书馆、打印、预约等官方网页入口 |

学校账号和实际数据仍需用户在 iPhone/iPad 验收，不能将构建通过解释为全部校园服务已可用。
详细使用路径、已知边界与验收项目见 [0.2.0 说明](docs/RELEASE_0_2.md)。
原生密码不保存，不设置聚合服务器，不实现自动重试密码或真实作业提交。

## 目录

```text
App/                       SwiftUI 界面、WebKit 登录、应用状态
Sources/CampusCore/        独立 Swift 包：数据模型、TIS / BB 读取、错误处理
Tests/CampusCoreTests/     Swift Testing 与虚构接口样例
Config/Info.plist          iOS 配置，最低 iOS / iPadOS 17
SUSTech.xcodeproj/         已生成的 Xcode 工程与共享 scheme
scripts/                  跨平台工程生成与检查
docs/                     已确认需求、阶段计划、接口来源、真机验收清单
.github/workflows/ios.yml  手动触发的云端测试、模拟器检查、真机 IPA 构建
```

## Windows 上检查

需要 Python 3.10+：

```powershell
python scripts/verify_repository.py
```

可选语法与 Xcode 工程结构解析（通过 uv 的隔离环境安装小型检查依赖）：

```powershell
uv run --with tree-sitter --with tree-sitter-swift --with openstep-parser python scripts/verify_repository.py --syntax
```

这些检查不能替代 Swift 编译和 iOS 运行。修改或增加 App 源文件、资源后：

```powershell
python scripts/generate_project.py
```

没有第三方 iOS 包依赖，也没有 XcodeGen 依赖。

## 在借用或云端 Mac 上构建

使用 **Xcode 26.0+**。iPhone / iPad 最低系统版本为 **17.0**，可后续按设备调整。

1. 将整个目录复制或检出到 Mac，包括根目录的 `Package.swift`。
2. 打开 `SUSTech.xcodeproj`，选择 `SUSTech` scheme 和 iPhone / iPad 模拟器。
3. 先运行核心测试，再构建应用：

```sh
swift test
xcodebuild -project SUSTech.xcodeproj -scheme SUSTech \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

模拟器构建不要求 Apple 开发者账号，也不产出可安装到真机的 IPA。
本工程不包含个人 Team ID、证书、签名文件或自动上传配置。

真机：在 Xcode 的 Signing & Capabilities 里选择本人的 Team，并将 bundle identifier
改为自己可用的标识，再选连接的设备运行。免费的 Personal Team 有签名和能力限制；
远程 Mac 构建也不会自动解决 iPhone 安装。TestFlight 需要付费开发者计划。
云端构建使用自己的私有 GitHub 仓库，不上传账号、证书或签名资料。

## 没有 Mac：云端构建与 Windows 侧载

已配置 **Build iPhone and iPad IPA** 手动工作流：核心测试、模拟器构建、
arm64 真机构建、平台检查、IPA 打包和产物上传。没有 push / PR 自动触发，
单次最多 20 分钟，产物保留 7 天。

成功后下载 `SUSTech-iPhone-iPad-数字` 产物，解压并找到 `SUSTech-unsigned.ipa`。
这是供 AltStore 等本地工具重新签名的真机包，不可直接点开安装。
工作流不需要 Apple 开发者账号、证书、校园账号或 GitHub Secrets。

Windows 安装、免费账号签名限制和续签方法见 [侧载教程](docs/WINDOWS_SIDELOAD.md)。
首次完整云编译与真实设备安装的结果，以实际运行和设备验收记录为准。

## 第一轮使用路径

1. 在“我的”切换到演示模式，检查 iPhone / iPad 布局。
2. 切回学校服务模式。分别打开教务和 BB 的学校页面，由用户本人登录。
3. 关闭学校页面，手动同步对应服务；看到页面不意味着原生会话已验证。
4. 核对课表、考试、课程和截止日期，查看所有部分失败提示。
5. 可清除本应用内的网页会话及内存数据，重新测试登录。

浏览器入口与内嵌 WebKit 不共享同一套会话。跨站支付、第三方跳转尚未验证；
当前仅允许学校 HTTPS 顶层导航，其他跳转明确拦截，可改用系统浏览器入口。

## 继续开发

以 [需求与阶段计划](docs/PRODUCT.md)、[接口来源](docs/INTERFACES.md) 和
[设备验收清单](docs/DEVICE_TESTING.md) 为准。先验证鉴权与首批只读流程，
再补齐 Android 功能和已认可的新增功能。真实校园账号只在设备上的学校页面输入。

## 许可

项目按非商业方向开发，上游协议与业务实现参考采用 PolyForm Noncommercial 1.0.0。
保留完整 [LICENSE](LICENSE)、[NOTICE](NOTICE) 及应用内上游声明。
这里没有复制学校品牌图标、上游截图或教师个人数据。
