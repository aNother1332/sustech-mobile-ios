# 0.9.0 业务核对与显示能力

核对日期：2026-10-28。经账号持有人授权，仅在本机内存会话中进行真实只读查询。没有执行预约、取消、打印提交、作业提交或支付；没有把凭据、认证令牌、个人资料或他人预约姓名保存为仓库样本、截图或 CI 输入。

## 真实只读结果

| 业务 | 核对结果 | 实现与边界 |
| --- | --- | --- |
| TIS 个人资料 | `/user/me` 可用，但不含专业；`POST /UserManager/queryxsxx` 返回 `ZYMC`、`YXMC` 等 | 合并两份真实资料，不从账号内部 ID 推断学号 |
| IC 房间 | 房间目录返回 26 个房间、8 个楼层分组 | 丢弃预约记录中的姓名等非必要字段 |
| IC 日历 | `GET /ic-web/reserve` 按 `resvDates=yyyyMMdd`、单个 `labIds` 可读取今天和次日日程 | 读取 `openTimes` 与单数 `resvInfo`；状态含 128 的记录不显示占用；缺失/异常日程不可选，不能当作空闲；逗号拼接房间 ID 已验证不可用，未采用 |
| 交换项目 | 列表返回 24 个项目，其中 22 个有真实图片字段；UTF-8 有效，文本含 HTML 数字实体 | 解码实体后去除标记；可见卡片按需加载图片，临时会话不使用磁盘缓存，离页取消并释放 |
| 交换图片 | 同源 HTTPS 图片返回 HTTP 200 `image/jpeg` | 不以虚构照片代替无封面的项目 |
| 空教室 | 有效教务身份及学期接口正常；旧目录 `POST /component/queryDiDian` 多组原版参数均返回 HTTP 200、零字节响应 | **尚未恢复真实查询**。保留简短错误；不伪造目录、不把未知占用显示为空闲。上游 CLI 同一路径也未提供可验证的替代来源 |
| Blackboard | CAS 后本人接口返回 HTTP 200 JSON | 不代表作业提交已实测 |
| 校园卡 | 账户页返回含余额字段的 HTML | 没有发起充值或付款 |
| 打印 | 客户端入口可达 | 不将入口 HTTP 200 当作打印任务查询或提交已通过 |
| 体育预约 | 未验证到独立原生登录或精确的企业微信直达链接 | 按确认方案移除体育 UI、复制密钥流程和无效入口；不伪造企业微信环境 |

## ProMotion

采用 `CADisableMinimumFrameDurationOnPhone=true`，并从当前窗口的 `windowScene.screen.maximumFramesPerSecond` 读取显示能力。SwiftUI/UIKit 动画由系统自适应调度，不创建空转的显示回调，不将最大能力当作实测帧率。

苹果官方产品规格核对的支持范围包括：iPhone 13–16 Pro/Pro Max、iPhone 17、iPhone Air、iPhone 17 Pro/Pro Max；iPad Pro 10.5 英寸、12.9 英寸第二代及之后、全部 11 英寸及 13 英寸系列。型号列表仅用于说明，代码不依赖这份名单，未来设备通过运行时能力检测。iPhone 17e 的官方规格未列 ProMotion，不能仅凭“17”识别。

低电量、温度、辅助功能设置和系统负载可能降低刷新率；尚未用持有人的 iPhone 实测稳定帧率。

- [Apple：优化 iPhone/iPad 的 ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)
- [Apple：高刷新率 Info.plist 配置](https://developer.apple.com/documentation/bundleresources/information-property-list/cadisableminimumframedurationonphone)
- [Apple：maximumFramesPerSecond](https://developer.apple.com/documentation/uikit/uiscreen/maximumframespersecond)
- [iPhone 17 官方规格](https://www.apple.com/iphone-17/specs/)
- [iPhone Air 官方规格](https://www.apple.com/iphone-air/specs/)

## 界面验证的含义

模拟器只使用 DEBUG 示例数据检查布局、启动及导航材质分支。正式版没有数据模式切换入口。模拟器截图不能证明真实预约写入、真实付款或 120 fps 性能；最终构建、截图与安装包来源另见发布说明及 `screenshots/SOURCES.json`。
