import CampusCore
import SwiftUI
import WidgetKit

enum CampusWidgetBridge {
    static let group = "group.cn.sustech.community.daily"
    static var root: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }
    static func clear() {
        if let root { try? FileManager.default.removeItem(at: root.appendingPathComponent("CampusWidget.json")) }; WidgetCenter.shared.reloadAllTimelines()
    }
    static func publish(_ store: CampusStore) {
        guard let root else { return }
        let path = root.appendingPathComponent("CampusWidget.json")
        guard UserDefaults.standard.bool(forKey: "widget-share-learning"), store.mode == .live, !store.clearing else {
            try? FileManager.default.removeItem(at: path); WidgetCenter.shared.reloadAllTimelines(); return
        }
        let lessons = store.teaching?.meetings.filter { row in
            guard let term = AcademicData.term() else { return false }
            return AcademicData.dates(row, term: term).contains { CampusClock.format($0) == CampusClock.format(.now) }
        }.sorted { $0.firstPeriod < $1.firstPeriod }.map { "\($0.firstPeriod)–\($0.lastPeriod)节 · \($0.name)" } ?? []
        let deadlines = store.deadlines.filter { $0.due.map { $0 > .now } ?? false }.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }.prefix(3).map { "\($0.title) · \($0.due?.formatted(date: .abbreviated, time: .shortened) ?? "")" }
        let value: [String: Any] = ["at": Date.now.timeIntervalSince1970, "day": CampusClock.format(.now), "classes": Array(lessons.prefix(3)), "deadlines": deadlines]
        do { let data = try JSONSerialization.data(withJSONObject: value); try data.write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); WidgetCenter.shared.reloadAllTimelines() } catch { /* Main app continues without shared-container access. */ }
    }
}

struct WidgetSettingsView: View {
    @Environment(CampusStore.self) private var store
    @AppStorage("widget-share-learning") private var share = false
    var body: some View {
        List {
            Section("信息小组件") {
                Text("长按桌面添加 SUSTechMobile，可选择课程、BB 截止时间、天气、校车或快捷入口。")
                Toggle("允许在桌面展示课程与截止时间", isOn: $share).onChange(of: share) { _, _ in CampusWidgetBridge.publish(store) }
                Text("仅共享显示所需的文字快照，不向扩展提供账号、密码、Cookie 或校园码。退出时清除。").font(.caption).foregroundStyle(.secondary)
            }
            Section("当前安装") {
                LabeledContent("共享容器", value: CampusWidgetBridge.root == nil ? "不可用" : "可用")
                Text("小组件需要包含 Widget 扩展的安装包，并为主应用与扩展匹配 App Groups 签名。普通安装包不包含扩展。").font(.caption).foregroundStyle(.secondary)
                Text("iOS 决定刷新时间；校车预测与旧快照始终显示读取时间，点击组件进入 App 刷新。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("桌面小组件").navigationBarTitleDisplayMode(.inline)
    }
}
