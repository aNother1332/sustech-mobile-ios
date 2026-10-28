import CampusCore
import SwiftUI

private let reviewBlue = Color(red: 51.0/255, green: 122.0/255, blue: 183.0/255)

struct ReviewCourseSummary: View {
    let course: ReviewCourse
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(course.name).font(.headline).foregroundStyle(reviewBlue)
                    Text(course.teachers).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(course.rating.isEmpty ? "—" : course.rating).font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(reviewBlue)
                    Text("\(course.count) 条评价").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                metric("难度", course.difficulty, .orange); metric("作业", course.homework, .purple)
                metric("给分", course.grading, .green); metric("收获", course.gain, reviewBlue)
            }
        }
    }
    @ViewBuilder private func metric(_ title: String, _ value: Int?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title); Spacer(minLength: 2); Text(value.map(String.init) ?? "—").monospacedDigit() }.font(.caption2).foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) { Capsule().fill(color.opacity(0.10)); Capsule().fill(color.opacity(0.72)).frame(width: proxy.size.width * CGFloat(min(max(value ?? 0, 0), 100)) / 100) }
            }.frame(height: 4)
        }.frame(maxWidth: .infinity)
    }
}

struct CourseReviewsView: View {
    @Environment(CampusStore.self) private var store
    @State private var query = ""
    @State private var courses: [ReviewCourse] = []
    @State private var page = 1
    @State private var total = 0
    @State private var busy = false
    @State private var more = false
    @State private var message: String?
    @AppStorage("saved-review-courses") private var saved = "[]"
    private let client = ReviewClient(http: ServiceHTTP(origin: URL(string: "https://ncesnext.com")!))
    private var favorites: [ReviewCourse] { (try? JSONDecoder().decode([ReviewCourse].self, from: Data(saved.utf8))) ?? [] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BusinessHeader(title: "NCES", symbol: "quote.bubble", color: reviewBlue)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(reviewBlue)
                    TextField("课程代码、名称、教师", text: $query).submitLabel(.search).onSubmit { Task { await search() } }
                    if busy { ProgressView() }
                }.padding(14).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 12))
                ServiceMessage(message: message)
                if !favorites.isEmpty { CampusSectionTitle(title: "收藏"); ForEach(favorites) { course in card(course) } }
                HStack { CampusSectionTitle(title: "课程"); Spacer(); if total > 0 { Text("\(total)").font(.caption).foregroundStyle(.secondary) } }
                ForEach(courses) { course in card(course) }
                if more { Button("加载更多") { Task { await search(append: true) } }.frame(maxWidth: .infinity).buttonStyle(.bordered).disabled(busy) }
            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(reviewBlue.opacity(0.045)).navigationTitle("课程评价").navigationBarTitleDisplayMode(.inline).tint(reviewBlue)
            .refreshable { await search() }.task { demo() }
    }
    private func card(_ course: ReviewCourse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink { ReviewsDetailView(course: course, client: client) } label: { ReviewCourseSummary(course: course) }.buttonStyle(.plain)
            HStack { Spacer(); Button { toggle(course) } label: { Image(systemName: favorites.contains { $0.id == course.id } ? "bookmark.fill" : "bookmark").font(.caption).foregroundStyle(reviewBlue) }.accessibilityLabel("收藏课程") }
        }.padding(16).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(reviewBlue.opacity(0.10), lineWidth: 1) }
    }
    private func toggle(_ course: ReviewCourse) {
        guard store.mode == .live else { return }
        var value = favorites
        if value.contains(where: { $0.id == course.id }) { value.removeAll { $0.id == course.id } } else { value.append(course) }
        if let data = try? JSONEncoder().encode(value) { saved = String(decoding: data, as: UTF8.self) }
    }
    private func search(append: Bool = false) async {
        guard store.mode == .live, !busy, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        busy = true; defer { busy = false }
        let text = query; let next = append ? page + 1 : 1
        do {
            let result = try await client.searchPage(text, page: next)
            guard text == query else { return }
            page = result.page; total = result.total; more = result.hasMore
            courses = append ? courses + result.items.filter { row in !courses.contains { $0.id == row.id } } : result.items
            message = courses.isEmpty ? "没有匹配课程" : nil
        } catch { message = error.localizedDescription }
    }
    private func demo() {
        #if DEBUG
        guard store.mode == .demo else { return }
        let data = Data(#"{"courses":{"items":[{"id":10001,"name":"线性代数（示例）","course_code":"DEMO101","teacher_names":"示例教师","review_count":12,"rate_average":9.2,"difficulty_score":50,"homework_score":60,"grading_score":90,"gain_score":85}]}}"#.utf8)
        if let value = try? JSONDecoder().decode(WireValue.self, from: data) { courses = (try? ReviewClient.courses(value)) ?? [] }
        #endif
    }
}
private struct ReviewsDetailView: View {
    @Environment(CampusStore.self) private var store
    let course: ReviewCourse; let client: ReviewClient
    @State private var items: [CourseReview] = []
    @State private var page = 0
    @State private var busy = false
    @State private var more = false
    @State private var message: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CampusCard { ReviewCourseSummary(course: course) }
                ServiceMessage(message: message)
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text(item.term).font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(reviewBlue.opacity(0.09), in: Capsule()); Spacer(); Text(item.rating).font(.headline.monospacedDigit()).foregroundStyle(reviewBlue) }
                        Text(item.content).font(.subheadline).lineSpacing(5).textSelection(.enabled)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 12))
                }
                if busy { ProgressView().frame(maxWidth: .infinity) }
                if more { Button("更多评价") { Task { await load() } }.disabled(busy) }
            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(reviewBlue.opacity(0.045)).navigationTitle(course.code).navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { page = 0; await load() }
    }
    private func load() async {
        guard store.mode == .live, !busy else { return }; busy = true; defer { busy = false }
        do { let result = try await client.reviewPage(course, page: page + 1); items = page == 0 ? result.items : items + result.items.filter { row in !items.contains { $0.id == row.id } }; page += 1; more = result.hasMore; message = nil }
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
            Section { BusinessHeader(title: "修读进度", symbol: "graduationcap", color: .blue) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            Section { SessionBadge()
                if busy { ProgressView() }; ServiceMessage(message: message)
                EmptyView()
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
