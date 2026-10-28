import CampusCore
import SwiftUI
import UIKit

struct InlineFailure: View {
    let message: String
    var body: some View {
        if let text = DisplayNotice.error(message) {
            Label(text, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
enum DisplayNotice {
    static func error(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        let silent = ["读取于", "更新于", "查询于", "同步于", "已读取", "已刷新", "已核对", "已保存至", "已连接", "已登录", "场馆授权已连接"]
        guard !silent.contains(where: value.hasPrefix) else { return nil }
        if value.contains("网络连接已中断") || value.contains("无法连接") { return "网络不可用" }
        if value.contains("登录") && (value.contains("过期") || value.contains("需要") || value.contains("未登录")) { return "未登录" }
        return String(value.components(separatedBy: .newlines).first?.prefix(80) ?? "")
    }
}
struct BusinessHeader: View {
    let title: String
    let symbol: String
    var color: Color = .blue
    var value: String = ""
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.18)).frame(width: 60, height: 60).rotationEffect(.degrees(-8))
                Image(systemName: symbol).font(.system(size: 29, weight: .light)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                if !value.isEmpty { Text(value).font(.caption).foregroundStyle(.white.opacity(0.85)) }
            }
            Spacer()
            Image("SchoolWordmark").renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white.opacity(0.12)).frame(width: 120)
        }.foregroundStyle(.white).padding(16)
            .background(LinearGradient(colors: [color.opacity(0.78), color], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
    }
}
/// Read the actual scene's display; this is a capability, not a live FPS measurement.
struct DisplayCapabilityReader: UIViewRepresentable {
    func makeUIView(context: Context) -> CapabilityView { CapabilityView() }
    func updateUIView(_ view: CapabilityView, context: Context) {}
    final class CapabilityView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            #if DEBUG
            if let screen = window?.windowScene?.screen { UserDefaults.standard.set(screen.maximumFramesPerSecond, forKey: "diagnostic-display-maximum") }
            #endif
        }
    }
}
