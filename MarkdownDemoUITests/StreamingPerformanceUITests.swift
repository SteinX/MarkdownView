import XCTest

final class StreamingPerformanceUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testSecondStreamNotDegraded() {
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5), "Chat tab should exist")
        chatTab.tap()

        let startButton = app.buttons["Start Stream"]
        let stopButton = app.buttons["Stop"]

        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start Stream button should be visible")
        let stream1Start = CFAbsoluteTimeGetCurrent()
        startButton.tap()

        XCTAssertTrue(stopButton.waitForExistence(timeout: 5), "Stop button should appear after tapping Start Stream")

        XCTAssertTrue(startButton.waitForExistence(timeout: 600), "First stream should complete")
        let stream1Duration = CFAbsoluteTimeGetCurrent() - stream1Start

        Thread.sleep(forTimeInterval: 1.0)

        XCTAssertTrue(startButton.exists, "Start Stream button should be ready for second stream")
        let stream2Start = CFAbsoluteTimeGetCurrent()
        startButton.tap()

        XCTAssertTrue(stopButton.waitForExistence(timeout: 5), "Stop button should appear for second stream")
        XCTAssertTrue(startButton.waitForExistence(timeout: 600), "Second stream should complete")
        let stream2Duration = CFAbsoluteTimeGetCurrent() - stream2Start

        let ratio = stream2Duration / stream1Duration
        print("╔══════════════════════════════════════════╗")
        print("║      STREAMING PERFORMANCE COMPARISON     ║")
        print("╠══════════════════════════════════════════╣")
        print("║ Stream 1 duration: \(String(format: "%.2f", stream1Duration))s")
        print("║ Stream 2 duration: \(String(format: "%.2f", stream2Duration))s")
        print("║ Ratio (S2/S1):     \(String(format: "%.2f", ratio))x")
        print("╚══════════════════════════════════════════╝")

        XCTAssertLessThan(
            ratio, 2.0,
            "Second stream (\(String(format: "%.1f", stream2Duration))s) should not be >2x slower than first stream (\(String(format: "%.1f", stream1Duration))s). Ratio: \(String(format: "%.2f", ratio))x"
        )
    }

    func testStreamingCPUMetrics() {
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5))
        chatTab.tap()

        let startButton = app.buttons["Start Stream"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTCPUMetric(application: app), XCTClockMetric()], options: options) {
            startButton.tap()

            let stopButton = app.buttons["Stop"]
            guard stopButton.waitForExistence(timeout: 5) else {
                XCTFail("Stop button did not appear")
                return
            }

            guard startButton.waitForExistence(timeout: 600) else {
                XCTFail("Stream did not complete within timeout")
                return
            }

            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}
