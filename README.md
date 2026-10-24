> **项目学习与致谢：** 本项目学习并参考了 [dumixthestpd/sustech-mobile](https://github.com/dumixthestpd/sustech-mobile) 与 [dumixthestpd/sustech_survival](https://github.com/dumixthestpd/sustech_survival) 的校园服务接口与业务实现，在此基础上以 Swift / SwiftUI 移植到 iPhone 和 iPad。感谢原作者的公开分享；上游许可与署名声明予以保留。

<p align="center">
  <img src="App/Assets.xcassets/AppIcon.appiconset/Icon-iphone-60-3x.png" width="100" alt="SUSTechMobile 中央火炬图标">
</p>

# SUSTechMobile · iPhone / iPad

用 Swift 与 SwiftUI 编写的南方科技大学校园事务聚合应用。把课表、考试、成绩和 Blackboard 学习信息放到 iPhone 与 iPad 上，并集中提供常用校园服务入口。

**非学校官方产品，按非商业用途开发。** 仓库名称为 `sustech-mobile-ios`，安装后的软件名称为 **SUSTechMobile**。最低支持 **iOS / iPadOS 17**。

[界面截图](#界面截图) · [当前功能](#当前功能) · [构建与安装](#构建与安装) · [功能规划](docs/FEATURE_ROADMAP.md) · [接口来源](docs/FEATURE_EVIDENCE.md)

## 当前状态

当前功能版本为 **0.2.0 试用版**。此前交付已通过 34 项 Swift 测试、7 项 IPA 打包测试、iPhone/iPad 模拟器启动和 arm64 真机目标编译。

**真实校园账号下的 CAS、教务、BB 和课件下载仍待逐项验收。** 截图与编译通过不代表学校接口均已验证可用。0.1.0 已验证过 Windows 签名安装路线；0.2.0 的安装仍可能遇到签名工具或 Apple 开发证书申请问题。

## 当前功能

| 模块 | 已实现的能力 | 使用边界 |
| --- | --- | --- |
| 今天 | 汇总课程、考试与已同步课程的学习任务，显示连接状态 | 学校服务模式需先登录和同步；首页不会自动扫描所有 BB 课程历史 |
| 学校登录 | 原生 CAS 账号密码表单；教务与 BB 分别验证；网页登录备用 | 不保存密码，不自动重试错误密码；验证码等交互交回学校网页 |
| 课表 | 全学期课表、教学周切换、学校返回的节次时刻、本机缓存 | 全学期接口失败时回退到当前周；不猜测调休、未知周次或上课时间 |
| 考试 | 课程、日期、时间、地点和座位信息 | 以学校实际返回结果和最新通知为准 |
| 成绩 | 分页读取、学期筛选、学分与单条成绩展示、GPA 记录试算 | 试算不合并重修或替代课程，不代表学校官方总 GPA |
| Blackboard | 课程列表；按课程读取任务、本人提交状态、公告与内容目录 | 未确认的状态显示未知；当前不提交作业 |
| 课件与离线 | 附件下载、Quick Look 预览、系统分享、文件删除；同步时间与缓存提示 | 附件支持范围有限；外部链接和特殊内容需到学校页面核对 |
| 办事入口 | 教务、BB、校园卡、打印、图书馆、IC 研讨间、场馆预约、语言辅导、国际交流、教师名录 | 目前主要提供官方网页入口；余额、预约、打印等原生流程尚未完成 |
| iPad | 宽屏侧栏与详情布局 | 真机旋转、分屏和完整辅助功能仍待验收 |
| 演示模式 | 不登录学校账号即可浏览示例课程、考试、任务与页面结构 | 示例为虚构数据，部分页面会显示尚未同步的空状态 |

详细变更与使用步骤见 [0.2.0 版本说明](docs/RELEASE_0_2.md)，验证记录见 [构建验收记录](docs/BUILD_VALIDATION.md)。

## 界面截图

以下均为云端 iOS 模拟器中实际运行本项目得到的截图，使用演示数据或空登录表单，**不含真实学生账号、成绩或课程记录**。每组左侧为 iPhone，右侧为 iPad；点击图片可查看原图。截图展示当前界面，包括尚未同步的空状态，不用概念图代替已实现页面。

### 今天

课程与学习任务汇总。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-today.png" width="260" alt="iPhone 今天"></td>
    <td><img src="docs/screenshots/iPad-today.png" width="520" alt="iPad 今天"></td>
  </tr>
</table>

### 课表

演示课表与课程安排。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-timetable.png" width="260" alt="iPhone 课表"></td>
    <td><img src="docs/screenshots/iPad-timetable.png" width="520" alt="iPad 课表"></td>
  </tr>
</table>

### 考试

示例考试的时间、地点与座位信息。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-exams.png" width="260" alt="iPhone 考试"></td>
    <td><img src="docs/screenshots/iPad-exams.png" width="520" alt="iPad 考试"></td>
  </tr>
</table>

### 成绩

演示模式尚无成绩样例，截图展示同步前空状态；真实成绩需登录后读取。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-grades.png" width="260" alt="iPhone 成绩"></td>
    <td><img src="docs/screenshots/iPad-grades.png" width="520" alt="iPad 成绩"></td>
  </tr>
</table>

### Blackboard

演示课程列表及离线文件入口；具体课程任务、公告与课件需读取后查看。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-blackboard.png" width="260" alt="iPhone Blackboard"></td>
    <td><img src="docs/screenshots/iPad-blackboard.png" width="520" alt="iPad Blackboard"></td>
  </tr>
</table>

### 办事

常用学校服务入口，页面明确标注尚未完成的原生能力。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-services.png" width="260" alt="iPhone 办事"></td>
    <td><img src="docs/screenshots/iPad-services.png" width="520" alt="iPad 办事"></td>
  </tr>
</table>

### 我的

数据模式、登录与连接管理。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-account.png" width="260" alt="iPhone 我的"></td>
    <td><img src="docs/screenshots/iPad-account.png" width="520" alt="iPad 我的"></td>
  </tr>
</table>

### 原生登录

空白 CAS 登录表单；不在截图中输入真实凭据。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-native-login.png" width="260" alt="iPhone 原生登录"></td>
    <td><img src="docs/screenshots/iPad-native-login.png" width="520" alt="iPad 原生登录"></td>
  </tr>
</table>

### 桌面图标

中央火炬图案与 SUSTechMobile 软件名称。

<table>
  <tr>
    <th>iPhone</th><th>iPad</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-home.png" width="260" alt="iPhone 桌面图标"></td>
    <td><img src="docs/screenshots/iPad-home.png" width="520" alt="iPad 桌面图标"></td>
  </tr>
</table>

## 构建与安装

需要 Xcode 26.0+ 编译，应用运行最低要求 iOS / iPadOS 17。没有第三方 iOS 包依赖，不需要 XcodeGen。

### 使用 Mac 构建

```sh
swift test
xcodebuild -project SUSTech.xcodeproj -scheme SUSTech \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

真机运行需要使用自己的 Apple 开发签名配置。仓库不包含个人证书、私钥、Team ID 或描述文件。

### 使用 Windows 与云端构建

无需拥有本地 Mac：可使用 GitHub Actions 的 macOS runner 编译，再由 Windows 侧载工具在本地签名安装。

1. Fork 本仓库，在自己的仓库中启用 Actions。
2. 手动运行 **Build iPhone and iPad IPA** 工作流。
3. 等待成功，下载 `SUSTech-iPhone-iPad-数字` 构建产物。
4. 解压后找到 `SUSTechMobile-unsigned.ipa`，核对同目录的 SHA-256 校验文件。
5. 使用适用的侧载工具，以自己的 Apple 账号在本地重新签名并安装。

IPA 是 **arm64 真机未签名包**，不能直接从文件管理器点击安装。GitHub Actions 产物默认保留 7 天，下载通常需要登录 GitHub。工作流手动触发，不使用 Apple 或校园账号凭据。免费 Apple 账号的签名有效期、设备限制与证书限制仍适用；TestFlight 需要另行配置付费开发者计划。

当前不提供 App Store 或 TestFlight 下载。Windows 安装背景及历史排障记录见 [侧载说明](docs/WINDOWS_SIDELOAD.md)；其中本地修补版 iLoader 的路径属于维护者环境，不是公开下载地址或通用安装依赖。

### Windows 上的源码检查

```powershell
python scripts/verify_repository.py
python -m unittest discover -s scripts/tests -v
```

可选 Swift 语法和工程结构检查：

```powershell
uv run --with tree-sitter --with tree-sitter-swift --with openstep-parser python scripts/verify_repository.py --syntax
```

这些检查不能替代 Swift 编译或真机测试。新增源文件或资源后运行 `python scripts/generate_project.py`。

## 隐私与会话

- 校园认证由客户端直接连接学校 HTTPS 服务，不设置代收校园密码的聚合服务器。
- 原生登录密码不保存，提交后清空输入框；网页登录由 WebKit 管理会话。
- 课表、成绩、课程信息和已下载文件可缓存在本机，界面标明同步状态与时间。
- 切换账号、退出和清理流程会处理对应缓存与会话，防止混用不同账号的数据。
- 请勿在 Issue、日志或截图中提交密码、验证码、Cookie、学号和真实成绩。

## 实现与上游来源

本项目是基于上游接口协议、字段含义与业务行为编写的 **Swift / SwiftUI 移植实现**，并非直接运行 Android 的 Kotlin 界面。CAS 登录、课表周次解析、BB 提交状态与 GPA 参考映射等有具体上游依据。

感谢以下项目：

| 项目 | 参考内容 |
| --- | --- |
| [dumixthestpd/sustech-mobile](https://github.com/dumixthestpd/sustech-mobile) | Android 功能范围、校园服务协议及业务流程 |
| [wormforce/sustech-cli](https://github.com/wormforce/sustech-cli) | 校园接口访问方式与数据解释 |
| [dumixthestpd/sustech_survival](https://github.com/dumixthestpd/sustech_survival) | 校园服务接口说明与流程研究 |

具体源码版本和协议证据见 [FEATURE_EVIDENCE.md](docs/FEATURE_EVIDENCE.md)。语言重写不消除上游许可与署名义务；完整条款与声明见 [LICENSE](LICENSE)、[NOTICE](NOTICE)。

图标从学校官方标识的矢量文件提取中央火炬，去除外围文字与圆环，采用深青背景。校徽及相关标识权利归南方科技大学；来源与生成方式见 [图标来源](Design/Branding/README.md)。本项目不代表学校官方。

## 开发路线与反馈

后续目标是逐步对齐 Android 版本，并在确认接口与实际需求后扩展原生打印、图书馆、校园卡和预约等功能，以及日历、提醒等学习辅助能力。**规划不等于已实现承诺。** 参见 [功能路线图](docs/FEATURE_ROADMAP.md) 与 [设备验收清单](docs/DEVICE_TESTING.md)。

欢迎通过 [Issues](https://github.com/aNother1332/sustech-mobile-ios/issues) 报告问题。请附系统版本、应用版本、操作步骤及脱敏后的错误信息。

```text
App/                       SwiftUI 界面、WebKit 会话与应用状态
Sources/CampusCore/        独立 Swift 包：CAS、TIS、BB、模型与解析
Tests/CampusCoreTests/     Swift Testing 与虚构接口样例
Config/Info.plist          应用配置
scripts/                   工程生成、检查、截图与 IPA 打包
Design/Branding/            图标来源及生成资源
docs/                      截图、功能规划、协议证据与验收记录
.github/workflows/ios.yml   手动云端构建工作流
```

维护流程见 [版本交付与本地清理](docs/RELEASE_WORKFLOW.md)。部分文档保留早期开发、个人安装路径与历史构建记录，请以 README 的当前状态为准。
