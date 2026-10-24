# 接口来源与当前实现边界

协议参考读取自此前审查的本机仓库副本，固定版本：

- [sustech-mobile 509a6535](https://github.com/dumixthestpd/sustech-mobile/tree/509a65357579f220d69b582956b38fc79d291f6a)
- [sustech-cli 1a760afb](https://github.com/wormforce/sustech-cli/tree/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53)
- [sustech_survival 77802954](https://github.com/dumixthestpd/sustech_survival/tree/778029546143af849d731dfe151626b40ba67ac9)

这是上游源码的行为参考，不是本项目对学校接口的实时验证记录。

## 0.3.0 当前新增实现

| 模块 | 协议与来源 | 当前边界 |
| --- | --- | --- |
| 会话 | 已有 CAS Cookie → GET 服务票据交换；WebKit 与原生共享 Cookie | Keychain 保存，不保存密码；学校有效期与独立 OAuth 不可统一承诺 |
| 校园卡 | Android EcardApi：`/epay/h5/accountinfo`、`/epay/h5/bill` 的 HTML | 余额、已返回账单、确认支出曲线；没有充值和未经证实的历史分页接口 |
| 空教室 | CLI remaining-classroom / survival classroom：`/component/queryDiDian`、`/cdkb/querycdkbList` | RoleCode 请求头，教学周、借用与节次范围；不保留借用人姓名电话 |
| 校车 | CRA 公共 `/stops`、`/arrivals/{stop}` | 本轮开发时只读探测确认站点数组和到站响应结构；没有学校私人数据验证 |
| 打印 | Android PMS：`/api/client/CloudPrint/Upload`、`/api/client/PrintJob/Get`、`/api/client/PrintJob/Del` | PDF multipart，字段和单双面编码按上游映射；未知回执先查队列 |
| IC | Android RoomApi：动态 auth/address、房间、我的预约、reserve、delete | 不混用设备外借表单；成员用准确学号解析；写入单次并回读 |
| CLE | survival ehall.cle 的 EMAP 查询、完整保存模型与取消模型 | 学校页面完成 eHall 初始化后读取本人身份和会话；不读取密码 |
| 体育 | 用户本地 sustech-court-grabber 的 API 协议 | 企业微信令牌独立；全场馆分页；不带错误的 type=2；本人验证码、单次手动预约 |
| BB | 原有课程 ID / tasks 的本机显示偏好 | 折叠课程不进入首页截止日期，保留目录和恢复入口，不修改学校记录 |

学校浏览器仅在 eHall 官方主机读取 `window.userId` / `window.userName` 以识别本人 CLE 预约；不读取密码。详细操作与设备验收见 [0.3.0 说明](RELEASE_0_3.md)。以下 0.2/0.1 内容为历史记录。

## 0.2.0 新增实现

原生 CAS：execution 表单、HTTPS 受限跳转、教务 `/cas` 与 BB SSO service 分项验证；验证码/滑块挑战使用官方网页。
TIS：全学期 `/xszykb/queryxszykbzong`、节次 `/component/queryKbjg`、分页成绩 `/cjgl/grcjcx/grcjcx`。
BB：按课程读取 gradebook columns、本人 attempts、user grades、announcements、contents/children、attachments 和同源下载。
缓存：课表、成绩、BB 内容与下载文件在本机受保护保存；密码不保存，学校 cookie 由 WebKit 保存。

详细路径、实现边界、测试和真机验收见 [0.2.0 说明](RELEASE_0_2.md)。以下保留 0.1.0 初始接口与设计记录，涉及“仅内存”等批次表述为历史状态。

## 0.1.0 初始原生读取

| 服务 | 方法 / 路径 | 契约 |
| --- | --- | --- |
| TIS | POST `/component/querydangqianxnxq`，空表单 | XN / XQ / XNXQ，学年和学期允许字符串或数字 |
| TIS | POST `/component/querydangqianzc`，空表单 | 裸整数教学周；空响应/null 不猜测为第一周 |
| TIS | POST `/xszykb/queryxszykbzhou`，xn/xq/zc 表单 | 数组；KEY 给星期，KSJC/JSJC 给起止节次 |
| TIS | POST `/component/queryKsxxByXs`，JSON `{}` | 考试数组，优先保留学校直接给出的考试时刻 |
| BB | GET `/learn/api/public/v1/users/me` | 只有取得实际 user id 才继续 |
| BB | GET `/learn/api/public/v1/users/{id}/courses?expand=course&limit=100` | 展开课程，读取分页，按课程 ID 去重 |
| BB | GET `/learn/api/public/v1/courses/{id}/gradebook/columns?limit=100` | 读取 grading.due，不把它误读为顶层 due；逐课程部分失败 |

来源：[TisApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/tis/TisApi.kt)、
[TisModels.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/tis/TisModels.kt)、
[BbApi.kt](https://github.com/dumixthestpd/sustech-mobile/blob/509a65357579f220d69b582956b38fc79d291f6a/app/src/main/java/edu/sustech/mobile/bb/BbApi.kt)。

BB 截止日期不是完整 assessment 任务接口。当前原生界面明确不显示“待交”结论；
后续参考 survival 的结构化 assessment 接口及 CLI 的类型与实测边界再扩展。
分页限制最多 100 页，循环/异常结构作为错误；不将缺少 `results` 视为空数组。
全学期课表的 ZC bitmap 上游注释和实现存在偏移表述差异，本批次使用单周端点避开未经验证的解释。
暂不硬编码课程时刻，也不从设备日期推算教学周或补课日。

## 会话与传输（0.1.0 历史设计）

- WKWebView 由用户交互登录，应用不读取 DOM、密码或注入自动登录脚本。
- 学校 HTTPS 顶层导航可在应用内进行；其他导航明确拦截，官方入口可交系统浏览器。
- 每次同步从本机 WebKit cookie store 创建临时 URLSession，系统按 cookie 的域/路径规则发送。
- 原生请求限定同服务 HTTPS origin，阻止重定向，不自动跟到 CAS 或任意外站。
- 原生响应中更新的学校 cookie 回写 WebKit；不记录 cookie 或请求内容，不接收远程账号。
- 默认 TLS 验证，不实现跳过证书验证，也不添加 ATS 全局例外。
- 401/重定向、403、429、HTTP 200 HTML、格式变化分开处理，无后台自动重登循环。
- 本批次无自建后端、无请求代理、无重试真实写操作。

## 测试样例

Tests 中 JSON 是依据上述字段契约手写的虚构样例，不是校园账号流量抓取，也不包含真实学生信息。
解析测试能验证错误结构、时区、节次语义等本地行为，不能替代学校真实权限和网络验证。
