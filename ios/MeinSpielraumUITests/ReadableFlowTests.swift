import XCTest

final class ReadableFlowTests: XCTestCase {
    private func launch(large: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (large ? ["--large-text"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["openHousehold"].waitForExistence(timeout: 20))
        return app
    }
    private func screenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func press(_ id: String, app: XCUIApplication) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 10), id)
        if !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable, id)
        button.tap()
    }
    func testOverviewHouseholdAndForms() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["availableAmount"].exists)
        screenshot("01-Uebersicht", app: app)
        press("openHousehold", app: app)
        screenshot("02-Haushalt", app: app)
        press("household-Einnahmen", app: app)
        XCTAssertTrue(app.buttons["Einnahme hinzufügen"].firstMatch.exists)
        screenshot("03-Einnahmen", app: app)
        press("backToOverview", app: app)
        press("editBudget", app: app)
        XCTAssertTrue(app.textFields["Kontostand in €"].waitForExistence(timeout: 5))
        screenshot("04-Budget-bearbeiten", app: app)
        app.buttons["Abbrechen"].firstMatch.tap()
        press("backToOverview", app: app)
        press("tab-Spartöpfe", app: app)
        XCTAssertTrue(app.buttons["addPot"].exists)
        screenshot("05-Spartoepfe", app: app)
        app.buttons["Bearbeiten"].firstMatch.tap()
        XCTAssertTrue(app.textFields["Name des Spartopfs"].waitForExistence(timeout: 5))
        screenshot("06-Spartopf-bearbeiten", app: app)
        app.buttons["Abbrechen"].firstMatch.tap()
        press("tab-Übersicht", app: app)
        press("addExpense", app: app)
        XCTAssertTrue(app.textFields["Betrag in €"].waitForExistence(timeout: 5))
        screenshot("07-Ausgabe", app: app)
        app.buttons["Abbrechen"].firstMatch.tap()
        press("openPurchaseCheck", app: app)
        XCTAssertTrue(app.textFields["Preis in €"].waitForExistence(timeout: 5))
        screenshot("08-Kaufcheck", app: app)
    }
    func testAssistantAndNotifications() {
        let app = launch()
        let assistant = app.buttons["openAssistant"]
        for _ in 0..<5 where !assistant.isHittable { app.swipeUp() }
        press("openAssistant", app: app)
        XCTAssertTrue(app.navigationBars["Budget-Assistent"].waitForExistence(timeout: 5))
        screenshot("09-Assistent", app: app)
        app.buttons["Schließen"].firstMatch.tap()
        for _ in 0..<5 where !app.buttons["openHousehold"].isHittable { app.swipeDown() }
        press("openHousehold", app: app)
        press("openNotifications", app: app)
        XCTAssertTrue(app.navigationBars["Benachrichtigungen"].waitForExistence(timeout: 5))
        screenshot("10-Mitteilungen", app: app)
    }
    func testLargeTextNavigation() {
        let app = launch(large: true)
        screenshot("11-Grosse-Schrift-Uebersicht", app: app)
        press("openHousehold", app: app)
        XCTAssertTrue(app.buttons["household-Einnahmen"].exists)
        screenshot("12-Grosse-Schrift-Haushalt", app: app)
    }
}
