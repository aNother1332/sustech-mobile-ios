import CampusCore
import CoreLocation
import Observation
import SwiftUI

@MainActor @Observable final class CampusLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var point: CLLocation?
    private var requested = false
    var message: String?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func request() {
        requested = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: message = "未授权定位；仍可按站名查询。"
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if requested, [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) { manager.requestLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }; point = last; message = "已按距你的位置排序 · 距离为直线估算"
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = "暂时无法定位，可继续按站名查询。" }
    func distance(_ stop: BusStop) -> Double? {
        guard let point, let lat = stop.latitude, let lon = stop.longitude, (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return point.distance(from: CLLocation(latitude: lat, longitude: lon))
    }
}

struct CardBalancePreference: View {
    let balance: String?
    @AppStorage("card-low-balance") private var threshold = 30.0
    private var value: Double? { guard let balance, let raw = HTMLText.captures("[0-9]+(?:\\.[0-9]+)?", in: balance).first?[0] else { return nil }; return Double(raw) }
    var body: some View {
        if let value, value < threshold { Label("余额低于 ¥\(threshold.formatted())", systemImage: "exclamationmark.circle.fill").font(.caption.bold()).foregroundStyle(Color(uiColor: .systemOrange)) }
        DisclosureGroup("低余额提示设置") { Stepper("低于 ¥\(threshold.formatted()) 提示", value: $threshold, in: 0...500, step: 10); Text("在应用读取余额时检查，不在后台持续轮询，不自动扣款或充值。").font(.caption).foregroundStyle(.secondary) }.font(.caption)
    }
}
