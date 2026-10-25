import Foundation
import Testing
@testable import CampusCore

private func extraWire(_ text: String) throws -> WireValue { try JSONDecoder().decode(WireValue.self, from: Data(text.utf8)) }

@Test func busMapRejectsMissingInvalidAndZeroCoordinates() throws {
    let rows = try extraWire(#"[{"id":"missing","longitude":114},{"id":"zero","longitude":0,"latitude":0},{"id":"bad","longitude":190,"latitude":22},{"id":"good","longitude":113.99,"latitude":22.60,"operating":true}]"#)
    let vehicles = try BusMapParser.vehicles(rows)
    #expect(vehicles.map(\.id) == ["good"])
    #expect(vehicles[0].coordinate.longitude == 113.99)
}
@Test func busFreshnessUsesGPSReportInsteadOfFetchOrReceiveTime() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let rows = try extraWire(#"[{"id":"old","longitude":114,"latitude":22,"source_time":1799999700,"received_at":"2027-01-15T08:00:00Z"},{"id":"fresh","longitude":114,"latitude":22,"source_time":1799999990,"data_status":"normal"},{"id":"unknown","longitude":114,"latitude":22,"received_at":"2027-01-15T08:00:00Z"}]"#)
    let items = try BusMapParser.vehicles(rows)
    #expect(!items[0].isFresh(at: now)); #expect(items[1].isFresh(at: now)); #expect(!items[2].isFresh(at: now))
}
@Test func routeGeometryKeepsLongitudeLatitudeOrderAndDoesNotInventMissingPaths() throws {
    let raw = try extraWire(#"[{"id":"line1","name_zh":"1路","directions":[{"id":"cw","geometry_json":"[[113.9,22.6],[113.91,22.61]]","stops":[{"id":"one"}]},{"id":"bad","geometry_json":"not JSON"}]}]"#)
    let routes = try BusMapParser.routes(raw)
    #expect(routes[0].directions[0].points.first?.latitude == 22.6)
    #expect(routes[0].directions[0].stopIDs == ["one"])
    #expect(routes[0].directions[1].points.isEmpty)
}
@Test func teacherContactReadsOnlyExplicitEmailAndOffice() throws {
    let base = try #require(URL(string: "https://www.sustech.edu.cn/zh/faculties/demo.html"))
    let html = #"<div class="introduce"><div class="message-left fl"><span class="fa-envelope"></span><span class="font">demo@example.invalid</span><a href="https://faculty.sustech.edu.cn/demo">个人主页</a></div><div class="message-right"><p>办公室：示例楼 203</p></div></div>"#
    let contact = FacultyContactParser.parse(html, base: base)
    #expect(contact.email == "demo@example.invalid"); #expect(contact.office == "示例楼 203"); #expect(contact.profile?.host == "faculty.sustech.edu.cn")
}
@Test func teacherContactDoesNotTreatMailingAddressOrFooterMailAsPersonal() throws {
    let base = try #require(URL(string: "https://www.sustech.edu.cn/zh/faculties/demo.html"))
    let html = #"<div class="message-left"><span>Professor</span></div><div class="message-right"><p>通讯地址：学苑大道1088号</p></div><footer><a href="mailto:webmaster@example.invalid">网站维护</a></footer>"#
    let result = FacultyContactParser.parse(html, base: base)
    #expect(result.email == nil); #expect(result.office == nil)
}
@Test(arguments: ["https://sustech.edu.cn.evil.example/", "http://faculty.sustech.edu.cn/", "https://name:password@faculty.sustech.edu.cn/", "https://faculty.sustech.edu.cn:8443/"])
func teacherContactRejectsUnofficialAndInsecureDestinations(_ raw: String) throws { #expect(!FacultyContactParser.official(try #require(URL(string: raw)))) }
