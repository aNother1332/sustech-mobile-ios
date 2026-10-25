import AppIntents
import SwiftUI
import WidgetKit

enum CampusWidgetKind: String, AppEnum {
    case classes, deadlines, weather, bus
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "内容" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { [.classes: "今日课程", .deadlines: "BB 截止日期", .weather: "校园天气", .bus: "校车到站"] }
}
struct CampusWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "校园信息" }
    static var description: IntentDescription { "选择信息类型；校车组件需填写站点 ID，可从校车页面复制。" }
    @Parameter(title: "内容", default: .classes) var kind: CampusWidgetKind
    @Parameter(title: "校车站点 ID", default: "stop_admin_bldg_1") var stop: String
}
struct CampusWidgetEntry: TimelineEntry {
    let date: Date
    var title: String
    var lines: [String]
    var fetched: Date?
    var route: String
}
struct CampusWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CampusWidgetEntry { CampusWidgetEntry(date: .now, title: "今日课程", lines: ["打开 App 同步课程"], route: "study") }
    func snapshot(for configuration: CampusWidgetConfiguration, in context: Context) async -> CampusWidgetEntry { await entry(configuration) }
    func timeline(for configuration: CampusWidgetConfiguration, in context: Context) async -> Timeline<CampusWidgetEntry> {
        let value = await entry(configuration)
        return Timeline(entries: [value], policy: .after(.now.addingTimeInterval(configuration.kind == .bus ? 300 : 900)))
    }
    private func entry(_ configuration: CampusWidgetConfiguration) async -> CampusWidgetEntry {
        var value = CampusWidgetEntry(date: .now, title: "校园信息", lines: ["打开 App 刷新"], route: "today")
        switch configuration.kind {
        case .classes, .deadlines:
            value.title = configuration.kind == .classes ? "今日课程" : "BB 截止日期"; value.route = "study"
            guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.cn.sustech.community.daily"), let data = try? Data(contentsOf: root.appendingPathComponent("CampusWidget.json")), let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let at = raw["at"] as? Double else { value.lines = ["请在 App 小组件设置中允许共享"]; return value }
            value.fetched = Date(timeIntervalSince1970: at)
            if configuration.kind == .classes {
                let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
                guard raw["day"] as? String == formatter.string(from: .now) else { value.lines = ["课程快照已过期，请打开 App 同步"]; return value }
            }
            value.lines = (raw[configuration.kind == .classes ? "classes" : "deadlines"] as? [[String: Any]] ?? []).filter { ($0["until"] as? Double ?? 0) > Date.now.timeIntervalSince1970 }.compactMap { $0["text"] as? String }
            if value.lines.isEmpty { value.lines = ["本次快照没有记录，打开 App 核对"] }
        case .weather:
            value.title = "校园天气"
            do {
                let raw = try await json(URL(string: "https://api.sustech.online/weather")!)
                if let text = raw["msg"] as? String, !text.isEmpty { value.lines = [text]; value.fetched = .now }
            } catch { value.lines = ["天气暂不可用，点击打开 App"] }
        case .bus:
            value.title = "校车到站"; value.route = "bus"
            guard configuration.stop.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { value.lines = ["请在组件设置中填写正确站点 ID"]; return value }
            do {
                let raw = try await json(URL(string: "https://buseta.sustcra.com/arrivals/\(configuration.stop)")!)
                value.lines = (raw["arrivals"] as? [[String: Any]] ?? []).prefix(3).map { row in
                    let route = row["route_name_zh"] as? String ?? "校车"
                    let direction = row["direction_name_zh"] as? String ?? ""
                    if let eta = row["eta_minutes"] as? Int { return "\(route) \(direction) · \(eta) 分钟" }
                    return "\(route) \(direction) · 计划班次，打开核对"
                }
                if value.lines.isEmpty { value.lines = ["本次未返回预测"] }; value.fetched = .now
            } catch { value.lines = ["预测暂不可用，点击打开 App"] }
        }
        return value
    }
    private func json(_ url: URL) async throws -> [String: Any] {
        let configuration = URLSessionConfiguration.ephemeral; configuration.timeoutIntervalForRequest = 10
        let (data, response) = try await URLSession(configuration: configuration).data(from: url)
        guard let reply = response as? HTTPURLResponse, (200..<300).contains(reply.statusCode), let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw URLError(.badServerResponse) }; return value
    }
}
struct CampusInfoWidget: Widget {
    let kind = "CampusInfo"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CampusWidgetConfiguration.self, provider: CampusWidgetProvider()) { entry in
            VStack(alignment: .leading, spacing: 7) {
                Label(entry.title, systemImage: "flame.fill").font(.caption.bold()).foregroundStyle(Color(red: 237.0/255, green: 108.0/255, blue: 0))
                ForEach(Array(entry.lines.prefix(3).enumerated()), id: \.offset) { _, line in Text(line).font(.caption).lineLimit(3) }
                Spacer(minLength: 0)
                if let date = entry.fetched { Text("读取于 \(date.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 10)).foregroundStyle(.secondary) }
            }.widgetURL(URL(string: "sustechmobile://\(entry.route)"))
                .containerBackground(.background, for: .widget)
        }.configurationDisplayName("校园信息").description("课程、BB、天气或校车；刷新由系统调度。").supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
enum CampusShortcut: String, AppEnum {
    case code, card, printing, bus, study, reservations, library
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "快捷入口" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { [.code: "校园码", .card: "校园卡", .printing: "打印", .bus: "校车", .study: "课表", .reservations: "预约", .library: "图书馆"] }
    var title: String { switch self { case .code: "校园码"; case .card: "校园卡"; case .printing: "打印"; case .bus: "校车"; case .study: "课表"; case .reservations: "预约"; case .library: "图书馆" } }
    var symbol: String { switch self { case .code: "qrcode"; case .card: "creditcard.fill"; case .printing: "printer.fill"; case .bus: "bus.fill"; case .study: "calendar"; case .reservations: "sportscourt.fill"; case .library: "books.vertical.fill" } }
}
struct ShortcutConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "校园快捷入口" }
    @Parameter(title: "左上", default: .code) var first: CampusShortcut
    @Parameter(title: "右上", default: .card) var second: CampusShortcut
    @Parameter(title: "左下", default: .printing) var third: CampusShortcut
    @Parameter(title: "右下", default: .bus) var fourth: CampusShortcut
}
struct ShortcutEntry: TimelineEntry { let date: Date; let items: [CampusShortcut] }
struct ShortcutProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ShortcutEntry { ShortcutEntry(date: .now, items: [.code, .card, .printing, .bus]) }
    func snapshot(for configuration: ShortcutConfiguration, in context: Context) async -> ShortcutEntry { ShortcutEntry(date: .now, items: [configuration.first, configuration.second, configuration.third, configuration.fourth]) }
    func timeline(for configuration: ShortcutConfiguration, in context: Context) async -> Timeline<ShortcutEntry> { Timeline(entries: [await snapshot(for: configuration, in: context)], policy: .never) }
}
struct CampusShortcutsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CampusShortcuts", intent: ShortcutConfiguration.self, provider: ShortcutProvider()) { entry in
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(entry.items.enumerated()), id: \.offset) { _, item in Link(destination: URL(string: "sustechmobile://\(item.rawValue)")!) { VStack(spacing: 5) { Image(systemName: item.symbol).font(.title3); Text(item.title).font(.caption2.bold()) }.frame(maxWidth: .infinity).foregroundStyle(Color(red: 0, green: 0.35, blue: 0.36)) } }
            }.containerBackground(.background, for: .widget)
        }.configurationDisplayName("校园快捷入口").description("四个可配置的常用服务入口。").supportedFamilies([.systemMedium])
    }
}
@main struct CampusWidgetBundle: WidgetBundle { var body: some Widget { CampusInfoWidget(); CampusShortcutsWidget() } }
