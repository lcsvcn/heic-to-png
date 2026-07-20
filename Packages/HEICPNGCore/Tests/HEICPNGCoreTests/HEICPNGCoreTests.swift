import CoreGraphics
import Foundation
import HEICPNGCore
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class HEICPNGCoreTests: XCTestCase {
    func testTypeDetectionHandlesHEICAndHEIFCaseInsensitively() {
        let converter = HEICPNGConverter()

        XCTAssertTrue(converter.isSupportedHEICFile(URL(fileURLWithPath: "/tmp/IMG_0001.HEIC")))
        XCTAssertTrue(converter.isSupportedHEICFile(URL(fileURLWithPath: "/tmp/IMG_0002.heif")))
        XCTAssertFalse(converter.isSupportedHEICFile(URL(fileURLWithPath: "/tmp/IMG_0003.jpg")))
    }

    func testDestinationURLUsesNumericSuffixesWithoutOverwriting() throws {
        let directory = try makeTemporaryDirectory()
        let converter = HEICPNGConverter()
        let sourceURL = directory.appendingPathComponent("Vacation.HEIC")

        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("Vacation.png").path,
            contents: Data()
        )
        FileManager.default.createFile(
            atPath: directory.appendingPathComponent("Vacation 2.png").path,
            contents: Data()
        )

        let outputURL = try converter.destinationURL(for: sourceURL)

        XCTAssertEqual(outputURL.lastPathComponent, "Vacation 3.png")
    }

    func testBatchConversionReportsUnsupportedFiles() {
        let converter = HEICPNGConverter()
        let url = URL(fileURLWithPath: "/tmp/not-an-image.txt")

        let result = converter.convert(urls: [url])

        XCTAssertTrue(result.converted.isEmpty)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.failures[0].message.contains("not a HEIC or HEIF"))
    }

    func testConvertsGeneratedHEICToPNGWhenSystemEncoderIsAvailable() throws {
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Sample.heic")
        let wroteHEIC = try writeTinyHEIC(to: sourceURL)

        guard wroteHEIC else {
            throw XCTSkip("HEIC encoding is not available on this system.")
        }

        let result = try HEICPNGConverter().convert(sourceURL)
        XCTAssertEqual(result.outputURL.pathExtension.lowercased(), "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))

        guard let imageSource = CGImageSourceCreateWithURL(result.outputURL as CFURL, nil),
              let outputType = CGImageSourceGetType(imageSource) else {
            XCTFail("Expected converted PNG to be readable by ImageIO.")
            return
        }

        XCTAssertEqual(outputType as String, UTType.png.identifier)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HEICPNGCoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeTinyHEIC(to url: URL) throws -> Bool {
        guard let image = makeTinyImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.heic.identifier as CFString,
                1,
                nil
              ) else {
            return false
        }

        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    private func makeTinyImage() -> CGImage? {
        let bytes: [UInt8] = [
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 255, 255
        ]
        let data = Data(bytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

