import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public final class HEICPNGConverter {
    private let fileManager: FileManager
    private let filenameResolver: HEICPNGFilenameResolver

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.filenameResolver = HEICPNGFilenameResolver(fileManager: fileManager)
    }

    public func isSupportedHEICFile(_ url: URL) -> Bool {
        let extensionName = url.pathExtension.lowercased()
        guard !extensionName.isEmpty else {
            return false
        }

        if let type = UTType(filenameExtension: extensionName) {
            return type.conforms(to: .heic) || type.conforms(to: .heif)
        }

        return extensionName == "heic" || extensionName == "heif"
    }

    public func destinationURL(
        for sourceURL: URL,
        destinationDirectory: URL? = nil
    ) throws -> URL {
        let outputDirectory = destinationDirectory ?? sourceURL.deletingLastPathComponent()
        return try filenameResolver.availablePNGURL(for: sourceURL, in: outputDirectory)
    }

    @discardableResult
    public func convert(
        _ sourceURL: URL,
        destinationDirectory: URL? = nil
    ) throws -> HEICPNGConversionResult {
        guard isSupportedHEICFile(sourceURL) else {
            throw HEICPNGConversionError.unsupportedFile(sourceURL)
        }

        let outputURL = try destinationURL(
            for: sourceURL,
            destinationDirectory: destinationDirectory
        )

        let didAccessSource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw HEICPNGConversionError.imageSourceUnavailable(sourceURL)
        }

        guard let decodedImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw HEICPNGConversionError.imageDecodeFailed(sourceURL)
        }

        let orientation = imageOrientation(from: source)
        let renderedImage = try render(decodedImage, orientation: orientation, sourceURL: sourceURL)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw HEICPNGConversionError.outputDestinationFailed(outputURL)
        }

        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue
        ]
        CGImageDestinationAddImage(destination, renderedImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            try? fileManager.removeItem(at: outputURL)
            throw HEICPNGConversionError.outputWriteFailed(outputURL)
        }

        return HEICPNGConversionResult(sourceURL: sourceURL, outputURL: outputURL)
    }

    public func convert(
        urls: [URL],
        destinationDirectory: URL? = nil
    ) -> HEICPNGBatchResult {
        var converted: [HEICPNGConversionResult] = []
        var failures: [HEICPNGConversionFailure] = []

        for url in urls {
            do {
                let result = try convert(url, destinationDirectory: destinationDirectory)
                converted.append(result)
            } catch {
                failures.append(
                    HEICPNGConversionFailure(
                        sourceURL: url,
                        message: error.localizedDescription
                    )
                )
            }
        }

        return HEICPNGBatchResult(converted: converted, failures: failures)
    }

    private func imageOrientation(from source: CGImageSource) -> CGImagePropertyOrientation {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32
        return rawOrientation.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
    }

    private func render(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation,
        sourceURL: URL
    ) throws -> CGImage {
        guard orientation != .up else {
            return image
        }

        let sourceWidth = image.width
        let sourceHeight = image.height
        let swapsAxes = orientation == .left ||
            orientation == .leftMirrored ||
            orientation == .right ||
            orientation == .rightMirrored

        let outputWidth = swapsAxes ? sourceHeight : sourceWidth
        let outputHeight = swapsAxes ? sourceWidth : sourceHeight
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw HEICPNGConversionError.bitmapContextFailed(sourceURL)
        }

        context.interpolationQuality = .high
        context.concatenate(transform(
            for: orientation,
            sourceWidth: CGFloat(sourceWidth),
            sourceHeight: CGFloat(sourceHeight)
        ))

        let drawRect: CGRect
        if swapsAxes {
            drawRect = CGRect(x: 0, y: 0, width: sourceHeight, height: sourceWidth)
        } else {
            drawRect = CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight)
        }
        context.draw(image, in: drawRect)

        guard let renderedImage = context.makeImage() else {
            throw HEICPNGConversionError.bitmapContextFailed(sourceURL)
        }

        return renderedImage
    }

    private func transform(
        for orientation: CGImagePropertyOrientation,
        sourceWidth: CGFloat,
        sourceHeight: CGFloat
    ) -> CGAffineTransform {
        switch orientation {
        case .up:
            return .identity
        case .upMirrored:
            return CGAffineTransform(translationX: sourceWidth, y: 0).scaledBy(x: -1, y: 1)
        case .down:
            return CGAffineTransform(translationX: sourceWidth, y: sourceHeight).rotated(by: .pi)
        case .downMirrored:
            return CGAffineTransform(translationX: 0, y: sourceHeight).scaledBy(x: 1, y: -1)
        case .left:
            return CGAffineTransform(translationX: 0, y: sourceWidth).rotated(by: -.pi / 2)
        case .leftMirrored:
            return CGAffineTransform(translationX: sourceHeight, y: sourceWidth)
                .scaledBy(x: -1, y: 1)
                .rotated(by: -.pi / 2)
        case .right:
            return CGAffineTransform(translationX: sourceHeight, y: 0).rotated(by: .pi / 2)
        case .rightMirrored:
            return CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2)
        }
    }
}

