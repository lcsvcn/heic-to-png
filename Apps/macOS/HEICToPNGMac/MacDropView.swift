import SwiftUI

struct MacDropView: View {
    @ObservedObject var viewModel: MacConversionViewModel
    let showLogs: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            header

            Divider()

            automaticSection

            Divider()

            quickActionSection

            Divider()

            manualSection

            Divider()

            postConversionSection
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 640)
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
        }
    }

    private var automaticSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Automatic", systemImage: "bolt.circle")

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Auto-convert",
                    activeDescription: "New HEIC and HEIF files in watched folders are converted to PNG.",
                    inactiveDescription: "Folder watching is paused.",
                    systemImage: "bolt.fill",
                    isOn: $viewModel.autoConvertNewHEICFiles
                )

                rowDivider

                settingsToggleRow(
                    title: "AirDrop / Downloads",
                    activeDescription: "AirDrop and downloaded HEIC files get PNG copies automatically.",
                    inactiveDescription: "Downloads and AirDrop files are ignored.",
                    disabledDescription: "Turn on Auto-convert to watch Downloads and AirDrop files.",
                    systemImage: "arrow.down.circle",
                    isOn: $viewModel.autoWatchDownloadsFolder,
                    isEnabled: viewModel.autoConvertNewHEICFiles
                )

                rowDivider

                settingsToggleRow(
                    title: "Desktop / Screenshots",
                    activeDescription: "HEIC and HEIF files saved to Desktop get PNG copies automatically.",
                    inactiveDescription: "Desktop files are ignored.",
                    disabledDescription: "Turn on Auto-convert to watch Desktop files.",
                    systemImage: "camera.viewfinder",
                    isOn: $viewModel.autoWatchDesktopFolder,
                    isEnabled: viewModel.autoConvertNewHEICFiles
                )
            }

            ForEach(Array(viewModel.customWatchedFolderNames.enumerated()), id: \.offset) { index, name in
                customFolderRow(name: name, index: index)
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

            settingsToggleRow(
                title: "Quick Action",
                activeDescription: "Finder can run Convert HEIC to PNG from Quick Actions.",
                inactiveDescription: "Finder Quick Action requests are skipped by this app.",
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

    private var postConversionSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("After Conversion", systemImage: "checkmark.circle")

            VStack(spacing: 0) {
                settingsToggleRow(
                    title: "Reveal after converting",
                    activeDescription: "Finder opens and selects converted PNG files.",
                    inactiveDescription: "Converted files stay in place without opening Finder.",
                    systemImage: "folder",
                    isOn: $viewModel.autoRevealConvertedFiles
                )

                rowDivider

                settingsToggleRow(
                    title: "Copy after converting",
                    activeDescription: "Converted PNG files are copied to the clipboard.",
                    inactiveDescription: "The clipboard is left unchanged after conversion.",
                    systemImage: "doc.on.doc",
                    isOn: $viewModel.autoCopyConvertedFiles
                )
            }
        }
    }

    private func customFolderRow(name: String, index: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            settingsIcon(
                systemImage: "folder",
                isEnabled: viewModel.autoConvertNewHEICFiles
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(viewModel.autoConvertNewHEICFiles ? "Custom watched folder." : "Turn on Auto-convert to watch this folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button {
                viewModel.removeWatchedFolder(at: index)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove watched folder")
        }
        .padding(.vertical, 8)
        .opacity(viewModel.autoConvertNewHEICFiles ? 1 : 0.58)
        .disabled(!viewModel.autoConvertNewHEICFiles)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 48)
    }

    private func settingsToggleRow(
        title: String,
        activeDescription: String,
        inactiveDescription: String,
        disabledDescription: String? = nil,
        systemImage: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            settingsIcon(systemImage: systemImage, isEnabled: isEnabled)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(settingDescription(
                    isOn: isOn.wrappedValue,
                    isEnabled: isEnabled,
                    activeDescription: activeDescription,
                    inactiveDescription: inactiveDescription,
                    disabledDescription: disabledDescription
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
    }

    private func settingsIcon(systemImage: String, isEnabled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isEnabled ? Color.accentColor : Color.secondary.opacity(0.28))

            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 32, height: 32)
    }

    private func settingDescription(
        isOn: Bool,
        isEnabled: Bool,
        activeDescription: String,
        inactiveDescription: String,
        disabledDescription: String?
    ) -> String {
        guard isEnabled else {
            return disabledDescription ?? inactiveDescription
        }

        return isOn ? activeDescription : inactiveDescription
    }
}
