import CampusCore
import QuickLook
import SwiftUI

struct BBCourseView: View {
    let course: BlackboardCourse
    @Environment(CampusStore.self) private var store
    @State private var tab = 0
    @State private var onlyPending = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Picker("课程内容", selection: $tab) {
                    Text("任务").tag(0); Text("公告").tag(1); Text("课件").tag(2)
                }.pickerStyle(.segmented)
                if tab == 2 { BBContentList(course: course, parent: nil) }
                else {
                    Button { Task { await store.refreshCourse(course) } } label: {
                        if store.courseLoading.contains(course.id) { ProgressView("正在读取课程…") }
                        else { Label("刷新任务与公告", systemImage: "arrow.clockwise") }
                    }.disabled(store.courseLoading.contains(course.id) || store.mode == .demo || store.authenticating || store.clearing)
                    if let detail = store.courseDetails[course.id] {
                        Text("最近读取：\(detail.updated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(detail.warnings.enumerated()), id: \.offset) { _, warning in Text(warning).font(.caption).foregroundStyle(.orange) }
                        if tab == 0 {
                            if let date = detail.tasksUpdated { Text("任务数据：\(date.formatted())").font(.caption).foregroundStyle(.secondary) }
                            Toggle("只看未提交与草稿", isOn: $onlyPending)
                            Text("未知状态不归入未提交；没有截止日期的任务也会保留。").font(.caption).foregroundStyle(.secondary)
                            let tasks = detail.tasks.filter { !onlyPending || [.pending, .draft].contains($0.submission) }
                            if tasks.isEmpty { Text(onlyPending ? "本次读取中没有确认未交/草稿的条目。请同时检查未知状态和读取提示。" : "本次未读取到任务，请同时检查读取提示。").foregroundStyle(.secondary) }
                            ForEach(tasks) { task in
                                NavigationLink { BBTaskView(task: task) } label: { CampusCard { DeadlineRow(deadline: task) } }.buttonStyle(.plain)
                            }
                        } else {
                            if let date = detail.announcementsUpdated { Text("公告数据：\(date.formatted())").font(.caption).foregroundStyle(.secondary) }
                            if detail.announcements.isEmpty { Text("本次未读取到公告，请同时检查读取提示。").foregroundStyle(.secondary) }
                            ForEach(detail.announcements) { item in
                                CampusCard {
                                    Text(item.title).font(.headline)
                                    if let date = BBStudyParser.date(item.created) { Text(date.formatted()).font(.caption).foregroundStyle(.secondary) }
                                    Text(item.body).textSelection(.enabled)
                                }
                            }
                        }
                    } else { ContentUnavailableView("课程尚未读取", systemImage: "books.vertical", description: Text("点击刷新以读取本人任务和课程公告。")) }
                }
            }.padding(12).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .refreshable { if tab == 2 { _ = try? await store.contents(course: course.id, parent: nil) } else { await store.refreshCourse(course) } }
        .navigationTitle(course.name).navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .task { if store.courseDetails[course.id] == nil { await store.refreshCourse(course) } }
    }
}

struct BBTaskView: View {
    let task: LearningDeadline
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                DeadlineRow(deadline: task)
                Text(task.statusNote).font(.callout).foregroundStyle(.secondary)
                Divider()
                Text(task.details.isEmpty ? "没有读取到任务正文，请到学校课程页面核对完整要求。" : task.details).textSelection(.enabled)
                Link("在学校课程页面核对", destination: SchoolService.blackboard.portalURL)
                NavigationLink("原生文件作业提交") { BBSubmissionView(task: task).id(task.courseID) }
                if let due = task.due { NavigationLink("日历与提醒") { EventActionView(title: task.title, start: due, end: due.addingTimeInterval(900), key: "bb-" + task.id, courseID: task.courseID) } }
                Text("个人文件作业可进入原生提交；其他类型使用学校页面。").font(.caption).foregroundStyle(.secondary)
            }.padding(12).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }.navigationTitle("任务详情").navigationBarTitleDisplayMode(.inline)
    }
}

struct BBContentList: View {
    let course: BlackboardCourse
    let parent: String?
    @Environment(CampusStore.self) private var store
    @State private var loading = false
    @State private var failure: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { Task { await load() } } label: {
                if loading { ProgressView("正在读取课件目录…") } else { Label("刷新课件目录", systemImage: "arrow.clockwise") }
            }.disabled(loading || store.mode == .demo || store.authenticating || store.clearing)
            if let failure { Text(failure).font(.caption).foregroundStyle(.orange) }
            if let rows = store.contentCache[store.contentKey(course.id, parent)] {
                Text("已缓存的目录；附件需单独下载后才能离线打开。").font(.caption).foregroundStyle(.secondary)
                if rows.isEmpty { Text("该目录本次返回为空。").foregroundStyle(.secondary) }
                ForEach(rows) { item in
                    NavigationLink {
                        if item.hasChildren {
                            ScrollView { BBContentList(course: course, parent: item.id).padding(12) }
                                .refreshable { await load() }
        .navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
                        } else { BBContentView(course: course, item: item) }
                    } label: {
                        CampusCard {
                            Label(item.title, systemImage: item.hasChildren ? "folder" : "doc.text")
                            if !item.body.isEmpty { Text(item.body).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                        }
                    }.buttonStyle(.plain)
                }
            } else if !loading { Text("尚未读取目录。外部链接或特殊文件可在学校页面查看。").foregroundStyle(.secondary) }
        }.task { if store.contentCache[store.contentKey(course.id, parent)] == nil { await load() } }
    }
    private func load() async {
        guard !loading else { return }
        loading = true; failure = nil
        defer { loading = false }
        do { _ = try await store.contents(course: course.id, parent: parent) }
        catch is CancellationError { }
        catch { failure = "课件目录读取失败；如显示目录，为之前缓存。请检查会话和网络。" }
    }
}

struct BBContentView: View {
    let course: BlackboardCourse
    let item: BBContent
    @Environment(CampusStore.self) private var store
    @State private var attachments: [BBAttachment]?
    @State private var loading = false
    @State private var failure: String?
    @State private var preview: OfflineFile?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title).font(.title2.bold())
                if !item.body.isEmpty { Text(item.body).textSelection(.enabled) }
                Button("读取可下载附件") { Task { await load() } }.disabled(loading || store.clearing || store.authenticating)
                if loading { ProgressView() }
                if let failure { Text(failure).font(.callout).foregroundStyle(.orange) }
                if let attachments {
                    if attachments.isEmpty { Text("本次未发现支持的附件。外部链接、测验等请在学校页面处理。").foregroundStyle(.secondary) }
                    ForEach(attachments) { attachment in
                        let key = store.fileKey(course: course.id, content: item.id, attachment: attachment.id)
                        CampusCard {
                            Text(attachment.name).font(.headline)
                            if let file = store.files.first(where: { $0.key == key }) {
                                Button("打开已下载文件") { preview = file }
                                Text("下载于 \(file.saved.formatted())").font(.caption).foregroundStyle(.secondary)
                            }
                            Button {
                                Task {
                                    do { preview = try await store.download(attachment, course: course, content: item.id) }
                                    catch is CancellationError { }
                                    catch { failure = "下载未完成。请检查会话、网络、文件大小或目标地址；单文件上限 200 MB。" }
                                }
                            } label: {
                                if store.downloading.contains(key) { ProgressView("正在下载…") }
                                else { Label("下载到本机", systemImage: "arrow.down.document") }
                            }.disabled(store.downloading.contains(key) || store.clearing || store.authenticating)
                        }
                    }
                }
                NavigationLink("查看全部离线文件") { OfflineDownloadsView() }
                Link("在学校页面查看完整内容", destination: SchoolService.blackboard.portalURL)
            }.padding(12).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }.navigationTitle("课件详情").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $preview) { OfflinePreview(file: $0) }
    }
    private func load() async {
        loading = true; failure = nil
        defer { loading = false }
        do { attachments = try await store.attachments(course: course.id, content: item.id) }
        catch is CancellationError { }
        catch { failure = "附件列表读取失败，请检查登录和网络后重试。" }
    }
}

struct OfflineDownloadsView: View {
    @Environment(CampusStore.self) private var store
    @State private var selected: OfflineFile?
    var body: some View {
        List {
            Section {
                Text("文件保存在本机，退出/切换账号时清除。系统支持的格式可预览，也可分享至“文件”或其他应用。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.files.sorted { $0.saved > $1.saved }) { file in
                Button { selected = file } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(file.name).foregroundStyle(.primary)
                        Text(file.course).font(.caption).foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file) + " · " + file.saved.formatted()).font(.caption2).foregroundStyle(.secondary)
                    }
                }.swipeActions { Button("删除", role: .destructive) { store.deleteFile(file) } }
            }
            if store.files.isEmpty { Text("还没有下载文件。") }
        }.navigationTitle("离线文件").navigationBarTitleDisplayMode(.inline).sheet(item: $selected) { OfflinePreview(file: $0) }
    }
}

struct OfflinePreview: View {
    @State private var printing = false
    let file: OfflineFile
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            DocumentPreview(url: store.fileURL(file))
                .navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $printing) { NavigationStack { PrintingView(initialURL: store.fileURL(file)) } }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { HStack { ShareLink(item: store.fileURL(file)); if file.name.lowercased().hasSuffix(".pdf") { Button("校园打印", systemImage: "printer") { printing = true } } } }
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
                }
        }
    }
}

private struct DocumentPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) { }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
}
