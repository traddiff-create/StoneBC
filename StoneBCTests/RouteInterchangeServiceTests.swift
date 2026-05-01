import XCTest
@testable import StoneBC

final class RouteInterchangeServiceTests: XCTestCase {

    // MARK: - Happy path

    func testImportData_validGPX_returnsOneCandidate_withExpectedTrackpoints() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StoneBCTests"
             xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>Inline Test Route</name></metadata>
          <trk>
            <name>Inline Test Route</name>
            <trkseg>
              <trkpt lat="44.0805" lon="-103.2310"><ele>1000</ele></trkpt>
              <trkpt lat="44.0900" lon="-103.2400"><ele>1100</ele></trkpt>
              <trkpt lat="44.1000" lon="-103.2500"><ele>1200</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """

        let candidates = try RouteInterchangeService.importData(
            Data(gpx.utf8),
            filename: "inline.gpx"
        )

        XCTAssertEqual(candidates.count, 1)
        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidate.name, "Inline Test Route")
        XCTAssertEqual(candidate.trackpoints.count, 3)
        XCTAssertEqual(candidate.sourceFormat, .gpx)
        XCTAssertEqual(candidate.sourceFilename, "inline.gpx")
    }

    // MARK: - Error paths

    func testImportData_emptyData_throwsEmptyFile() {
        XCTAssertThrowsError(try RouteInterchangeService.importData(Data(), filename: "empty.gpx")) { error in
            guard case RouteInterchangeError.emptyFile = error else {
                return XCTFail("expected .emptyFile, got \(error)")
            }
        }
    }

    func testImportData_malformedGPX_throwsInvalidFormat_doesNotCrash() {
        // Truncated XML — no closing tags
        let malformed = "<?xml version=\"1.0\"?><gpx><trk><trkseg><trkpt lat=\"44\" lon=\"-103\""
        XCTAssertThrowsError(try RouteInterchangeService.importData(Data(malformed.utf8), filename: "broken.gpx")) { error in
            guard case RouteInterchangeError.invalidFormat = error else {
                return XCTFail("expected .invalidFormat, got \(error)")
            }
        }
    }

    func testImportData_gpxWithNoTrackpoints_throwsNoTrackpoints() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>Empty Track</name></metadata>
          <trk><name>Empty Track</name><trkseg></trkseg></trk>
        </gpx>
        """

        XCTAssertThrowsError(try RouteInterchangeService.importData(Data(gpx.utf8), filename: "no-trkpt.gpx")) { error in
            guard case RouteInterchangeError.noTrackpoints = error else {
                return XCTFail("expected .noTrackpoints, got \(error)")
            }
        }
    }

    func testImportData_unsupportedExtension_throwsUnsupportedFormat() {
        let txt = "this is not a route file"
        XCTAssertThrowsError(try RouteInterchangeService.importData(Data(txt.utf8), filename: "notes.txt")) { error in
            guard case RouteInterchangeError.unsupportedFormat = error else {
                return XCTFail("expected .unsupportedFormat, got \(error)")
            }
        }
    }

    // MARK: - Batch behavior

    func testImportFiles_mixedGoodAndBad_returnsOneCandidateAndOneFailure() throws {
        let good = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><name>Good</name><trkseg>
            <trkpt lat="44.08" lon="-103.23"><ele>1000</ele></trkpt>
            <trkpt lat="44.09" lon="-103.24"><ele>1100</ele></trkpt>
          </trkseg></trk>
        </gpx>
        """

        let goodURL = try writeTemp(named: "good.gpx", contents: good)
        let badURL = try writeTemp(named: "empty.gpx", contents: "")
        defer {
            try? FileManager.default.removeItem(at: goodURL)
            try? FileManager.default.removeItem(at: badURL)
        }

        let batch = RouteInterchangeService.importFiles([goodURL, badURL])

        XCTAssertEqual(batch.candidates.count, 1)
        XCTAssertEqual(batch.candidates.first?.name, "Good")
        XCTAssertEqual(batch.failures.count, 1)
        XCTAssertEqual(batch.failures.first?.filename, "empty.gpx")
    }

    // MARK: - Helpers

    private func writeTemp(named filename: String, contents: String) throws -> URL {
        // Put each file inside a unique subdir so the leaf filename
        // (and therefore url.lastPathComponent) stays exactly what the
        // caller asked for.
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RouteInterchangeServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)
        try Data(contents.utf8).write(to: url)
        return url
    }
}
