import XCTest

/// 冒烟测试：四个页签可达、月视图关键控件存在。
final class SmokeUITests: XCTestCase {
    func testTabsNavigateAndMonthHeaderVisible() {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab 栏应出现")

        for title in ["倒计时", "闹钟", "设置"] {
            let button = tabBar.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(title) 页签应存在")
            button.tap()
        }

        tabBar.buttons["日历"].tap()
        XCTAssertTrue(
            app.buttons["搜索日程"].waitForExistence(timeout: 5),
            "回到日历页后月视图头部应可见"
        )
    }
}
