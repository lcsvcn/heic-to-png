import AppKit
import Foundation
import HEICPNGCore
import UniformTypeIdentifiers

@MainActor
final class MacConversionViewModel: ObservableObject {
    @Published var converted: [HEICPNGConversionResult] = []
    @Published var failures: [HEICPNGConversionFailure] = []
    @Published var isConverting = false

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

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.heic, .heif]
        panel.prompt = "Convert"

        guard panel.runModal() == .OK else {
            return
        }

        convert(urls: panel.urls)
    }

    func convert(urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        isConverting = true
        converted = []
        failures = []

        Task.detached { [converter] in
            let batch = converter.convert(urls: urls)
            await MainActor.run {
                self.converted = batch.converted
                self.failures = batch.failures
                self.isConverting = false

                if batch.didConvertAnything {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        batch.converted.map(\.outputURL)
                    )
                }
            }
        }
    }

    func copyConvertedFiles() {
        let urls = converted.map(\.outputURL)
        guard !urls.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    func revealConvertedFiles() {
        let urls = converted.map(\.outputURL)
        guard !urls.isEmpty else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

