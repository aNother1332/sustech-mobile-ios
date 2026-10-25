import CampusCore
import SwiftUI

struct TodaySummaryView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var weather: CampusWeather?
    @State private var fetched: Date?
    @State private var message: String?
    private var nextLesson: (CourseMeeting, Date)? {
        guard let snapshot = store.teaching, let term = AcademicData.term() else { return nil }
        return snapshot.meetings.flatMap { item -> [(CourseMeeting, Date)] in
            guard let time = snapshot.periods.first(where: { $0.period == item.firstPeriod })?.start else { return [] }
            return AcademicData.dates(item, term: term).compactMap { date in
                guard let start = CampusClock.date(CampusClock.format(date) + " " + time, "yyyy-MM-dd HH:mm"), start > .now else { return nil }; return (item, start)
            }
        }.min { $0.1 < $1.1 }
    }
    private var nextExam: CampusExam? { store.teaching?.exams.filter { $0.date >= CampusClock.format(.now) }.sorted { $0.date + $0.time < $1.date + $1.time }.first }
    var body: some View {
        VStack(spacing: 10) {
            CampusCard(accent: .campusOrange) {
                HStack { Label("校园天气", systemImage: "cloud.sun.fill").font(.subheadline.bold()); Spacer(); Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("刷新天气") }
                if let weather {
                    Text(weather.summary).font(.subheadline)
                    HStack { if let aqi = weather.aqi { Text("US AQI \(aqi)").font(.caption.bold()) }; Spacer(); if let fetched { Text(fetched, style: .time).font(.caption).foregroundStyle(.secondary) } }
                } else { Text(message ?? "读取校园天气…").font(.caption).foregroundStyle(.secondary) }
                DisclosureGroup("数据来源") { Text("天气：SUSTech CRA；空气质量：Open-Meteo（CC BY 4.0），数值采用 US AQI。").font(.caption).foregroundStyle(.secondary) }.font(.caption)
            }
            if let next = nextLesson {
                CampusCard { HStack { Label("下一节课", systemImage: "bell.fill").font(.caption.bold()).foregroundStyle(Color.campusGreen); Spacer(); Text(next.1, format: .dateTime.month().day().hour().minute()).font(.caption) }; Text(next.0.name).font(.headline); Text(next.0.details).font(.caption).foregroundStyle(.secondary) }
            }
            if let exam = nextExam {
                CampusCard(accent: .campusOrange) { Label("下一场考试", systemImage: "pencil.and.list.clipboard").font(.caption.bold()); Text(exam.course).font(.subheadline.bold()); Text(exam.date + " · " + exam.time + " · " + exam.room).font(.caption).foregroundStyle(.secondary) }
            }
        }.task { await load() }.onChange(of: phase) { _, value in if value == .active, fetched == nil || Date.now.timeIntervalSince(fetched!) > 900 { Task { await load() } } }
    }
    private func load() async {
        if store.mode == .demo { message = "演示模式不请求实时天气"; return }
        do { weather = try await CampusWeather.read(); fetched = .now; message = nil } catch { message = "天气暂不可用，点击刷新重试" }
    }
}
