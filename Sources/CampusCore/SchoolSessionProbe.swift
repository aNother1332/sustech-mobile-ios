import Foundation

public enum SchoolSessionProbe {
    public static func teaching(_ http: ServiceHTTP) async throws {
        // The semester endpoint can return public data without authentication.
        // Require the actual authenticated identity, never infer login from it.
        let identity = try await http.json("/user/me")
        guard !identity["username"].text.isEmpty || !identity["userId"].text.isEmpty || !identity["yhdm"].text.isEmpty,
              identity["enabled"] != .bool(false) else { throw CampusError.signInRequired }
    }
}
