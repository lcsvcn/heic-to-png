import Foundation
import HEICPNGCore

enum MacConversionLogKind: String, Codable, Sendable {
    case conversion
    case failure
    case setting
    case watcher
    case quickAction
}

enum MacConversionLogSource: String, Codable, Sendable {
    case manual = "Manual"
    case automatic = "Automatic"
    case finderQuickAction = "Finder Quick Action"
}

struct MacConversionLogEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let kind: MacConversionLogKind
    let title: String
    let detail: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: MacConversionLogKind,
        title: String,
        detail: String? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

enum MacConversionLogStore {
    static let didChangeNotification = Notification.Name("com.lcsvcn.HEICToPNG.conversionLogDidChange")

    private enum Key {
        static let entries = "conversionLogEntries"
    }

    private static let maxEntries = 500

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: MacConversionPreferences.appGroupIdentifier) ?? .standard
    }

    static func entries() -> [MacConversionLogEntry] {
        guard let data = defaults.data(forKey: Key.entries),
              let entries = try? JSONDecoder().decode([MacConversionLogEntry].self, from: data) else {
            return []
        }

        return entries.sorted { $0.date > $1.date }
    }

    static func append(
        kind: MacConversionLogKind,
        title: String,
        detail: String? = nil,
        date: Date = Date()
    ) {
        var currentEntries = entries()
        currentEntries.insert(
            MacConversionLogEntry(
                date: date,
                kind: kind,
                title: title,
                detail: detail
            ),
            at: 0
        )
        currentEntries = Array(currentEntries.prefix(maxEntries))

        if let data = try? JSONEncoder().encode(currentEntries) {
            defaults.set(data, forKey: Key.entries)
        }

        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func appendConversionBatch(
        _ batch: HEICPNGBatchResult,
        source: MacConversionLogSource
    ) {
        if batch.converted.isEmpty && batch.failures.isEmpty {
            append(
                kind: source == .finderQuickAction ? .quickAction : .conversion,
                title: "\(source.rawValue): no HEIC or HEIF files found"
            )
            return
        }

        for result in batch.converted {
            append(
                kind: source == .finderQuickAction ? .quickAction : .conversion,
                title: "\(source.rawValue): converted \(result.outputURL.lastPathComponent)",
                detail: "\(result.sourceURL.path) -> \(result.outputURL.path)"
            )
        }

        for failure in batch.failures {
            append(
                kind: .failure,
                title: "\(source.rawValue): failed \(failure.sourceURL.lastPathComponent)",
                detail: failure.message
            )
        }
    }

    static func appendSettingChange(_ setting: String, isEnabled: Bool) {
        append(
            kind: .setting,
            title: "\(setting) \(isEnabled ? "enabled" : "disabled")"
        )
    }

    static func clear() {
        defaults.removeObject(forKey: Key.entries)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
