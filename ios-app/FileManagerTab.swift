
import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct FileManagerTab: View {
    @State private var showingImporter = false
    @State private var showingImportResult = false

    @State private var importResultTitle = ""
    @State private var importResultMessage = ""

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    private var libraryURL: URL {
        fileManager.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        )[0]
    }

    private var cachesURL: URL {
        fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
    }

    private var temporaryURL: URL {
        fileManager.temporaryDirectory
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        FileDirectoryView(directory: documentsURL)
                    } label: {
                        Label("Documents", systemImage: "folder.fill")
                    }

                    NavigationLink {
                        FileDirectoryView(directory: libraryURL)
                    } label: {
                        Label("Library", systemImage: "folder.fill")
                    }

                    NavigationLink {
                        FileDirectoryView(directory: cachesURL)
                    } label: {
                        Label("Caches", systemImage: "folder.fill")
                    }

                    NavigationLink {
                        FileDirectoryView(directory: temporaryURL)
                    } label: {
                        Label("tmp", systemImage: "folder.fill")
                    }
                } header: {
                    Text("App Storage")
                } footer: {
                    Text(
                        "These folders belong to AirCard-iOS. " +
                        "Other apps' private files are not accessible."
                    )
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label(
                            "Import Files",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                } footer: {
                    Text(
                        "Selected files will be copied into " +
                        "Documents/Imported."
                    )
                }
            }
            .navigationTitle("File Manager")
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.item, .folder],
                allowsMultipleSelection: true
            ) { result in
                importFiles(result)
            }
            .alert(
                importResultTitle,
                isPresented: $showingImportResult
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importResultMessage)
            }
        }
    }

    // MARK: - Import Files

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let selectedURLs = try result.get()

            guard !selectedURLs.isEmpty else {
                return
            }

            let importFolder = documentsURL
                .appendingPathComponent(
                    "Imported",
                    isDirectory: true
                )

            try fileManager.createDirectory(
                at: importFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )

            var importedCount = 0
            var failedFiles: [String] = []

            for sourceURL in selectedURLs {
                do {
                    try copyImportedFile(
                        from: sourceURL,
                        to: importFolder
                    )

                    importedCount += 1
                } catch {
                    failedFiles.append(
                        "\(sourceURL.lastPathComponent): " +
                        error.localizedDescription
                    )
                }
            }

            if failedFiles.isEmpty {
                importResultTitle = "Import Complete"
                importResultMessage =
                    "\(importedCount) file(s) imported successfully."
            } else {
                importResultTitle = "Import Finished"
                importResultMessage =
                    "Imported: \(importedCount)\n" +
                    "Failed: \(failedFiles.count)\n\n" +
                    failedFiles.joined(separator: "\n")
            }

            showingImportResult = true

        } catch {
            importResultTitle = "Import Error"
            importResultMessage = error.localizedDescription
            showingImportResult = true
        }
    }

    // MARK: - Copy Selected File

    private func copyImportedFile(
        from sourceURL: URL,
        to destinationFolder: URL
    ) throws {

        let hasAccess =
            sourceURL.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        var destinationURL = destinationFolder
            .appendingPathComponent(
                sourceURL.lastPathComponent
            )

        // Avoid overwriting existing files.

        if fileManager.fileExists(atPath: destinationURL.path) {
            let newName =
                UUID().uuidString + "_" +
                sourceURL.lastPathComponent

            destinationURL = destinationFolder
                .appendingPathComponent(newName)
        }

        let coordinator = NSFileCoordinator(
            filePresenter: nil
        )

        var coordinationError: NSError?
        var copyError: Error?

        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in

            do {
                try fileManager.copyItem(
                    at: coordinatedURL,
                    to: destinationURL
                )
            } catch {
                copyError = error
            }
        }

        if let error = coordinationError {
            throw error
        }

        if let error = copyError {
            throw error
        }
    }
}

// MARK: - Directory Browser

struct FileDirectoryView: View {
    let directory: URL

    @State private var entries: [URL] = []
    @State private var loadError: String?

    private let fileManager = FileManager.default

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Folder is Empty",
                    systemImage: "folder",
                    description: Text(
                        "There are no visible files in this folder."
                    )
                )
            } else {
                ForEach(entries, id: \.self) { url in
                    if isDirectory(url) {
                        NavigationLink {
                            FileDirectoryView(directory: url)
                        } label: {
                            Label(
                                url.lastPathComponent,
                                systemImage: "folder.fill"
                            )
                        }
                    } else {
                        HStack {
                            Label(
                                url.lastPathComponent,
                                systemImage: "doc"
                            )
                            .lineLimit(1)

                            Spacer()

                            ShareLink(item: url) {
                                Image(
                                    systemName: "square.and.arrow.up"
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(directory.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    loadDirectory()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadDirectory()
        }
        .alert(
            "Folder Error",
            isPresented: Binding(
                get: { loadError != nil },
                set: {
                    if !$0 {
                        loadError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadError ?? "Unknown error")
        }
    }

    // MARK: - Load Directory

    private func loadDirectory() {
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ],
                options: [.skipsHiddenFiles]
            )
            .filter { url in
                let values = try? url.resourceValues(
                    forKeys: [.isSymbolicLinkKey]
                )

                return values?.isSymbolicLink != true
            }
            .sorted { first, second in
                let firstIsDirectory = isDirectory(first)
                let secondIsDirectory = isDirectory(second)

                if firstIsDirectory != secondIsDirectory {
                    return firstIsDirectory
                }

                return first.lastPathComponent
                    .localizedCaseInsensitiveCompare(
                        second.lastPathComponent
                    ) == .orderedAscending
            }

        } catch {
            entries = []
            loadError = error.localizedDescription
        }
    }

    // MARK: - Check Directory

    private func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )

        return values?.isDirectory == true &&
               values?.isSymbolicLink != true
    }
}
