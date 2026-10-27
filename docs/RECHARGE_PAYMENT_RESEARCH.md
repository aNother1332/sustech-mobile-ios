# Campus card recharge: payment integration research

Research date: 2026-10-25 (Asia/Shanghai). Scope: public, unauthenticated GET requests and first-party documentation only. No account sessions, orders, payments, authentication codes, or merchant credentials were used. This note records evidence and implementation boundaries; it does not establish that recharge is implemented or verified on a real account.

## Finding

A native recharge entry and return-to-app balance refresh are feasible. The supplied Alipay link already exposes an Alipay mini-program launch route for a school-specific recharge page. This is a launch link, not evidence of permission to create recharge orders directly from this app. A native amount-entry/order-confirmation interface requires a verified, authenticated school/provider order API and supported payment handoff; those prerequisites must be verified separately.

Even an official native payment SDK usually hands authorization to the payment provider's app. “Native recharge UI” and “payment completed entirely within SUSTechMobile” are distinct promises. The latter is not established by either supplied URL.

## Alipay link: observed public redirect

User-provided URL: <https://ur.alipay.com/_2caU83nozW8S75SNtALLHW>.

An unauthenticated GET returned HTTP 302 to `https://render.alipay.com/p/s/i/`, whose query contains a URL-encoded `scheme`. That scheme decodes to the following significant fields:

```text
alipays://platformapi/startapp
appId = 2019090967125695
page = pages/new-user-recharge/index
schoolInfo.agentName = 南方科技大学
schoolInfo.agentCode = SUSTC
schoolInfo.operationTip = 学号
schoolInfo.extInfo.isExtraSchool = N
schoolInfo.orderId = 0
shareBizType = H5App_XCX
```

The final HTTP response was a 200 Alipay landing HTML page, which loads Alipay-hosted JavaScript and is designed to open the Alipay application. The path and parameters are evidence that this shared entry targets a recharge mini-program page preselected for SUSTech. `orderId=0` in school configuration must not be interpreted as a created payment order or payment status.

The following remain **unknown** from this public read:

- The mini-program's verified publisher/legal entity, its relationship to SUSTech, the actual payment merchant and beneficiary, and any institutional endorsement of third-party embedding.
- Whether the link expires or changes, whether the page accepts a recharge amount in externally supplied parameters, and whether a third-party return callback is supported.
- Its authenticated card/account binding, student identifier checks, supported card types, payment limits, order creation/status APIs, and eventual crediting behavior.

An `alipay.com` domain establishes the hosting/launch provider, not the identity of the recharge merchant. The app must not label this unverified publisher as an independently verified “official SUSTech merchant”. Do not add guessed amount, student ID, or callback query parameters.

## School WeChat/WeCom page

User-provided page: <https://campuscard.xh.sustech.edu.cn/?pay_money=1/#/PayMoney>.

An anonymous GET of the supplied school URL returned HTTP 200 and a static SPA shell. Its referenced public bundle, <https://campuscard.xh.sustech.edu.cn/app.caff27cd602985759528.js>, was fetched read-only (6,797,416 bytes, SHA256 `31f494cb18fae9d67e1e5b4f38810d6133fd0cedbd7ac2d93c364477a346e790`). The Webpack source modules establish:

- `app/pages/PayMoney/PayMoney.vue` (module 575) reads the card identity with `getCardInfo`, selects a recharge amount, and builds `cardId`, `xm`, `je` (two decimal places) and `return_url`. It does not establish third-party native access authorization.
- `app/stores/CardOperation.js` (module 642) has POST actions `/cardDeposit/{session.cardId}` and `/newCardDeposit/{session.cardId}` under its configured API `https://campuscard.xh.sustech.edu.cn/api`. These were **not invoked**. The former returns fields submitted as a form to the school payment service; the latter returns a URL used by `window.location.href`. Both branches exist; presence alone does not prove which one is currently enabled for every account.
- `app/config/domain.js` (module 66) contains `SUSTC_PAY_API=https://payment.sustech.edu.cn/zhifu/payAccept.aspx`.
- `app/stores/index.js` (module 126) attaches the session `userId` and `token` as request headers. `WxLogin.vue` (module 584) accepts a returned `user` and `access_token` and stores that identity. CAS cookies alone do not provide these credentials.
- The single `pay_money` occurrence is in the home routing component: it reads `query.pay_money` into an unused local, then uses `window.location.search.indexOf(1)>1` to navigate to `PayMoney`. The recharge component has its own amount state (default 50). Thus the supplied `pay_money=1` is **not evidence of a supported amount-prefill API**; this implementation preserves the supplied link exactly and offers no fake native amount field.
- No `getBrandWCPayRequest` occurrence was found in this bundle. Android comments about JSAPI may concern the downstream payment page or a previous implementation. This does not establish Safari support, H5 payment permissions, or a native SDK integration.

The public source includes a development login action referencing a private-network HTTP address. It was not called, incorporated into the app, or treated as a supported authentication method. No authenticated order-status or specific crediting contract has been verified. Raw school bundles are retained outside this repository as research material, not redistributed with the app.

The user's WeCom-only observation still needs a real-device check of school authorization and payment. Setting a WebView user-agent cannot manufacture WeCom OAuth identity or a real payment JS bridge.

WeCom's first-party [construct webpage authorization URL documentation](https://developer.work.weixin.qq.com/document/path/91022) describes an OAuth authorization URL with enterprise/application identity, encoded `redirect_uri`, `scope`, authorization `code`, and application visibility constraints. A school-controlled callback and application permissions are separate from this project's existing CAS login. Existing CAS cookies do not establish WeCom OAuth authorization.

## Provider documentation and implications

### WeChat H5 and APP payments

The first-party [H5 development guide](https://pay.weixin.qq.com/doc/v2/merchant/4011936565) was read directly (HTTP 200; the old `wiki/doc/api/H5.php?chapter=15_4` URL redirects there). It explicitly specifies:

1. The merchant backend validates the user session and allowed request origin.
2. The merchant backend creates the order with WeChat, using H5 transaction type `MWEB`.
3. The backend returns an `mweb_url` for the payment intermediate page, which performs H5 permissions/security checks.
4. WeChat sends successful-payment notification to the merchant backend.
5. The user can return after **either completing or cancelling** payment.
6. The backend uses notification information and, when needed, an order query before presenting the result.

Consequences: a JSAPI-only school endpoint cannot be assumed to support H5 payments in Safari or a third-party WKWebView. Merely rewriting a callback URL or user-agent does not add merchant H5 permissions. A return navigation must never mark a recharge successful.

The first-party [APP payment scenario page](https://pay.weixin.qq.com/wiki/doc/api/app/app.php?chapter=8_1), read successfully, describes merchant backend generation/signing of order data, SDK handoff to WeChat, user confirmation there, and return to the merchant app. “APP payment” still involves the WeChat app. Integration needs the appropriate merchant/app association and valid backend-produced payment data; a public website link alone does not supply these.

### Alipay documentation access limit

The Alipay-hosted redirect itself is first-party evidence for the launch route above. The following official documentation entry URLs returned HTTP 200 but only a JavaScript shell in this research environment:

- <https://opendocs.alipay.com/open/204/105295>
- <https://opendocs.alipay.com/open/204/105301>
- <https://opendocs.alipay.com/open/204/105302>

Their bodies were **not available**, and no claim about SDK registration, mini-program permission requirements, payment-result verification, or specific query parameters is attributed to these unread pages. Exact current Alipay SDK/miniprogram integration requirements need a readable current official source before adding an SDK or promising callback support. The supplied short link is sufficient to research external launch; it is not sufficient to implement direct order submission.

### iOS app launching and external goods

Apple's [UIApplication.open documentation](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:)) was inspected through its [first-party structured documentation response](https://developer.apple.com/tutorials/data/documentation/uikit/uiapplication/open(_:options:completionhandler:).json). It states that custom schemes can open an installed application, and that the completion boolean reports whether the URL was opened successfully. This is **not a payment result**. Missing providers should yield an actionable failure, not a “payment failed/succeeded” claim.

Apple's [App Review Guidelines, 3.1.3(e)](https://developer.apple.com/app-store/review/guidelines/#goods-and-services-outside-of-the-app) says physical goods/services consumed outside the app use methods other than in-app purchase. Campus meal/physical-service recharge therefore does not become an App Store digital-content purchase merely because it is initiated in a native interface. This is an integration interpretation, not an App Review approval guarantee.

## Recommended implementation stages

1. Native “Recharge campus card” screen: show available channels, launch the supplied provider entry only on explicit user tap, and retain an option to copy the exact link for a required provider environment. Label the action as “Open Alipay recharge” or “Open school recharge”, not “Pay ¥X” unless an actual order has been prepared and verified.
2. On app foreground return, offer/read balance and recent transactions using the existing authenticated read-only campus-card client. Show observed balance/transactions and their sync time. If there is no matching school recharge transaction or order result, show “Return received; please check whether recharge has credited”, not “Recharge successful”. A balance delta alone cannot uniquely identify this payment because other concurrent transactions may occur.
3. After proving school/provider session, account ownership, amount rules, server-side order creation, allowed payment handoff, and read-back of a specific order, implement native amount selection and explicit final confirmation. Do not embed merchant private keys or use an unrelated merchant account. Keep payment credentials and biometric/password approval in the provider UI.
4. Distinguish payment authorization, provider settlement, and campus-card crediting. Network timeout, app switch, cancellation, or missing callback can leave a result unknown. Do not automatically create a second order or recharge on retry; query/reconcile the original order first.

Real-device checks remain necessary on both iPhone and iPad: provider installed/missing, link opening, correct school/account display, user cancellation, authorization failure, return without payment, delayed credit, expired account session, and app termination/relaunch. This research performed no live recharge.

## Implemented in 0.3.1

`App/CardRechargeView.swift` provides a native channel selection screen, opens the exact supplied Alipay HTTPS link via iOS, and offers sharing/copying of the exact supplied school link into the supported WeChat/WeCom environment. HTTPS opening may show the Alipay landing page before handing off; automatic handoff is not yet device-verified. No undocumented schemes, guessed amount/callback parameters, merchant credentials, native order creation or automatic payment were added.

The screen supports an explicit read-only refresh of current balance and recent bills using the existing card client. Opening a link or returning from another app never marks an order paid. Account/session changes clear displayed query data. Demo mode disables provider opening/sharing and real queries. An added simulator scene captures this screen without invoking providers. Real authorization, payment, beneficiary identity and crediting remain untested.


## 2026-10-27 follow-up / 0.8.0

重新 GET 同一官方公开 bundle，SHA256 仍为 `31f494cb18fae9d67e1e5b4f38810d6133fd0cedbd7ac2d93c364477a346e790`。用户在企业微信确认充值只能选固定金额；源码 `columns/columnsNew` 同样为固定列表，`isCustom` 未在充值输入中提供实际自定义处理。不能据此承诺任意金额。

当前 `commitNew` 用 `parseFloat(couponSelected).toFixed(2)` 设置 `je`，调用 `/api/newCardDeposit/{cardId}`，返回后使用 `response.data` 作为跳转地址。旧 `/cardDeposit` 分支仍存在，不能混用。未调用任一 POST。

`WxLogin.vue` 从 `$route.query.user` 和 `$route.query.access_token` 建立 Session 后跳回首页，可能从地址栏移除凭据。新增的原生导入仅接受本人主动粘贴的第一方回调或本人导出的 JSON，核对本人卡身份后才显示；普通充值主页链接不含这些参数，不能据此获得授权。iOS 不能读取企业微信自己的 sessionStorage。

`PayResult.vue` 将 query.data 的 Base64 JSON 解释为 orderdate/orderno/amount/jylsh；未找到经认证回查单笔订单的有效契约。可自行拼造的返回参数不能当作到账证据。原生下单关闭；金额格式工具仅为本机草稿，以 Decimal 校验、规范化两位小数，避免浮点金额误差。本机 0.01–500 范围是本项目草稿限制，不是已证实的学校规则。

下一步必须由真实授权环境核对：第一方令牌交接是否可持续取得；服务端是否接受自定义 `je`（如 3.00）；新下单响应的精确格式、订单号和支付域；取消/超时后的原订单查询与到账确认。验证前不提供会让用户误以为已付款的原生确认按钮。
