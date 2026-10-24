# 南科 · 日常 — iPhone / iPad

南方科技大学校园事务聚合应用的 iOS 开发起点。目标是在原生 iOS 上逐步对齐
`dumixthestpd/sustech-mobile`，并加入学习待办、课件、日历、排课等能力。
非学校官方产品，按非商业用途开发。名称为工作名。

## 当前交付状态

当前是 **0.1.0 开发试用版**。已完成云端 Xcode 编译，产出供 Windows 本地重新签名的真机 IPA。
2026-10-24 的[成功构建](https://github.com/aNother1332/sustech-apple/actions/runs/40096253259)
通过 18 项 Swift 测试、7 项 IPA 打包测试、模拟器编译与 arm64 真机编译。
**尚未完成用户设备安装、模拟器界面运行或学校账号真实接口验收。**
不能把“编译成功”视为“学校服务已可用”。详情见 [构建验收记录](docs/BUILD_VALIDATION.md)。

| 内容 | 本批次状态 |
| --- | --- |
| 今天 / 学习 / 办事 / 我的 | SwiftUI 界面，iPhone 标签栏、iPad 分栏导航 |
| 演示模式 | 显式切换，虚构课程和任务，不自动同步；手动打开学校网页仍会联网 |
| 学校网页登录 | WKWebView 交互式登录；会话由本机 WebKit 保存；待真机验证 |
| 教务读取 | 当前学期、当前周、周课表、考试；待真实接口验证 |
| BB 读取 | 用户、已加入课程、分页成绩册截止日期；逐课程展示部分失败 |
| BB 提交状态 / 课件 / 作业提交 | 未实现，当前截止日期始终标注状态未核验 |
| 校园卡 / 打印 / 图书馆 / 预约 / CLE 等 | 学校网页入口，原生能力后续补齐 |
| 密码存储 | 不收集密码，不解析登录表单，不实现自动密码重登 |
| 课程数据离线缓存 / 通知 / 小组件 | 未实现，当前课程数据只在内存中 |
| Mac 应用 | 不提供；Mac 仅用作后续构建与调试环境 |

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
