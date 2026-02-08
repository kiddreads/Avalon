// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

// MARK: - File Manager (start inside app folder / Fin)

struct FileManagerView: View {
  private static var finRootURL: URL {
    URL(fileURLWithPath: UserFolderUtil.getUserFolder())
  }

  var body: some View {
    NavigationView {
      ZStack {
        AppBackground()
        FileManagerListView(
          url: Self.finRootURL,
          displayName: "Fin"
        )
      }
      .navigationTitle("File Manager")
      .navigationBarTitleDisplayMode(.large)
    }
    .navigationViewStyle(.stack)
  }
}

// MARK: - View mode and grid size (persisted)

private let kFileManagerViewModeKey = "fin.fileManager.viewMode"
private let kFileManagerGridSizeKey = "fin.fileManager.gridSize"

private enum FileManagerViewMode: String, CaseIterable {
  case list = "list"
  case icons = "icons"
}

private enum FileManagerGridSize: String, CaseIterable {
  case small = "small"
  case medium = "medium"
  case large = "large"

  var minimumCellWidth: CGFloat {
    switch self {
    case .small: return 72
    case .medium: return 96
    case .large: return 128
    }
  }

  var label: String {
    switch self {
    case .small: return "Small"
    case .medium: return "Medium"
    case .large: return "Large"
    }
  }
}

// MARK: - List of items in a directory

private struct FileManagerListView: View {
  let url: URL
  let displayName: String

  @State private var items: [FileManagerItem] = []
  @State private var loadError: String?
  @State private var itemToDelete: FileManagerItem?
  @State private var deleteError: String?
  @State private var zipErrorMessage: String?
  @State private var showExtractProgress = false
  @State private var extractProgress: Progress?
  @State private var extractFileName = ""
  @State private var showIniEditor = false
  @State private var iniFileToEdit: URL?
  @AppStorage(kFileManagerViewModeKey) private var viewMode: String = FileManagerViewMode.list.rawValue
  @AppStorage(kFileManagerGridSizeKey) private var gridSizeRaw: String = FileManagerGridSize.medium.rawValue

  private var viewModeEnum: FileManagerViewMode {
    get { FileManagerViewMode(rawValue: viewMode) ?? .list }
    set { viewMode = newValue.rawValue }
  }

  private var gridSize: FileManagerGridSize {
    get { FileManagerGridSize(rawValue: gridSizeRaw) ?? .medium }
    set { gridSizeRaw = newValue.rawValue }
  }

  private var gridColumns: [GridItem] {
    [GridItem(.adaptive(minimum: gridSize.minimumCellWidth, maximum: 160), spacing: 12)]
  }

  var body: some View {
    content
      .navigationTitle(displayName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Menu {
            Picker("View", selection: $viewMode) {
              Label("List", systemImage: "list.bullet").tag(FileManagerViewMode.list.rawValue)
              Label("Icons", systemImage: "square.grid.2x2").tag(FileManagerViewMode.icons.rawValue)
            }
            .pickerStyle(.inline)
            if viewModeEnum == .icons {
              Divider()
              Picker("Grid size", selection: $gridSizeRaw) {
                Text("Small").tag(FileManagerGridSize.small.rawValue)
                Text("Medium").tag(FileManagerGridSize.medium.rawValue)
                Text("Large").tag(FileManagerGridSize.large.rawValue)
              }
              .pickerStyle(.inline)
            }
          } label: {
            Label("View options", systemImage: "line.3.horizontal.circle")
          }
        }
      }
      .onAppear { loadContents() }
      .alert("Delete \"\(itemToDelete?.name ?? "")\"?", isPresented: Binding(
        get: { itemToDelete != nil },
        set: { if !$0 { itemToDelete = nil; deleteError = nil } }
      )) {
        Button("Cancel", role: .cancel) { itemToDelete = nil }
        Button("Delete", role: .destructive) {
          if let item = itemToDelete {
            deleteItem(item)
          }
          itemToDelete = nil
        }
      } message: {
        if let item = itemToDelete {
          Text(item.isDirectory ? "This folder and its contents will be removed." : "This file will be removed.")
        }
      }
      .alert("Cannot delete", isPresented: Binding(
        get: { deleteError != nil },
        set: { if !$0 { deleteError = nil } }
      )) {
        Button("OK", role: .cancel) { deleteError = nil }
      } message: {
        if let err = deleteError { Text(err) }
      }
      .alert("Archive", isPresented: Binding(
        get: { zipErrorMessage != nil },
        set: { if !$0 { zipErrorMessage = nil } }
      )) {
        Button("OK", role: .cancel) { zipErrorMessage = nil }
      } message: {
        if let msg = zipErrorMessage { Text(msg) }
      }
      .sheet(isPresented: $showExtractProgress) {
        ExtractProgressView(fileName: extractFileName, progress: extractProgress)
      }
      .sheet(isPresented: $showIniEditor) {
        if let fileURL = iniFileToEdit {
          IniEditorView(fileURL: fileURL)
        }
      }
  }

  private var content: some View {
    Group {
      if let error = loadError {
        ContentUnavailableView {
          Label("Unable to load", systemImage: "folder.badge.questionmark")
        } description: {
          Text(error)
        }
      } else if items.isEmpty {
        ContentUnavailableView("This folder is empty", systemImage: "folder")
      } else if viewModeEnum == .icons {
        iconGridView
      } else {
        listView
      }
    }
  }

  private func isArchive(_ item: FileManagerItem) -> Bool {
    guard !item.isDirectory else { return false }
    let ext = item.url.pathExtension.lowercased()
    return ext == "zip" || ext == "7z"
  }

  private func isZip(_ item: FileManagerItem) -> Bool {
    !item.isDirectory && item.url.pathExtension.lowercased() == "zip"
  }

  private func isIniFile(_ item: FileManagerItem) -> Bool {
    !item.isDirectory && (item.url.pathExtension.lowercased() == "ini" || item.url.pathExtension.lowercased() == "cfg")
  }

  private func extractItem(_ item: FileManagerItem) {
    let url = item.url
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
        if result != nil {
          loadContents()
        } else {
          zipErrorMessage = ZipHelper.messageForUnzipFailure()
        }
      }
    }
  }

  private func unzipItem(_ item: FileManagerItem) {
    extractItem(item)
  }

  private func zipFolder(_ item: FileManagerItem) {
    guard ZipHelper.zip(folder: item.url) != nil else {
      zipErrorMessage = ZipHelper.messageForZipFailure()
      return
    }
    loadContents()
  }

  private func deleteItem(_ item: FileManagerItem) {
    let fm = FileManager.default
    do {
      try fm.removeItem(at: item.url)
      loadContents()
    } catch {
      deleteError = error.localizedDescription
    }
  }

  private var listView: some View {
    List {
      ForEach(items) { item in
        if item.isDirectory {
          NavigationLink(destination: FileManagerListView(
            url: item.url,
            displayName: item.name
          )) {
            Label(item.name, systemImage: "folder.fill")
              .foregroundColor(.accentColor)
          }
          .contextMenu {
            Button { zipFolder(item) } label: {
              Label("Compress to ZIP", systemImage: "doc.zipper")
            }
            Button(role: .destructive) { itemToDelete = item } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        } else {
          HStack {
            Label(item.name, systemImage: fileIcon(for: item.url))
              .foregroundColor(.secondary)
            Spacer()
            if let size = item.fileSizeString {
              Text(size)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .contentShape(Rectangle())
          .onTapGesture {
            if isArchive(item) {
              extractItem(item)
            } else if isIniFile(item) {
              iniFileToEdit = item.url
              showIniEditor = true
            }
          }
          .contextMenu {
            if isIniFile(item) {
              Button {
                iniFileToEdit = item.url
                showIniEditor = true
              } label: {
                Label("Edit", systemImage: "pencil")
              }
            }
            if isArchive(item) {
              Button { extractItem(item) } label: {
                Label("Extract", systemImage: "doc.zipper")
              }
            }
            Button(role: .destructive) { itemToDelete = item } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
  }

  private var iconGridView: some View {
    ScrollView {
      LazyVGrid(columns: gridColumns, spacing: 12) {
        ForEach(items) { item in
          if item.isDirectory {
            NavigationLink(destination: FileManagerListView(
              url: item.url,
              displayName: item.name
            )) {
              FileManagerIconCell(item: item, fileIconName: fileIcon(for: item.url))
            }
            .contextMenu {
              Button { zipFolder(item) } label: {
                Label("Compress to ZIP", systemImage: "doc.zipper")
              }
              Button(role: .destructive) { itemToDelete = item } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          } else {
            FileManagerIconCell(item: item, fileIconName: fileIcon(for: item.url))
              .contentShape(Rectangle())
              .onTapGesture {
                if isArchive(item) {
                  extractItem(item)
                } else if isIniFile(item) {
                  iniFileToEdit = item.url
                  showIniEditor = true
                }
              }
              .contextMenu {
                if isIniFile(item) {
                  Button {
                    iniFileToEdit = item.url
                    showIniEditor = true
                  } label: {
                    Label("Edit", systemImage: "pencil")
                  }
                }
                if isArchive(item) {
                  Button { extractItem(item) } label: {
                    Label("Extract", systemImage: "doc.zipper")
                  }
                }
                Button(role: .destructive) { itemToDelete = item } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
          }
        }
      }
      .padding()
    }
  }

  private func fileIcon(for url: URL) -> String {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "ini", "cfg": return "doc.plaintext"
    case "png", "jpg", "jpeg": return "photo"
    case "glsl", "shader": return "chevron.left.forwardslash.chevron.right"
    case "zip", "7z": return "doc.zipper"
    default: return "doc"
    }
  }
}

// MARK: - Grid icon cell (icon + name)

private struct FileManagerIconCell: View {
  let item: FileManagerItem
  let fileIconName: String

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: item.isDirectory ? "folder.fill" : fileIconName)
        .font(.system(size: 36))
        .foregroundColor(item.isDirectory ? .accentColor : .secondary)
        .frame(height: 44)
      Text(item.name)
        .font(.caption2)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .foregroundColor(.primary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(uiColor: .secondarySystemGroupedBackground))
    )
  }
}

// MARK: - Item model

private struct FileManagerItem: Identifiable {
  let id: URL
  let url: URL
  let name: String
  let isDirectory: Bool
  let fileSizeString: String?

  static func load(from directoryURL: URL) -> [FileManagerItem] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return contents.compactMap { url -> FileManagerItem? in
      let name = url.lastPathComponent
      guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
            let isDir = values.isDirectory else { return nil }
      let size: String? = isDir ? nil : (values.fileSize).map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
      return FileManagerItem(id: url, url: url, name: name, isDirectory: isDir, fileSizeString: size)
    }
    .sorted { a, b in
      if a.isDirectory != b.isDirectory { return a.isDirectory }
      return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
  }
}

// MARK: - Load directory contents

private extension FileManagerListView {
  func loadContents() {
    loadError = nil
    items = FileManagerItem.load(from: url)
  }
}
