<h1 align="center">致谢 · 本项目的学习与参考来源</h1>

<p align="center"><strong>SUSTechMobile 的 iOS 移植建立在上游项目公开分享的校园服务研究与实现经验之上。</strong></p>

<h2 align="center"><a href="https://github.com/dumixthestpd/sustech-mobile">sustech-mobile</a> &nbsp; · &nbsp; <a href="https://github.com/dumixthestpd/sustech_survival">sustech_survival</a></h2>

<p align="center">原作者：<a href="https://github.com/dumixthestpd"><strong>dumixthestpd</strong></a><br>感谢原作者公开源码、整理校园接口，并分享校园工具的实现经验。</p>

| 学习与参考项目 | 对本项目的帮助 |
| --- | --- |
| **[sustech-mobile](https://github.com/dumixthestpd/sustech-mobile)** | Android 校园事务聚合应用；本项目学习其功能设计、校园服务访问方式与业务流程，并以此作为逐步对齐 iOS 功能的参考。 |
| **[sustech_survival](https://github.com/dumixthestpd/sustech_survival)** | 校园服务接口与流程资料；帮助本项目理解学校系统的认证方式、接口约定和数据含义。 |

**本项目在学习上述项目的基础上，以 Swift / SwiftUI 编写 iPhone 与 iPad 移植实现。相关协议、字段解释与业务行为具有上游来源，语言重写不消除原项目的许可和署名义务。** 完整参考证据见 [接口来源记录](docs/FEATURE_EVIDENCE.md)，许可与署名见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。也感谢 [wormforce/sustech-cli](https://github.com/wormforce/sustech-cli) 提供的校园接口访问与数据解释参考。

---

<p align="center">
  <img src="App/Assets.xcassets/AppIcon.appiconset/Icon-iphone-60-3x.png" width="100" alt="SUSTechMobile 中央火炬图标">
</p>

# SUSTechMobile · iPhone / iPad

用 Swift 与 SwiftUI 编写的南方科技大学校园事务聚合应用。把课表、考试、成绩和 Blackboard 学习信息放到 iPhone 与 iPad 上，并集中提供常用校园服务入口。

**非学校官方产品，按非商业用途开发。** 仓库名称为 `sustech-mobile-ios`，安装后的软件名称为 **SUSTechMobile**。最低支持 **iOS / iPadOS 17**。

[界面截图](#界面截图) · [当前功能](#当前功能) · [构建与安装](#构建与安装) · [功能规划](docs/FEATURE_ROADMAP.md) · [接口来源](docs/FEATURE_EVIDENCE.md)

## 当前状态

当前功能版本为 **0.6.0 试用版**。本次新增首页教学周、原生教师邮箱/办公室详情，以及参考 [SUSTech CRA / sustech-online-ng](https://github.com/sustech-cra/sustech-online-ng) 实现的原生校园巴士地图：线路、站点、车辆位置、方向、上报时间和过期标记。教师联系方式按需读取官方页面并缓存；未识别到的字段不推测。此前 0.5.0 新增校园码/身份码、低余额设置、2026 校历与调课、网格周课表、本学期课程汇总、994 条公开教师目录、交换项目列表、附近校车、天气/AQI、下一节课/考试、网络诊断、扫描任务删除、版本检查，以及独立 WidgetKit 信息与快捷入口扩展。

界面根据 Apple 设计原则重新整理，采用[学校官方标识页](https://www.sustech.edu.cn/zh/school_logo.html)公布的 **南科大橙 `#ED6C00`、墨绿 `#003F43`、天青 `#2BBCB3`**，以深色重点摘要、彩色服务入口与紧凑课程块建立层级；支持深色模式和系统大字号。使用文字和图标共同表达状态，临近截止时间单独强调。完整功能与验证边界见 [0.6.0 说明](docs/RELEASE_0_6.md)、[0.5.0 说明](docs/RELEASE_0_5.md)。

**真实校园账号下的新接口及续借、打印、预约、BB 提交仍待逐项真机验收。** 界面与编译通过不代表学校服务全部可用；未签名 IPA 仍需本地签名安装，Apple 证书申请问题不属于 App 内登录功能。

## 当前功能

| 模块 | 已实现的能力 | 使用边界 |
| --- | --- | --- |
| 今天 | 当前教学周、校园天气/US AQI、下一节课/考试、今日课程、BB 任务与常用入口 | 折叠课程不进入截止日期汇总；不自动扫描全部 BB 历史 |
| 学校登录 | 原生 CAS 表单、App 内网页共享会话、Keychain 保留 Cookie、按需交换业务会话 | 不保存密码；有效期由学校决定；验证码与独立 OAuth 仍需本人操作 |
| 课表与考试 | 网格/列表周课表、本学期课程汇总、教学日历、放假与补课、考试和离线缓存 | 全学期失败时当前周回退；未知周次和临时调整需核对 |
| 成绩 | 分页读取、学期筛选、成绩与学分、GPA 记录试算 | 不代表学校官方总 GPA 或毕业审核结论 |
| Blackboard | 课程、任务、提交状态、公告、课件、折叠/恢复，Original 个人单文件提交 | 不支持测验/Ultra/小组/已有草稿；预检、本人确认、一次 POST、服务器新记录回读；结果未知不重发 |
| 课件与离线 | 下载、Quick Look 预览、系统分享、删除与同步时间 | 外部链接和特殊内容交学校页面 |
| 校园卡 | 余额、近期账单、本地范围筛选、按日消费曲线 | 原生充值渠道页（支付宝 / 微信入口）；金额与付款在平台完成；消费统计仅覆盖已返回记录 |
| 空教室 | 教室目录、教学周/星期/节次筛选、课程与借用占用查询 | 每次核对筛选前 20 间；系统未见占用不保证可进入 |
| 校车 | 站点、线路方向、预计到站、更新时间与数据来源 | CRA 公共数据，手动刷新，预测不等于实际到站 |
| 校园打印 | PDF 导入、纸张/颜色/单双面/份数/页码、上传、队列与删除 | 50 MB 以内有效 PDF；需签名安装后在校园环境验证；不自动重传 |
| 预约中心 | IC 房间、CLE 辅导、reservation 体育场馆目录与时段、手动预约/取消、本人记录 | 各平台认证和规则独立；体育首次企业微信授权、本人完成滑块；没有抢场 |
| 图书馆 | 馆藏检索、位置/索书号、收藏、人数、静默连接、在借与手动续借 | Primo 独立授权可交互回退；人数不代表空座，续借回读后核对到期日 |
| 日程与提醒 | 课程、考试、BB、预约、借阅到期与个人事项；日历添加/更新、本地提醒 | 课程日期需核对校历锚点；基于已同步信息，不承诺实时后台更新 |
| 课程评价 | NCES 搜索、公开评价分页、收藏 | 社区来源，不代表学校正式评价 |
| 排课 | 学校候选教学班查询/收藏/导入、三套本地方案、周次/节次冲突、学分比较 | 不执行正式选课；未知/部分识别时段不自动导入，主课/实验关系需核对 |
| 修读进度 | 学校总要求、完成情况、学分类别、模块要求 | 学校数据部分失败独立显示，不合计重叠类别为毕业结论 |
| 打印增强 | PDF 课件直接打印、站点、扫描任务列表/确认删除、用量查询 | 扫描下载路径未验证；系统分享扩展单独签名验证 |
| 校园码 | 原生校园码与身份码、30/60 秒前台刷新、过期/后台隐藏、低余额设置 | 真实消费机/核验终端仍待验证，不等于 Apple Wallet 卡片 |
| 教师目录 | 994 条公开资料搜索，原生详情中的邮箱/办公室、复制/分享和邮件入口 | 名录快照 2026-10-02；联系方式按需读取、缓存 7 天，可能未公开或无法识别 |
| 交换项目 | 原生分页列表、可申请筛选、已加载项目搜索、官方详情与申请 | CAS 与 WS 服务会话需学校账号实测，申请在官方页面完成 |
| 校车地图 | 原生 Apple 地图、线路轨迹、站点到站入口、车辆位置、线路筛选、暂停车辆开关 | 10 秒前台轮询；超过 2 分钟或未知上报时间标灰，不等同连续 GPS；底图需联网 |
| 小组件 | 可配课程/BB/天气/校车信息，四宫格快捷入口与 App 路由 | 独立扩展包；共享课程与 BB 需主动开启，App Groups 签名未实测 |
| 维护工具 | 网络与服务可达性诊断、GitHub 发布版本检查 | 可达性不代表已登录；侧载更新仍需本地签名 |
| 其他办事 | 保留图书馆等官方网页及原体育预约平台入口 | 尚未原生化的流程继续使用学校页面 |
| iPad 与演示 | 宽屏布局，虚构学习样例及无需账号的界面浏览 | 新校园服务在演示模式不产生真实打印或预约 |

0.5.0 提供普通包和包含系统分享打印、WidgetKit 扩展的独立验证包；扩展需要有效 App Groups 签名，免费账号/iLoader 兼容性未通过真机验收。普通包保留主 App 内 PDF 导入。

**完整原生充值下单仍未完成。** 已具备原生授权/身份只读验证及金额准备页，但外部企业微信授权交接、当前下单分支响应和权威单笔到账查询未验证，正式下单保持关闭。现有外部充值入口继续可用。详见 [写入协议审计](docs/WRITE_PROTOCOL_AUDIT_0_4.md)。

上一版使用与限制见 [0.4.0 说明](docs/RELEASE_0_4.md)，审查修正见 [代码审查](docs/REVIEW_0_4.md)。

本轮操作路径和验收步骤见 [0.3.0 说明](docs/RELEASE_0_3.md)，上一版记录见 [0.2.0 说明](docs/RELEASE_0_2.md)。

## 界面截图

以下为云端 iOS 模拟器实际运行的 **0.5／0.6 版本界面截图（70 张）**，包含 iPhone/iPad、深色外观及大字号。课程、任务、余额等为虚构示例或未连接状态；教师目录为学校已公开资料快照；不含真实学生账号或认证凭据。0.5 基础界面运行 [40172533665](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40172533665)，界面提交 `6f752ef`。最后的校历/小组件过期逻辑、官方项目详情控件与说明修正经[最终构建 40173815553](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40173815553)验证，78 项 Swift 测试与 8 项打包测试通过，重点场景另复查 12 张。每张图的来源见 [SOURCES.json](docs/screenshots/SOURCES.json)。截图不作为真实校园业务验收。

### 0.6 校园巴士地图与教师联系方式

地图采用原生 Apple 地图，车辆为虚构示例；路线与站点来自 CRA 公开数据快照。浅色、深色和 iPad 地图均已实际运行，自动检查确认加载 4 条线路、351 个轨迹点、33 个站点与 2 辆示例车。

| iPhone | iPad |
| --- | --- |
| ![校园巴士地图（示例车辆）](docs/screenshots/iPhone-bus-map.png) | ![校园巴士地图（示例车辆）](docs/screenshots/iPad-bus-map.png) |
| ![深色巴士地图](docs/screenshots/iPhone-bus-map-dark.png) | ![深色巴士地图](docs/screenshots/iPad-bus-map-dark.png) |
| ![教师联系方式（虚构示例）](docs/screenshots/iPhone-faculty-detail.png) | ![教师联系方式（虚构示例）](docs/screenshots/iPad-faculty-detail.png) |

新增地图截图运行 [40177111042](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40177111042)，教师详情运行 [40175903374](https://github.com/aNother1332/sustech-mobile-ios/actions/runs/40175903374)。教师详情中的邮箱与办公室为虚构样例，真实使用按需读取官方页面。名录与既有页面保留各版本截图，70 个文件的来源记录于 SOURCES.json。

### 学校标识色与深色外观

| 首页 · 深色 | 办事 · 深色 |
| --- | --- |
| ![深色首页](docs/screenshots/iPhone-today-dark.png) | ![深色办事](docs/screenshots/iPhone-services-dark.png) |

### 校园码、校历与教师目录

| iPhone | iPad |
| --- | --- |
| ![校园码未连接示例](docs/screenshots/iPhone-code.png) | ![校园码未连接示例](docs/screenshots/iPad-code.png) |
| ![教学日历](docs/screenshots/iPhone-calendar.png) | ![教学日历](docs/screenshots/iPad-calendar.png) |
| ![公开教师目录](docs/screenshots/iPhone-faculty.png) | ![公开教师目录](docs/screenshots/iPad-faculty.png) |

### 交换项目与小组件设置

| iPhone | iPad |
| --- | --- |
| ![交换项目示例界面](docs/screenshots/iPhone-exchange.png) | ![交换项目示例界面](docs/screenshots/iPad-exchange.png) |
| ![小组件共享设置](docs/screenshots/iPhone-widgets.png) | ![小组件共享设置](docs/screenshots/iPad-widgets.png) |

小组件设置截图不等于桌面组件签名成功，实际扩展安装与 App Groups 仍需真机核对。

### 系统大字号

| iPhone | iPad |
| --- | --- |
| ![大字号列表课表](docs/screenshots/iPhone-study-large.png) | ![大字号列表课表](docs/screenshots/iPad-study-large.png) |

### 图书馆

| iPhone | iPad |
| --- | --- |
| ![iPhone 图书馆](docs/screenshots/iPhone-library.png) | ![iPad 图书馆](docs/screenshots/iPad-library.png) |

### 统一日程

| iPhone | iPad |
| --- | --- |
| ![iPhone 日程](docs/screenshots/iPhone-agenda.png) | ![iPad 日程](docs/screenshots/iPad-agenda.png) |

### 课程评价

| iPhone | iPad |
| --- | --- |
| ![iPhone 课程评价](docs/screenshots/iPhone-reviews.png) | ![iPad 课程评价](docs/screenshots/iPad-reviews.png) |

### 排课工作台

| iPhone | iPad |
| --- | --- |
| ![iPhone 排课](docs/screenshots/iPhone-planner.png) | ![iPad 排课](docs/screenshots/iPad-planner.png) |

### 修读进度 · 未连接状态

| iPhone | iPad |
| --- | --- |
| ![iPhone 修读进度](docs/screenshots/iPhone-degree.png) | ![iPad 修读进度](docs/screenshots/iPad-degree.png) |

### 校园卡充值

原生渠道选择与到账查询；截图为演示模式，支付入口禁用。金额和支付在外部平台完成，尚未验证真实充值到账。

| iPhone | iPad |
| --- | --- |
| ![iPhone 充值渠道](docs/screenshots/iPhone-recharge.png) | ![iPad 充值渠道](docs/screenshots/iPad-recharge.png) |

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

### 校园卡与消费曲线

虚构余额与四笔样例账单；三笔支出合计 25.80 元，一笔退款不计入消费曲线。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-card.png" width="260" alt="iPhone 校园卡与消费曲线"></td>
    <td><img src="docs/screenshots/iPad-card.png" width="520" alt="iPad 校园卡与消费曲线"></td>
  </tr>
</table>

### 空教室查询

教学周、星期与节次筛选。演示模式不请求私人教务数据，目录为空。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-classrooms.png" width="260" alt="iPhone 空教室查询"></td>
    <td><img src="docs/screenshots/iPad-classrooms.png" width="520" alt="iPad 空教室查询"></td>
  </tr>
</table>

### 原生 PDF 打印

文件导入、纸张、颜色、单双面、份数和页码参数。演示模式不能提交真实打印。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-printing.png" width="260" alt="iPhone 原生 PDF 打印"></td>
    <td><img src="docs/screenshots/iPad-printing.png" width="520" alt="iPad 原生 PDF 打印"></td>
  </tr>
</table>

### 统一预约中心

IC、CLE 和新体育场馆入口，并保留原体育预约平台。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-reservations.png" width="260" alt="iPhone 统一预约中心"></td>
    <td><img src="docs/screenshots/iPad-reservations.png" width="520" alt="iPad 统一预约中心"></td>
  </tr>
</table>

### IC 研讨间

未连接状态：房间与本人预约需登录后读取，不用虚构列表冒充学校可约资源。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-ic.png" width="260" alt="iPhone IC 研讨间"></td>
    <td><img src="docs/screenshots/iPad-ic.png" width="520" alt="iPad IC 研讨间"></td>
  </tr>
</table>

### CLE 语言辅导

官方连接、日期与预约说明，以及原生时段和本人预约区域。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-cle.png" width="260" alt="iPhone CLE 语言辅导"></td>
    <td><img src="docs/screenshots/iPad-cle.png" width="520" alt="iPad CLE 语言辅导"></td>
  </tr>
</table>

### 体育场馆

企业微信授权入口、场馆列表和本人订单区域；未连接状态不显示虚构场地。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-court.png" width="260" alt="iPhone 体育场馆"></td>
    <td><img src="docs/screenshots/iPad-court.png" width="520" alt="iPad 体育场馆"></td>
  </tr>
</table>

### BB 课程折叠

将示例线性代数课程移入“已折叠课程”，主列表仅保留程序设计基础。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-blackboard-folded.png" width="260" alt="iPhone BB 课程折叠"></td>
    <td><img src="docs/screenshots/iPad-blackboard-folded.png" width="520" alt="iPad BB 课程折叠"></td>
  </tr>
</table>

### 折叠后的首页截止日期

线性代数的示例任务已从首页排除，仅保留未折叠课程的截止日期。

<table>
  <tr><th>iPhone</th><th>iPad</th></tr>
  <tr>
    <td><img src="docs/screenshots/iPhone-today-folded.png" width="260" alt="iPhone 折叠后的首页截止日期"></td>
    <td><img src="docs/screenshots/iPad-today-folded.png" width="520" alt="iPad 折叠后的首页截止日期"></td>
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

后续目标是逐步对齐 Android 版本，验证和完善本轮原生办事流程，继续扩展图书馆借阅、日历与本地提醒等能力。**规划不等于已实现承诺。** 参见 [功能路线图](docs/FEATURE_ROADMAP.md) 与 [设备验收清单](docs/DEVICE_TESTING.md)。

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
