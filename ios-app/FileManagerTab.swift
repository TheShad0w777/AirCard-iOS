import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Manager Tab

struct FileManagerTab: View {
    @State private var showingImporter = false
    @State private var importError: String?

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var libraryURL: URL {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }

    private var cachesURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
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
                    Text("These are folders belonging to AirCard-iOS. Files belonging to other apps are not accessible here.")
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Files", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("Imported files are copied into AirCard's Documents/Imported folder.")
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
                "Import Error",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Unknown error")
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            let selectedURLs = try result.get()

            let importFolder = documentsURL
                .appendingPathComponent("Imported", isDirectory: true)

            try fileManager.createDirectory(
                at: importFolder,
                withIntermediateDirectories: true
            )

            for sourceURL in selectedURLs {
                let hasAccess = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                var destinationURL = importFolder
                    .appendingPathComponent(sourceURL.lastPathComponent)

                if fileManager.fileExists(atPath: destinationURL.path) {
                    let newName = UUID().uuidString + "_" + sourceURL.lastPathComponent
                    destinationURL = importFolder.appendingPathComponent(newName)
                }

                try fileManager.copyItem(
                    at: sourceURL,
                    to: destinationURL
                )
            }
        } catch {
            importError = error.localizedDescription
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
                    description: Text("There are no visible files in this folder.")
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
                                Image(systemName: "square.and.arrow.up")
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
                set: { if !$0 { loadError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadError ?? "Unknown error")
        }
    }

    private func loadDirectory() {
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).sorted {
                let firstIsDirectory = isDirectory($0)
                let secondIsDirectory = isDirectory($1)

                if firstIsDirectory != secondIsDirectory {
                    return firstIsDirectory
                }

                return $0.lastPathComponent.localizedCaseInsensitiveCompare(
                    $1.lastPathComponent
                ) == .orderedAscending
            }
        } catch {
            entries = []
            loadError = error.localizedDescription
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(
            forKeys: [.isDirectoryKey]
        )
        return values?.isDirectory ?? false
    }
}
