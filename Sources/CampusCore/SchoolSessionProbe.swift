import Foundation

public enum SchoolSessionProbe {
    public static func teaching(_ http: ServiceHTTP) async throws {
        // Same protected endpoint/method/parser as the supported native TIS client.
        _ = try TISParser.semester(await http.data("/component/querydangqianxnxq", form: [:]))
    }
}
