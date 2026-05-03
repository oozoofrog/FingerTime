//
//  FingerTimeUITests.swift
//  FingerTimeUITests
//
//  Created by oozoofrog on 5/3/26.
//

import XCTest

final class FingerTimeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testCenterFacePhotoDialogOpens() throws {
        let app = XCUIApplication()
        app.launch()

        let centerPhotoButton = app.buttons["중앙 얼굴 사진 선택"]
        XCTAssertTrue(centerPhotoButton.waitForExistence(timeout: 8), "중앙 얼굴 사진 버튼이 보여야 합니다.")
        centerPhotoButton.tap()

        let photoLibraryButton = app.buttons["사진 보관함에서 선택"]
        XCTAssertTrue(photoLibraryButton.waitForExistence(timeout: 5), "사진 선택 액션 시트가 떠야 합니다.")
        XCTAssertTrue(
            app.buttons["카메라로 찍기"].exists || app.buttons["카메라 사용 불가"].exists,
            "카메라 선택지 또는 사용 불가 선택지가 함께 보여야 합니다."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
