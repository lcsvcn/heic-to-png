import AppKit
import Foundation
import HEICPNGCore
import UniformTypeIdentifiers

private struct MacExpandedConversionInput: Sendable {
    let fileURLs: [URL]
    let failures: [HEICPNGConversionFailure]
    let scopedFolderURLs: [URL]
}

@MainActor
final class MacConversionViewModel: ObservableObject {
    @Published var converted: [HEICPNGConversionResult] = []
    @Published var failures: [HEICPNGConversionFailure] = []
    @Published var isConverting = false
    @Published var finderQuickActionEnabled: Bool {
        didSet {
            MacConversionPreferences.finderQuickActionEnabled = finderQuickActionEnabled
            logSettingChange(
                "Finder Quick Action",
                isEnabled: finderQuickActionEnabled,
                oldValue: oldValue
            )
        }
    }
    @Published var autoRevealConvertedFiles: Bool {
        didSet {
            MacConversionPreferences.autoRevealConvertedFiles = autoRevealConvertedFiles
            logSettingChange(
                "Reveal after converting",
                isEnabled: autoRevealConvertedFiles,
                oldValue: oldValue
            )
        }
    }
    @Published var autoCopyConvertedFiles: Bool {
        didSet {
            MacConversionPreferences.autoCopyConvertedFiles = autoCopyConvertedFiles
            logSettingChange(
                "Copy after converting",
                isEnabled: autoCopyConvertedFiles,
                oldValue: oldValue
            )
        }
    }
    @Published var autoConvertNewHEICFiles: Bool {
        didSet {
            MacConversionPreferences.autoConvertNewHEICFiles = autoConvertNewHEICFiles
            logSettingChange(
                "Auto-convert new HEIC files",
                isEnabled: autoConvertNewHEICFiles,
                oldValue: oldValue
            )
            updateAutoWatcher()
        }
    }
    @Published var autoWatchDownloadsFolder: Bool {
        didSet {
            MacConversionPreferences.autoWatchDownloadsFolder = autoWatchDownloadsFolder
            logSettingChange(
                "AirDrop / Downloads",
                isEnabled: autoWatchDownloadsFolder,
                oldValue: oldValue
            )
            updateAutoWatcher()
        }
    }
    @Published var autoWatchDesktopFolder: Bool {
        didSet {
            MacConversionPreferences.autoWatchDesktopFolder = autoWatchDesktopFolder
            logSettingChange(
                "Desktop / Screenshots",
                isEnabled: autoWatchDesktopFolder,
                oldValue: oldValue
            )
            updateAutoWatcher()
        }
    }
    @Published private(set) var customWatchedFolderNames: [String] = []
    @Published private(set) var logEntries: [MacConversionLogEntry] = []

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
        logEntries = MacConversionLogStore.entries()

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
            return watchedFolderSummary
        }

        let successText = converted.isEmpty ? nil : "\(converted.count) converted"
        let failureText = failures.isEmpty ? nil : "\(failures.count) failed"
        return [successText, failureText].compactMap { $0 }.joined(separator: ", ")
    }

    var watchedFolderSummary: String {
        guard autoConvertNewHEICFiles else {
            return "Off"
        }

        let folderCount = watchedFolderNames.count
        if folderCount == 0 {
            return "No folders"
        }

        return folderCount == 1 ? "Watching 1 folder" : "Watching \(folderCount) folders"
    }

    var watchedFolderNames: [String] {
        var names: [String] = []

        if autoWatchDownloadsFolder {
            names.append("Downloads")
        }

        if autoWatchDesktopFolder {
            names.append("Desktop")
        }

        names.append(contentsOf: customWatchedFolderNames)
        return names
    }

    var lastConvertedOutputURLs: [URL] {
        converted.map(\.outputURL)
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

    func chooseFolderToConvert() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
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
            let input = Self.expandedConversionInput(from: urls, converter: converter)
            defer {
                for folderURL in input.scopedFolderURLs {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            let conversionBatch = converter.convert(urls: input.fileURLs)
            let batch = HEICPNGBatchResult(
                converted: conversionBatch.converted,
                failures: input.failures + conversionBatch.failures
            )
            let outputURLs = batch.converted.map(\.outputURL)

            await MainActor.run {
                self.converted = batch.converted
                self.failures = batch.failures
                self.isConverting = false
                MacConversionLogStore.appendConversionBatch(batch, source: .manual)
                self.reloadLogs()

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
                MacConversionLogStore.append(
                    kind: .watcher,
                    title: "Started watching \(url.lastPathComponent)",
                    detail: url.path
                )
            } catch {
                failures.insert(
                    HEICPNGConversionFailure(
                        sourceURL: url,
                        message: "Could not watch \(url.lastPathComponent)."
                    ),
                    at: 0
                )
                MacConversionLogStore.append(
                    kind: .failure,
                    title: "Could not watch \(url.lastPathComponent)",
                    detail: error.localizedDescription
                )
            }
        }

        reloadCustomWatchedFolders()
        updateAutoWatcher()
        reloadLogs()
    }

    func removeWatchedFolder(at index: Int) {
        let removedName = customWatchedFolderNames.indices.contains(index) ? customWatchedFolderNames[index] : nil
        MacConversionPreferences.removeCustomWatchedFolder(at: index)
        reloadCustomWatchedFolders()
        updateAutoWatcher()

        if let removedName {
            MacConversionLogStore.append(
                kind: .watcher,
                title: "Stopped watching \(removedName)"
            )
            reloadLogs()
        }
    }

    func reloadLogs() {
        logEntries = MacConversionLogStore.entries()
    }

    func clearLogs() {
        MacConversionLogStore.clear()
        reloadLogs()
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
        MacConversionLogStore.appendConversionBatch(batch, source: .automatic)
        reloadLogs()

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

    private func logSettingChange(_ setting: String, isEnabled: Bool, oldValue: Bool) {
        guard oldValue != isEnabled else {
            return
        }

        MacConversionLogStore.appendSettingChange(setting, isEnabled: isEnabled)
        reloadLogs()
    }

    private static func customWatchedFolders() -> [URL] {
        MacConversionPreferences.customWatchedFolderURLs()
    }

    nonisolated private static func expandedConversionInput(
        from urls: [URL],
        converter: HEICPNGConverter,
        fileManager: FileManager = .default
    ) -> MacExpandedConversionInput {
        var fileURLs: [URL] = []
        var failures: [HEICPNGConversionFailure] = []
        var scopedFolderURLs: [URL] = []
        var seenPaths: Set<String> = []

        for rawURL in urls {
            let url = rawURL.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                failures.append(
                    HEICPNGConversionFailure(
                        sourceURL: url,
                        message: "Could not find \(url.lastPathComponent)."
                    )
                )
                continue
            }

            if isDirectory.boolValue {
                if url.startAccessingSecurityScopedResource() {
                    scopedFolderURLs.append(url)
                }

                let folderFileURLs = heicFileURLs(
                    in: url,
                    converter: converter,
                    fileManager: fileManager
                )

                if folderFileURLs.isEmpty {
                    failures.append(
                        HEICPNGConversionFailure(
                            sourceURL: url,
                            message: "No HEIC or HEIF images found in \(url.lastPathComponent)."
                        )
                    )
                }

                for fileURL in folderFileURLs {
                    appendUnique(fileURL, to: &fileURLs, seenPaths: &seenPaths)
                }
            } else {
                appendUnique(url, to: &fileURLs, seenPaths: &seenPaths)
            }
        }

        return MacExpandedConversionInput(
            fileURLs: fileURLs,
            failures: failures,
            scopedFolderURLs: scopedFolderURLs
        )
    }

    nonisolated private static func heicFileURLs(
        in folderURL: URL,
        converter: HEICPNGConverter,
        fileManager: FileManager
    ) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard converter.isSupportedHEICFile(url),
                  isRegularFile(url) else {
                continue
            }

            urls.append(url)
        }

        return urls
    }

    nonisolated private static func appendUnique(
        _ url: URL,
        to urls: inout [URL],
        seenPaths: inout Set<String>
    ) {
        let path = url.standardizedFileURL.path
        guard !seenPaths.contains(path) else {
            return
        }

        seenPaths.insert(path)
        urls.append(url)
    }

    nonisolated private static func isRegularFile(
        _ url: URL
    ) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
