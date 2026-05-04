import XCTest
import CoreLocation
import ImageIO
import UniformTypeIdentifiers
@testable import StoneBC

final class PhotoGeotaggingServiceTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PhotoGeotaggingServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - geotagByTimestamp

    func testGeotagByTimestamp_closestMatch_returnsThatPointsCoordinate() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let track = [
            (coordinate: CLLocationCoordinate2D(latitude: 44.00, longitude: -103.00), timestamp: base),
            (coordinate: CLLocationCoordinate2D(latitude: 44.10, longitude: -103.10), timestamp: base.addingTimeInterval(60)),
            (coordinate: CLLocationCoordinate2D(latitude: 44.20, longitude: -103.20), timestamp: base.addingTimeInterval(120))
        ]

        // Photo taken 5s after the middle point.
        let photo = base.addingTimeInterval(65)
        let coord = PhotoGeotaggingService.geotagByTimestamp(
            photoTimestamp: photo,
            trackWithTimestamps: track
        )

        let middle = try? XCTUnwrap(coord)
        XCTAssertEqual(middle?.latitude ?? 0, 44.10, accuracy: 1e-9)
        XCTAssertEqual(middle?.longitude ?? 0, -103.10, accuracy: 1e-9)
    }

    func testGeotagByTimestamp_outsideMaxDelta_returnsNil() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let track = [
            (coordinate: CLLocationCoordinate2D(latitude: 44.00, longitude: -103.00), timestamp: base)
        ]

        // Photo taken 5 minutes after the only track point (max delta is 120s).
        let photo = base.addingTimeInterval(300)
        let coord = PhotoGeotaggingService.geotagByTimestamp(
            photoTimestamp: photo,
            trackWithTimestamps: track
        )

        XCTAssertNil(coord)
    }

    // MARK: - geotagByInterpolation

    func testGeotagByInterpolation_photoAtMidpoint_returnsMiddleTrackpoint() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(100)
        let trackpoints: [[Double]] = [
            [44.00, -103.00, 1000],
            [44.05, -103.05, 1050],
            [44.10, -103.10, 1100]
        ]

        // Photo at t=50% of window → fraction 0.5 → index = 0.5 * 2 = 1.
        let photo = start.addingTimeInterval(50)
        let coord = PhotoGeotaggingService.geotagByInterpolation(
            photoTimestamp: photo,
            trackpoints: trackpoints,
            trackStartTime: start,
            trackEndTime: end
        )

        let middle = try? XCTUnwrap(coord)
        XCTAssertEqual(middle?.latitude ?? 0, 44.05, accuracy: 1e-9)
        XCTAssertEqual(middle?.longitude ?? 0, -103.05, accuracy: 1e-9)
    }

    func testGeotagByInterpolation_photoOutsideWindow_returnsNil() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(100)
        let trackpoints: [[Double]] = [[44.00, -103.00, 1000], [44.10, -103.10, 1100]]

        // Photo taken 10 minutes before the track started — outside maxDelta of 120s.
        let photo = start.addingTimeInterval(-600)
        let coord = PhotoGeotaggingService.geotagByInterpolation(
            photoTimestamp: photo,
            trackpoints: trackpoints,
            trackStartTime: start,
            trackEndTime: end
        )

        XCTAssertNil(coord)
    }

    // MARK: - extractEXIFCoordinate (round-trip via inline JPEG fixture)

    func testExtractEXIFCoordinate_readsBackGPSWrittenWithImageIO() throws {
        let url = tempDir.appendingPathComponent("with-gps.jpg")

        // Build a 1x1 RGBA image — smallest valid JPEG.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let ctx = try XCTUnwrap(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ))
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let cgImage = try XCTUnwrap(ctx.makeImage())

        // EXIF GPS — service stores latitude/longitude as positive doubles
        // and uses the Ref strings to flip sign. So we write +103.231 with
        // ref = "W" and expect to read back -103.231.
        let gps: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: 44.0805,
            kCGImagePropertyGPSLatitudeRef as String: "N",
            kCGImagePropertyGPSLongitude as String: 103.2310,
            kCGImagePropertyGPSLongitudeRef as String: "W"
        ]
        let metadata: [String: Any] = [
            kCGImagePropertyGPSDictionary as String: gps
        ]

        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(dest, cgImage, metadata as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest), "JPEG fixture must finalize")

        let coord = try XCTUnwrap(PhotoGeotaggingService.extractEXIFCoordinate(from: url))
        XCTAssertEqual(coord.latitude, 44.0805, accuracy: 1e-4)
        XCTAssertEqual(coord.longitude, -103.2310, accuracy: 1e-4)
    }
}
