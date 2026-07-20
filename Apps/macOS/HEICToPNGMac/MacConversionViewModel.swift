import AppKit
import Foundation
import HEICPNGCore
import UniformTypeIdentifiers

@MainActor
final class MacConversionViewModel: ObservableObject {
    @Published var converted: [HEICPNGConversionResult] = []
    @Published var failures: [HEICPNGConversionFailure] = []
    @Published var isConverting = false
    @Published var finderQuickActionEnabled: Bool {
        didSet {
            MacConversionPreferences.finderQuickActionEnabled = finderQuickActionEnabled
        }
    }
    @Published var autoRevealConvertedFiles: Bool {
        didSet {
            MacConversionPreferences.autoRevealConvertedFiles = autoRevealConvertedFiles
        }
    }
    @Published var autoCopyConvertedFiles: Bool {
        didSet {
            MacConversionPreferences.autoCopyConvertedFiles = autoCopyConvertedFiles
        }
    }

    private let converter = HEICPNGConverter()

    init() {
        finderQuickActionEnabled = MacConversionPreferences.finderQuickActionEnabled
        autoRevealConvertedFiles = MacConversionPreferences.autoRevealConvertedFiles
        autoCopyConvertedFiles = MacConversionPreferences.autoCopyConvertedFiles
    }

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
        let shouldReveal = autoRevealConvertedFiles
        let shouldCopy = autoCopyConvertedFiles

        Task.detached { [converter] in
            let batch = converter.convert(urls: urls)
            let outputURLs = batch.converted.map(\.outputURL)

            await MainActor.run {
                self.converted = batch.converted
                self.failures = batch.failures
                self.isConverting = false

                if batch.didConvertAnything && shouldCopy {
                    self.copyFilesToPasteboard(outputURLs)
                }

                if batch.didConvertAnything && shouldReveal {
                    NSWorkspace.shared.activateFileViewerSelecting(outputURLs)
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

    func openExtensionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func copyFilesToPasteboard(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }
}
