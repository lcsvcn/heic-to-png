import Foundation

enum MacConversionPreferences {
    static let appGroupIdentifier = "group.com.lcsvcn.HEICToPNG"

    private enum Key {
        static let finderQuickActionEnabled = "finderQuickActionEnabled"
        static let autoRevealConvertedFiles = "autoRevealConvertedFiles"
        static let autoCopyConvertedFiles = "autoCopyConvertedFiles"
        static let autoConvertNewHEICFiles = "autoConvertNewHEICFiles"
        static let autoWatchDownloadsFolder = "autoWatchDownloadsFolder"
        static let autoWatchDesktopFolder = "autoWatchDesktopFolder"
        static let customWatchedFolderBookmarks = "customWatchedFolderBookmarks"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var finderQuickActionEnabled: Bool {
        get { bool(forKey: Key.finderQuickActionEnabled, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.finderQuickActionEnabled) }
    }

    static var autoRevealConvertedFiles: Bool {
        get { bool(forKey: Key.autoRevealConvertedFiles, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.autoRevealConvertedFiles) }
    }

    static var autoCopyConvertedFiles: Bool {
        get { bool(forKey: Key.autoCopyConvertedFiles, defaultValue: false) }
        set { defaults.set(newValue, forKey: Key.autoCopyConvertedFiles) }
    }

    static var autoConvertNewHEICFiles: Bool {
        get { bool(forKey: Key.autoConvertNewHEICFiles, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.autoConvertNewHEICFiles) }
    }

    static var autoWatchDownloadsFolder: Bool {
        get { bool(forKey: Key.autoWatchDownloadsFolder, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.autoWatchDownloadsFolder) }
    }

    static var autoWatchDesktopFolder: Bool {
        get { bool(forKey: Key.autoWatchDesktopFolder, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.autoWatchDesktopFolder) }
    }

    static var customWatchedFolderBookmarks: [Data] {
        get { defaults.array(forKey: Key.customWatchedFolderBookmarks) as? [Data] ?? [] }
        set { defaults.set(newValue, forKey: Key.customWatchedFolderBookmarks) }
    }

    static func customWatchedFolderURLs() -> [URL] {
        customWatchedFolderBookmarks.compactMap { bookmark in
            var isStale = false
            return try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
    }

    static func addCustomWatchedFolder(_ url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let existingPaths = Set(customWatchedFolderURLs().map(\.standardizedFileURL.path))
        guard !existingPaths.contains(url.standardizedFileURL.path) else {
            return
        }

        customWatchedFolderBookmarks.append(bookmark)
    }

    static func removeCustomWatchedFolder(at index: Int) {
        var bookmarks = customWatchedFolderBookmarks
        guard bookmarks.indices.contains(index) else {
            return
        }

        bookmarks.remove(at: index)
        customWatchedFolderBookmarks = bookmarks
    }

    private static func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }
}
