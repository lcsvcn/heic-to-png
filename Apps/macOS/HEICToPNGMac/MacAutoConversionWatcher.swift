import Darwin
import Foundation
import HEICPNGCore

final class MacAutoConversionWatcher: @unchecked Sendable {
    typealias BatchHandler = @Sendable (HEICPNGBatchResult) -> Void

    var onBatch: BatchHandler?

    private struct FolderMonitor {
        let url: URL
        let source: DispatchSourceFileSystemObject
        let hasSecurityScope: Bool
    }

    private let queue = DispatchQueue(label: "com.lcsvcn.HEICToPNG.autoConversionWatcher")
    private let converter = HEICPNGConverter()
    private let fileManager = FileManager.default
    private var monitors: [String: FolderMonitor] = [:]
    private var pendingPaths: Set<String> = []

    func start(watching folderURLs: [URL]) {
        queue.async {
            self.stopLocked()

            for url in folderURLs {
                self.addMonitor(for: url)
            }
        }
    }

    func stop() {
        queue.async {
            self.stopLocked()
        }
    }

    private func addMonitor(for folderURL: URL) {
        let standardizedURL = folderURL.standardizedFileURL
        let path = standardizedURL.path
        guard monitors[path] == nil else {
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        let hasSecurityScope = standardizedURL.startAccessingSecurityScopedResource()
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            if hasSecurityScope {
                standardizedURL.stopAccessingSecurityScopedResource()
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .rename, .link],
            queue: queue
        )
        let monitor = FolderMonitor(
            url: standardizedURL,
            source: source,
            hasSecurityScope: hasSecurityScope
        )

        source.setEventHandler { [weak self] in
            self?.scheduleScan(of: standardizedURL)
        }
        source.setCancelHandler {
            close(descriptor)
            if hasSecurityScope {
                standardizedURL.stopAccessingSecurityScopedResource()
            }
        }

        monitors[path] = monitor
        source.resume()
        scheduleScan(of: standardizedURL, delay: .milliseconds(500))
    }

    private func stopLocked() {
        for monitor in monitors.values {
            monitor.source.cancel()
        }

        monitors = [:]
        pendingPaths = []
    }

    private func scheduleScan(of folderURL: URL, delay: DispatchTimeInterval = .seconds(2)) {
        queue.asyncAfter(deadline: .now() + delay) {
            self.scan(folderURL)
        }
    }

    private func scan(_ folderURL: URL) {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard converter.isSupportedHEICFile(url),
                  isRegularFile(url) else {
                continue
            }

            scheduleConversion(of: url, attempt: 0)
        }
    }

    private func scheduleConversion(of sourceURL: URL, attempt: Int) {
        let key = sourceURL.standardizedFileURL.path
        if attempt == 0 {
            guard !pendingPaths.contains(key) else {
                return
            }
            pendingPaths.insert(key)
        }

        let delay = attempt == 0 ? DispatchTimeInterval.seconds(2) : .seconds(min(2 + attempt, 8))
        queue.asyncAfter(deadline: .now() + delay) {
            self.convertIfNeeded(sourceURL, attempt: attempt + 1)
        }
    }

    private func convertIfNeeded(_ sourceURL: URL, attempt: Int) {
        let key = sourceURL.standardizedFileURL.path
        defer {
            if attempt >= 6 {
                pendingPaths.remove(key)
            }
        }

        guard fileManager.fileExists(atPath: sourceURL.path),
              isRegularFile(sourceURL) else {
            pendingPaths.remove(key)
            return
        }

        guard !hasSiblingPNG(for: sourceURL) else {
            pendingPaths.remove(key)
            return
        }

        do {
            let result = try converter.convert(
                sourceURL,
                deleteSourceAfterConversion: MacConversionPreferences.deleteOriginalAfterConversion
            )
            pendingPaths.remove(key)
            publish(HEICPNGBatchResult(converted: [result], failures: []))
        } catch {
            guard attempt < 6 else {
                let failure = HEICPNGConversionFailure(
                    sourceURL: sourceURL,
                    message: error.localizedDescription
                )
                publish(HEICPNGBatchResult(converted: [], failures: [failure]))
                return
            }

            scheduleConversion(of: sourceURL, attempt: attempt)
        }
    }

    private func publish(_ batch: HEICPNGBatchResult) {
        guard batch.didConvertAnything || batch.hasFailures else {
            return
        }

        let handler = onBatch
        DispatchQueue.main.async {
            handler?(batch)
        }
    }

    private func hasSiblingPNG(for sourceURL: URL) -> Bool {
        let pngURL = sourceURL.deletingPathExtension().appendingPathExtension("png")
        return fileManager.fileExists(atPath: pngURL.path)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
