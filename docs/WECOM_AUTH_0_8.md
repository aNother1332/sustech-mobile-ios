# 体育场馆企业微信授权核对（2026-10-27）

## 实际流程

1. 使用学校公开 OAuth appid `wx8839ace7048d181b`，`snsapi_base`，回调到 `reservation.sustech.edu.cn/clientMobile.html`。
2. 企业微信授权后，回调 URL 携带一次性 `code`。普通场馆目录进入时可能立即消耗它。用户本地 court-grabber 文档因此使用 `#/reservation/fastReservation` 专用回调保留 code，再复制链接。
3. App 接收本人主动粘贴的完整回调 URL 或 code，调用 `/api/blade-app/qywx/getUserIdByCode` 换取 `wxOpenid/userid` 与 `token`。
4. 后续本人信息、场馆、时段、订单接口以 userid/token 鉴权，响应可能更新 token。本地只在验证成功后写入钥匙串。
5. code 一次使用，token 也会过期。用户本地项目记录约 10 分钟，但本轮没有用真实学校账号重新测量，不把该值写死成普遍有效期。CAS 会话不能代替这项企业微信授权。

## 0.8.0 操作

- 复制专用授权链接并用 `wxwork://` 请求唤起企业微信。此 scheme 只唤起客户端，不声称能将任意网址自动导航到企业微信；用户仍需粘贴打开。
- 从企业微信右上角复制回调，回到 App 点击系统粘贴按钮，一次完成提取、连接和刷新；不会在后台读取剪贴板。
- 已连接时可显式复制本机密钥，包含 userid/token 的 JSON，设置 localOnly 和 60 秒过期。仅供本人使用，不上传服务器、不记入日志。
- 已连接时的“学校预约”快捷方式使用官方路由 `#/reservation/gym`；授权导入继续使用 `fastReservation`，两者用途区分。
- 导入本机密钥先调用用户接口验证，格式正确不代表仍有效。退出清除本机钥匙串；不实现抢场、自动解验证码或循环提交。

## 公开资料与限制

重新 GET 学校 `clientMobile.html` 与当前 JS bundle，路由中确认 `reservation/gym`、`gym/:gymId`、`fastReservation`、`ground/:groundId/:datetime?`、`userCenter` 等。公开 bundle 的 store 使用 localStorage 保存 user.wxOpenid/token；iOS 沙箱禁止本 App 读取企业微信的 localStorage。

本轮未执行真人登录、真实预约或取消。跳转可达性、回调复制是否保留 code、过期后的真实错误和不同场馆规则仍需本人设备核对。

源：学校 https://reservation.sustech.edu.cn/clientMobile.html ；本地参考项目 `sustech-court-grabber` 的登录协议和文档。公开 JS SHA256：

- `clientMobile.afbebf9b.js`：`995e320e50550cbca563eaa2449110d742cb5e68df8019cc8844e40367efb05a`
- `chunk-common.6e843c3c.js`：`21023f59c63adb24da4050f83abb4a1d288b2419bb53d0aa1cf69c60d59c1217`
