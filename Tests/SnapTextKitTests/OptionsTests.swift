import XCTest

@testable import SnapTextKit

final class OptionsTests: XCTestCase {
    private func parse(_ arguments: String...) throws -> Invocation {
        try CommandLineParser.parse(["snaptext"] + arguments)
    }

    private func options(_ arguments: String...) throws -> Options {
        guard case .run(let options) = try CommandLineParser.parse(["snaptext"] + arguments) else {
            throw XCTSkip("expected a run invocation")
        }
        return options
    }

    func testBarePathIsAFileSource() throws {
        XCTAssertEqual(try options("image.png").source, .file("image.png"))
    }

    func testExplicitFileCommand() throws {
        XCTAssertEqual(try options("file", "image.png").source, .file("image.png"))
    }

    func testSubcommands() throws {
        XCTAssertEqual(try options("clipboard").source, .clipboard)
        XCTAssertEqual(try options("screenshot").source, .fullScreen)
        XCTAssertEqual(try options("region").source, .region)
    }

    func testDefaults() throws {
        let options = try options("image.png")
        XCTAssertEqual(options.recognitionLevel, .accurate)
        XCTAssertTrue(options.usesLanguageCorrection)
        XCTAssertFalse(options.copy)
        XCTAssertFalse(options.json)
        XCTAssertFalse(options.verbose)
        XCTAssertTrue(options.languages.isEmpty)
    }

    func testFlags() throws {
        let options = try options("region", "--copy", "--json", "--fast", "--no-correction", "--verbose")
        XCTAssertEqual(options.source, .region)
        XCTAssertTrue(options.copy)
        XCTAssertTrue(options.json)
        XCTAssertEqual(options.recognitionLevel, .fast)
        XCTAssertFalse(options.usesLanguageCorrection)
        XCTAssertTrue(options.verbose)
    }

    func testLastRecognitionLevelWins() throws {
        XCTAssertEqual(try options("a.png", "--fast", "--accurate").recognitionLevel, .accurate)
    }

    func testRepeatedLanguageFlags() throws {
        XCTAssertEqual(
            try options("a.png", "--language", "en-US", "--language", "bn-BD").languages,
            ["en-US", "bn-BD"]
        )
    }

    func testFlagsMayPrecedeTheSource() throws {
        XCTAssertEqual(try options("--copy", "clipboard").source, .clipboard)
    }

    func testDoubleDashProtectsDashedPaths() throws {
        XCTAssertEqual(try options("--", "-weird-name.png").source, .file("-weird-name.png"))
    }

    func testHelpAndVersion() throws {
        XCTAssertEqual(try parse("--help"), .help)
        XCTAssertEqual(try parse("-h"), .help)
        XCTAssertEqual(try parse("help"), .help)
        XCTAssertEqual(try parse("--version"), .version)
    }

    func testUsageErrors() {
        assertUsageError { _ = try self.parse() }
        assertUsageError { _ = try self.parse("--bogus") }
        assertUsageError { _ = try self.parse("--language") }
        assertUsageError { _ = try self.parse("file") }
        assertUsageError { _ = try self.parse("a.png", "b.png") }
    }

    func testUsageErrorsExitWithCodeTwo() {
        XCTAssertEqual(SnapTextCLI.run(arguments: ["snaptext", "--bogus"]), 2)
    }

    private func assertUsageError(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> Void
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            guard case SnapTextError.usage = error else {
                return XCTFail("expected a usage error, got \(error)", file: file, line: line)
            }
            XCTAssertEqual((error as! SnapTextError).exitCode, 2, file: file, line: line)
        }
    }
}
