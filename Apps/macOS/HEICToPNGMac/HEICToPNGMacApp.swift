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
    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
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
        window.setContentSize(NSSize(width: 430, height: 520))
        window.minSize = NSSize(width: 410, height: 500)
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
        statusMenu.addItem(.separator())

        addToggleItem(
            title: "Auto-convert",
            selector: #selector(toggleAutoConvert(_:)),
            isOn: viewModel.autoConvertNewHEICFiles
        )
        addToggleItem(
            title: "AirDrop / Downloads",
            selector: #selector(toggleDownloadsWatch(_:)),
            isOn: viewModel.autoWatchDownloadsFolder,
            isEnabled: viewModel.autoConvertNewHEICFiles
        )
        addToggleItem(
            title: "Desktop / Screenshots",
            selector: #selector(toggleDesktopWatch(_:)),
            isOn: viewModel.autoWatchDesktopFolder,
            isEnabled: viewModel.autoConvertNewHEICFiles
        )
        addToggleItem(
            title: "Finder Quick Action",
            selector: #selector(toggleFinderQuickAction(_:)),
            isOn: viewModel.finderQuickActionEnabled
        )
        addToggleItem(
            title: "Reveal after converting",
            selector: #selector(toggleRevealAfterConverting(_:)),
            isOn: viewModel.autoRevealConvertedFiles
        )
        addToggleItem(
            title: "Copy after converting",
            selector: #selector(toggleCopyAfterConverting(_:)),
            isOn: viewModel.autoCopyConvertedFiles
        )

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

    private func addToggleItem(
        title: String,
        selector: Selector,
        isOn: Bool,
        isEnabled: Bool = true
    ) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        item.isEnabled = isEnabled
        statusMenu.addItem(item)
    }

    private func addActionItem(title: String, selector: Selector) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        statusMenu.addItem(item)
    }

    @objc private func toggleAutoConvert(_ sender: NSMenuItem) {
        viewModel.autoConvertNewHEICFiles.toggle()
        rebuildStatusMenu()
    }

    @objc private func toggleDownloadsWatch(_ sender: NSMenuItem) {
        viewModel.autoWatchDownloadsFolder.toggle()
        rebuildStatusMenu()
    }

    @objc private func toggleDesktopWatch(_ sender: NSMenuItem) {
        viewModel.autoWatchDesktopFolder.toggle()
        rebuildStatusMenu()
    }

    @objc private func toggleFinderQuickAction(_ sender: NSMenuItem) {
        viewModel.finderQuickActionEnabled.toggle()
        rebuildStatusMenu()
    }

    @objc private func toggleRevealAfterConverting(_ sender: NSMenuItem) {
        viewModel.autoRevealConvertedFiles.toggle()
        rebuildStatusMenu()
    }

    @objc private func toggleCopyAfterConverting(_ sender: NSMenuItem) {
        viewModel.autoCopyConvertedFiles.toggle()
        rebuildStatusMenu()
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
