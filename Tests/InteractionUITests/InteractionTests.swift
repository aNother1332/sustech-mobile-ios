import XCTest

@MainActor
final class InteractionTests: XCTestCase {
    func testHomeSummaryCardsOpenTheirDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["--smoke-demo"]
        app.launch()
        let balance = app.buttons["home-card-balance"].firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        balance.tap()
        XCTAssertTrue(app.navigationBars["校园卡"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        let agenda = app.buttons["home-card-agenda"].firstMatch
        XCTAssertTrue(agenda.waitForExistence(timeout: 10))
        agenda.tap()
        XCTAssertTrue(app.navigationBars["我的日程"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testCurriculumOpensExactlyTheChosenDocument() {
        let app = XCUIApplication()
        app.launchArguments = ["--smoke-demo", "--smoke-degree", "--smoke-pdf-interaction"]
        app.launch()
        let own = app.buttons["curriculum-read"].firstMatch
        XCTAssertTrue(own.waitForExistence(timeout: 15))
        own.tap()
        let ownTitle = app.navigationBars["示例专业培养方案"]
        XCTAssertTrue(ownTitle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["2025级全校培养方案"].exists)
        ownTitle.buttons["完成"].tap()
        let full = app.buttons["查看全校培养方案"]
        XCTAssertTrue(full.waitForExistence(timeout: 5))
        full.tap()
        XCTAssertTrue(app.navigationBars["2025级全校培养方案"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testAvailableICCellOpensBookingFormWithoutSubmitting() {
        let app = XCUIApplication()
        app.launchArguments = ["--smoke-demo", "--smoke-ic", "--smoke-ic-interaction"]
        app.launch()
        let cell = app.buttons["ic-slot-demo-room-16"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: cell)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed)
        cell.tap()
        XCTAssertTrue(app.navigationBars["预约研讨间"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["核对并预约一次"].isEnabled)
        app.terminate()
    }
}
