import CampusCore
import SwiftUI

struct CourseReviewsView: View {
    @Environment(CampusStore.self) private var store
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
            Section { ModeNotice(); DetailNote(title: "NCES 社区评价", text: "课程与教师评价来自 ncesnext.com，保留原始评价及学期。评分是社区参考，不代表学校教学评价或课程质量结论。")
                ServiceMessage(message: message); if busy { ProgressView() }
            }
            if !favorites.isEmpty { Section("已收藏") { ForEach(favorites) { course in courseRow(course) } } }
            Section("搜索结果") { ForEach(courses) { course in courseRow(course) }
                if more { Button("加载更多") { Task { await search(append: true) } }.disabled(busy) }
            }
        }.navigationTitle("课程评价").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "课程代码、名称或教师")
        .onSubmit(of: .search) { Task { await search() } }.refreshable { await search() }
        .task { if store.mode == .demo {
            let data = Data(#"{"courses":{"items":[{"id":10001,"name":"线性代数（虚构示例）","course_code":"DEMO101","teacher_names":"示例教师","review_count":12,"rate_average":4.5},{"id":10002,"name":"信号与系统（虚构示例）","course_code":"DEMO102","teacher_names":"示例教师","review_count":8,"rate_average":4.2}]}}"#.utf8)
            if let value = try? JSONDecoder().decode(WireValue.self, from: data) { courses = (try? ReviewClient.courses(value)) ?? [] }
        } }
    }
    private func courseRow(_ course: ReviewCourse) -> some View {
        NavigationLink { ReviewsDetailView(course: course, client: client) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(course.name).font(.subheadline.bold()); Spacer(); Text(course.rating.isEmpty ? "暂无评分" : course.rating).font(.subheadline.monospacedDigit()) }
                Text(course.code + " · " + course.teachers + " · \(course.count) 条评价").font(.caption).foregroundStyle(.secondary)
            }
        }.swipeActions { Button(favorites.contains { $0.id == course.id } ? "取消收藏" : "收藏") {
            guard store.mode == .live else { return }
            var value = favorites
            if value.contains(where: { $0.id == course.id }) { value.removeAll { $0.id == course.id } } else { value.append(course) }
            if let data = try? JSONEncoder().encode(value) { saved = String(decoding: data, as: UTF8.self) }
        }.tint(.campusGreen) }
    }
    private func search(append: Bool = false) async {
        guard store.mode == .live, !busy, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; busy = true; defer { busy = false }
        let text = query; let next = append ? page + 1 : 1
        do { let result = try await client.search(text, page: next); guard text == query else { return }; page = next; more = result.count == 20
            courses = append ? courses + result.filter { row in !courses.contains { $0.id == row.id } } : result; message = result.isEmpty && !append ? "未找到匹配课程" : nil
        } catch { message = error.localizedDescription }
    }
}
private struct ReviewsDetailView: View {
    @Environment(CampusStore.self) private var store
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
        }.navigationTitle("课程评价").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { page = 0; await load() }
    }
    private func load() async {
        guard store.mode == .live, !busy else { return }; busy = true; defer { busy = false }
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
            Section { ModeNotice(); SessionBadge(); DetailNote(title: "培养方案与口径", text: "读取教务系统的个性化修读进度。类别可能重叠，不能将各行学分直接相加。学校字段缺失时不推算毕业资格，最终以适用培养方案及教学工作部确认为准。")
                if busy { ProgressView() }; ServiceMessage(message: message)
                Button("刷新修读进度") { Task { await load() } }.disabled(busy || store.mode == .demo)
            }
            if let result { ForEach(result.sections) { section in Section(section.title) { ForEach(Array(section.values.enumerated()), id: \.offset) { _, value in LabeledContent(value.0, value: value.1) } } }
                if !result.warnings.isEmpty { Section("部分来源未读取") { ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) } } }
            }
        }.navigationTitle("学业修读进度").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }; let version = store.sessionRevision
        let http = await store.serviceHTTP(.teaching)
        do { let value = try await DegreeClient(http: http).progress(); guard version == store.sessionRevision else { return }; result = value; message = nil; store.recordSession(.teaching) }
        catch { guard version == store.sessionRevision else { return }; message = error.localizedDescription; store.recordSession(.teaching, error: error) }
        await store.absorb(http, revision: version)
    }
}
