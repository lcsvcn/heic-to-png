import Foundation

enum MacConversionPreferences {
    static let appGroupIdentifier = "group.com.lcsvcn.HEICToPNG"

    private enum Key {
        static let finderQuickActionEnabled = "finderQuickActionEnabled"
        static let autoRevealConvertedFiles = "autoRevealConvertedFiles"
        static let autoCopyConvertedFiles = "autoCopyConvertedFiles"
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

    private static func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }
}

