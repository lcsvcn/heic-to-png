import CoreGraphics
import Foundation
import HEICPNGCore
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class HEICPNGCoreTests: XCTestCase {
    private enum ImageInspectionError: Error {
        case decodeFailed(URL)
        case contextFailed(URL)
        case metadataFailed(URL)
    }

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
        let wroteHEIC = try writeHEIC(to: sourceURL, image: makeTinyImage())

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

    func testConvertsHEICWithTransparencyToPNGPreservingAlphaWhenSystemEncoderSupportsAlpha() throws {
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Transparent.heic")
        let wroteHEICWithAlpha = try writeTransparentHEIC(to: sourceURL)

        guard wroteHEICWithAlpha else {
            throw XCTSkip("HEIC alpha encoding is not available on this system.")
        }

        let result = try HEICPNGConverter().convert(sourceURL)
        let alphaValues = try pixelAlphaValues(in: result.outputURL)

        XCTAssertTrue(
            alphaValues.contains { $0 <= 8 },
            "Expected the PNG to retain at least one transparent pixel. Alpha values: \(alphaValues)"
        )
        XCTAssertTrue(
            alphaValues.contains { (96...192).contains($0) },
            "Expected the PNG to retain at least one partially transparent pixel. Alpha values: \(alphaValues)"
        )
        XCTAssertTrue(
            alphaValues.contains { $0 >= 240 },
            "Expected the PNG to retain at least one opaque pixel. Alpha values: \(alphaValues)"
        )
    }

    func testConvertsOrientedHEICToUprightPNG() throws {
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Rotated.heic")
        let wroteHEIC = try writeHEIC(
            to: sourceURL,
            image: makeWideMarkerImage(),
            properties: [
                kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue
            ]
        )

        guard wroteHEIC else {
            throw XCTSkip("HEIC encoding is not available on this system.")
        }

        let result = try HEICPNGConverter().convert(sourceURL)
        let outputMetadata = try imageMetadata(at: result.outputURL)

        XCTAssertEqual(outputMetadata.width, 3)
        XCTAssertEqual(outputMetadata.height, 2)
        XCTAssertEqual(outputMetadata.orientation, .up)
    }

    func testBatchConversionContinuesAfterCorruptHEIC() throws {
        let directory = try makeTemporaryDirectory()
        let validURL = directory.appendingPathComponent("Valid.heic")
        let corruptURL = directory.appendingPathComponent("Broken.heic")
        let wroteHEIC = try writeHEIC(to: validURL, image: makeTinyImage())

        guard wroteHEIC else {
            throw XCTSkip("HEIC encoding is not available on this system.")
        }

        try Data("not really an image".utf8).write(to: corruptURL)

        let result = HEICPNGConverter().convert(urls: [corruptURL, validURL])

        XCTAssertEqual(result.converted.count, 1)
        XCTAssertEqual(result.converted[0].sourceURL, validURL)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures[0].sourceURL, corruptURL)
        XCTAssertTrue(
            result.failures[0].message.contains("Could not open") ||
                result.failures[0].message.contains("Could not read image data")
        )
    }

    func testMissingDestinationDirectoryThrowsUserFriendlyError() throws {
        let directory = try makeTemporaryDirectory()
        let sourceURL = directory.appendingPathComponent("Sample.heic")
        let missingDirectory = directory.appendingPathComponent("Missing")

        XCTAssertThrowsError(
            try HEICPNGConverter().destinationURL(
                for: sourceURL,
                destinationDirectory: missingDirectory
            )
        ) { error in
            XCTAssertEqual(
                error as? HEICPNGConversionError,
                .destinationDirectoryMissing(missingDirectory)
            )
            XCTAssertTrue(error.localizedDescription.contains("destination folder does not exist"))
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HEICPNGCoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeHEIC(
        to url: URL,
        image: CGImage?,
        properties: [CFString: Any] = [:]
    ) throws -> Bool {
        guard let image,
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.heic.identifier as CFString,
                1,
                nil
              ) else {
            return false
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private func writeTransparentHEIC(to url: URL) throws -> Bool {
        guard try writeHEIC(to: url, image: makeAlphaImage()) else {
            return false
        }

        guard let alphaValues = try? pixelAlphaValues(in: url) else {
            return false
        }

        return alphaValues.contains { $0 <= 8 } &&
            alphaValues.contains { (96...192).contains($0) } &&
            alphaValues.contains { $0 >= 240 }
    }

    private func makeTinyImage() -> CGImage? {
        makeImage(
            width: 2,
            height: 2,
            pixels: [
                255, 0, 0, 255,
                0, 255, 0, 255,
                0, 0, 255, 255,
                255, 255, 255, 255
            ]
        )
    }

    private func makeAlphaImage() -> CGImage? {
        makeImage(
            width: 2,
            height: 2,
            pixels: [
                0, 0, 0, 0,
                128, 0, 0, 128,
                0, 255, 0, 255,
                0, 0, 255, 255
            ]
        )
    }

    private func makeWideMarkerImage() -> CGImage? {
        makeImage(
            width: 2,
            height: 3,
            pixels: [
                255, 0, 0, 255,
                0, 255, 0, 255,
                0, 0, 255, 255,
                255, 255, 0, 255,
                255, 0, 255, 255,
                0, 255, 255, 255
            ]
        )
    }

    private func makeImage(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        let data = Data(pixels)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder32Big.rawValue |
                    CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func pixelAlphaValues(in url: URL) throws -> [UInt8] {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImageInspectionError.decodeFailed(url)
        }

        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue |
                CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageInspectionError.contextFailed(url)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
    }

    private func imageMetadata(at url: URL) throws -> (width: Int, height: Int, orientation: CGImagePropertyOrientation) {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw ImageInspectionError.metadataFailed(url)
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let rawOrientation = properties[kCGImagePropertyOrientation] as? UInt32
        let orientation = rawOrientation.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
        return (width, height, orientation)
    }
}
