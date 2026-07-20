import SwiftUI

struct MacDropView: View {
    @ObservedObject var viewModel: MacConversionViewModel
    let showLogs: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            header

            Divider()

            automaticSection

            Divider()

            quickActionSection

            Divider()

            manualSection

            Divider()

            footerActions
        }
        .padding(18)
        .frame(minWidth: 410, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 28, weight: .semibold))

            VStack(alignment: .leading, spacing: 3) {
                Text("HEIC to PNG")
                    .font(.headline)
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showLogs()
            } label: {
                Label("See Logs", systemImage: "list.bullet.rectangle")
            }
        }
    }

    private var automaticSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Automatic", systemImage: "bolt.circle")

            optionToggle(
                "Auto-convert",
                systemImage: "bolt.fill",
                isOn: $viewModel.autoConvertNewHEICFiles
            )

            optionToggle(
                "AirDrop / Downloads",
                systemImage: "arrow.down.circle",
                isOn: $viewModel.autoWatchDownloadsFolder,
                isEnabled: viewModel.autoConvertNewHEICFiles
            )

            optionToggle(
                "Desktop / Screenshots",
                systemImage: "camera.viewfinder",
                isOn: $viewModel.autoWatchDesktopFolder,
                isEnabled: viewModel.autoConvertNewHEICFiles
            )

            ForEach(Array(viewModel.customWatchedFolderNames.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 10) {
                    Label(name, systemImage: "folder")
                        .lineLimit(1)

                    Spacer(minLength: 16)

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

            HStack(spacing: 10) {
                Button {
                    viewModel.chooseWatchedFolder()
                } label: {
                    Label("Watch Folder", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.autoConvertNewHEICFiles)

                Button {
                    showLogs()
                } label: {
                    Label("See Logs", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Finder", systemImage: "filemenu.and.selection")

            optionToggle(
                "Quick Action",
                systemImage: "filemenu.and.selection",
                isOn: $viewModel.finderQuickActionEnabled
            )

            Button {
                viewModel.openExtensionSettings()
            } label: {
                Label("Extension Settings", systemImage: "switch.2")
            }
            .buttonStyle(.link)
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Manual", systemImage: "hand.point.up.left")

            HStack(spacing: 10) {
                Button {
                    viewModel.chooseFiles()
                } label: {
                    Label("Convert Files", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.chooseFolderToConvert()
                } label: {
                    Label("Convert Folder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            optionToggle(
                "Reveal",
                systemImage: "folder",
                isOn: $viewModel.autoRevealConvertedFiles
            )

            optionToggle(
                "Copy",
                systemImage: "doc.on.doc",
                isOn: $viewModel.autoCopyConvertedFiles
            )
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func optionToggle(
        _ title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)

            Spacer(minLength: 16)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(width: 46, alignment: .trailing)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
    }
}
