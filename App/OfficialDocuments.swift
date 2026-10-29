import CampusCore
import PDFKit
import SwiftUI

@MainActor
@Observable
final class OfficialPDF {
    var document: PDFDocument?
    var thumbnail: UIImage?
    var error: String?
    var loading = false
    private var requestID = UUID()
    func load(_ url: URL) async {
        let request = UUID(); requestID = request; loading = true
        defer { if requestID == request { loading = false } }
        document = nil; thumbnail = nil; error = nil
        guard url.scheme == "https", ["tao.sustech.edu.cn", "www.sustech.edu.cn"].contains(url.host ?? "") else { error = "文件地址不可用"; return }
        let config = URLSessionConfiguration.ephemeral; config.urlCache = nil; config.timeoutIntervalForRequest = 40
        let session = URLSession(configuration: config); defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()
            guard requestID == request else { return }
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.url?.host == url.host, data.count < 50_000_000, data.starts(with: Data("%PDF".utf8)),
                  let document = PDFDocument(data: data), document.pageCount > 0 else { throw ServiceFailure("文件暂不可用") }
            self.document = document
            thumbnail = document.page(at: 0)?.thumbnail(of: CGSize(width: 190, height: 250), for: .mediaBox)
        } catch is CancellationError { }
        catch { if requestID == request, !Task.isCancelled { self.error = "文件暂不可用" } }
    }
}

struct OfficialPDFReader: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical; view.backgroundColor = .secondarySystemBackground; view.document = document
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { if view.document !== document { view.document = document } }
}

struct OfficialDocumentPage: View {
    let title: String
    let document: PDFDocument
    var body: some View { OfficialPDFReader(document: document).navigationTitle(title).navigationBarTitleDisplayMode(.inline) }
}

struct CurriculumDocument: Decodable, Identifiable {
    let year: Int; let title: String; let url: URL
    var id: Int { year }
    static var all: [CurriculumDocument] {
        guard let url = Bundle.main.url(forResource: "curriculum-documents", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CurriculumDocument].self, from: data)) ?? []
    }
}

struct CurriculumCard: View {
    @Environment(CampusStore.self) private var store
    @State private var file = OfficialPDF()
    @State private var chosenYear: Int?
    private var year: Int { chosenYear ?? store.profile?.admissionYear ?? 2026 }
    private var source: CurriculumDocument? { CurriculumDocument.all.first { $0.year == year } }
    private var selection: (title: String, document: PDFDocument)? {
        guard let document = file.document else { return nil }
        guard let profile = store.profile, !CurriculumPolicy.showCompleteBook(profile), let root = document.outlineRoot else { return ("完整培养方案", document) }
        var entries: [(level: Int, title: String, page: Int, context: String)] = []
        func visit(_ outline: PDFOutline, level: Int, context: String) {
            for i in 0..<outline.numberOfChildren {
                guard let child = outline.child(at: i) else { continue }
                let title = child.label ?? ""
                if let page = child.destination?.page { entries.append((level, title, document.index(for: page), context)) }
                visit(child, level: level + 1, context: context + title)
            }
        }
        visit(root, level: 0, context: "")
        let matches = entries.indices.filter { CurriculumPolicy.matches(title: entries[$0].title, major: profile.major) }
        let selected = matches.first { entries[$0].context.contains(profile.department) } ?? (matches.count == 1 ? matches.first : nil)
        guard let selected else { return ("完整培养方案", document) }
        let item = entries[selected]
        let end = entries.dropFirst(selected + 1).first { $0.level <= item.level && $0.page > item.page }?.page ?? document.pageCount
        guard item.page >= 0, end > item.page, end <= document.pageCount else { return ("完整培养方案", document) }
        let chapter = PDFDocument()
        for i in item.page..<end { if let page = document.page(at: i)?.copy() as? PDFPage { chapter.insert(page, at: chapter.pageCount) } }
        return (profile.major + "培养方案", chapter)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("培养方案").font(.headline); Spacer()
                Menu {
                    ForEach(CurriculumDocument.all) { item in Button(String(item.year) + "级") { chosenYear = item.year } }
                } label: {
                    Label(String(year) + "级", systemImage: "chevron.down").font(.subheadline).foregroundStyle(.orange)
                }.buttonStyle(.borderless).accessibilityIdentifier("curriculum-year")
            }
            if file.loading { ProgressView().frame(maxWidth: .infinity) }
            if let error = file.error { InlineFailure(message: error) }
            if let selection {
                NavigationLink { OfficialDocumentPage(title: selection.title, document: selection.document).toolbar(.visible, for: .navigationBar) } label: {
                    HStack(spacing: 18) {
                        if let image = file.thumbnail { Image(uiImage: image).resizable().scaledToFit().frame(width: 86, height: 116).clipShape(RoundedRectangle(cornerRadius: 5)).shadow(color: .black.opacity(0.08), radius: 5) }
                        VStack(alignment: .leading, spacing: 9) { Text(selection.title).font(.headline); Text(String(year) + "级 · " + String(selection.document.pageCount) + " 页").font(.caption).foregroundStyle(.secondary); Label("打开阅读", systemImage: "doc.text.magnifyingglass").font(.caption).foregroundStyle(.blue) }
                        Spacer(minLength: 0)
                    }.padding(16).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.borderless).accessibilityIdentifier("curriculum-read")
                if let document = file.document, selection.document !== document { NavigationLink("完整培养方案") { OfficialDocumentPage(title: "\(year)级培养方案", document: document) }.font(.caption).buttonStyle(.borderless) }
            }
            if source == nil { Link("学校培养方案目录", destination: URL(string: "https://tao.sustech.edu.cn/xueshengfuwu/pyfa/")!).font(.subheadline) }
        }.task(id: source?.url) { if let source { await file.load(source.url) } }
    }
}
