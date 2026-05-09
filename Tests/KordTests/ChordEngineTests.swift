import XCTest
import CoreGraphics
@testable import Kord

final class ChordEngineTests: XCTestCase {
    var dictionary: ChordDictionary!
    var engine: ChordEngine!
    var delegate: MockEngineDelegate!

    override func setUp() {
        super.setUp()
        dictionary = ChordDictionary()
        try! dictionary.loadFromString("""
        timing_window_ms: 70
        words:
          problem: prb
          with: wh
          the: th
        """)
        engine = ChordEngine(dictionary: dictionary)
        delegate = MockEngineDelegate()
        engine.delegate = delegate
    }

    override func tearDown() {
        engine.reset()
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(engine.state, .idle)
    }

    func testFirstChordableKeyDownTransitionsToCollecting() {
        let event = makeKeyEvent(keyCode: 35, char: "p", type: .keyDown)
        let consumed = engine.handleKeyEvent(event)

        XCTAssertTrue(consumed)
        XCTAssertEqual(engine.state, .collecting)
    }

    func testNonChordableKeyPassesThrough() {
        // 'z' is not in any chord entry
        let event = makeKeyEvent(keyCode: 6, char: "z", type: .keyDown)
        let consumed = engine.handleKeyEvent(event)

        XCTAssertFalse(consumed)
        XCTAssertEqual(engine.state, .idle)
    }

    func testSecondKeyDownStaysCollecting() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))
        let consumed = engine.handleKeyEvent(makeKeyEvent(keyCode: 15, char: "r", type: .keyDown))

        XCTAssertTrue(consumed)
        XCTAssertEqual(engine.state, .collecting)
    }

    func testKeyUpIsIgnored() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))
        let consumed = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyUp))

        XCTAssertFalse(consumed)
    }

    func testTimerCommitsChord() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 15, char: "r", type: .keyDown))
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 11, char: "b", type: .keyDown))

        let expectation = XCTestExpectation(description: "chord recognized")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(delegate.recognizedExpansion, "problem")
    }

    func testTimerReplaysSingleKey() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))

        let expectation = XCTestExpectation(description: "single key replayed")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(delegate.recognizedExpansion)
        XCTAssertEqual(delegate.failedKeys?.count, 1)
    }

    func testTimerReplaysUnrecognizedChord() {
        // x and y are not chordable, but p and t are
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 17, char: "t", type: .keyDown))
        // "pt" is not in dictionary

        let expectation = XCTestExpectation(description: "unrecognized chord replayed")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(delegate.recognizedExpansion)
        XCTAssertEqual(delegate.failedKeys?.count, 2)
    }

    func testModifierKeyPassesThrough() {
        let event = makeKeyEvent(keyCode: 55, char: nil, type: .keyDown, isModifier: true)
        let consumed = engine.handleKeyEvent(event)

        XCTAssertFalse(consumed)
        XCTAssertEqual(engine.state, .idle)
    }

    func testModifierDuringCollectingCancels() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))

        let modEvent = makeKeyEvent(keyCode: 55, char: nil, type: .keyDown, isModifier: true)
        let consumed = engine.handleKeyEvent(modEvent)

        XCTAssertFalse(consumed)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNotNil(delegate.failedKeys)
    }

    func testThreeKeyChord() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 15, char: "r", type: .keyDown))
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 11, char: "b", type: .keyDown))

        let expectation = XCTestExpectation(description: "3-key chord recognized")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(delegate.recognizedExpansion, "problem")
    }

    func testEventWithCommandModifierPassesThrough() {
        let event = makeKeyEvent(keyCode: 35, char: "p", type: .keyDown, flags: .maskCommand)
        let consumed = engine.handleKeyEvent(event)

        XCTAssertFalse(consumed)
        XCTAssertEqual(engine.state, .idle)
    }

    func testResetClearsState() {
        _ = engine.handleKeyEvent(makeKeyEvent(keyCode: 35, char: "p", type: .keyDown))
        XCTAssertEqual(engine.state, .collecting)

        engine.reset()
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - Helpers

    private func makeKeyEvent(
        keyCode: Int64,
        char: String?,
        type: KeyEvent.EventType,
        isModifier: Bool = false,
        flags: CGEventFlags = []
    ) -> KeyEvent {
        var actualFlags = flags
        if isModifier {
            switch keyCode {
            case 54, 55: actualFlags.insert(.maskCommand)
            case 56, 60: actualFlags.insert(.maskShift)
            case 58, 61: actualFlags.insert(.maskAlternate)
            case 59, 62: actualFlags.insert(.maskControl)
            default: break
            }
        }

        return KeyEvent(
            keyCode: keyCode,
            character: char,
            type: type,
            timestamp: mach_absolute_time(),
            flags: actualFlags
        )
    }
}

// MARK: - Mock

final class MockEngineDelegate: ChordEngineDelegate {
    var recognizedExpansion: String?
    var failedKeys: [BufferedKey]?
    var didRequestDeleteWordBackward = false

    func chordEngine(_ engine: ChordEngine, didRecognizeChord expansion: String) {
        recognizedExpansion = expansion
    }

    func chordEngineDidRequestDeleteWordBackward(_ engine: ChordEngine) {
        didRequestDeleteWordBackward = true
    }

    func chordEngine(_ engine: ChordEngine, didFailWithKeys keys: [BufferedKey]) {
        failedKeys = keys
    }
}
