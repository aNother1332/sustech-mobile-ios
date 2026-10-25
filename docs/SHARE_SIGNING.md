# 分享打印与桌面小组件签名验证

0.5.0 的普通包 `SUSTechMobile-unsigned.ipa` 不包含扩展。
扩展包 `SUSTechMobile-with-extensions-unsigned.ipa` 包含：

- `CampusPrintShare.appex`：系统分享菜单接收 PDF。
- `CampusWidgets.appex`：可配置的信息组件与四宫格快捷入口。

主 App、两个扩展均需正确签名，并获得相同 App Group：
`group.cn.sustech.community.daily`。对应 Bundle ID：
`cn.sustech.community.daily`、`.printshare`、`.widgets`。

共享容器必须来自有效 provisioning profile。手工加入 entitlement 字符串不产生
Apple 授权；如果工具重写 Bundle ID/Group ID，需要同步修改三个组件实际使用的标识。
Windows iLoader 对这一组合的注册、重签和真机兼容性尚未验证，不能承诺普通包能显示小组件。
不要为试错反复申请或撤销证书；先使用普通包验证主应用。

小组件：安装扩展包后，长按桌面添加 SUSTechMobile；编辑组件可选课程、BB、天气或
校车站点 ID。站点 ID 在 App 校车站点详情中可分享。课程/BB 需先在“我的 → 桌面小组件设置”
主动允许共享文字快照。不会共享密码、Cookie、支付码。关闭共享或切换账户会删除快照并请求
系统重载；系统可能延迟刷新已显示的组件。时间标签表示读取时间，校车不承诺实时刷新。

分享打印：文件 App 选 PDF → 分享 → 校园打印 → 打开主应用“校园打印/系统分享待打印”
→ 选择文件 → 本人核对参数后提交。扩展不自动上传或打印。无共享容器时使用主应用直接导入。

本轮云端编译验证不等于 Apple 签名授权及真实设备验收。
