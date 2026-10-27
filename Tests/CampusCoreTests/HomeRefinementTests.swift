import Foundation
import Testing
@testable import CampusCore

@Test func customRechargeDraftPreservesExactDecimalWithoutClaimingOrderSupport() throws {
    #expect(try RechargeDraft.normalizedAmount("3") == "3.00")
    #expect(try RechargeDraft.normalizedAmount("3.25") == "3.25")
    #expect(try RechargeDraft.normalizedAmount("0.01") == "0.01")
    #expect(try RechargeDraft.normalizedAmount("050.5") == "50.50")
    for input in ["0", "-3", "500.01", "3.001", "1e2", "3,5", "NaN", "", "3."] {
        #expect(throws: ServiceFailure.self) { try RechargeDraft.normalizedAmount(input) }
    }
    #expect(throws: ServiceFailure.self) { try RechargeDraft.requireVerifiedOrderContract() }
}
@Test func rechargeImportAcceptsOnlyFirstPartyExplicitCredentials() throws {
    let auth = try RechargeAuth.imported("https://campuscard.xh.sustech.edu.cn/#/wxlogin?user=123&access_token=demo-token")
    #expect(auth.userId == "123" && auth.cardId == "123" && auth.token == "demo-token")
    #expect(throws: (any Error).self) { try RechargeAuth.imported("https://example.com/#/wxlogin?user=123&access_token=demo-token") }
    #expect(throws: (any Error).self) { try RechargeAuth.imported("https://campuscard.xh.sustech.edu.cn/#/PayMoney") }
    #expect(throws: (any Error).self) { try RechargeAuth.imported("https://campuscard.xh.sustech.edu.cn/?user=123&user=456&access_token=demo") }
}
@Test func courtCredentialImportRejectsMalformedOrHeaderUnsafeSecrets() throws {
    let value = try CourtCredentials.imported(#"{"userID":"demo-user","token":"demo-token"}"#)
    #expect(value.userID == "demo-user")
    #expect(throws: ServiceFailure.self) { try CourtCredentials.imported(#"{"userID":"demo-user","token":"bad\nsecret"}"#) }
    #expect(throws: ServiceFailure.self) { try CourtCredentials.imported(#"{"userID":"","token":"demo"}"#) }
}
