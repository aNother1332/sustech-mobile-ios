import Foundation

public enum CampusError: Error, LocalizedError, Equatable, Sendable {
    case signInRequired
    case accessDenied
    case rateLimited
    case unexpectedHTML
    case invalidResponse(String)
    case http(Int)
    case unsafeURL

    public var errorDescription: String? {
        switch self {
        case .signInRequired: "会话未建立或已过期，请打开对应学校页面登录后重试。"
        case .accessDenied: "学校拒绝访问。请检查账号权限、校园网络或学校认可的访问方式。"
        case .rateLimited: "学校暂时限制了请求频率，请稍后手动重试。"
        case .unexpectedHTML: "接口返回了网页，可能需要重新登录，或当前网络受到访问限制。"
        case .invalidResponse(let source): "\(source)返回的数据格式与预期不同，未将其当作空数据。"
        case .http(let status): "学校服务返回 HTTP \(status)，请稍后重试。"
        case .unsafeURL: "请求地址不在当前服务允许的 HTTPS 范围内。"
        }
    }
}

