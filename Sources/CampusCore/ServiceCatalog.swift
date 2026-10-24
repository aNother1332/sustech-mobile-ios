import Foundation

public enum SchoolService: String, CaseIterable, Identifiable, Sendable {
    case teaching, blackboard, card, printing, library, rooms, booking, cle, exchange, faculty

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .teaching: "教务系统"
        case .blackboard: "Blackboard"
        case .card: "校园卡"
        case .printing: "校园打印"
        case .library: "图书馆"
        case .rooms: "IC 研讨间"
        case .booking: "场馆预约"
        case .cle: "语言辅导"
        case .exchange: "国际交流"
        case .faculty: "教师名录"
        }
    }

    public var symbol: String {
        switch self {
        case .teaching: "calendar"
        case .blackboard: "books.vertical"
        case .card: "creditcard"
        case .printing: "printer"
        case .library: "building.columns"
        case .rooms: "person.3"
        case .booking: "sportscourt"
        case .cle: "bubble.left.and.bubble.right"
        case .exchange: "globe.asia.australia"
        case .faculty: "person.crop.rectangle"
        }
    }

    public var summary: String {
        switch self {
        case .teaching: "课表、考试与学校教务页面"
        case .blackboard: "课程、截止日期与课程页面"
        case .card: "余额、账单与消费统计"
        case .printing: "官方打印平台 · 可能需要校内网络"
        case .library: "馆藏、借阅与图书馆服务"
        case .rooms: "图书馆空间与研讨间预约"
        case .booking: "场馆查询与官方预约页面"
        case .cle: "语言指导与预约服务"
        case .exchange: "交流项目与申请信息"
        case .faculty: "学校公开教师资料"
        }
    }

    public var portalURL: URL {
        // These are fixed developer-owned HTTPS constants, never user input.
        let address = switch self {
        case .teaching: "https://tis.sustech.edu.cn/"
        case .blackboard: "https://bb.sustech.edu.cn/"
        case .card: "https://campuscard.sustech.edu.cn/"
        case .printing: "https://pms.sustech.edu.cn/"
        case .library: "https://lib.sustech.edu.cn/"
        case .rooms: "https://booking.lib.sustech.edu.cn/"
        case .booking: "https://booking.sustech.edu.cn/"
        case .cle: "https://ehall.sustech.edu.cn/dxggyw/sys/yyzxyy/*default/index.do"
        case .exchange: "https://ws.sustech.edu.cn/"
        case .faculty: "https://www.sustech.edu.cn/zh/faculty/"
        }
        return URL(string: address)!
    }
}
