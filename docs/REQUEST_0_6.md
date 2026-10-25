# 0.6.0 request

- Show current academic week beside Today date, derived from bundled selected-level calendar
  without requiring school login; unknown dates explicitly have no confirmed week.
- Native faculty details add email and office from official public pages, one optional official
  personal-homepage follow; missing fields stay missing, no guessed addresses. Seven-day local
  cache supports offline rereading; demo uses synthetic contact details.
- Native MapKit campus bus map, route shapes, stops, route filter, vehicles, report time/freshness,
  direction/speed/next stop and foreground 10-second polling. Retain stop/ETA view. Include paused
  vehicles on demand. Public endpoints never receive school cookies.

Reference read: sustech-cra/sustech-online-ng commit 48c9773c38619761e82c5c639542dc4737517b85,
Vue bus-v2 api/BusMapV2/BusVehiclesV2; native Swift implementation, no copied Vue components.
Routes/stops demo snapshot from public buseta.sustcra.com, attribution CC BY-SA 4.0, fake vehicles.
No extrapolated positions; request success never makes stale GPS fresh.
