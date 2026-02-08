// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import SevenZip
import ZIPFoundation

/// Unzip and zip helpers using ZIPFoundation; 7z extraction via SevenZip.
enum ZipHelper {

  /// Unzips `zipURL` into the same directory as the zip; destination folder name = zip name without extension.
  /// If that folder already exists, appends a number (e.g. "name (1)").
  /// - Parameter progress: Optional. When provided, ZIPFoundation updates it during extraction (for UI).
  /// - Returns: URL of the created folder, or nil on failure.
  static func unzip(file zipURL: URL, progress: Progress? = nil, fileManager: FileManager = .default) -> URL? {
    let parent = zipURL.deletingLastPathComponent()
    let baseName = zipURL.deletingPathExtension().lastPathComponent
    var destDir = parent.appendingPathComponent(baseName, isDirectory: true)
    var counter = 0
    while fileManager.fileExists(atPath: destDir.path) {
      counter += 1
      destDir = parent.appendingPathComponent("\(baseName) (\(counter))", isDirectory: true)
    }
    do {
      try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
      if let progress = progress {
        try fileManager.unzipItem(at: zipURL, to: destDir, progress: progress)
      } else {
        try fileManager.unzipItem(at: zipURL, to: destDir)
      }
      return destDir
    } catch {
      return nil
    }
  }

  /// Extracts a 7z archive at `sevenZURL` into the same directory; folder name = archive name without extension.
  /// If that folder already exists, appends a number (e.g. "name (1)").
  /// - Returns: URL of the created folder, or nil on failure.
  static func unzip7z(file sevenZURL: URL, fileManager: FileManager = .default) -> URL? {
    let parent = sevenZURL.deletingLastPathComponent()
    let baseName = sevenZURL.deletingPathExtension().lastPathComponent
    var destDir = parent.appendingPathComponent(baseName, isDirectory: true)
    var counter = 0
    while fileManager.fileExists(atPath: destDir.path) {
      counter += 1
      destDir = parent.appendingPathComponent("\(baseName) (\(counter))", isDirectory: true)
    }
    do {
      try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
      let archive = try Archive(fileURL: sevenZURL)
      for entry in archive.entries {
        let path = entry.path
        guard !path.isEmpty else { continue }
        // Normalize path: remove leading slashes and resolve ".."
        let components = path.split(separator: "/").map(String.init).filter { $0 != "." && $0 != ".." }
        guard !components.isEmpty else { continue }
        let isDirectory = path.hasSuffix("/")
        let entryURL = components.reduce(destDir) { $0.appendingPathComponent($1, isDirectory: false) }
        if isDirectory {
          try fileManager.createDirectory(at: entryURL, withIntermediateDirectories: true)
        } else {
          let parentDir = entryURL.deletingLastPathComponent()
          try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
          let data = try archive.extract(entry: entry)
          try data.write(to: entryURL)
        }
      }
      return destDir
    } catch {
      return nil
    }
  }

  /// Extracts a supported archive (zip or 7z). For zip, optional progress is used for UI.
  /// - Returns: URL of the created folder, or nil on failure.
  static func extract(file url: URL, progress: Progress? = nil, fileManager: FileManager = .default) -> URL? {
    let ext = url.pathExtension.lowercased()
    if ext == "zip" {
      return unzip(file: url, progress: progress, fileManager: fileManager)
    }
    if ext == "7z" {
      return unzip7z(file: url, fileManager: fileManager)
    }
    return nil
  }

  /// Zips the folder at `folderURL` to a zip file in the same directory; zip name = folder name + ".zip".
  /// If that file already exists, appends a number (e.g. "name (1).zip").
  /// - Returns: URL of the created zip, or nil on failure.
  static func zip(folder folderURL: URL, fileManager: FileManager = .default) -> URL? {
    let parent = folderURL.deletingLastPathComponent()
    let baseName = folderURL.lastPathComponent
    var destZip = parent.appendingPathComponent("\(baseName).zip")
    var counter = 0
    while fileManager.fileExists(atPath: destZip.path) {
      counter += 1
      destZip = parent.appendingPathComponent("\(baseName) (\(counter)).zip")
    }
    do {
      try fileManager.zipItem(at: folderURL, to: destZip, shouldKeepParent: true, compressionMethod: .deflate)
      return destZip
    } catch {
      return nil
    }
  }

  /// Returns a user-facing error message for unzip/zip failure, or nil if no specific message.
  static func messageForUnzipFailure() -> String {
    "Could not extract the archive."
  }

  static func messageForZipFailure() -> String {
    "Could not create the archive."
  }
}
