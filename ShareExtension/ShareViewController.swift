import UIKit
import UniformTypeIdentifiers

@MainActor final class ShareViewController: UIViewController {
    private let label = UILabel()
    private var started = false
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        label.numberOfLines = 0; label.textAlignment = .center; label.text = "正在准备 PDF…"
        let done = UIButton(type: .system); done.setTitle("完成", for: .normal); done.addTarget(self, action: #selector(finish), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, done]); stack.axis = .vertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack); NSLayoutConstraint.activate([stack.centerYAnchor.constraint(equalTo: view.centerYAnchor), stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)])
        receive()
    }
    @objc private func finish() { extensionContext?.completeRequest(returningItems: nil) }
    private func receive() {
        guard !started else { return }; started = true
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.cn.sustech.community.daily") else {
            label.text = "当前签名未提供共享容器。请在校园打印页面使用“导入 PDF”；系统分享版需要支持 App Groups 的签名。"; return
        }
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }.filter { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }
        guard providers.count == 1, let provider = providers.first else { label.text = "请一次分享一个 PDF 文件（上限 50 MB）。"; return }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { [weak self] url, error in
            let result: String
            do {
                guard let url, error == nil else { throw CocoaError(.fileReadUnknown) }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard bytes > 0, bytes <= 50 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                let handle = try FileHandle(forReadingFrom: url); let header = try handle.read(upToCount: 5); try handle.close()
                guard header == Data("%PDF-".utf8) else { throw CocoaError(.fileReadCorruptFile) }
                let directory = group.appendingPathComponent("PrintInbox/" + UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
                let raw = url.lastPathComponent.replacingOccurrences(of: "[^a-zA-Z0-9\\u4e00-\\u9fff._-]", with: "_", options: .regularExpression)
                let name = raw.lowercased().hasSuffix(".pdf") ? raw : raw + ".pdf"
                let destination = directory.appendingPathComponent(String(name.suffix(160)))
                try FileManager.default.copyItem(at: url, to: destination)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
                var protected = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true; try protected.setResourceValues(values)
                result = "已加入待打印。打开 SUSTechMobile → 校园打印 → 系统分享待打印，确认参数后提交。"
            } catch { result = "无法接收该 PDF，请检查文件大小、格式及共享容器签名；也可在主 App 中导入。" }
            Task { @MainActor [weak self] in self?.label.text = result }
        }
    }
}
