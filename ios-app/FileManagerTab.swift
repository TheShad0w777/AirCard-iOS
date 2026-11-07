import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AirliftFFI

struct FileManagerTab: View {
    @State private var showingImporter = false
    @State private var showingImportResult = false

    @State private var importResultTitle = ""
    @State private var importResultMessage = ""

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
                // MARK: - Device AFC Files

                Section {
                    NavigationLink {
                        AFCRemoteDirectoryView(path: "/")
                    } label: {
                        Label(
                            "Browse Device Files",
                            systemImage: "externaldrive.fill"
                        )
                    }
                } header: {
                    Text("Connected Device")
                } footer: {
                    Text(
                        "Browse files exposed by the paired AFC service. " +
                        "Available folders depend on the device and connection."
                    )
                }

                // MARK: - App Storage

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
                        "Other apps' private files are not accessible here."
                    )
                }

                // MARK: - Import

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
                        "Selected files will be copied into Documents/Imported."
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
                .appendingPathComponent("Imported", isDirectory: true)

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
            .appendingPathComponent(sourceURL.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            let newName =
                UUID().uuidString + "_" +
                sourceURL.lastPathComponent

            destinationURL = destinationFolder
                .appendingPathComponent(newName)
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)

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

// MARK: - AFC Remote Directory Browser

struct AFCRemoteDirectoryView: View {
    let path: String

    @State private var entries: [String] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var directoryTitle: String {
        if path == "/" {
            return "Device Files"
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading AFC directory…")
                    Spacer()
                }
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "folder",
                    description: Text(
                        "This directory is empty or contains no visible entries."
                    )
                )
            } else {
                ForEach(entries, id: \.self) { name in
                    NavigationLink {
                        AFCRemoteDirectoryView(
                            path: childPath(for: name)
                        )
                    } label: {
                        HStack {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)

                            Text(name)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(directoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    loadDirectory()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            loadDirectory()
        }
        .alert(
            "AFC Error",
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

    // MARK: - Build Remote Path

    private func childPath(for name: String) -> String {
        if path == "/" {
            return "/" + name
        }

        return path + "/" + name
    }

    // MARK: - Load AFC Directory

    private func loadDirectory() {
        guard !isLoading else {
            return
        }

        isLoading = true
        loadError = nil

        // PairingController is MainActor-isolated.
        // Resolve the pairing path before starting background work.
        Task { @MainActor in
            let pairingPath = PairingController.pairingFilePath()

            guard FileManager.default.fileExists(
                atPath: pairingPath
            ) else {
                isLoading = false
                entries = []
                loadError =
                    "Pairing file not found. Pair your device with AirCard first."
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                var jsonPointer: UnsafeMutablePointer<CChar>? = nil
                var errorPointer: UnsafeMutablePointer<CChar>? = nil

                let resultCode = pairingPath.withCString { pairingCString in
                    path.withCString { pathCString in
                        al_afc_list_directory(
                            pairingCString,
                            pathCString,
                            &jsonPointer,
                            &errorPointer
                        )
                    }
                }

                let errorMessage = errorPointer.map {
                    String(cString: $0)
                }

                var receivedEntries: [String] = []

                if resultCode == 0, let jsonPointer {
                    let jsonString = String(cString: jsonPointer)

                    if let data = jsonString.data(using: .utf8),
                       let decoded = try? JSONSerialization.jsonObject(
                           with: data
                       ) as? [String] {
                        receivedEntries = decoded
                    }
                }

                // Release Rust-owned strings.
                if let jsonPointer {
                    al_string_free(jsonPointer)
                }

                if let errorPointer {
                    al_string_free(errorPointer)
                }

                DispatchQueue.main.async {
                    isLoading = false

                    if resultCode == 0 {
                        entries = receivedEntries
                    } else {
                        entries = []
                        loadError =
                            errorMessage ??
                            "AFC request failed. Error code: \(resultCode)"
                    }
                }
            }
        }
    }
}

// MARK: - App Sandbox Directory Browser

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
