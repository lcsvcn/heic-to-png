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
    @Published var autoConvertNewHEICFiles: Bool {
        didSet {
            MacConversionPreferences.autoConvertNewHEICFiles = autoConvertNewHEICFiles
            updateAutoWatcher()
        }
    }
    @Published var autoWatchDownloadsFolder: Bool {
        didSet {
            MacConversionPreferences.autoWatchDownloadsFolder = autoWatchDownloadsFolder
            updateAutoWatcher()
        }
    }
    @Published var autoWatchDesktopFolder: Bool {
        didSet {
            MacConversionPreferences.autoWatchDesktopFolder = autoWatchDesktopFolder
            updateAutoWatcher()
        }
    }
    @Published private(set) var customWatchedFolderNames: [String] = []

    private let converter = HEICPNGConverter()
    private let autoWatcher = MacAutoConversionWatcher()

    init() {
        finderQuickActionEnabled = MacConversionPreferences.finderQuickActionEnabled
        autoRevealConvertedFiles = MacConversionPreferences.autoRevealConvertedFiles
        autoCopyConvertedFiles = MacConversionPreferences.autoCopyConvertedFiles
        autoConvertNewHEICFiles = MacConversionPreferences.autoConvertNewHEICFiles
        autoWatchDownloadsFolder = MacConversionPreferences.autoWatchDownloadsFolder
        autoWatchDesktopFolder = MacConversionPreferences.autoWatchDesktopFolder
        customWatchedFolderNames = Self.customWatchedFolders().map(\.lastPathComponent)

        autoWatcher.onBatch = { [weak self] batch in
            Task { @MainActor in
                self?.handleAutomaticBatch(batch)
            }
        }
        updateAutoWatcher()
    }

    deinit {
        autoWatcher.stop()
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

    func chooseWatchedFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Watch"

        guard panel.runModal() == .OK else {
            return
        }

        for url in panel.urls {
            do {
                try MacConversionPreferences.addCustomWatchedFolder(url)
            } catch {
                failures.insert(
                    HEICPNGConversionFailure(
                        sourceURL: url,
                        message: "Could not watch \(url.lastPathComponent)."
                    ),
                    at: 0
                )
            }
        }

        reloadCustomWatchedFolders()
        updateAutoWatcher()
    }

    func removeWatchedFolder(at index: Int) {
        MacConversionPreferences.removeCustomWatchedFolder(at: index)
        reloadCustomWatchedFolders()
        updateAutoWatcher()
    }

    private func copyFilesToPasteboard(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    private func handleAutomaticBatch(_ batch: HEICPNGBatchResult) {
        converted = batch.converted + converted
        failures = batch.failures + failures
        let outputURLs = batch.converted.map(\.outputURL)

        if batch.didConvertAnything && autoCopyConvertedFiles {
            copyFilesToPasteboard(outputURLs)
        }

        if batch.didConvertAnything && autoRevealConvertedFiles {
            NSWorkspace.shared.activateFileViewerSelecting(outputURLs)
        }
    }

    private func updateAutoWatcher() {
        guard autoConvertNewHEICFiles else {
            autoWatcher.stop()
            return
        }

        autoWatcher.start(watching: watchedFolders())
    }

    private func watchedFolders() -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default

        if autoWatchDownloadsFolder,
           let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            urls.append(downloadsURL)
        }

        if autoWatchDesktopFolder,
           let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
            urls.append(desktopURL)
        }

        urls.append(contentsOf: Self.customWatchedFolders())
        return urls
    }

    private func reloadCustomWatchedFolders() {
        customWatchedFolderNames = Self.customWatchedFolders().map(\.lastPathComponent)
    }

    private static func customWatchedFolders() -> [URL] {
        MacConversionPreferences.customWatchedFolderURLs()
    }
}
