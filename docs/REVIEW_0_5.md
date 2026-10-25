# 0.5 review notes

Scope checked against REQUEST_0_5.md and pinned Android source.

- Shared sessions used by card code and WS clients; no password storage added.
- QR text stays in view memory, expiry hides old content, background/account changes hide it;
  fresh CSRF is read before each campus-code POST. No credentials or QR enter widget data.
- WS page lists remain read-only; application/detail uses the established official browser
  with zoom, navigation policy, error feedback and an external browser link.
- Scan deletion requires explicit confirmation, one POST, and code-0 success; ambiguous
  outcomes instruct refresh and are never retried automatically.
- Calendar checks cached schedule year/term, permits the explicitly documented spring
  first-Monday makeup, and excludes complete final-exam dates. Unknown years fall back.
- Widget sharing defaults off. Main app shares only display text/end timestamps. Mode/account
  transitions remove snapshot; widget filters expired items and displays last-read time.
- Nearby stops request location only after the user invokes the action; no background location.
- Public weather and shuttle APIs do not use school cookies. Optional enrichment failures do
  not destroy basic ETA results. Missing air-quality data is not fabricated as zero.
- Native sheet/navigation gestures retained. Press feedback respects Reduce Motion.
- Visual inspection covered iPhone Today/services/timetable/card/printing/faculty/calendar/code,
  iPad services/timetable, dark Today and accessibility-size study list. No key controls were
  obscured in the inspected captures; normal vertical scrolling is needed for lower content.

Not verified: real campus login flows and terminal QR recognition; actual scan deletion,
reservation/renewal/print/BB writes; native recharge order contract; extension provisioning,
App Groups and physical-device WidgetKit behavior. No real payment/consumption/write occurred.

Simulator captures are feature presentation/startup evidence, not authenticated end-to-end tests.
