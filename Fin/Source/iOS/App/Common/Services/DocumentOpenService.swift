// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import UIKit
final class DocumentOpenService: NSObject, UIApplicationDelegate {
  static let didOpenDownloadNotification = Notification.Name("DocumentOpenService.didOpenDownload")

  private static let gameFileExtensions: Set<String> = [
    "iso", "gcm", "tgc", "gcz", "ciso", "wbfs", "wad",
    "wia", "rvz", "nkit", "dol", "elf", "m3u",
    "zip", "7z"
  ]

  private static var downloadsDirectoryURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      .appendingPathComponent("Downloads", isDirectory: true)
  }

  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.isFileURL else { return false }

    let ext = url.pathExtension.lowercased()
    if Self.gameFileExtensions.contains(ext) {
      ImportFileManager.shared().importFile(at: url)
      return true
    }

    let didStart = url.startAccessingSecurityScopedResource()
    defer { if didStart { url.stopAccessingSecurityScopedResource() } }

    let fm = FileManager.default
    let destDir = Self.downloadsDirectoryURL
    do {
      try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
      let destURL = destDir.appendingPathComponent(url.lastPathComponent)
      if fm.fileExists(atPath: destURL.path) {
        try fm.removeItem(at: destURL)
      }
      try fm.copyItem(at: url, to: destURL)
      NotificationCenter.default.post(name: Self.didOpenDownloadNotification, object: nil)
      return true
    } catch {
      return true
    }
  }
}
