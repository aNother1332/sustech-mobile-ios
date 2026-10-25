import CampusCore
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

struct BBSubmissionView: View {
    let task: LearningDeadline
    @Environment(CampusStore.self) private var store
    @State private var file: Data?
    @State private var filename = ""
    @State private var preview: BBSubmitPreview?
    @State private var importing = false
    @State private var busy = false
    @State private var confirm = false
    @State private var reset = false
    @State private var message: String?
    @State private var pending: Pending?
    private struct Pending: Codable { let preview: BBSubmitPreview; let name: String; let hash: String }
    private var vaultKey: String { "bb-pending-" + store.accountScope + "-" + task.id }
    private var hash: String { file.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "" }
    private func target() throws -> BBSubmitTarget {
        guard task.id.hasPrefix(task.courseID + "-"), let content = task.contentID else { throw ServiceFailure("缺少可核对的作业标识。") }
        return try BBSubmitTarget(course: task.courseID, column: String(task.id.dropFirst(task.courseID.count + 1)), content: content)
    }
    var body: some View {
        List {
            Section {
                SessionBadge(service: .blackboard)
                Text(task.course).font(.caption).foregroundStyle(.secondary); Text(task.title).font(.headline)
                DetailNote(title: "支持范围", text: "仅支持开放的 Original 个人文件作业，单文件上限 50 MB。不覆盖已有草稿，不支持小组作业、测验或 Ultra。正式提交前核对文件与作业要求。")
                ServiceMessage(message: message)
                if busy { ProgressView() }
            }
            if let pending {
                Section("有一笔提交待核对") {
                    Text(pending.name).font(.subheadline)
                    Text(pending.hash).font(.caption2.monospaced()).textSelection(.enabled)
                    Button("只查询服务器提交记录") { Task { await reconcile(pending) } }.disabled(busy)
                    Button("已在学校核对，解除本机待确认状态", role: .destructive) { reset = true }.disabled(busy)
                }
            } else {
                Section("选定文件") {
                    Button(filename.isEmpty ? "选择文件" : "更换文件") { importing = true }.disabled(busy || store.mode == .demo)
                    if let file { Text(filename); Text(ByteCountFormatter.string(fromByteCount: Int64(file.count), countStyle: .file)).font(.caption); Text(hash).font(.caption2.monospaced()).textSelection(.enabled) }
                    Button("检查作业与提交资格") { Task { await check() } }.disabled(busy || file == nil || store.mode == .demo)
                    if preview != nil { Label("预检通过，请确认正式提交", systemImage: "checkmark.circle").foregroundStyle(Color.campusGreen)
                        Button("提交选定文件", role: .destructive) { confirm = true }.disabled(busy || file == nil)
                    }
                }
            }
        }.navigationTitle("提交作业").navigationBarTitleDisplayMode(.inline)
        .task { pending = CredentialVault.load(Pending.self, key: vaultKey) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            do { let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard bytes > 0, bytes <= 50 * 1024 * 1024 else { throw ServiceFailure("请选择 50 MB 以内文件。") }
                file = try Data(contentsOf: url); filename = url.lastPathComponent; preview = nil; message = nil
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("正式提交到 \(task.course) / \(task.title)？", isPresented: $confirm, titleVisibility: .visible) {
            Button("确认提交 \(filename) 一次", role: .destructive) { Task { await submit() } }
        } message: { Text("请确认这是最终文件。提交后查询服务器回执；结果不明时不会自动重试。SHA256：" + hash) }
        .confirmationDialog("已在学校确认原提交状态？", isPresented: $reset, titleVisibility: .visible) {
            Button("已核对，解除本机限制", role: .destructive) { CredentialVault.delete(vaultKey); pending = nil; preview = nil; message = "本机限制已解除；没有更改学校提交记录。" }
        } message: { Text("此操作不撤销学校提交。尚未核对时请先查询，避免重复提交。") }
    }
    private func check() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let http = await store.serviceHTTP(.blackboard)
        do { let value = try await BBSubmissionClient(http: http).preview(target()); guard version == store.sessionRevision else { return }; preview = value; message = "预检通过；尚未上传或提交文件。" }
        catch { guard version == store.sessionRevision else { return }; preview = nil; message = error.localizedDescription }
        await store.absorb(http, revision: version)
    }
    private func submit() async {
        guard !busy, let preview, let file, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        let value = Pending(preview: preview, name: filename, hash: hash)
        do { try CredentialVault.save(value, key: vaultKey) } catch { message = "无法保存本机待确认记录，已停止提交。"; return }
        pending = value
        let http = await store.serviceHTTP(.blackboard)
        do { let receipt = try await BBSubmissionClient(http: http).submit(preview, file: file, filename: filename)
            CredentialVault.delete(vaultKey); pending = nil; self.preview = nil; self.file = nil
            message = "服务器已确认新提交及文件名，提交记录：" + receipt
            if let course = store.blackboard?.courses.first(where: { $0.id == task.courseID }) { await store.refreshCourse(course) }
        } catch { message = "结果需核对：" + error.localizedDescription }
        await store.absorb(http, revision: store.sessionRevision)
    }
    private func reconcile(_ pending: Pending) async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let http = await store.serviceHTTP(.blackboard)
        do { let receipt = try await BBSubmissionClient(http: http).reconcile(pending.preview, filename: pending.name); guard version == store.sessionRevision else { return }; CredentialVault.delete(vaultKey); self.pending = nil; message = "已确认提交及文件名，记录：" + receipt }
        catch { guard version == store.sessionRevision else { return }; message = error.localizedDescription }
        await store.absorb(http, revision: version)
    }
}
