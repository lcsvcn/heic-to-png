import Foundation

public struct HEICPNGConversionResult: Equatable, Sendable {
    public let sourceURL: URL
    public let outputURL: URL

    public init(sourceURL: URL, outputURL: URL) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
    }
}

public struct HEICPNGConversionFailure: Equatable, Sendable {
    public let sourceURL: URL
    public let message: String

    public init(sourceURL: URL, message: String) {
        self.sourceURL = sourceURL
        self.message = message
    }
}

public struct HEICPNGBatchResult: Equatable, Sendable {
    public let converted: [HEICPNGConversionResult]
    public let failures: [HEICPNGConversionFailure]

    public init(
        converted: [HEICPNGConversionResult],
        failures: [HEICPNGConversionFailure]
    ) {
        self.converted = converted
        self.failures = failures
    }

    public var didConvertAnything: Bool {
        !converted.isEmpty
    }

    public var hasFailures: Bool {
        !failures.isEmpty
    }
}

public enum HEICPNGConversionError: Error, Equatable, Sendable {
    case unsupportedFile(URL)
    case imageSourceUnavailable(URL)
    case imageDecodeFailed(URL)
    case bitmapContextFailed(URL)
    case outputDestinationFailed(URL)
    case outputWriteFailed(URL)
    case destinationDirectoryMissing(URL)
    case filenameCollisionExhausted(URL)
}

extension HEICPNGConversionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "\(url.lastPathComponent) is not a HEIC or HEIF image."
        case .imageSourceUnavailable(let url):
            return "Could not open \(url.lastPathComponent)."
        case .imageDecodeFailed(let url):
            return "Could not read image data from \(url.lastPathComponent)."
        case .bitmapContextFailed(let url):
            return "Could not prepare \(url.lastPathComponent) for PNG export."
        case .outputDestinationFailed(let url):
            return "Could not create an output file for \(url.lastPathComponent)."
        case .outputWriteFailed(let url):
            return "Could not save \(url.lastPathComponent)."
        case .destinationDirectoryMissing(let url):
            return "The destination folder does not exist: \(url.path)"
        case .filenameCollisionExhausted(let url):
            return "Could not find an available PNG filename near \(url.lastPathComponent)."
        }
    }
}
