import AppKit
import Foundation
import HEICPNGCore
import UniformTypeIdentifiers

final class FinderActionRequestHandler: NSObject, NSExtensionRequestHandling, @unchecked Sendable {
    private let converter = HEICPNGConverter()

    func beginRequest(with context: NSExtensionContext) {
        let contextBox = SendableBox(context)
        let converter = converter

        Task {
            let context = contextBox.value
            let urls = await Self.fileURLs(from: context.inputItems)
            let batch = converter.convert(urls: urls)

            if batch.didConvertAnything {
                NSWorkspace.shared.activateFileViewerSelecting(batch.converted.map(\.outputURL))
            }

            let response = NSExtensionItem()
            response.attributedTitle = NSAttributedString(string: "Convert HEIC to PNG")
            response.attributedContentText = NSAttributedString(string: Self.summary(for: batch))

            context.completeRequest(returningItems: [response], completionHandler: nil)
        }
    }

    private static func summary(for batch: HEICPNGBatchResult) -> String {
        if batch.converted.isEmpty && batch.failures.isEmpty {
            return "No HEIC or HEIF files were selected."
        }

        let convertedText = batch.converted.isEmpty ? nil : "\(batch.converted.count) converted"
        let failureText = batch.failures.isEmpty ? nil : "\(batch.failures.count) failed"
        return [convertedText, failureText].compactMap { $0 }.joined(separator: ", ")
    }

    private static func fileURLs(from inputItems: [Any]) async -> [URL] {
        var urls: [URL] = []

        for item in inputItems {
            guard let extensionItem = item as? NSExtensionItem,
                  let attachments = extensionItem.attachments else {
                continue
            }

            for provider in attachments {
                if let url = await provider.fileURL() {
                    urls.append(url)
                }
            }
        }

        return urls
    }
}

private final class SendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private extension NSItemProvider {
    func fileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            if hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else if let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}
