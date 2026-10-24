import CampusCore
import SwiftUI

extension Color {
    static let campusGreen = Color(red: 0.12, green: 0.40, blue: 0.31)
}

struct CampusCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ModeNotice: View {
    @Environment(CampusStore.self) private var store

    var body: some View {
        if store.mode == .demo {
            Label("演示模式 · 下列课程与任务均为示例", systemImage: "sparkles")
                .font(.callout).foregroundStyle(Color.campusGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding().background(Color.campusGreen.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct ConnectionNotice: View {
    let state: ConnectionState

    var body: some View {
        switch state {
        case .idle:
            Label("尚未同步学校数据", systemImage: "circle.dashed").foregroundStyle(.secondary)
        case .loading:
            ProgressView("正在读取学校服务…")
        case .failed(let message):
            Label(message + " 如仍显示数据，则为最近一次成功同步的缓存，请留意更新时间。", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case .cached(let date):
            VStack(alignment: .leading, spacing: 4) {
                Label("本机缓存 · 尚未验证当前会话", systemImage: "externaldrive").foregroundStyle(.secondary)
                Text("最近同步：\(date.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.secondary)
            }
        case .loaded(let date, let warnings):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: warnings.isEmpty ? "checkmark.circle" : "exclamationmark.circle")
                    Text(warnings.isEmpty ? "已读取" : "部分数据未能读取")
                    Text(date, style: .time)
                }.foregroundStyle(warnings.isEmpty ? Color.campusGreen : .orange)
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct MeetingRow: View {
    @Environment(CampusStore.self) private var store
    let meeting: CourseMeeting

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(meeting.firstPeriod)").font(.headline)
                Text("至 \(meeting.lastPeriod) 节").font(.caption).foregroundStyle(.secondary)
            }.frame(width: 64, alignment: .leading).foregroundStyle(Color.campusGreen)
            VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 7) {
            Text(deadline.course).font(.caption).foregroundStyle(.secondary)
            Text(deadline.title).font(.headline)
            if let due = deadline.due {
                Text(due.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(Color.campusGreen)
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
            if [.teaching, .blackboard].contains(service) { NativeLoginButton() }
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
