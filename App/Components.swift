import CampusCore
import SwiftUI

extension Color {
    static let campusGreen = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.35, green: 0.85, blue: 0.81, alpha: 1) : UIColor(red: 0, green: 63.0/255, blue: 67.0/255, alpha: 1) })
    static let campusOrange = Color(red: 237.0/255, green: 108.0/255, blue: 0)
    static let campusCyan = Color(red: 43.0/255, green: 188.0/255, blue: 179.0/255)
    static let campusInk = Color(red: 0, green: 63.0/255, blue: 67.0/255)
}

struct CampusCard<Content: View>: View {
    var accent: Color = .campusCyan
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1) }
    }
}

struct ModeNotice: View {
    @Environment(CampusStore.self) private var store

    var body: some View {
        if store.mode == .demo {
            Label("演示数据", systemImage: "sparkles")
                .font(.caption).foregroundStyle(Color.campusGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 6).background(Color.campusGreen.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ConnectionNotice: View {
    let state: ConnectionState

    var body: some View {
        if case .failed(let message) = state { InlineFailure(message: message) }

    }
}

struct MeetingRow: View {
    @Environment(CampusStore.self) private var store
    let meeting: CourseMeeting

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(meeting.firstPeriod)").font(.headline)
                Text("至 \(meeting.lastPeriod) 节").font(.caption).foregroundStyle(.secondary)
            }.frame(width: 52, alignment: .leading).foregroundStyle(Color.campusGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.name).font(.headline)
                if !meeting.details.isEmpty { Text(meeting.details).font(.caption).foregroundStyle(.secondary) }
                if let snapshot = store.teaching {
                    if let start = snapshot.periods.first(where: { $0.period == meeting.firstPeriod })?.start,
                       let end = snapshot.periods.first(where: { $0.period == meeting.lastPeriod })?.end {
                        Text("\(start)–\(end)").font(.caption).foregroundStyle(Color.campusGreen)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
    }
}

struct DeadlineRow: View {
    @Environment(CampusStore.self) private var store
    let deadline: LearningDeadline

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deadline.course).font(.caption).foregroundStyle(.secondary)
            Text(deadline.title).font(.headline)
            if let due = deadline.due {
                Text(due.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.semibold)).foregroundStyle(deadline.submission == .pending && due.timeIntervalSinceNow < 86400 ? Color(uiColor: .systemOrange) : Color.campusGreen)
                if deadline.submission == .pending, due > .now, due.timeIntervalSinceNow < 86400 { Label("24 小时内截止", systemImage: "clock.badge.exclamationmark").font(.caption.bold()).foregroundStyle(Color(uiColor: .systemOrange)) }
            } else {
                Text(deadline.rawDue.isEmpty ? "学校未提供截止日期" : "时间待核对：\(deadline.rawDue)").font(.subheadline).foregroundStyle(.orange)
            }
            Label(deadline.submission.label, systemImage: deadline.submission == .submitted ? "checkmark.circle" : "questionmark.circle")
                .font(.caption).foregroundStyle(.secondary)
            if let date = store.courseDetails[deadline.courseID]?.tasksUpdated {
                Text("状态读取于 \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
    }
}

struct PortalActions: View {
    let service: SchoolService
    var open: () -> Void

    var body: some View {
        HStack {
            if [.teaching, .blackboard].contains(service) { NativeLoginButton(service: service == .blackboard ? .blackboard : .teaching) }
            Button("学校网页", action: open).buttonStyle(.bordered)
            Spacer()
            Link(destination: service.portalURL) {
                Label("浏览器", systemImage: "safari")
            }.accessibilityLabel("在系统浏览器打开\(service.title)，登录状态可能不同")
        }
    }
}

extension LearningDeadline.Submission {
    var label: String {
        switch self {
        case .unknown: "状态待核对"
        case .submitted: "已提交 / 待评分或已完成"
        case .pending: "未提交"
        case .draft: "草稿 / 尚未最终提交"
        case .exempt: "免交 / 豁免"
        }
    }
}
