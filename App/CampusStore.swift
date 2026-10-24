import CampusCore
import Foundation
import Observation
import WebKit

enum DataMode: String, CaseIterable {
    case live = "学校服务"
    case demo = "演示模式"
}

enum ConnectionState {
    case idle
    case loading
    case loaded(Date, warnings: [String])
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

@MainActor
@Observable
final class CampusStore {
    private(set) var mode = DataMode.live
    private(set) var teaching: TeachingSnapshot?
    private(set) var blackboard: BlackboardSnapshot?
    private(set) var teachingState = ConnectionState.idle
    private(set) var blackboardState = ConnectionState.idle
    private(set) var clearing = false
    private var generation = 0

    // App-local WebKit storage owns the login session. No password scraping,
    // cookie logging, shared server, or JS login injection is used.
    let websiteDataStore = WKWebsiteDataStore.default()

    func setMode(_ mode: DataMode) {
        guard !clearing else { return }
        generation += 1
        self.mode = mode
        teaching = nil
        blackboard = nil
        teachingState = .idle
        blackboardState = .idle
        if mode == .demo {
            teaching = DemoData.teaching
            blackboard = DemoData.blackboard
        }
    }

    func refreshTeaching() async {
        guard mode == .live, !teachingState.isLoading, !clearing else { return }
        let version = generation
        teachingState = .loading
        let cookies = await websiteDataStore.httpCookieStore.allCookies()
        guard generation == version else { return }
        let http = CampusHTTPClient(origin: SchoolService.teaching.portalURL, cookies: cookies)
        do {
            let snapshot = try await TISClient(http: http).snapshot()
            try Task.checkCancellation()
            guard generation == version else { return }
            await retainCookies(http.cookies())
            guard generation == version else { return }
            teaching = snapshot
            teachingState = .loaded(.now, warnings: snapshot.warnings)
        } catch {
            guard generation == version else { return }
            teachingState = .failed(error is CancellationError ? "同步已取消，可以重新同步。" : error.localizedDescription)
        }
    }

    func refreshBlackboard() async {
        guard mode == .live, !blackboardState.isLoading, !clearing else { return }
        let version = generation
        blackboardState = .loading
        let cookies = await websiteDataStore.httpCookieStore.allCookies()
        guard generation == version else { return }
        let http = CampusHTTPClient(origin: SchoolService.blackboard.portalURL, cookies: cookies)
        do {
            let snapshot = try await BlackboardClient(http: http).snapshot()
            try Task.checkCancellation()
            guard generation == version else { return }
            await retainCookies(http.cookies())
            guard generation == version else { return }
            blackboard = snapshot
            blackboardState = .loaded(.now, warnings: snapshot.warnings)
        } catch {
            guard generation == version else { return }
            blackboardState = .failed(error is CancellationError ? "同步已取消，可以重新同步。" : error.localizedDescription)
        }
    }

    func clearLocalSession() async {
        guard !clearing else { return }
        clearing = true
        generation += 1
        teaching = nil
        blackboard = nil
        teachingState = .idle
        blackboardState = .idle
        mode = .live
        await websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        clearing = false
    }

    private func retainCookies(_ cookies: [HTTPCookie]) async {
        let version = generation
        for cookie in cookies where Self.isSchoolDomain(cookie.domain) {
            guard generation == version, !clearing else { return }
            await websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }

    private static func isSchoolDomain(_ domain: String) -> Bool {
        let host = domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn")
    }
}
