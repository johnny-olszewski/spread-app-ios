//
//  SpreadUITestsLaunchTests.swift
//  SpreadUITests
//
//  Created by Johnny O on 1/6/26.
//

import XCTest

final class SpreadUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Conditions: Launch the app and capture a launch screenshot.
    /// Expected: App launches and a screenshot attachment is recorded.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
