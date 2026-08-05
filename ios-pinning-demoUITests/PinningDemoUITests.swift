import XCTest

// These drive the real app against the real testserver.host, so a failure here means either the
// app is broken or the pins have gone stale (e.g. a CA rotated underneath us). That's deliberate:
// stale pins are the failure mode this demo has hit before, and we want CI to catch it rather
// than a confused user.

final class PinningDemoUITests: XCTestCase {

    // Every button, in the order they appear. Kept in sync with RequestViewModel by hand, and
    // so testAllButtonsArePresent also checks the counts match.
    static let unpinnedButtons = [
        "Plain HTTP",
        "HTTPS",
        "Alamofire HTTPS",
        "AFNetworking HTTPS"
    ]

    static let pinnedButtons = [
        "Config-based pinning",
        "URLSession pinning",
        "Alamofire cert pinning",
        "Alamofire PK pinning",
        "AFNetworking cert pinning",
        "TrustKit pinning"
    ]

    static var allButtons: [String] { unpinnedButtons + pinnedButtons }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["SSL Pinning Demo"].waitForExistence(timeout: 30),
            "App did not launch and render its title"
        )
        return app
    }

    private func scrollTo(_ button: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !button.isHittable && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
    }

    /// The app launches and renders. This is the minimum bar - it passes without network access.
    func testAllButtonsArePresent() throws {
        let app = launch()

        for name in Self.allButtons {
            let button = app.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(name)")
            XCTAssertEqual(button.value as? String, "pending", "\(name) did not start pending")
        }

        XCTAssertEqual(
            app.buttons.count, Self.allButtons.count,
            "The app has buttons this test doesn't know about - add them to the lists above, " +
            "so that they're covered by testAllRequestsSucceed too"
        )
    }

    /// Every request succeeds on an unintercepted device. Pinned buttons only go green if their
    /// pins still match the live certificate chain, so this is what catches CA rotation.
    func testAllRequestsSucceed() throws {
        let app = launch()

        // Start everything first, so the requests run concurrently rather than serially:
        for name in Self.allButtons {
            let button = app.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(name)")
            scrollTo(button, in: app)
            button.tap()
        }

        let succeeded = NSPredicate(format: "value == 'success'")
        let expectations = Self.allButtons.map {
            XCTNSPredicateExpectation(predicate: succeeded, object: app.buttons[$0])
        }
        _ = XCTWaiter().wait(for: expectations, timeout: 60)

        let failures = Self.allButtons
            .map { ($0, app.buttons[$0].value as? String ?? "unknown") }
            .filter { $0.1 != "success" }
            .map { "\($0.0) (ended as: \($0.1))" }

        XCTAssertTrue(
            failures.isEmpty,
            "These requests did not succeed: \(failures.joined(separator: ", ")). " +
            "If the pinned ones failed, check whether the pinned CAs have rotated."
        )
    }
}
