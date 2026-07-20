import SwiftUI
import UniformTypeIdentifiers

struct IOSConversionView: View {
    @StateObject private var viewModel = IOSConversionViewModel()
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(viewModel.statusText)
                        .font(.headline)
                        .accessibilityIdentifier("ios.statusText")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                Button {
                    isImporting = true
                } label: {
                    Label("Choose Files", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ios.chooseFilesButton")

                HStack(spacing: 12) {
                    Button {
                        viewModel.copyConvertedImages()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.converted.isEmpty)
                    .accessibilityIdentifier("ios.copyButton")

                    Button {
                        viewModel.shareConvertedImages()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.converted.isEmpty)
                    .accessibilityIdentifier("ios.shareButton")
                }

                List {
                    if viewModel.converted.isEmpty && viewModel.failures.isEmpty {
                        Label("No recent conversions", systemImage: "clock")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("ios.emptyState")
                    }

                    if !viewModel.converted.isEmpty {
                        Section("Converted") {
                            ForEach(viewModel.converted, id: \.outputURL) { result in
                                Label(result.outputURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    if !viewModel.failures.isEmpty {
                        Section("Needs Attention") {
                            ForEach(viewModel.failures, id: \.sourceURL) { failure in
                                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("ios.resultsList")
            }
            .padding(.horizontal, 16)
            .navigationTitle("HEIC to PNG")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.heic, .heif],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    viewModel.convert(urls: urls)
                case .failure(let error):
                    viewModel.failures = [
                        .init(
                            sourceURL: URL(fileURLWithPath: "Import"),
                            message: error.localizedDescription
                        )
                    ]
                }
            }
            .sheet(isPresented: Binding(
                get: { !viewModel.shareURLs.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        viewModel.shareURLs = []
                    }
                }
            )) {
                ActivityView(activityItems: viewModel.shareURLs)
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
