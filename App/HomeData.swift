import CampusCore
import SwiftUI

struct PersonalAgendaItem: Codable { var id: String; var title: String; var start: Date }

extension CampusStore {
    func refreshHomeBalance() async {
        guard mode == .live, !clearing, !authenticating, !cardBalanceLoading else { return }
        let request = UUID(); let revision = sessionRevision
        cardBalanceRequest = request; cardBalanceLoading = true
        defer { if cardBalanceRequest == request { cardBalanceLoading = false; cardBalanceRequest = nil } }
        let http = await serviceHTTP(.card)
        do {
            let value = try await CardClient(http: http).account()
            guard revision == sessionRevision, mode == .live else { return }
            cardBalance = value.balance; cardBalanceMessage = nil; recordSession(.card)
        } catch {
            guard revision == sessionRevision, mode == .live else { return }
            cardBalanceMessage = (error as? CampusError) == .signInRequired ? "连接校园卡" : "暂未刷新"
            recordSession(.card, error: error)
        }
        await absorb(http, revision: revision)
    }
    var homeAgenda: [AgendaEntry] {
        let raw = UserDefaults.standard.string(forKey: "personal-agenda-" + accountScope) ?? "[]"
        let personal = mode == .live ? ((try? JSONDecoder().decode([PersonalAgendaItem].self, from: Data(raw.utf8))) ?? []) : []
        var entries = agendaExtras + personal.map { AgendaEntry(id: $0.id, title: $0.title, source: "个人事项", start: $0.start, end: $0.start.addingTimeInterval(3600)) }
        entries += deadlines.compactMap { task in
            guard task.submission == .pending || task.submission == .draft, let date = task.due else { return nil }
            return AgendaEntry(id: "bb-" + task.id, title: task.title, source: task.course, start: date, end: date.addingTimeInterval(900), courseID: task.courseID)
        }
        for exam in teaching?.exams ?? [] {
            if let time = HTMLText.captures("[0-9]{1,2}:[0-9]{2}", in: exam.time).first?[0], let date = CampusClock.date(exam.date + " " + time, "yyyy-MM-dd HH:mm") {
                entries.append(AgendaEntry(id: "exam-" + exam.id, title: exam.course + " 考试", source: exam.room, start: date, end: date.addingTimeInterval(3600)))
            }
        }
        return entries.filter { $0.end > .now && $0.start < Date.now.addingTimeInterval(7 * 86400) }.sorted { $0.start < $1.start }
    }
}

struct HomeAgendaView: View {
    @Environment(CampusStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CampusSectionTitle(title: "待办日程")
                Spacer()
                NavigationLink("全部") { AgendaView().id(store.sessionRevision).toolbar(.visible, for: .navigationBar) }.font(.caption)
            }
            if store.homeAgenda.isEmpty { Text("近期暂无待办").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8) }
            ForEach(store.homeAgenda.prefix(5)) { item in
                NavigationLink { EventActionView(title: item.title, start: item.start, end: item.end, key: item.id, courseID: item.courseID).toolbar(.visible, for: .navigationBar) } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.campusOrange).frame(width: 3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(item.source).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.start, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(Color.campusGreen)
                    }.fixedSize(horizontal: false, vertical: true).padding(12).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(CampusPressStyle())
            }
        }
    }
}
