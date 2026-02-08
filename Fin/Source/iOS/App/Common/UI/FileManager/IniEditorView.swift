// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// SwiftUI editor for INI/CFG configuration files
struct IniEditorView: View {
  let fileURL: URL
  
  @State private var fileContent: String = ""
  @State private var isLoading = false
  @State private var loadError: String?
  @State private var saveError: String?
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      ZStack {
        TextEditor(text: $fileContent)
          .font(.system(.body, design: .monospaced))
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .padding(8)
          .disabled(isLoading)
        
        if isLoading {
          ProgressView("Loading...")
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(10)
        }
        
        if let error = loadError {
          VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.orange)
            Text("Cannot Load File")
              .font(.headline)
            Text(error)
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding()
          .background(Color(uiColor: .systemBackground))
          .cornerRadius(10)
        }
      }
      .navigationTitle(fileURL.lastPathComponent)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Save") {
            saveFile()
          }
          .disabled(isLoading || loadError != nil)
        }
      }
      .alert("Save Error", isPresented: Binding(
        get: { saveError != nil },
        set: { if !$0 { saveError = nil } }
      )) {
        Button("OK") { saveError = nil }
      } message: {
        if let error = saveError {
          Text(error)
        }
      }
      .onAppear {
        loadFile()
      }
    }
  }
  
  private func loadFile() {
    isLoading = true
    loadError = nil
    
    print("📄 Loading file: \(fileURL.path)")
    print("📄 File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
    print("📄 Is readable: \(FileManager.default.isReadableFile(atPath: fileURL.path))")
    
    // Try to access the file immediately to check permissions
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      DispatchQueue.main.async {
        self.loadError = "File does not exist at path: \(fileURL.path)"
        self.isLoading = false
      }
      print("❌ File does not exist")
      return
    }
    
    guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
      DispatchQueue.main.async {
        self.loadError = "File is not readable. Check permissions."
        self.isLoading = false
      }
      print("❌ File is not readable")
      return
    }
    
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        print("✅ Loaded \(content.count) characters")
        DispatchQueue.main.async {
          self.fileContent = content
          self.isLoading = false
        }
      } catch {
        print("❌ Load error: \(error)")
        print("❌ Error details: \(error.localizedDescription)")
        DispatchQueue.main.async {
          self.loadError = "Failed to load file: \(error.localizedDescription)"
          self.isLoading = false
        }
      }
    }
  }
  
  private func saveFile() {
    do {
      try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
      // Auto-dismiss after successful save
      dismiss()
    } catch {
      saveError = error.localizedDescription
    }
  }
}

#if DEBUG
struct IniEditorView_Previews: PreviewProvider {
  static var previews: some View {
    IniEditorView(fileURL: URL(fileURLWithPath: "/tmp/test.ini"))
  }
}
#endif
