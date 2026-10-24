import Foundation
import Testing
@testable import CampusCore

@Test func cardHTMLAndSpendingCurveDoNotCountRefundsOrUnknownDirections() throws {
    let account = try CardParser.account("""
    <div class="weui-cell__bd"><p>账户余额</p></div><div class="weui-cell__ft">36.50 元</div>
    """)
    #expect(account.balance == "36.50 元")
    let html = """
    <div class="weui-media-box weui-media-box_text"><h4 class="weui-media-box__title"><div>食堂消费</div><div>-12.30元</div></h4><div style="color:#999;flex:1">2026-10-25 12:00</div><span class="label label-success">成功</span></div>
    <div class="weui-media-box weui-media-box_text"><h4 class="weui-media-box__title"><div>退款</div><div>+2.30元</div></h4><div style="color:#999;flex:1">2026-10-25 13:00</div></div>
    <div class="weui-media-box weui-media-box_text"><h4 class="weui-media-box__title"><div>未知交易</div><div>5.00元</div></h4><div style="color:#999;flex:1">2026-10-25 14:00</div></div>
    """
    let bills = try CardParser.bills(html)
    #expect(bills.count == 3)
    #expect(bills[1].expense == nil)
    #expect(bills[2].expense == nil)
    #expect(CardParser.curve(bills).first?.amount == Decimal(string: "12.30"))
}

@Test func malformedCardPagesAreNotAnEmptyBalance() {
    #expect(throws: CampusError.self) { try CardParser.account("<html>登录</html>") }
    #expect(throws: CampusError.self) { try CardParser.bills("<input name='execution'>") }
}

@Test func roomBorrowingsCountAsOccupiedAndDiscardPersonalDetails() throws {
    let data = Data(#"[{"KEY":"xq2_jc3","SKSJ":"【借用】[1-3,5周]\n使用人:虚构人员\n联系电话:00000000000"}]"#.utf8)
    let value = try JSONDecoder().decode(WireValue.self, from: data)
    let entries = try ClassroomParser.entries(value)
    #expect(entries[0].overlaps(week: 2, weekday: 2, first: 2, last: 4))
    #expect(!entries[0].overlaps(week: 4, weekday: 2, first: 2, last: 4))
    #expect(entries[0].kind == "教室借用")
}

@Test func unknownClassroomWeeksAreConservativelyOccupied() throws {
    let value = try JSONDecoder().decode(WireValue.self, from: Data(#"[{"KEY":"xq1_jc1","SKSJ":"未明确周次"}]"#.utf8))
    #expect(try ClassroomParser.entries(value)[0].overlaps(week: 8, weekday: 1, first: 1, last: 2))
}

@Test func printOptionsMatchWireCodesAndRejectBadRanges() throws {
    var options = PrintOptions()
    options.duplex = 3; options.copies = 2
    let fields = try options.fields()
    #expect(fields["dwDuplex"] == "3")
    #expect(fields["dwPaperId"] == "9")
    #expect(fields["dwFrom"] == "0")
    options.first = 8; options.last = 3
    #expect(throws: ServiceFailure.self) { try options.fields() }
}

@Test func sessionRedirectsStayOnSchoolHTTPS() {
    #expect(SessionConnector.allowed(URL(string: "https://cas.sustech.edu.cn/cas/login")!))
    #expect(!SessionConnector.allowed(URL(string: "https://cas.sustech.edu.cn.evil.example")!))
    #expect(!SessionConnector.allowed(URL(string: "http://tis.sustech.edu.cn")!))
    #expect(!SessionConnector.allowed(URL(string: "https://user:password@tis.sustech.edu.cn")!))
}

@Test func cardFailedTransactionsAreExcluded() throws {
    let html = """
    <div class="weui-media-box weui-media-box_text"><h4><div>消费</div><div>-12.00</div></h4><div style="color:#999;flex:1">2026-10-25</div><span class="label label-danger">失败</span></div>
    """
    #expect(try CardParser.curve(CardParser.bills(html)).isEmpty)
}

@Test func courtBookingCannotProceedWithoutHumanChallenge() async {
    let api = CourtClient()
    let ground = ReservationItem(id: "fixture", title: "示例场地", detail: "", raw: .object([:]))
    let slot = CourtSlot(day: "2026-10-26", start: "8:00", end: "9:00", status: "1")
    await #expect(throws: ServiceFailure.self) {
        try await api.book(ground: ground, slot: slot, captchaToken: "", phone: "00000000000", people: 1)
    }
}

@Test func wireValuePreservesLargeStringIdentifiers() throws {
    let value = try JSONDecoder().decode(WireValue.self, from: Data(#"{"id":"1333325020650307585","status":1}"#.utf8))
    #expect(value["id"].text == "1333325020650307585")
    #expect(value["status"].int == 1)
    #expect(try JSONDecoder().decode(WireValue.self, from: JSONEncoder().encode(value)) == value)
}
