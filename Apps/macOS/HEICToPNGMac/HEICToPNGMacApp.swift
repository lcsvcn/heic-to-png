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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
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
            button.action = #selector(toggleConverterWindow(_:))
            button.target = self
        }
        statusItem = item
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showConverterWindow()
        viewModel.convert(urls: urls)
    }

    @objc private func toggleConverterWindow(_ sender: AnyObject?) {
        guard let window = windowController?.window else {
            return
        }

        if window.isVisible {
            window.orderOut(sender)
        } else {
            showConverterWindow()
        }
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
