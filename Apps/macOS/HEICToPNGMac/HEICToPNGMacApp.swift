import AppKit
import SwiftUI

@main
struct HEICToPNGMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum StatusToggle {
        case autoConvert
        case downloads
        case desktop
        case finderQuickAction
        case reveal
        case copy
    }

    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
    private weak var statusSummaryItem: NSMenuItem?
    private var statusToggleViews: [StatusToggle: StatusMenuCheckboxView] = [:]
    private var windowController: NSWindowController?
    private var logsWindowController: NSWindowController?
    private let viewModel = MacConversionViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = makeConverterWindow()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "photo.badge.arrow.down",
                accessibilityDescription: "Convert HEIC to PNG"
            )
        }
        statusMenu.delegate = self
        rebuildStatusMenu()
        item.menu = statusMenu
        statusItem = item
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showConverterWindow()
        viewModel.convert(urls: urls)
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildStatusMenu()
    }

    private func makeConverterWindow() -> NSWindowController {
        let hostingController = NSHostingController(
            rootView: MacDropView(viewModel: viewModel) { [weak self] in
                self?.showLogsWindow()
            }
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "HEIC to PNG"
        window.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 680))
        window.minSize = NSSize(width: 520, height: 640)
        window.center()

        return NSWindowController(window: window)
    }

    private func rebuildStatusMenu() {
        statusMenu.removeAllItems()

        let titleItem = NSMenuItem(title: "HEIC to PNG", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        statusMenu.addItem(titleItem)

        let statusItem = NSMenuItem(title: viewModel.watchedFolderSummary, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusMenu.addItem(statusItem)
        statusSummaryItem = statusItem
        statusMenu.addItem(.separator())

        statusToggleViews = [:]
        addCheckboxItem(
            id: .autoConvert,
            title: "Auto-convert",
            isOn: viewModel.autoConvertNewHEICFiles
        ) { [weak self] isOn in
            self?.viewModel.autoConvertNewHEICFiles = isOn
            self?.refreshStatusMenuState()
        }
        addCheckboxItem(
            id: .downloads,
            title: "AirDrop / Downloads",
            isOn: viewModel.autoWatchDownloadsFolder,
            isEnabled: viewModel.autoConvertNewHEICFiles
        ) { [weak self] isOn in
            self?.viewModel.autoWatchDownloadsFolder = isOn
            self?.refreshStatusMenuState()
        }
        addCheckboxItem(
            id: .desktop,
            title: "Desktop / Screenshots",
            isOn: viewModel.autoWatchDesktopFolder,
            isEnabled: viewModel.autoConvertNewHEICFiles
        ) { [weak self] isOn in
            self?.viewModel.autoWatchDesktopFolder = isOn
            self?.refreshStatusMenuState()
        }
        addCheckboxItem(
            id: .finderQuickAction,
            title: "Finder Quick Action",
            isOn: viewModel.finderQuickActionEnabled
        ) { [weak self] isOn in
            self?.viewModel.finderQuickActionEnabled = isOn
            self?.refreshStatusMenuState()
        }
        addCheckboxItem(
            id: .reveal,
            title: "Reveal after converting",
            isOn: viewModel.autoRevealConvertedFiles
        ) { [weak self] isOn in
            self?.viewModel.autoRevealConvertedFiles = isOn
            self?.refreshStatusMenuState()
        }
        addCheckboxItem(
            id: .copy,
            title: "Copy after converting",
            isOn: viewModel.autoCopyConvertedFiles
        ) { [weak self] isOn in
            self?.viewModel.autoCopyConvertedFiles = isOn
            self?.refreshStatusMenuState()
        }

        statusMenu.addItem(.separator())
        addActionItem(
            title: "Open App",
            selector: #selector(openAppFromMenu(_:))
        )
        addActionItem(
            title: "See Logs",
            selector: #selector(openLogsFromMenu(_:))
        )
        statusMenu.addItem(.separator())
        addActionItem(
            title: "Quit",
            selector: #selector(quitFromMenu(_:))
        )
    }

    private func addCheckboxItem(
        id: StatusToggle,
        title: String,
        isOn: Bool,
        isEnabled: Bool = true,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        let item = NSMenuItem()
        let checkboxView = StatusMenuCheckboxView(
            title: title,
            isOn: isOn,
            isEnabled: isEnabled,
            onChange: onChange
        )
        item.view = checkboxView
        statusMenu.addItem(item)
        statusToggleViews[id] = checkboxView
    }

    private func addActionItem(title: String, selector: Selector) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        statusMenu.addItem(item)
    }

    private func refreshStatusMenuState() {
        statusSummaryItem?.title = viewModel.watchedFolderSummary
        statusToggleViews[.autoConvert]?.update(
            isOn: viewModel.autoConvertNewHEICFiles
        )
        statusToggleViews[.downloads]?.update(
            isOn: viewModel.autoWatchDownloadsFolder,
            isEnabled: viewModel.autoConvertNewHEICFiles
        )
        statusToggleViews[.desktop]?.update(
            isOn: viewModel.autoWatchDesktopFolder,
            isEnabled: viewModel.autoConvertNewHEICFiles
        )
        statusToggleViews[.finderQuickAction]?.update(
            isOn: viewModel.finderQuickActionEnabled
        )
        statusToggleViews[.reveal]?.update(
            isOn: viewModel.autoRevealConvertedFiles
        )
        statusToggleViews[.copy]?.update(
            isOn: viewModel.autoCopyConvertedFiles
        )
    }

    @objc private func openAppFromMenu(_ sender: NSMenuItem) {
        showConverterWindow()
    }

    @objc private func openLogsFromMenu(_ sender: NSMenuItem) {
        showLogsWindow()
    }

    @objc private func quitFromMenu(_ sender: NSMenuItem) {
        NSApp.terminate(sender)
    }

    private func showConverterWindow() {
        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func showLogsWindow() {
        viewModel.reloadLogs()

        if logsWindowController == nil {
            logsWindowController = makeLogsWindow()
        }

        NSApp.activate(ignoringOtherApps: true)
        logsWindowController?.showWindow(nil)
        logsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func makeLogsWindow() -> NSWindowController {
        let hostingController = NSHostingController(
            rootView: MacConversionLogsView(viewModel: viewModel)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Conversion Logs"
        window.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 680, height: 460))
        window.minSize = NSSize(width: 600, height: 360)
        window.center()

        return NSWindowController(window: window)
    }
}

@MainActor
private final class StatusMenuCheckboxView: NSView {
    private let glyphView = StatusMenuCheckboxGlyphView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let onChange: @MainActor (Bool) -> Void
    private var isOn: Bool
    private var itemIsEnabled: Bool

    init(
        title: String,
        isOn: Bool,
        isEnabled: Bool,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        self.isOn = isOn
        self.itemIsEnabled = isEnabled
        self.onChange = onChange

        super.init(frame: NSRect(x: 0, y: 0, width: 278, height: 32))

        glyphView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title
        titleLabel.font = NSFont.menuFont(ofSize: 0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(glyphView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            glyphView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            glyphView.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyphView.widthAnchor.constraint(equalToConstant: 22),
            glyphView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: glyphView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        update(isOn: isOn, isEnabled: isEnabled)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(isOn: Bool, isEnabled: Bool = true) {
        self.isOn = isOn
        itemIsEnabled = isEnabled
        glyphView.update(isOn: isOn, isEnabled: isEnabled)
        titleLabel.textColor = isEnabled ? .labelColor : .disabledControlTextColor
    }

    override func mouseDown(with event: NSEvent) {
        guard itemIsEnabled else {
            return
        }

        let newValue = !isOn
        update(isOn: newValue, isEnabled: itemIsEnabled)
        onChange(newValue)
    }
}

@MainActor
private final class StatusMenuCheckboxGlyphView: NSView {
    private let checkmarkView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 6

        checkmarkView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )
        checkmarkView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 14,
            weight: .bold
        )
        checkmarkView.contentTintColor = .white
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkmarkView)
        NSLayoutConstraint.activate([
            checkmarkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 15),
            checkmarkView.heightAnchor.constraint(equalToConstant: 15)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(isOn: Bool, isEnabled: Bool) {
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.45
        layer?.backgroundColor = isOn
            ? NSColor.systemBlue.withAlphaComponent(enabledAlpha).cgColor
            : NSColor.tertiaryLabelColor.withAlphaComponent(0.36).cgColor
        checkmarkView.isHidden = !isOn
        checkmarkView.alphaValue = enabledAlpha
    }
}
