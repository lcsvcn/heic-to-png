import SwiftUI
import UniformTypeIdentifiers

struct MacDropView: View {
    @ObservedObject var viewModel: MacConversionViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "photo.badge.arrow.down")
                    .font(.system(size: 26, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Convert HEIC to PNG")
                        .font(.headline)
                    Text(viewModel.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            dropZone

            HStack(spacing: 12) {
                Button {
                    viewModel.chooseFiles()
                } label: {
                    Label("Choose", systemImage: "plus")
                }

                Button {
                    viewModel.copyConvertedFiles()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.converted.isEmpty)

                Button {
                    viewModel.revealConvertedFiles()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .disabled(viewModel.converted.isEmpty)
            }

            options

            Divider()

            resultList
        }
        .padding(18)
        .frame(minWidth: 390, minHeight: 650)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                }

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                Text("Drop HEIC or HEIF files")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 150)
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $isTargeted,
            perform: handleDrop(providers:)
        )
    }

    private var resultList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.converted, id: \.outputURL) { result in
                    Label(result.outputURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .lineLimit(2)
                }

                ForEach(viewModel.failures, id: \.sourceURL) { failure in
                    Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                }

                if viewModel.converted.isEmpty && viewModel.failures.isEmpty {
                    Text("No recent conversions")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $viewModel.finderQuickActionEnabled) {
                Label("Finder Quick Action", systemImage: "filemenu.and.selection")
            }

            Toggle(isOn: $viewModel.autoRevealConvertedFiles) {
                Label("Reveal after converting", systemImage: "folder")
            }

            Toggle(isOn: $viewModel.autoCopyConvertedFiles) {
                Label("Copy after converting", systemImage: "doc.on.doc")
            }

            Divider()

            Toggle(isOn: $viewModel.autoConvertNewHEICFiles) {
                Label("Auto-convert new HEIC files", systemImage: "bolt.circle")
            }

            Toggle(isOn: $viewModel.autoWatchDownloadsFolder) {
                Label("AirDrop / Downloads", systemImage: "arrow.down.circle")
            }
            .disabled(!viewModel.autoConvertNewHEICFiles)

            Toggle(isOn: $viewModel.autoWatchDesktopFolder) {
                Label("Desktop / Screenshots", systemImage: "camera.viewfinder")
            }
            .disabled(!viewModel.autoConvertNewHEICFiles)

            ForEach(Array(viewModel.customWatchedFolderNames.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 8) {
                    Label(name, systemImage: "folder")
                        .lineLimit(1)
                    Spacer()
                    Button {
                        viewModel.removeWatchedFolder(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove watched folder")
                }
                .disabled(!viewModel.autoConvertNewHEICFiles)
            }

            Button {
                viewModel.chooseWatchedFolder()
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.link)
            .disabled(!viewModel.autoConvertNewHEICFiles)

            Button {
                viewModel.openExtensionSettings()
            } label: {
                Label("Extensions", systemImage: "switch.2")
            }
            .buttonStyle(.link)
        }
        .toggleStyle(.switch)
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await provider.fileURL() {
                    urls.append(url)
                }
            }
            await MainActor.run {
                viewModel.convert(urls: urls)
            }
        }

        return true
    }
}

private extension NSItemProvider {
    @MainActor
    func fileURL() async -> URL? {
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
