// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Downloads folder (under app documents)

private var downloadsDirectoryURL: URL {
  let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  return docs.appendingPathComponent("Downloads", isDirectory: true)
}

// MARK: - Downloads view (Open Browser + Import + list)

struct DownloadsView: View {
  var onOpenBrowser: () -> Void
  var onOpenURL: (URL) -> Void
  var onDismiss: () -> Void

  @State private var items: [DownloadItem] = []
  @State private var showDocumentPicker = false
  @State private var importError: String?
  @State private var zipErrorMessage: String?
  @State private var showExtractProgress = false
  @State private var extractProgress: Progress?
  @State private var extractFileName = ""

  private let legalHomebrewLinks: [(title: String, url: URL)] = [
    ("GameBrew — homebrew games", URL(string: "https://www.gamebrew.org/")!),
    ("WiiBrew — homebrew apps (Wii)", URL(string: "https://wiibrew.org/wiki/Homebrew_apps")!),
    ("GC-Forever — GameCube homebrew", URL(string: "https://www.gc-forever.com/")!)
  ]

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button {
            onOpenBrowser()
            onDismiss()
          } label: {
            Label("Open Browser", systemImage: "safari")
          }
        } header: {
          Text("Download from web")
        } footer: {
          Text("Files downloaded in Safari go to Safari's downloads. To import them into Fin, use Share → Open in Fin. Game files (ISO, WBFS, RVZ, etc.) are auto-added to your library.")
        }

        Section("Legal homebrew links") {
          ForEach(Array(legalHomebrewLinks.enumerated()), id: \.offset) { _, item in
            Button {
              onOpenURL(item.url)
              onDismiss()
            } label: {
              Label(item.title, systemImage: "link")
            }
          }
        }

        Section {
          Button {
            showDocumentPicker = true
          } label: {
            Label("Import File or ZIP", systemImage: "square.and.arrow.down")
          }
        } header: {
          Text("Import")
        } footer: {
          Text("Copy a file or ZIP into the app's Downloads folder. You can extract ZIPs in the Files app or use the Fin file manager.")
        }

        Section("Downloaded files") {
          if items.isEmpty {
            Text("No files yet")
              .foregroundColor(.secondary)
          } else {
            ForEach(items) { item in
              HStack {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                  .foregroundColor(.secondary)
                Text(item.name)
                Spacer()
                if !item.isDirectory, let size = item.fileSizeString {
                  Text(size)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .contentShape(Rectangle())
              .onTapGesture {
                if isGameFile(item) {
                  importAsGame(item)
                } else if isArchive(item) {
                  extractItem(item)
                }
              }
              .contextMenu {
                if isGameFile(item) {
                  Button { importAsGame(item) } label: {
                    Label("Import as Game", systemImage: "gamecontroller")
                  }
                }
                if item.isDirectory {
                  Button { zipFolder(item) } label: {
                    Label("Compress to ZIP", systemImage: "doc.zipper")
                  }
                } else if isArchive(item) {
                  Button { extractItem(item) } label: {
                    Label("Extract", systemImage: "doc.zipper")
                  }
                }
                Button(role: .destructive) { deleteItem(item) } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Downloads")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done", action: onDismiss)
        }
      }
      .onAppear { loadItems() }
      .onReceive(NotificationCenter.default.publisher(for: DocumentOpenService.didOpenDownloadNotification)) { _ in
        loadItems()
      }
      .sheet(isPresented: $showDocumentPicker) {
        DocumentPickerView(contentTypes: [.zip, .data], onPick: { url in
          showDocumentPicker = false
          importFile(at: url)
        }, onDismiss: { showDocumentPicker = false })
      }
      .alert("Import failed", isPresented: Binding(
        get: { importError != nil },
        set: { if !$0 { importError = nil } }
      )) {
        Button("OK", role: .cancel) { importError = nil }
      } message: {
        if let err = importError { Text(err) }
      }
      .alert("Archive", isPresented: Binding(
        get: { zipErrorMessage != nil },
        set: { if !$0 { zipErrorMessage = nil } }
      )) {
        Button("OK", role: .cancel) { zipErrorMessage = nil }
      } message: {
        if let err = zipErrorMessage { Text(err) }
      }
      .sheet(isPresented: $showExtractProgress) {
        ExtractProgressView(fileName: extractFileName, progress: extractProgress)
      }
    }
  }

  private static let gameExtensions: Set<String> = [
    "iso", "gcm", "tgc", "gcz", "ciso", "wbfs", "wad",
    "wia", "rvz", "nkit", "dol", "elf", "m3u"
  ]

  private func isGameFile(_ item: DownloadItem) -> Bool {
    guard !item.isDirectory else { return false }
    let ext = item.id.pathExtension.lowercased()
    return Self.gameExtensions.contains(ext)
  }

  private func importAsGame(_ item: DownloadItem) {
    let source = item.id
    let softwareFolder = UserFolderUtil.getSoftwareFolder()
    let dest = (softwareFolder as NSString).appendingPathComponent(item.name)
    let fm = FileManager.default
    do {
      if !fm.fileExists(atPath: softwareFolder) {
        try fm.createDirectory(atPath: softwareFolder, withIntermediateDirectories: true)
      }
      if fm.fileExists(atPath: dest) {
        try fm.removeItem(atPath: dest)
      }
      try fm.copyItem(atPath: source.path, toPath: dest)
      NotificationCenter.default.post(name: .DOLImportFileFinished, object: nil)
    } catch {
      importError = error.localizedDescription
    }
  }

  private func importGameFilesInDirectory(_ dirURL: URL) {
    let fm = FileManager.default
    let softwareFolder = UserFolderUtil.getSoftwareFolder()
    if !fm.fileExists(atPath: softwareFolder) {
      try? fm.createDirectory(atPath: softwareFolder, withIntermediateDirectories: true)
    }
    guard let enumerator = fm.enumerator(at: dirURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
    var imported = false
    for case let fileURL as URL in enumerator {
      let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      if isDir { continue }
      let ext = fileURL.pathExtension.lowercased()
      if Self.gameExtensions.contains(ext) {
        let dest = (softwareFolder as NSString).appendingPathComponent(fileURL.lastPathComponent)
        if !fm.fileExists(atPath: dest) {
          try? fm.copyItem(atPath: fileURL.path, toPath: dest)
          imported = true
        }
      }
    }
    if imported {
      NotificationCenter.default.post(name: .DOLImportFileFinished, object: nil)
    }
  }

  private func deleteItem(_ item: DownloadItem) {
    try? FileManager.default.removeItem(at: item.id)
    loadItems()
  }

  private func isArchive(_ item: DownloadItem) -> Bool {
    guard !item.isDirectory else { return false }
    let ext = item.id.pathExtension.lowercased()
    return ext == "zip" || ext == "7z"
  }

  private func isZip(_ item: DownloadItem) -> Bool {
    !item.isDirectory && item.id.pathExtension.lowercased() == "zip"
  }

  private func extractItem(_ item: DownloadItem) {
    let url = item.id
    let isZipFile = isZip(item)
    let progress = isZipFile ? Progress() : nil
    extractFileName = item.name
    extractProgress = progress
    showExtractProgress = true
    DispatchQueue.global(qos: .userInitiated).async {
      let result = ZipHelper.extract(file: url, progress: progress)
      DispatchQueue.main.async {
        showExtractProgress = false
        extractProgress = nil
        if let extractedURL = result {
          importGameFilesInDirectory(extractedURL)
          loadItems()
        } else {
          zipErrorMessage = ZipHelper.messageForUnzipFailure()
        }
      }
    }
  }

  private func unzipItem(_ item: DownloadItem) {
    extractItem(item)
  }

  private func zipFolder(_ item: DownloadItem) {
    guard item.isDirectory, ZipHelper.zip(folder: item.id) != nil else {
      zipErrorMessage = ZipHelper.messageForZipFailure()
      return
    }
    loadItems()
  }

  private func loadItems() {
    let url = downloadsDirectoryURL
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    items = DownloadItem.load(from: url)
  }

  private func importFile(at sourceURL: URL) {
    let fm = FileManager.default
    let destDir = downloadsDirectoryURL
    do {
      try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
      let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
      if fm.fileExists(atPath: destURL.path) {
        try fm.removeItem(at: destURL)
      }
      if sourceURL.startAccessingSecurityScopedResource() {
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        try fm.copyItem(at: sourceURL, to: destURL)
      } else {
        try fm.copyItem(at: sourceURL, to: destURL)
      }
      loadItems()
    } catch {
      importError = error.localizedDescription
    }
  }
}

// MARK: - Download item

private struct DownloadItem: Identifiable {
  let id: URL
  let name: String
  let isDirectory: Bool
  let fileSizeString: String?

  static func load(from directoryURL: URL) -> [DownloadItem] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return contents.compactMap { url -> DownloadItem? in
      let name = url.lastPathComponent
      guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
            let isDir = values.isDirectory else { return nil }
      let size: String? = isDir ? nil : (values.fileSize).map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
      return DownloadItem(id: url, name: name, isDirectory: isDir, fileSizeString: size)
    }
    .sorted { a, b in
      if a.isDirectory != b.isDirectory { return a.isDirectory }
      return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
  }
}
