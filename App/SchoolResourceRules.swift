import WebKit

@MainActor
enum SchoolResourceRules {
    static func shared() async -> WKContentRuleList? {
        // Legacy EMAP markup still names the official static host over HTTP.
        // Upgrade those resources; never weaken transport security for cookies.
        let rules = #"[{"trigger":{"url-filter":"^http://res\\.sustech\\.edu\\.cn/"},"action":{"type":"make-https"}}]"#
        return try? await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "school-official-https-resources", encodedContentRuleList: rules)
    }
}
