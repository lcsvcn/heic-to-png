import Foundation

public struct HEICPNGFilenameResolver {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func availablePNGURL(
        for sourceURL: URL,
        in destinationDirectory: URL
    ) throws -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw HEICPNGConversionError.destinationDirectoryMissing(destinationDirectory)
        }

        let baseName = sanitizedBaseName(from: sourceURL)
        let firstCandidate = destinationDirectory.appendingPathComponent(baseName).appendingPathExtension("png")
        if !fileManager.fileExists(atPath: firstCandidate.path) {
            return firstCandidate
        }

        for index in 2...9999 {
            let candidate = destinationDirectory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension("png")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw HEICPNGConversionError.filenameCollisionExhausted(firstCandidate)
    }

    private func sanitizedBaseName(from sourceURL: URL) -> String {
        let rawName = sourceURL.deletingPathExtension().lastPathComponent
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "image" : trimmedName
    }
}

