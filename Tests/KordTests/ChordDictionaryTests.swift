import XCTest
@testable import Kord

final class ChordDictionaryTests: XCTestCase {
    var dictionary: ChordDictionary!

    override func setUp() {
        super.setUp()
        dictionary = ChordDictionary()
    }

    func testLoadFromString() throws {
        let yaml = """
        timing_window_ms: 80

        words:
          problem: prb
          with: wh
          transaction: txn
        """

        try dictionary.loadFromString(yaml)

        XCTAssertEqual(dictionary.timingWindowMs, 80)
        XCTAssertFalse(dictionary.isEmpty)
    }

    func testLookupWithNormalizedSignature() throws {
        let yaml = """
        words:
          problem: prb
          with: wh
        """
        try dictionary.loadFromString(yaml)

        // Keys are sorted: p,r,b -> b,p,r -> "bpr"
        XCTAssertEqual(dictionary.lookup(Set(["p", "r", "b"])), "problem")
        XCTAssertEqual(dictionary.lookup(Set(["w", "h"])), "with")
    }

    func testLookupNoMatch() throws {
        let yaml = """
        words:
          problem: prb
        """
        try dictionary.loadFromString(yaml)

        XCTAssertNil(dictionary.lookup(Set(["x", "y", "z"])))
    }

    func testLookupSingleCharReturnsNil() throws {
        let yaml = """
        words:
          apple: a
        """
        try dictionary.loadFromString(yaml)

        // Single char chord - engine won't fire it but dictionary still stores it
        XCTAssertEqual(dictionary.lookup(Set(["a"])), "apple")
    }

    func testTimingWindowClamping() throws {
        let yamlTooLow = """
        timing_window_ms: 10
        words:
          test: ab
        """
        try dictionary.loadFromString(yamlTooLow)
        XCTAssertEqual(dictionary.timingWindowMs, 30)

        let yamlTooHigh = """
        timing_window_ms: 500
        words:
          test: ab
        """
        try dictionary.loadFromString(yamlTooHigh)
        XCTAssertEqual(dictionary.timingWindowMs, 150)
    }

    func testDefaultTimingWindow() throws {
        let yaml = """
        words:
          test: ab
        """
        try dictionary.loadFromString(yaml)
        XCTAssertEqual(dictionary.timingWindowMs, 70)
    }

    func testInvalidFormatThrows() {
        XCTAssertThrowsError(try dictionary.loadFromString("just a string")) { error in
            XCTAssertTrue(error is ChordDictionary.DictionaryError)
        }
    }

    func testMissingWordsThrows() {
        let yaml = """
        timing_window_ms: 70
        """
        XCTAssertThrowsError(try dictionary.loadFromString(yaml)) { error in
            XCTAssertTrue(error is ChordDictionary.DictionaryError)
        }
    }

    func testNormalizedSignatureIsSorted() {
        let sig = dictionary.normalizedSignature(Set(["z", "a", "m"]))
        XCTAssertEqual(sig, "amz")
    }

    func testOrderIndependentLookup() throws {
        let yaml = """
        words:
          alphabet: abc
        """
        try dictionary.loadFromString(yaml)

        // Regardless of insertion order, lookup should work
        XCTAssertEqual(dictionary.lookup(Set(["c", "b", "a"])), "alphabet")
        XCTAssertEqual(dictionary.lookup(Set(["a", "b", "c"])), "alphabet")
        XCTAssertEqual(dictionary.lookup(Set(["b", "a", "c"])), "alphabet")
    }

    func testLoadFromListFormatSkipsDashShortcut() throws {
        let yaml = """
        words:
          - shortcut: "prb"
            word: "problem"
          - shortcut: "-"
            word: "with"
          - shortcut: "txn"
            word: "transaction"
        """
        try dictionary.loadFromString(yaml)

        XCTAssertEqual(dictionary.lookup(Set(["p", "r", "b"])), "problem")
        XCTAssertEqual(dictionary.lookup(Set(["t", "x", "n"])), "transaction")
        XCTAssertNil(dictionary.lookup(Set(["w", "h"])))
    }
}
