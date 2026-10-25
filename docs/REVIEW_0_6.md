# 0.6 source and UI verification

- Native bus implementation reads CRA public protocol; no Vue components or map tiles copied.
  Route/stop demonstration snapshot attributed CC BY-SA 4.0 with bundled license and in-app link.
- GPS source time is independent of API receipt/fetch time. Invalid/zero coordinates rejected;
  stale/unknown time turns markers gray. No dead reckoning. Only foreground polling.
- Routes/stops may fail independently; vehicle loading remains available, missing metadata retries.
- Map demo initializes even before app scene becomes active. Simulator smoke requires a freshly
  written populated-state proof (routes, points, stops, vehicles) before accepting map screenshots.
- Map captures confirmed 4 routes, 351 points, 33 stops and 2 fake vehicles on both device families
  and in light/dark appearance. Inspected all three principal map captures, teacher details and Today.
  Route tracks visually follow campus roads at captured zoom; physical-device coordinate calibration
  and actual GPS reporting delay remain to be checked on campus.
- Teacher fetch is public and uses isolated ephemeral sessions, no school credentials. Redirects
  restricted to official HTTPS domains; one personal-page follow only. Office must be explicitly
  labeled, never inferred from a generic campus/mailing address or a building icon.
- Public cache has seven-day freshness with manual refresh; failed cache writes do not claim network
  failure. Mail links constructed as URL components, no automatic mail sending.
- Home date and week use Shanghai boundaries; course badge aligned with the same matching calendar.

No real school write operations or Apple authentication were used. Teacher contact demo is fictional;
public source read checks do not guarantee every teacher publishes an office or has a working homepage.
