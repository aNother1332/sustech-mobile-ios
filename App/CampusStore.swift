import CampusCore
import Foundation
import Observation
import WebKit
import UserNotifications
import WidgetKit

enum DataMode: String, CaseIterable { case live = "学校服务", demo = "演示模式" }
enum ConnectionState {
    case idle, loading
    case loaded(Date, warnings: [String])
    case cached(Date)
    case failed(String)
    var isLoading: Bool { if case .loading = self { true } else { false } }
}

@MainActor @Observable
final class CampusStore {
    private(set) var mode = DataMode.live
    var loginAccount: String?
    var cardBalance: String?
    var cardBalanceLoading = false
    var campusWeather: CampusWeather?
    var weatherFetched: Date?
    var weatherLoading = false
    var weatherMessage: String?
    var cardBalanceMessage: String?
    var cardBalanceRequest: UUID?
    var agendaExtras: [AgendaEntry] = []
    var profile: StudentProfile?
    var profileMessage: String?
    private(set) var teaching: TeachingSnapshot?
    private(set) var academic: AcademicSnapshot?
    private(set) var blackboard: BlackboardSnapshot?
    private(set) var teachingState = ConnectionState.idle
    private(set) var gradesState = ConnectionState.idle
    private(set) var blackboardState = ConnectionState.idle
    private(set) var courseDetails: [String: BBCourseDetail] = [:]
    private(set) var contentCache: [String: [BBContent]] = [:]
    private(set) var files: [OfflineFile] = []
    private(set) var courseLoading: Set<String> = []
    private(set) var downloading: Set<String> = []
    private(set) var clearing = false
    private(set) var authenticating = false
    private(set) var writing = false
    func beginWrite() -> Bool {
        guard !writing, !clearing, !authenticating, mode == .live else { return false }
        writing = true; return true
    }
    func endWrite() { writing = false }
    var automaticLoginMessage: String?
    var resumingConnections = false
    var lastAutomaticLogin: Date?
    private(set) var authenticationMessage: String?
    private(set) var challengeService: SchoolService?
    private(set) var cacheMessage: String?
    var serviceSessions: [CASService: ServiceSessionState] = [:]
    var serviceProbeTokens: [CASService: UUID] = [:]
    private var generation = 0
    var sessionRevision: Int { generation }
    private var owner: String?
    var accountScope: String { owner ?? "unverified" }
    private var teachingDate: Date?
    private var gradesDate: Date?
    private var blackboardDate: Date?
    private let repository = LocalRepository()
    let sessions = SchoolSessions()
    var websiteDataStore: WKWebsiteDataStore { sessions.websiteDataStore }
    private(set) var hiddenCourses: Set<String> = []
    var activeCourses: [BlackboardCourse] { (blackboard?.courses ?? []).filter { !hiddenCourses.contains($0.id) } }
    func setCourseHidden(_ id: String, hidden: Bool) {
        if hidden {
            hiddenCourses.insert(id)
            Task { let requests = await UNUserNotificationCenter.current().pendingNotificationRequests(); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: requests.filter { ($0.content.userInfo["courseID"] as? String) == id }.map(\.identifier)) }
        } else { hiddenCourses.remove(id) }
        if let owner, mode == .live {
            do { try CoursePreferences().save(hiddenCourses, owner: owner) }
            catch { cacheMessage = "课程显示偏好未能保存，请解锁设备后重试。" }
        }
        persist()
    }

    init() { restore() }

    var deadlines: [LearningDeadline] {
        if mode == .demo { return (blackboard?.deadlines ?? []).filter { !hiddenCourses.contains($0.courseID) } }
        return courseDetails.filter { !hiddenCourses.contains($0.key) }.values.flatMap(\.tasks).sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    private func resetDisplayedData() {
        CampusWidgetBridge.clear()
        serviceSessions = [:]; serviceProbeTokens = [:]
        cardBalanceRequest = nil; cardBalanceLoading = false; cardBalanceMessage = nil; agendaExtras = []
        loginAccount = nil; cardBalance = nil; profile = nil; profileMessage = nil
        teaching = nil; academic = nil; blackboard = nil
        courseDetails = [:]; contentCache = [:]; files = []; hiddenCourses = []
        teachingDate = nil; gradesDate = nil; blackboardDate = nil
        teachingState = .idle; gradesState = .idle; blackboardState = .idle
        courseLoading = []; downloading = []
    }
    private func restore() {
        guard let archive = repository.load() else { return }
        loginAccount = archive.loginAccount
        profile = archive.profile
        owner = archive.owner
        teaching = archive.teaching; academic = archive.grades; blackboard = archive.blackboard
        teachingDate = archive.teachingDate; gradesDate = archive.gradesDate; blackboardDate = archive.blackboardDate
        courseDetails = archive.courseDetails; contentCache = archive.contents
        hiddenCourses = CoursePreferences().load(owner: archive.owner) ?? archive.hiddenCourses ?? []
        files = archive.files.filter { FileManager.default.fileExists(atPath: repository.fileURL($0).path) }
        if let date = teachingDate, teaching != nil { teachingState = .cached(date) }
        if let date = gradesDate, academic != nil { gradesState = .cached(date) }
        if let date = blackboardDate, blackboard != nil { blackboardState = .cached(date) }
    }
    private func persist() {
        CampusWidgetBridge.publish(self)
        guard mode == .live, let owner, !clearing else { return }
        var archive = LocalArchive(owner: owner)
        archive.teaching = teaching; archive.teachingDate = teachingDate
        archive.grades = academic; archive.gradesDate = gradesDate
        archive.blackboard = blackboard; archive.blackboardDate = blackboardDate
        archive.hiddenCourses = hiddenCourses
        archive.loginAccount = loginAccount
        archive.profile = profile
        archive.courseDetails = courseDetails; archive.contents = contentCache; archive.files = files
        do { try repository.save(archive); cacheMessage = nil }
        catch { cacheMessage = "数据已读取，但本机缓存保存失败；请在解锁设备后重试。" }
    }
    func setMode(_ mode: DataMode) {
        #if !DEBUG
        guard mode == .live else { return }
        #endif
        guard !clearing, !authenticating, !writing else { return }
        generation += 1
        self.mode = mode
        resetDisplayedData()
        if mode == .demo { teaching = DemoData.teaching; blackboard = DemoData.blackboard }
        else { restore() }
    }

    func signIn(username: String, password: String, remember: Bool = false, automatic: Bool = false) async {
        guard !authenticating, !clearing, !writing, mode == .live else { return }
        if !automatic, let previous = rememberedUsername, previous != username { forgetSchoolAccount() }
        authenticating = true
        defer { authenticating = false; if Task.isCancelled { authenticationMessage = "登录已取消。" } }
        authenticationMessage = "正在连接学校 CAS…"
        challengeService = nil
        generation += 1
        let version = generation
        let sameAccount = owner == LocalRepository.identity(username)
        if sameAccount {
            teachingState = teachingDate.map { .cached($0) } ?? .idle
            gradesState = gradesDate.map { .cached($0) } ?? .idle
            blackboardState = blackboardDate.map { .cached($0) } ?? .idle
            courseLoading = []; downloading = []; serviceProbeTokens = [:]
            serviceSessions = serviceSessions.mapValues { $0.status == .checking ? ServiceSessionState() : $0 }
        } else {
            resetDisplayedData()
            owner = nil
            do { try repository.erase() } catch {
                authenticationMessage = "无法清除旧账号缓存，请先解锁设备后重试。"; return
            }
            let oldReminders = await UNUserNotificationCenter.current().pendingNotificationRequests()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: oldReminders.filter { $0.identifier.hasPrefix("campus-") }.map(\.identifier))
            await sessions.clear()
        }
        guard generation == version, !Task.isCancelled else { return }
        let client = CASClient()
        var authenticated = false
        var stopAutomatic = false
        var results: [String] = []
        for service in [CASService.teaching, .blackboard] {
            guard generation == version, !Task.isCancelled else { return }
            let label = service == .teaching ? "教务" : "Blackboard"
            authenticationMessage = "正在连接\(label)…"
            do {
                let cookies = try await client.signIn(service: service, username: username, password: password)
                guard generation == version, !Task.isCancelled else { return }
                loginAccount = username
                authenticated = true
                await retainCookies(cookies, version: version)
                guard generation == version else { return }
                owner = LocalRepository.identity(username)
                hiddenCourses = CoursePreferences().load(owner: owner!) ?? []
                if service == .teaching {
                    let http = CampusHTTPClient(origin: SchoolService.teaching.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.teaching.portalURL))
                    _ = try TISParser.semester(await http.data(path: "/component/querydangqianxnxq", form: [:]))
                    await refreshTeaching()
                } else {
                    await refreshBlackboard()
                }
                guard generation == version else { return }
                let state = service == .teaching ? teachingState : blackboardState
                if case .failed(let error) = state { results.append("\(label)：\(error)") }
                else { }
            } catch is CancellationError { return }
            catch {
                guard generation == version else { return }
                results.append("\(label)：\(error.localizedDescription)")
                if let error = error as? CASFailure, error == .challenge || error == .missingForm {
                    challengeService = service == .teaching ? .teaching : .blackboard
                }
                // A rejection must not submit the same password again to another service.
                if let error = error as? CASFailure, [.rejected, .challenge, .missingForm].contains(error) { stopAutomatic = true; break }
                if error as? CampusError == .rateLimited { stopAutomatic = true; break }
            }
        }
        guard generation == version else { return }
        var credentialsReady = false
        if authenticated, remember {
            do { try CredentialVault.save(RememberedSchoolAccount(username: username, password: password), key: "school-auto-login"); credentialsReady = true }
            catch { stopAutomatic = true; results.append("自动登录未启用，请解锁设备后重试") }
        }
        if !automatic, !remember, !forgetSchoolAccount() { results.append("已关闭自动登录；钥匙串中的旧凭据删除失败，请解锁设备后重试。") }
        if stopAutomatic {
            UserDefaults.standard.set(true, forKey: "school-auto-login-paused")
            automaticLoginMessage = "自动登录已暂停，请手动登录核对密码或完成学校验证。"
        } else if authenticated {
            if credentialsReady { UserDefaults.standard.removeObject(forKey: "school-auto-login-paused") }
            automaticLoginMessage = nil
        } else if automatic { automaticLoginMessage = "自动登录未完成，稍后可手动重试。" }
        authenticationMessage = results.isEmpty ? nil : results.joined(separator: "\n")
        if authenticated { await refreshProfile() }
        persist()
    }

    func refreshProfile() async {
        if mode == .demo { profile = StudentProfile(name: "示例同学", studentID: "示例学号", major: "示例专业", department: "示例院系"); return }
        guard !clearing else { return }
        let version = generation
        let http = await serviceHTTP(.teaching)
        do {
            let base = StudentProfile.parse(try await http.json("/user/me"))
            let details = try? await http.json("/UserManager/queryxsxx", form: [:], headers: ["RoleCode": "01"])
            let value = details.map { base.merging(StudentProfile.parse($0)) } ?? base
            guard version == generation else { return }
            if !value.isEmpty { profile = value; profileMessage = nil; persist() }
            else { profileMessage = "暂未读取到个人资料" }
        } catch { if version == generation { profileMessage = LoginRequirement.confirmed(error) ? nil : "个人资料暂不可用"; recordSession(.teaching, error: error) } }
        await absorb(http, revision: version)
    }

    /// Browsing a service preserves shared CAS and per-service sessions.
    func prepareSchoolBrowser(_ service: SchoolService) async -> Bool {
        guard !authenticating, !clearing, !writing else { return false }
        await sessions.restore()
        return true
    }

    func refreshTeaching() async {
        guard mode == .live, !teachingState.isLoading, !clearing else { return }
        let version = generation
        teachingState = .loading
        if serviceSessions[.teaching]?.valid != true { await sessions.connectIfPossible(.teaching) }
        let cookies = await sessions.cookies()
        guard version == generation else { return }
        let http = CampusHTTPClient(origin: SchoolService.teaching.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.teaching.portalURL))
        do {
            let snapshot = try await TISClient(http: http).snapshot()
            try Task.checkCancellation()
            guard version == generation else { return }
            await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
            guard version == generation else { return }
            if owner == nil { owner = "web-" + UUID().uuidString }
            recordSession(.teaching)
            teaching = snapshot; teachingDate = .now
            teachingState = .loaded(teachingDate!, warnings: snapshot.warnings)
            persist()
        } catch {
            guard version == generation else { return }
            recordSession(.teaching, error: error)
            teachingState = .failed(safeError(error))
        }
    }
    func refreshGrades() async {
        guard mode == .live, !gradesState.isLoading, !clearing else { return }
        let version = generation
        gradesState = .loading
        if serviceSessions[.teaching]?.valid != true { await sessions.connectIfPossible(.teaching) }
        let cookies = await sessions.cookies()
        guard version == generation else { return }
        let http = CampusHTTPClient(origin: SchoolService.teaching.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.teaching.portalURL))
        do {
            let snapshot = try await TISClient(http: http).grades()
            try Task.checkCancellation()
            guard version == generation else { return }
            await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
            guard version == generation else { return }
            if owner == nil { owner = "web-" + UUID().uuidString }
            recordSession(.teaching)
            academic = snapshot; gradesDate = .now
            gradesState = .loaded(gradesDate!, warnings: [])
            persist()
        } catch { guard version == generation else { return }; recordSession(.teaching, error: error); gradesState = .failed(safeError(error)) }
    }
    func refreshBlackboard() async {
        guard mode == .live, !blackboardState.isLoading, !clearing else { return }
        let version = generation
        blackboardState = .loading
        if serviceSessions[.blackboard]?.valid != true { await sessions.connectIfPossible(.blackboard) }
        let cookies = await sessions.cookies()
        guard version == generation else { return }
        let http = CampusHTTPClient(origin: SchoolService.blackboard.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.blackboard.portalURL))
        do {
            let snapshot = try await BlackboardClient(http: http).snapshot()
            try Task.checkCancellation()
            guard version == generation else { return }
            await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
            guard version == generation else { return }
            let ids = Set(snapshot.courses.map(\.id))
            courseDetails = courseDetails.filter { ids.contains($0.key) }
            if owner == nil { owner = "web-" + UUID().uuidString }
            recordSession(.blackboard)
            blackboard = snapshot; blackboardDate = .now
            blackboardState = .loaded(blackboardDate!, warnings: snapshot.warnings)
            persist()
        } catch { guard version == generation else { return }; recordSession(.blackboard, error: error); blackboardState = .failed(safeError(error)) }
    }
    func refreshCourse(_ course: BlackboardCourse) async {
        guard mode == .live, !clearing, !authenticating, !courseLoading.contains(course.id) else { return }
        let version = generation
        await checkSession(.blackboard)
        guard version == generation, mode == .live, !clearing, !authenticating else { return }
        courseLoading.insert(course.id)
        defer { if version == generation { courseLoading.remove(course.id) } }
        if serviceSessions[.blackboard]?.valid != true { await sessions.connectIfPossible(.blackboard) }
        let cookies = await sessions.cookies()
        guard version == generation else { return }
        let http = CampusHTTPClient(origin: SchoolService.blackboard.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.blackboard.portalURL))
        let client = BlackboardClient(http: http)
        do {
            let detail = try await client.courseDetail(course)
            try Task.checkCancellation()
            guard version == generation else { return }
            await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
            guard version == generation else { return }
            recordSession(.blackboard)
            courseDetails[course.id] = detail.retainingUnreadSections(from: courseDetails[course.id])
            persist()
        } catch {
            guard version == generation else { return }
            recordSession(.blackboard, error: error)
            if (error as? CampusError) == .signInRequired { await checkSession(.blackboard, force: true) }
            guard version == generation else { return }
            let old = courseDetails[course.id]
            courseDetails[course.id] = BBCourseDetail(tasks: old?.tasks ?? [], announcements: old?.announcements ?? [],
                warnings: [safeError(error), "如有数据，为最近一次缓存。"], tasksRead: false, announcementsRead: false,
                tasksUpdated: old?.tasksUpdated, announcementsUpdated: old?.announcementsUpdated)
        }
    }
    func contents(course: String, parent: String?) async throws -> [BBContent] {
        guard mode == .live, !clearing, !authenticating else { throw CancellationError() }
        let version = generation
        if serviceSessions[.blackboard]?.valid != true { await sessions.connectIfPossible(.blackboard) }
        let cookies = await sessions.cookies()
        guard version == generation else { throw CancellationError() }
        let http = CampusHTTPClient(origin: SchoolService.blackboard.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.blackboard.portalURL))
        let client = BlackboardClient(http: http)
        let result: [BBContent]
        do { result = try await client.contents(courseID: course, parentID: parent) }
        catch { if version == generation { recordSession(.blackboard, error: error); if (error as? CampusError) == .signInRequired { await checkSession(.blackboard, force: true) } }; throw error }
        try Task.checkCancellation()
        guard version == generation else { throw CancellationError() }
        await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
        guard version == generation else { throw CancellationError() }
        contentCache[contentKey(course, parent)] = result
        persist()
        return result
    }
    func attachments(course: String, content: String) async throws -> [BBAttachment] {
        let version = generation
        guard mode == .live, !clearing, !authenticating else { throw CancellationError() }
        if serviceSessions[.blackboard]?.valid != true { await sessions.connectIfPossible(.blackboard) }
        let cookies = await sessions.cookies()
        guard version == generation else { throw CancellationError() }
        let http = CampusHTTPClient(origin: SchoolService.blackboard.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.blackboard.portalURL))
        let result: [BBAttachment]
        do { result = try await BlackboardClient(http: http).attachments(courseID: course, contentID: content) }
        catch { if version == generation { recordSession(.blackboard, error: error); if (error as? CampusError) == .signInRequired { await checkSession(.blackboard, force: true) } }; throw error }
        try Task.checkCancellation()
        guard version == generation else { throw CancellationError() }
        await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
        guard version == generation else { throw CancellationError() }
        return result
    }
    func contentKey(_ course: String, _ parent: String?) -> String { course + "|" + (parent ?? "root") }
    func fileKey(course: String, content: String, attachment: String) -> String { course + "|" + content + "|" + attachment }
    func fileURL(_ file: OfflineFile) -> URL { repository.fileURL(file) }

    func download(_ attachment: BBAttachment, course: BlackboardCourse, content: String) async throws -> OfflineFile {
        let key = fileKey(course: course.id, content: content, attachment: attachment.id)
        guard mode == .live, !clearing, !authenticating, !downloading.contains(key), owner != nil else { throw CancellationError() }
        let version = generation
        downloading.insert(key)
        defer { if generation == version { downloading.remove(key) } }
        if serviceSessions[.blackboard]?.valid != true { await sessions.connectIfPossible(.blackboard) }
        let cookies = await sessions.cookies()
        guard version == generation else { throw CancellationError() }
        let http = CampusHTTPClient(origin: SchoolService.blackboard.portalURL, cookies: cookies, recovery: recovery(for: SchoolService.blackboard.portalURL))
        let temporary: URL
        do { temporary = try await http.download(path: attachment.path) }
        catch { if version == generation { recordSession(.blackboard, error: error); if (error as? CampusError) == .signInRequired { await checkSession(.blackboard, force: true) } }; throw error }
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard version == generation else { throw CancellationError() }
        await retainCookies(http.changedCookies().filter { cookie in let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")); return http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true }, version: version)
        guard version == generation else { throw CancellationError() }
        try repository.prepare()
        let id = UUID()
        let name = LocalRepository.filename(attachment.name)
        let relative = id.uuidString + "-" + (name.isEmpty ? "课件" : name)
        let destination = repository.root.appendingPathComponent(relative)
        try FileManager.default.moveItem(at: temporary, to: destination)
        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
            let bytes = (try FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.int64Value ?? 0
            let saved = OfflineFile(id: id, key: key, name: name, course: course.name, relativePath: relative, saved: .now, bytes: bytes)
            let old = files.filter { $0.key == key }
            files.removeAll { $0.key == key }
            files.append(saved)
            for file in old { try? FileManager.default.removeItem(at: repository.fileURL(file)) }
            persist()
            return saved
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
    func deleteFile(_ file: OfflineFile) {
        do {
            try FileManager.default.removeItem(at: repository.fileURL(file))
            files.removeAll { $0.id == file.id }
            persist()
        } catch { cacheMessage = "文件删除失败，请解锁设备后重试。" }
    }
    func clearLocalSession() async {
        if let root = CampusWidgetBridge.root { try? FileManager.default.removeItem(at: root.appendingPathComponent("CampusWidget.json")) }; WidgetCenter.shared.reloadAllTimelines()
        guard !clearing, !writing else { return }
        let forgotCredentials = forgetSchoolAccount()
        clearing = true; generation += 1
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix("campus-") }.map(\.identifier))
        resetDisplayedData(); owner = nil; mode = .live
        authenticationMessage = nil; challengeService = nil
        do { try repository.erase(); cacheMessage = nil }
        catch { cacheMessage = "部分本机文件未能清除，请解锁设备后再次清除。" }
        if !forgotCredentials { cacheMessage = "自动登录已关闭，但钥匙串凭据未能删除，请解锁设备后重试清除。" }
        await sessions.clear()
        clearing = false
    }
    private func retainCookies(_ cookies: [HTTPCookie], version: Int) async {
        for cookie in cookies {
            let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
            guard ["cas.sustech.edu.cn", "tis.sustech.edu.cn", "bb.sustech.edu.cn", "sustech.edu.cn"].contains(host) else { continue }
            guard generation == version, !clearing else { return }
            await websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }
    private func safeError(_ error: Error) -> String {
        if error is CancellationError { return "读取已取消，可以重新同步。" }
        if let error = error as? CampusError { return error.localizedDescription }
        if let error = error as? CASFailure { return error.localizedDescription }
        return "未能读取学校服务，请检查网络、会话或权限后重试。"
    }

    func serviceHTTP(_ service: CASService) async -> ServiceHTTP {
        if serviceSessions[service]?.valid != true { await sessions.connectIfPossible(service) }
        let origin: URL
        switch service {
        case .teaching: origin = SchoolService.teaching.portalURL
        case .blackboard: origin = SchoolService.blackboard.portalURL
        case .card: origin = SchoolService.card.portalURL
        case .printing: origin = SchoolService.printing.portalURL
        }
        return ServiceHTTP(origin: origin, cookies: await sessions.cookies(), recovery: recovery(for: origin))
    }
    func serviceHTTP(origin: URL) async -> ServiceHTTP {
        ServiceHTTP(origin: origin, cookies: await sessions.cookies(), recovery: recovery(for: origin))
    }
    func absorb(_ http: ServiceHTTP, revision: Int) async {
        guard generation == revision, !clearing else { return }
        for cookie in http.changedCookies() {
            guard generation == revision, !clearing else { return }
            let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn") else { continue }
            guard http.origin.host == host || http.origin.host?.hasSuffix("." + host) == true else { continue }
            await websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }
}
