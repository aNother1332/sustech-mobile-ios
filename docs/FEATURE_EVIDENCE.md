# 后续功能的源码证据与优先级

审查日期：2026-10-24。此记录仅分析固定版本源码，未登录学校、未调用真实校园账号接口、未验证当前学校系统兼容性。手机安装成功只证明交付链路可用，不证明校园接口已验收。

## 固定来源

- M：[sustech-mobile 509a6535](https://github.com/dumixthestpd/sustech-mobile/tree/509a65357579f220d69b582956b38fc79d291f6a)
- C：[sustech-cli 1a760afb](https://github.com/wormforce/sustech-cli/tree/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53)
- S：[sustech_survival 77802954](https://github.com/dumixthestpd/sustech_survival/tree/778029546143af849d731dfe151626b40ba67ac9)

对应本地只读研究副本位于 `D:/Altstore/Source/campus-research/{mobile,cli,survival}`。本报告中“支持”表示来源有协议/实现，不能理解为本项目已经移植或实测。上游的真实测试声明与本项目验收分开记录。

## 当前首要依赖：CAS 登录

用户澄清实际症状是 CAS 页面显示不完整，希望原生输入学号密码。显示不完整不等于服务端拒绝移动浏览器；本项目已设置桌面 User-Agent，因此还需区分页面布局、preferredContentMode 与真实认证失败。原生输入方案有直接上游依据：

- [M CasLogin.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/sso/CasLogin.kt)：说明 TIS 拒绝移动浏览器登录，使用桌面 Chrome User-Agent；部分服务另加 `X-Requested-With: XMLHttpRequest`。先 GET `https://cas.sustech.edu.cn/cas/login?service=...` 解析 execution，再 POST username/password/execution/_eventId=submit，捕获 ST ticket，访问服务换取服务会话 cookie。固定版本未见该 CAS 流程要求额外 JS 密码加密；这不代表未来学校一定不调整协议。
- [C src/sso/cas.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/sso/cas.ts)：同样支持原生账号表单，但在 POST 密码前检查交互验证码，返回 `CAS_INTERACTIVE_CHALLENGE_REQUIRED`，转官方浏览器完成验证；不是万能免验证码登录。
- [C src/tis/auth.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/tis/auth.ts)：TIS 的 service 为 `https://tis.sustech.edu.cn/cas`。

建议：用户在设备上原生输入，默认内存持有密码；若增加“记住密码”则使用 Keychain 且可清除。会话 cookie 应正确回写 WebKit，供网页入口复用。重定向限定 HTTPS + 服务白名单，凭据 POST 只发 CAS；先服务端身份验证再宣告成功。验证码/协议变化进入明确交互回退，停止无限重登。不要直接照搬 Android 的宽松 ticket URL 判断和错误页片段日志；CLI 的主机白名单、重定向次数上限更适合参考。

## 对齐 Android 的实用优先级

| 优先级 | 功能 | 直接源码证据 | 实现边界/验收重点 |
| --- | --- | --- | --- |
| P0 | 登录、会话诊断、错误区分 | 上述 CAS 源码 | 登录是其他个人功能前提；要分账号拒绝、验证码、网络、服务不支持。 |
| P1 | 全学期课表、切周、真实上课时刻 | [M TisApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/tis/TisApi.kt) | `/xszykb/queryxszykbzong`、`/component/queryKbjg`；校验周位图、单双周、补课、校历对应日期，不硬编码节次时间。 |
| P1 | 成绩、按学期汇总、GPA参考 | 同一 TisApi.kt；[C academics.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/tis/academics.ts) | `/cjgl/grcjcx/grcjcx`；不能照抄 Android “500条够用”的假设，应分页。GPA重修/等级制/免修规则须显式说明，与学校口径核对。 |
| P1 | BB 作业详情、实际提交状态、公告 | [S assessments.py](https://github.com/dumixthestpd/sustech_survival/blob/778029546143af849d731dfe151626b40ba67ac9/src/sustech_survival/bb/assessments.py)、[C blackboard.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard.ts) | 联结课程、gradebook、作业/attempt状态；保留已提交、草稿、未提交、未知及部分失败。截止日期存在不等于待交；404不能一概解释无提交。 |
| P1 | 离线缓存、最近同步时间 | 本项目 PRODUCT/INTERFACES 的既定欠缺 | 本项目目前内存存储；先加入账号隔离、退出清除、过期标记，再做依赖缓存的提醒/组件。 |
| P2 | 打印上传、参数、队列、扫描、用量、站点 | [M PmsApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/pms/PmsApi.kt)、[C pms.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/pms.ts) | `/client/CloudPrint/Upload` 与打印队列等；校内/VPN要求、独立认证、首次账号关联均需验证。上传超时先查队列，不自动重传。参数含单双面、份数、页码等，严格按来源映射。 |
| P2 | 图书检索、馆藏位置、人数、我的借阅与续借 | [M LibraryApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/library/LibraryApi.kt)、[M LoansApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/library/LoansApi.kt) | Primo 检索与个人借阅认证不同；续借会消耗次数，先显示对象/日期再提交并回读；馆藏可借不等于书还在架上。 |
| P2 | IC研讨间：空闲/我的预约/预约/取消 | [M RoomApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/library/room/RoomApi.kt)、[C library-booking-auth.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/library-booking-auth.ts) | 独立登录链、成员/人数/时段/规则，不能由列表为空推导可预约；提交前刷新可用性，回读预约。 |
| P2 | 校园卡余额与账单 | [M EcardApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/ecard/EcardApi.kt) | 优先只读；充值交官方支付环境，iOS微信跳转另验。校园码/身份码是否可移植需单列验证，不能从余额接口推导。 |
| P2 | 校车站点、方向、实时到站 | [M BusApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/transit/BusApi.kt) | 公共聚合来源；展示更新时间/方向/预计性质，不把缓存当实时。定位为可选，用于附近站点。 |
| P3 | 课程评价、教师目录、国际交流、场馆/CLE入口 | [M README](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/README.md)、[C SERVICES](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/docs/SERVICES.md) | Android 部分已有原生协议但实际界面交官方网页，应按“用户闭环”对齐；评价是社区信息，目录可能是离线快照。 |

## 在对齐基础上可以新增的能力

1. **统一学习待办：最优先的组合功能。** BB真实提交状态 + TIS考试 + 用户个人事项，之后增加借阅到期/预约。筛选今天/本周/已提交，未知状态保留来源说明。本地勾选完成与学校提交成功是不同状态。技术依据是上述 BB assessment、TIS exams 与 LoansApi，不需要聚合服务器。
2. **BB课件离线阅读。** [C blackboard.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard.ts) 有内容树、教师附件、下载；[S download.py](https://github.com/dumixthestpd/sustech_survival/blob/778029546143af849d731dfe151626b40ba67ac9/src/sustech_survival/bb/download.py) 提供下载实现。按用户选课/选文件保存，展示大小和来源，同源下载检查、账号隔离、更新与清理；教师附件和个人已交文件分开。不是所有外链、DRM文件都支持。
3. **系统日历与本地提醒。** [C blackboard-calendar.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard-calendar.ts) 提供BB REST日历；[C calendar/client.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/calendar/client.ts) 读取社区维护校历并处理节假日/补课。本项目当前仅有星期/节次，没有完整日期/真实时间；先补全课表发生日期再导出。通过EventKit或ICS显式导出，稳定ID防重复、变更可更新。BB原生ICS链接相当于私密令牌，不写入日志。iOS后台不保证即时提醒新增任务。
4. **排课工作台。** [C planner.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/tis/planner.ts) 有时间冲突求解、用户不可用时段和偏好；[C SELECTION_CONTRACTS](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/docs/SELECTION_CONTRACTS.md) 说明主课/实验/习题组件组合。可做收藏课程、多方案对比、冲突/学分统计，适合iPad双栏。先只做本地方案，不能声称学校已选上或必定能选。
5. **空教室与自习推荐。** [S classroom/live.py](https://github.com/dumixthestpd/sustech_survival/blob/778029546143af849d731dfe151626b40ba67ac9/src/sustech_survival/tis/classroom/live.py) 的 `/cdkb/querycdkbList` 能覆盖课表之外的教室借用；[C remaining-classroom.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/tis/remaining-classroom.ts) 有目录、占用与时间过滤。仅依据课程目录推导会漏借用，结果必须标“系统未见占用”，不保证开门/可进入；隐藏上游借用人电话等无关个人信息。
6. **从分享菜单打印。** PMS上传形成闭环后，加Share Extension收PDF/图片/其他支持格式，跳主应用选参数并确认，适合从BB课件/文件App快速打印。当前没有服务端证据证明任何格式都可打印，先限制已验证格式。扩展目标与免费签名限制需云构建和真机签名实测。
7. **学业进度与缺课建议。** [C DEGREE_PROGRESS](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/docs/DEGREE_PROGRESS.md) 描述官方个性化修读进度；[C DEGREE_AUDIT](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/docs/DEGREE_AUDIT.md) 则是成绩与本地要求文件比较，两者不能混同。优先官方结构化进度，区分在修/已完成/条件不明，培养方案需要人工审核，不能承诺毕业资格。
8. **CLE空闲与额度、预约日历增强。** [S CLE文档](https://github.com/dumixthestpd/sustech_survival/blob/778029546143af849d731dfe151626b40ba67ac9/docs/zh/cle.md) 及 [CleClient](https://github.com/dumixthestpd/sustech_survival/blob/778029546143af849d731dfe151626b40ba67ac9/src/sustech_survival/ehall/cle/client.py) 支持时段、我的预约与额度。需要浏览器引导e-hall会话，纯CAS直连可能403；先原生只读+官方页面写入，规则按当前学校返回而不是永久硬编码。
9. **前台同步后的变化提示。** 对成绩、截止日期、预约做本地快照差异；[C academic/changes.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/academic/changes.ts) 有比较参考。只在真实成功同步后提示，部分失败不冒充数据被删除；不承诺推送实时性。

## 已讨论的新增写操作

- **BB文件提交可排后续试验批。** [C blackboard-submission.ts](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard-submission.ts)、[C SERVICES](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/docs/SERVICES.md) 表明支持Classic/Original个人作业HTTP表单；Ultra/小组不支持。来源仅对特定个人文件重交声明过真实提交+回读，不能推广为本项目已验证。先读新表单和nonce，展示课程/作业/文件与大小，用户确认后单次提交，回读attempt回执；超时进入结果不确定，不自动重发。文本富编辑、测验和小组交付另议。
- **手动选退课应晚于本地排课。** 参考C SELECTION_CONTRACTS：必须保留courseId+rwh组件准确身份、当前选课轮次、fresh预检查与最终回读；本地请求ID不等于学校幂等键。未知结果禁止自动重试。不能用课程代码/组合ID替代真实写入ID。用户每次审查目标再执行，投点与自动抢课继续暂缓。

## 建议下一批可验收交付

先完成原生CAS/网页回退、真实TIS/BB同步验收和缓存，再做“全学期课表+实际时刻+成绩”与“真实BB待办/公告”。这两组分别建立日历/组件和课件/提交的基础。随后单独交付打印闭环、图书馆闭环和IC预约，保持Android对齐目标。新增六项可逐批审核，不应在一次版本里同时扩展全部系统。

验收证据至少包括：用户本人设备上的成功/失败会话、与官方网页同一条记录核对、账号退出和切换、离线旧数据标记、部分权限拒绝/数据为空区别。所有来源许可与署名按本项目NOTICE和上游许可保留。

