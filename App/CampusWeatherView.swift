import CampusCore
import SwiftUI

extension CampusStore {
    func refreshWeather(force: Bool = false) async {
        #if DEBUG
        if mode == .demo { campusWeather = CampusWeather(summary: "南科大天气：24℃–30℃。气温26℃，体感27℃，近两个小时内无降雨。（示例）", aqi: 35); return }
        #endif
        guard !weatherLoading else { return }
        if !force, let date = weatherFetched, Date.now.timeIntervalSince(date) < 900 { return }
        weatherLoading = true; defer { weatherLoading = false }
        do { campusWeather = try await CampusWeather.read(); weatherFetched = .now; weatherMessage = nil }
        catch { weatherMessage = "天气暂不可用" }
    }
}

struct CampusWeatherView: View {
    @Environment(CampusStore.self) private var store
    var body: some View {
        CampusCard {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: store.campusWeather?.symbol ?? "cloud.sun").font(.system(size: 35, weight: .light)).foregroundStyle(Color.campusOrange)
                VStack(alignment: .leading, spacing: 8) {
                    if let weather = store.campusWeather {
                        Text(weather.summary.replacingOccurrences(of: "南科大天气：", with: "")).font(.subheadline).lineSpacing(4)
                        if let aqi = weather.aqi { Text("US AQI \(aqi)").font(.caption.weight(.medium)).foregroundStyle(Color.campusGreen) }
                    } else if store.weatherLoading { ProgressView() }
                    if let message = store.weatherMessage { InlineFailure(message: message) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.task { await store.refreshWeather() }
    }
}
