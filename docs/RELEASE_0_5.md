# 0.5.0 — Android parity and official-colour redesign

App name remains SUSTechMobile. iPhone/iPad only, iOS 17+.

Implemented: campus/identity QR foreground refresh with expiry masking; low-balance settings;
2026 calendar with undergraduate/graduate selector, holiday/makeup mapping; weekly grid and
enrolled-course grouping; offline bilingual faculty directory; paged exchange listing and
official detail/application WebView; nearby stops, optional live-position enrichment and
foreground shuttle refresh; weather/US AQI; next lesson/exam; service diagnostics; confirmed
scan deletion; public GitHub release checks; configurable WidgetKit information and shortcut
extensions with opt-in text-only snapshot sharing.

Design uses exact official RGB from https://www.sustech.edu.cn/uploads/logo3.png:
orange #ED6C00, dark green #003F43, cyan #2BBCB3. System semantic surfaces support dark mode.
Text, symbols and labels accompany colour. Native sheets/navigation retain platform gestures;
press springs use critical damping and respect Reduce Motion. Accessibility text sizes can
use the timetable list. Service tiles adapt to iPad width.

Known boundaries: QR endpoints and all authenticated school operations require real-device
validation. No actual deletion/payment/consumption/application performed in automated checks.
Only the bundled 2026 academic calendar is covered; unknown dates require manual anchor.
Calendar matching checks the academic year/term before applying dates to cached schedules.
Spring first-week makeups may originate before sign-in, and the complete final exam date range
is excluded from regular lessons. Widget entries expire against their lesson-end/deadline times.
Official temporary changes remain authoritative. Exchange applications stay on official pages.
Widget/shared-print extensions require matching signing profiles and App Groups; ordinary IPA
omits extensions. WidgetKit refresh is system-budgeted, not continuous real time. No full native
recharge payment claim is made; limitations from 0.4 remain.

Validation complete: final build 40173815553 at commit 778d842, 78 Swift tests and 8 Python tests.
Simulator/device builds include both extensions. Full capture 40172533665 produced 64 screenshots;
final build recaptured 12 images covering changed screens and home. See BUILD_VALIDATION.md and
screenshots/SOURCES.json for exact provenance. Real campus/device boundaries above remain.
