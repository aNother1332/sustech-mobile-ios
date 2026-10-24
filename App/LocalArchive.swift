import CampusCore
import CryptoKit
import Foundation

struct OfflineFile: Identifiable, Codable {
    let id: UUID
    let key: String
    let name: String
    let course: String
    let relativePath: String
    let saved: Date
    let bytes: Int64
}

struct LocalArchive: Codable {
    var version = 2
    var owner: String
    var teaching: TeachingSnapshot?
    var teachingDate: Date?
    var grades: AcademicSnapshot?
    var gradesDate: Date?
    var blackboard: BlackboardSnapshot?
    var blackboardDate: Date?
    var courseDetails: [String: BBCourseDetail] = [:]
    var contents: [String: [BBContent]] = [:]
    var files: [OfflineFile] = []
}

/// One protected archive belongs to one active identity/session. Account changes
/// and explicit logout remove it and its files before another identity can sync.
struct LocalRepository {
    let root: URL
    init() {
        root = URL.applicationSupportDirectory.appendingPathComponent("CampusStudy", isDirectory: true)
    }
    var archiveURL: URL { root.appendingPathComponent("archive-v2.json") }
    func load() -> LocalArchive? {
        guard let data = try? Data(contentsOf: archiveURL), let archive = try? JSONDecoder().decode(LocalArchive.self, from: data),
              archive.version == 2 else { return nil }
        return archive
    }
    func save(_ archive: LocalArchive) throws {
        try prepare()
        let data = try JSONEncoder().encode(archive)
        try data.write(to: archiveURL, options: [.atomic, .completeFileProtection])
    }
    func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var url = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
    func erase() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }
    func fileURL(_ file: OfflineFile) -> URL { root.appendingPathComponent(file.relativePath) }
    static func identity(_ value: String) -> String {
        SHA256.hash(data: Data(value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
    static func filename(_ value: String) -> String {
        let basename = value.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? "课件"
        let clean = basename.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && !"/:".unicodeScalars.contains($0) }
        return String(String.UnicodeScalarView(clean)).prefix(120).description
    }
}
