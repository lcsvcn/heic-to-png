import SwiftUI

struct MacConversionLogsView: View {
    @ObservedObject var viewModel: MacConversionViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Conversion Logs", systemImage: "list.bullet.rectangle")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.reloadLogs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh logs")

                Button {
                    viewModel.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear logs")
                .disabled(viewModel.logEntries.isEmpty)
            }
            .padding(16)

            Divider()

            if viewModel.logEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("No logs yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.logEntries) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }
}

private struct LogEntryRow: View {
    let entry: MacConversionLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)

                    Spacer()

                    Text(Self.dateFormatter.string(from: entry.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let detail = entry.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch entry.kind {
        case .conversion:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        case .setting:
            return "switch.2"
        case .watcher:
            return "folder.badge.gearshape"
        case .quickAction:
            return "filemenu.and.selection"
        }
    }

    private var iconColor: Color {
        switch entry.kind {
        case .conversion, .quickAction:
            return .green
        case .failure:
            return .orange
        case .setting, .watcher:
            return .accentColor
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
