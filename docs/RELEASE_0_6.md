# 0.6.0 — week, faculty contact and campus bus map

SUSTechMobile, build 9, iOS/iPadOS 17+.

Today date now includes actual calendar week (selected undergraduate/graduate calendar,
Shanghai date boundaries, no school login required). No invented week outside bundled data.

Faculty directory opens a native detail page with public email/office, copy/share/email link,
source links and read time. Fetches only the selected teacher and optionally one official
personal homepage. Missing office is explicitly unavailable. Seven-day local public cache.

Bus opens native MapKit map with route paths, stop pins, vehicle icons, route filter,
speed/heading/next stop and source report time. Frontmost page polls every 10 seconds and
stops polling in background. GPS older than 120 seconds/unknown is gray, independent of the
API fetch time. No extrapolation. Optional paused vehicles via /vehicles/all. Existing nearby
stop and ETA interface stays available. Route geometry uses public source coordinates as-is;
physical-device geographic alignment and actual reporting delay require campus verification.

Reference: sustech-cra/sustech-online-ng@48c9773c38619761e82c5c639542dc4737517b85.
Bundled public route/stop demo data attributed CC BY-SA 4.0, vehicles synthetic. Native Apple
basemap, no CRA tiles or Vue code bundled. Source links and data license are available in app.

Earlier limits remain: no verified full native recharge order contract, no physical-device
App Groups signing validation. No actual payment, printing, booking or deletion during tests.


Validation: final build 40178259028 at e07485d, 84 Swift tests and 8 Python tests;
main app/share/widget simulator and device builds passed. Map UI run 40177111042 checked
populated overlays on iPhone/iPad in light/dark mode. Exact screenshot/IPA provenance is in
BUILD_VALIDATION.md and screenshots/SOURCES.json. Physical-device boundaries above remain.
