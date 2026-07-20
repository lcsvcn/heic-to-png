import Foundation
import HEICPNGCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class IOSConversionViewModel: ObservableObject {
    @Published var converted: [HEICPNGConversionResult] = []
    @Published var failures: [HEICPNGConversionFailure] = []
    @Published var isConverting = false
    @Published var shareURLs: [URL] = []

    private let converter = HEICPNGConverter()

    var statusText: String {
        if isConverting {
            return "Converting..."
        }

        if converted.isEmpty && failures.isEmpty {
            return "Ready"
        }

        let successText = converted.isEmpty ? nil : "\(converted.count) converted"
        let failureText = failures.isEmpty ? nil : "\(failures.count) failed"
        return [successText, failureText].compactMap { $0 }.joined(separator: ", ")
    }

    func convert(urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        isConverting = true
        converted = []
        failures = []

        Task.detached { [converter] in
            let destinationDirectory = try? Self.convertedDirectory()
            let batch = converter.convert(
                urls: urls,
                destinationDirectory: destinationDirectory
            )

            await MainActor.run {
                self.converted = batch.converted
                self.failures = batch.failures
                self.isConverting = false
            }
        }
    }

    func copyConvertedImages() {
        let items = converted.compactMap { result -> [String: Any]? in
            guard let data = try? Data(contentsOf: result.outputURL) else {
                return nil
            }
            return [UTType.png.identifier: data]
        }

        guard !items.isEmpty else {
            return
        }

        UIPasteboard.general.items = items
    }

    func shareConvertedImages() {
        shareURLs = converted.map(\.outputURL)
    }

    private static func convertedDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents.appendingPathComponent("Converted", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

