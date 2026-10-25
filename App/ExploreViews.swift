import CampusCore
import SwiftUI

struct CourseReviewsView: View {
    @State private var query = ""
    @State private var courses: [ReviewCourse] = []
    @State private var page = 1
    @State private var busy = false
    @State private var more = false
    @State private var message: String?
    @AppStorage("saved-review-courses") private var saved = "[]"
    private let client = ReviewClient(http: ServiceHTTP(origin: URL(string: "https://ncesnext.com")!))
    private var favorites: [ReviewCourse] { (try? JSONDecoder().decode([ReviewCourse].self, from: Data(saved.utf8))) ?? [] }
    var body: some View {
        List {
            Section { DetailNote(title: "NCES 社区评价", text: "课程与教师评价来自 ncesnext.com，保留原始评价及学期。评分是社区参考，不代表学校教学评价或课程质量结论。")
                ServiceMessage(message: message); if busy { ProgressView() }
            }
            if !favorites.isEmpty { Section("已收藏") { ForEach(favorites) { course in courseRow(course) } } }
            Section("搜索结果") { ForEach(courses) { course in courseRow(course) }
                if more { Button("加载更多") { Task { await search(append: true) } }.disabled(busy) }
            }
        }.navigationTitle("课程评价").searchable(text: $query, prompt: "课程代码、名称或教师")
        .onSubmit(of: .search) { Task { await search() } }.refreshable { await search() }
    }
    private func courseRow(_ course: ReviewCourse) -> some View {
        NavigationLink { ReviewsDetailView(course: course, client: client) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(course.name).font(.subheadline.bold()); Spacer(); Text(course.rating.isEmpty ? "暂无评分" : course.rating).font(.subheadline.monospacedDigit()) }
                Text(course.code + " · " + course.teachers + " · \(course.count) 条评价").font(.caption).foregroundStyle(.secondary)
            }
        }.swipeActions { Button(favorites.contains { $0.id == course.id } ? "取消收藏" : "收藏") {
            var value = favorites
            if value.contains(where: { $0.id == course.id }) { value.removeAll { $0.id == course.id } } else { value.append(course) }
            if let data = try? JSONEncoder().encode(value) { saved = String(decoding: data, as: UTF8.self) }
        }.tint(.campusGreen) }
    }
    private func search(append: Bool = false) async {
        guard !busy, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; busy = true; defer { busy = false }
        let text = query; let next = append ? page + 1 : 1
        do { let result = try await client.search(text, page: next); guard text == query else { return }; page = next; more = result.count == 20
            courses = append ? courses + result.filter { row in !courses.contains { $0.id == row.id } } : result; message = result.isEmpty && !append ? "未找到匹配课程" : nil
        } catch { message = error.localizedDescription }
    }
}
private struct ReviewsDetailView: View {
    let course: ReviewCourse; let client: ReviewClient
    @State private var items: [CourseReview] = []
    @State private var page = 0
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        List {
            Section { Text(course.name).font(.headline); Text(course.teachers).font(.caption); ServiceMessage(message: message) }
            ForEach(items) { item in VStack(alignment: .leading, spacing: 5) { Text(item.term + " · 评分 " + item.rating).font(.caption).foregroundStyle(.secondary); Text(item.content).font(.subheadline).textSelection(.enabled) } }
            Button(page == 0 ? "读取评价" : "读取下一页") { Task { await load() } }.disabled(busy)
            if busy { ProgressView() }
        }.navigationTitle("课程评价").task { await load() }.refreshable { page = 0; await load() }
    }
    private func load() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let result = try await client.reviews(course, page: page + 1); items = page == 0 ? result : items + result.filter { row in !items.contains { $0.id == row.id } }; page += 1; message = result.isEmpty ? "本页没有可公开显示的评价" : nil }
        catch { message = error.localizedDescription }
    }
}
struct DegreeProgressView: View {
    @Environment(CampusStore.self) private var store
    @State private var result: DegreeResult?
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        List {
            Section { SessionBadge(); DetailNote(title: "培养方案与口径", text: "读取教务系统的个性化修读进度。类别可能重叠，不能将各行学分直接相加。学校字段缺失时不推算毕业资格，最终以适用培养方案及教学工作部确认为准。")
                if busy { ProgressView() }; ServiceMessage(message: message)
                Button("刷新修读进度") { Task { await load() } }.disabled(busy || store.mode == .demo)
            }
            if let result { ForEach(result.sections) { section in Section(section.title) { ForEach(Array(section.values.enumerated()), id: \.offset) { _, value in LabeledContent(value.0, value: value.1) } } }
                if !result.warnings.isEmpty { Section("部分来源未读取") { ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) } } }
            }
        }.navigationTitle("学业修读进度").task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }; let version = store.sessionRevision
        let http = await store.serviceHTTP(.teaching)
        do { let value = try await DegreeClient(http: http).progress(); guard version == store.sessionRevision else { return }; result = value; message = nil; store.recordSession(.teaching) }
        catch { guard version == store.sessionRevision else { return }; message = error.localizedDescription; store.recordSession(.teaching, error: error) }
        await store.absorb(http, revision: version)
    }
}

struct PlanEntry: Identifiable, Codable {
    var id = UUID(); var name: String; var code: String; var credits: Double
    var weekday: Int; var first: Int; var last: Int; var firstWeek: Int; var lastWeek: Int; var scenario: String
    func conflicts(_ other: PlanEntry) -> Bool {
        weekday == other.weekday && first <= other.last && last >= other.first && firstWeek <= other.lastWeek && lastWeek >= other.firstWeek
    }
}
struct PlannerView: View {
    @Environment(CampusStore.self) private var store
    @AppStorage("local-course-plans-v1") private var saved = "[]"
    @State private var scenario = "方案 A"
    @State private var name = ""
    @State private var code = ""
    @State private var credits = 2.0
    @State private var day = 1
    @State private var first = 1
    @State private var last = 2
    @State private var firstWeek = 1
    @State private var lastWeek = 16
    private var all: [PlanEntry] { (try? JSONDecoder().decode([PlanEntry].self, from: Data(saved.utf8))) ?? [] }
    private var entries: [PlanEntry] { all.filter { $0.scenario == scenario } }
    private var conflicts: [String] {
        var result: [String] = []
        for (i, a) in entries.enumerated() { for b in entries.dropFirst(i + 1) where a.conflicts(b) { result.append(a.name + " ↔ " + b.name) } }; return result
    }
    var body: some View {
        List {
            Section {
                Picker("本地方案", selection: $scenario) { ForEach(["方案 A", "方案 B", "方案 C"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                HStack { Text("\(entries.count) 个时段"); Spacer(); Text("学分合计 \(entries.reduce(0) { $0 + $1.credits }.formatted())") }.font(.subheadline)
                DetailNote(text: "本地排课方案，不执行选课。每个条目是一个连续周次时段；主课/实验/单双周可分别录入，关联课程学分只填一次。学校教学班、先修条件与可选名额需另行核对。")
                NavigationLink("查课程评价与收藏") { CourseReviewsView() }
            }
            if !conflicts.isEmpty { Section("时间冲突") { ForEach(Array(conflicts.enumerated()), id: \.offset) { _, value in Label(value, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } } }
            Section("候选时段") { ForEach(entries) { item in VStack(alignment: .leading, spacing: 3) { Text(item.name + " " + item.code).font(.subheadline.bold()); Text("周\(item.weekday) · \(item.first)–\(item.last)节 · \(item.firstWeek)–\(item.lastWeek)周 · \(item.credits.formatted())学分").font(.caption).foregroundStyle(.secondary) }.swipeActions { Button("删除", role: .destructive) { save(all.filter { $0.id != item.id }) } } } }
            Section("添加候选课") {
                TextField("课程名称", text: $name); TextField("课程代码（可选）", text: $code)
                Stepper("学分 \(credits.formatted())", value: $credits, in: 0...20, step: 0.5)
                Stepper("星期 \(day)", value: $day, in: 1...7)
                Stepper("起始第 \(first) 节", value: $first, in: 1...20).onChange(of: first) { _, v in last = max(last, v) }
                Stepper("结束第 \(last) 节", value: $last, in: first...20)
                Stepper("开始第 \(firstWeek) 周", value: $firstWeek, in: 1...40).onChange(of: firstWeek) { _, v in lastWeek = max(lastWeek, v) }
                Stepper("结束第 \(lastWeek) 周", value: $lastWeek, in: firstWeek...40)
                Button("加入当前方案") { save(all + [PlanEntry(name: name, code: code, credits: credits, weekday: day, first: first, last: last, firstWeek: firstWeek, lastWeek: lastWeek, scenario: scenario)]); name = ""; code = "" }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("方案对比") { ForEach(["方案 A", "方案 B", "方案 C"], id: \.self) { key in let values = all.filter { $0.scenario == key }; LabeledContent(key, value: "\(values.count) 时段 · \(values.reduce(0) { $0 + $1.credits }.formatted()) 学分") } }
        }.navigationTitle("排课工作台")
    }
    private func save(_ entries: [PlanEntry]) { if let data = try? JSONEncoder().encode(entries) { saved = String(decoding: data, as: UTF8.self) } }
}
