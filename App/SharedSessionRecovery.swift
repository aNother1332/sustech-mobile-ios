import CampusCore
import Foundation

extension CampusStore {
    func prepareBusiness(_ service: SchoolService) async throws {
        do {
            switch service {
            case .rooms: try await sessions.connectIC()
            case .cle: try await sessions.connectCLE()
            case .booking: try await sessions.connectCollege()
            case .exchange: try await sessions.connectExchange()
            default: return
            }
        } catch {
            guard LoginRequirement.confirmed(error) else { throw error }
            _ = try await renewSession(for: service.portalURL)
        }
    }
    func recovery(for origin: URL) -> SessionRecovery? {
        let known = CASService.allCases.contains { $0.entry.host == origin.host }
            || [SchoolService.rooms, .cle, .booking, .exchange].contains { $0.portalURL.host == origin.host }
        guard known else { return nil }
        return { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.renewSession(for: origin)
        }
    }
    private func exchangeSession(for origin: URL) async throws {
        if origin.host == SchoolService.printing.portalURL.host {
            try await sessions.renewPrinting {
                guard !UserDefaults.standard.bool(forKey: "printing-auto-login-paused"), let account = CredentialVault.load(RememberedSchoolAccount.self, key: "printing-auto-login") else { throw CampusError.signInRequired }
                let version = self.sessionRevision
                let http = ServiceHTTP(origin: origin, cookies: await self.sessions.cookies())
                do { try await PrintingAuthentication(http: http).signIn(username: account.username, password: account.password) }
                catch { if error is PrintingAuthFailure { UserDefaults.standard.set(true, forKey: "printing-auto-login-paused") }; throw error }
                await self.absorb(http, revision: version)
            }
        }
        else if let service = CASService.allCases.first(where: { $0.entry.host == origin.host }) { try await sessions.connectCAS(service) }
        else if origin.host == SchoolService.rooms.portalURL.host { try await sessions.renewIC() }
        else if origin.host == SchoolService.cle.portalURL.host { try await sessions.connectCLE(force: true) }
        else if origin.host == SchoolService.booking.portalURL.host { try await sessions.connectCollege(force: true) }
        else if origin.host == SchoolService.exchange.portalURL.host { try await sessions.connectExchange(force: true) }
    }
    func renewSession(for origin: URL) async throws -> RecoveredSession {
        let version = sessionRevision
        guard !clearing else { throw CancellationError() }
        do { try await exchangeSession(for: origin) }
        catch {
            guard origin.host != SchoolService.printing.portalURL.host, LoginRequirement.confirmed(error), remembersSchoolAccount else { throw error }
            try await renewRememberedCAS()
            guard version == sessionRevision else { throw CancellationError() }
            try await exchangeSession(for: origin)
        }
        guard version == sessionRevision, !clearing else { throw CancellationError() }
        let headers = origin.host == SchoolService.booking.portalURL.host ? ["Authorization": sessions.collegeToken] : [:]
        return RecoveredSession(cookies: await sessions.cookies(), headers: headers)
    }
}
