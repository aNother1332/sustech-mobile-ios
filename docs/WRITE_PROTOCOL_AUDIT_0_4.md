# Blackboard submission and campus-card native ordering audit

Research date: 2026-10-25. This audit reads pinned upstream code and the already downloaded public school frontend. No school credentials were read, no authenticated request was made, and no assignment attempt, recharge order, or payment was created. Source evidence establishes an implementation contract, not successful real-account validation.

## Primary source inventory

- CLI pinned commit: `1a760afb4dac3fc4ea9ccd4877475e2152a9cf53`.
- [Original assignment form implementation](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard-assignment-form.ts).
- [Submission orchestration and reconciliation](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard-submission.ts).
- [BB read APIs](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/services/blackboard.ts), functions `listBlackboardAttemptsForUser`, `getBlackboardAttempt`, and `listBlackboardAttemptFiles`.
- [Offline form fixtures](https://github.com/wormforce/sustech-cli/blob/1a760afb4dac3fc4ea9ccd4877475e2152a9cf53/src/test/blackboard_form_submission.test.ts). Fixture passing demonstrates intended behavior against examples; it does not verify a live school deployment.
- School public [SPA bundle](https://campuscard.xh.sustech.edu.cn/app.caff27cd602985759528.js): SHA256 `31f494cb18fae9d67e1e5b4f38810d6133fd0cedbd7ac2d93c364477a346e790`, 6,797,416 bytes. Webpack source-module paths below identify relevant code. Bundle remains outside the repository at `D:/Altstore/Source/campus-research/recharge/school-app.js`.
- Existing [payment-platform and external-launch research](RECHARGE_PAYMENT_RESEARCH.md).

## Blackboard: supported initial scope

Implement Classic/Original **individual file assignments**, with optional comment. Do not treat `resource/x-bb-asmt-test-link`, assessments, Ultra assignments, external tools, group submissions, or existing drafts as compatible just because a deadline is visible. Upstream permits an independent text branch, but that is a separate UI/validation scope.

Before showing a submit confirmation, resolve the exact course ID, gradebook column ID and content ID, verify accessible assignment metadata/content handler `resource/x-bb-assignment`, and read the student's existing attempts. The read-only assignment preview uses:

```text
GET https://bb.sustech.edu.cn/webapps/assignment/uploadAssignment
    ?course_id=_COURSE_1&content_id=_CONTENT_1&mode=view
```

An attempts-list 404 does not mean there were no attempts. Upstream accepts an initial 404 as empty only after checking accessible column/content, available `Yes`, grading type `Attempts`, matching handler, and a matching blank first-upload form whose title starts `Upload Assignment:` or `上传作业:`. A history form, any `aggregateGradeForm`, a nonempty attempt field or attempt-history link disqualifies this fallback. A later pagination 404 or 403 is a failure.

## Blackboard: one confirmed submission

Only **after the user confirms**, fetch the fresh upload form using the same cookie session:

```text
GET /webapps/assignment/uploadAssignment
    ?course_id=_COURSE_1&content_id=_CONTENT_1&action=newAttempt&group_id=
```

`newAttempt` is a preparation step with potentially stateful server behavior. Do not call it on list loading, pull-to-refresh, or file preview. Inspect the returned URL as well as the form.

The accepted form must satisfy all of these source-derived conditions:

- Exactly one `form#uploadAssignmentFormId`, POST, `multipart/form-data`.
- Action resolves to the exact BB HTTPS origin and `/webapps/assignment/uploadAssignment`, with a unique `action=submit`. No userinfo, fragment, foreign port/origin, unrecognised action query keys, duplicate `course_id`/`content_id`/`group_id`, or nonempty group.
- Hidden `course_id` and `content_id` each occur once and match the selected assignment. Normalise only decimal IDs or exact `_digits_1` IDs.
- Exactly one nonempty hidden `blackboard.platform.security.NonceUtil.nonce`; preserve other fresh fields, including the AJAX nonce if present.
- Exactly one empty `attempt_id`; no nonempty `attemptId` or `group_id`. Refuse any nonempty editor text rather than overwrite a draft.
- Exactly one local-file picker `#newFile_chooseLocalFile[type=file]`. Reject duplicate editor field names or collisions with hidden fields.

Copy enabled hidden fields and blank exposed editor fields. Override these multipart parts:

```text
isAjaxSubmit = true
dispatch = submit
newFile_attachmentType = L
newFile_fileId = new
newFile_artifactFileId = undefined
newFile_artifactType = undefined
newFile_artifactTypeResourceKey = undefined
newFile_linkTitle = <reviewed filename>
newFile_LocalFile0 = <reviewed bytes, filename included>
```

Optional comments use an exposed `student_comments` or `studentComments.text` textarea; HTML-escape `&`, `<`, `>` and replace newlines with `<br />`. Preserve the blank submission editor for a file-only upload. Review file name, byte count and SHA256 before confirmation, and ensure the bytes still match immediately before sending.

Send exactly one POST to the validated fresh action with `x-requested-with: XMLHttpRequest`, `Origin: https://bb.sustech.edu.cn`, and the fresh GET as `Referer`. Generate the multipart boundary correctly. Disable redirects for the write. A valid JSON `destinationUrl` on the same BB path and exact target is an acknowledgement, **not proof of submitted work**.

## Blackboard: readback and uncertain outcomes

Before POST, collect all paginated own attempt IDs. Exact upstream read endpoints are:

```text
GET /learn/api/public/v1/users/me
GET /learn/api/public/v2/courses/_COURSE_1/gradebook/columns/_COLUMN_1/attempts?userId=_USER_1
GET /learn/api/public/v2/courses/_COURSE_1/gradebook/columns/_COLUMN_1/attempts/_ATTEMPT_1
GET /learn/api/public/v1/courses/_COURSE_1/gradebook/attempts/_ATTEMPT_1/files
```

Reconcile even if the POST response was lost. Confirm only if exactly **one new attempt ID** is observed, its detail ID matches, its status is `NeedsGrading` or `Completed`, its returned file list contains the reviewed filename, and any submitted comment agrees after whitespace normalisation. An old same-named file, `InProgress`, multiple new attempts, missing ownership, incomplete pagination, missing expected file, or read failure leaves the outcome unknown. Filename readback is the upstream's verification strength; it is not a downloaded-file hash verification. Include receipt information when returned, but do not invent one.

Do not automatically resend after a POST timeout or parsing error. Preserve the target and file metadata needed to let the user inspect/reconcile the existing attempt. Avoid logging cookies, HTML, nonces, submitted file contents, or credential-bearing query strings. Clear user-scoped results on account switch; hold the app's existing write guard throughout confirmation-to-reconciliation.

## Recharge: exact source-derived order contract

The school frontend has two order branches in `app/stores/CardOperation.js` (module 642):

```text
POST https://campuscard.xh.sustech.edu.cn/api/cardDeposit/{session.cardId}
POST https://campuscard.xh.sustech.edu.cn/api/newCardDeposit/{session.cardId}
Headers: userId: <session.userId>, token: <session.token>
JSON: { cardId: <target stuempno>, xm: <verified custname>,
        je: "50.00", return_url: "https://campuscard.xh.sustech.edu.cn/#/pay-result" }
```

`app/pages/PayMoney/PayMoney.vue` (module 575) obtains the signed-in identity through `getCardInfo`, selects amounts, and serialises `je` with exactly two decimals. Standard choices are 10, 20, 30, 50, 100, 200 and 500; another frontend list also includes 1. These choices are UI evidence, not verified backend minimum/maximum rules. Do not claim support for arbitrary decimal amounts without checking the actual authenticated contract.

The old `cardDeposit` response supplies fields for a form submitted to `https://payment.sustech.edu.cn/zhifu/payAccept.aspx`. The newer `newCardDeposit` branch assigns `response.data` to `window.location.href`; the same function also deletes `response.data.cardId`, so its exact response schema cannot be established from this inconsistent static code. Do not select a branch by guesswork, try both, or fall back from one order POST to another. Either may create a second order.

The read-only identity endpoint is provided by `app/stores/Cardinfo.js` (module 643):

```text
GET https://campuscard.xh.sustech.edu.cn/api/cardInfo/{cardId}
Headers: userId, token
```

The page uses `stuempno` and `custname` from the returned card information. Source inspection alone does not establish expiry/error schema, usable provider destinations, idempotency, transaction status, or crediting status.

## Recharge: token capture is possible only inside an authorised school page

`app/pages/WxLogin/WxLoginRouter.js` exposes hash route `/wxlogin`. Its component (module 584) reads `$route.query.user` and `$route.query.access_token`, sets `userId = cardId = user`, then calls `Session.update`. `app/core/Session/Session.js` (module 595) stores `sessionStorage.userId`, `sessionStorage.cardId` and `sessionStorage.token`. `app/stores/index.js` attaches those values as API headers.

If a real, authorised school page reaches **our WKWebView**, a narrow same-origin/main-frame bridge can retain those three fields in Keychain after validating the identity with the read endpoint above. Check exact HTTPS host `campuscard.xh.sustech.edu.cn`, standard port, no URL credentials, correct frame origin, user-scoped generation, and actual `stuempno`. Do not inspect arbitrary sites' storage, print the tokens, or infer validity from storage merely existing. The hash-query form can be `#/wxlogin?user=...&access_token=...`; normal URL query parsing alone misses it.

This does **not solve credential acquisition**: WeCom OAuth runs in the provider's browser context. Our WKWebView cannot read WeCom's cookies/sessionStorage. No supported redirect from that OAuth flow into SUSTechMobile or its WKWebView is established. CAS cookies do not supply these tokens. Changing the user-agent does not supply OAuth identity. The frontend's private-network development-login route is not an acceptable production authentication flow and must not be used.

## Recharge: no authoritative order-status contract found

`app/pages/PayResult/PayResult.vue` (module 576) only Base64-decodes and JSON-parses the route's `data` into fields including `orderdate`, `orderno`, `amount` and `jylsh`. It makes no order-status request and verifies no signature. A URL callback, return to foreground, or unrelated balance increase cannot prove this particular order succeeded or that funds reached the card.

Therefore a complete native ordering release is **blocked on actual supported credential acquisition, branch/response validation, permitted provider handoff, and authoritative order reconciliation**. An internal protocol/parser or disabled evidence-gated native preparation UI is feasible; presenting it as a working full native recharge flow is not. Keep the existing external recharge entry functional while those requirements are unresolved. User confirmation for an eventual charge belongs in the app after displaying verified account and amount; this audit did not ask for or exercise a real charge.

## Independent validation required

BB offline tests should cover exact multipart bytes/fields, stale file rejection, duplicate/foreign form actions, drafts/groups/Ultra rejection, lost POST acknowledgement followed by successful readback, old same-name file, multiple candidates, pagination failure, cancellation, account switch, and exactly one POST. Real-account validation requires a disposable eligible assignment or the user's explicit confirmation of a specific real submission; do not submit random files to actual coursework.

Recharge offline tests can validate amount formatting, same-origin identity capture, account mismatch rejection, refusal without credentials, untrusted handoff URLs, unverified return data, and prohibition on automatic order retry. They cannot establish that a server accepts orders. Real payment and crediting require a separate user-confirmed device session and must remain labelled unverified until observed.
