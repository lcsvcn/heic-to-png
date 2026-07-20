import HEICPNGCore
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let converter = HEICPNGConverter()
    private var convertedURLs: [URL] = []
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let saveButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        loadAndConvert()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        statusLabel.text = "Converting..."
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        activityIndicator.startAnimating()

        configure(saveButton, title: "Save", image: "folder", action: #selector(saveFiles))
        configure(copyButton, title: "Copy", image: "doc.on.doc", action: #selector(copyFiles))
        configure(shareButton, title: "Share", image: "square.and.arrow.up", action: #selector(shareFiles))
        configure(doneButton, title: "Done", image: "checkmark", action: #selector(done))

        let buttonStack = UIStackView(arrangedSubviews: [saveButton, copyButton, shareButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10

        let stack = UIStackView(arrangedSubviews: [
            statusLabel,
            activityIndicator,
            buttonStack,
            doneButton
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        setActionButtonsEnabled(false)
    }

    private func configure(
        _ button: UIButton,
        title: String,
        image: String,
        action: Selector
    ) {
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func loadAndConvert() {
        Task {
            let inputURLs = await loadInputURLs()
            let destinationDirectory = try? Self.temporaryConvertedDirectory()
            let batch = converter.convert(
                urls: inputURLs,
                destinationDirectory: destinationDirectory
            )

            await MainActor.run {
                self.convertedURLs = batch.converted.map(\.outputURL)
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                self.setActionButtonsEnabled(!self.convertedURLs.isEmpty)

                if batch.converted.isEmpty && batch.failures.isEmpty {
                    self.statusLabel.text = "No HEIC or HEIF images found."
                } else {
                    let convertedText = "\(batch.converted.count) converted"
                    let failureText = batch.failures.isEmpty ? nil : "\(batch.failures.count) failed"
                    self.statusLabel.text = [convertedText, failureText]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                }
            }
        }
    }

    private func setActionButtonsEnabled(_ enabled: Bool) {
        [saveButton, copyButton, shareButton].forEach { button in
            button.isEnabled = enabled
            button.alpha = enabled ? 1 : 0.45
        }
    }

    private func loadInputURLs() async -> [URL] {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        var urls: [URL] = []

        for provider in providers {
            if let url = await provider.loadHEICFileCopy() {
                urls.append(url)
            }
        }

        return urls
    }

    @objc private func saveFiles() {
        let picker = UIDocumentPickerViewController(forExporting: convertedURLs, asCopy: true)
        present(picker, animated: true)
    }

    @objc private func copyFiles() {
        let items = convertedURLs.compactMap { url -> [String: Any]? in
            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            return [UTType.png.identifier: data]
        }

        UIPasteboard.general.items = items
        statusLabel.text = "\(items.count) copied"
    }

    @objc private func shareFiles() {
        let activityViewController = UIActivityViewController(
            activityItems: convertedURLs,
            applicationActivities: nil
        )
        present(activityViewController, animated: true)
    }

    @objc private func done() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private static func temporaryConvertedDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HEICToPNGShareExtension", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension NSItemProvider {
    func loadHEICFileCopy() async -> URL? {
        let supportedType = [UTType.heic.identifier, UTType.heif.identifier, UTType.fileURL.identifier]
            .first { hasItemConformingToTypeIdentifier($0) }

        guard let supportedType else {
            return nil
        }

        if supportedType == UTType.fileURL.identifier {
            return await loadFileURL()
        }

        return await withCheckedContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: supportedType) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }

                let copyURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension.isEmpty ? "heic" : url.pathExtension)

                do {
                    if FileManager.default.fileExists(atPath: copyURL.path) {
                        try FileManager.default.removeItem(at: copyURL)
                    }
                    try FileManager.default.copyItem(at: url, to: copyURL)
                    continuation.resume(returning: copyURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadFileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

