// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// SwiftUI editor for INI/CFG configuration files
struct IniEditorView: View {
  let fileURL: URL
  
  @State private var fileContent: String = ""
  @State private var isLoading = true
  @State private var loadError: String?
  @State private var saveError: String?
  @State private var showingSaveSuccess = false
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      ZStack {
        if isLoading {
          ProgressView("Loading...")
        } else if let error = loadError {
          ContentUnavailableView {
            Label("Cannot Load File", systemImage: "exclamationmark.triangle")
          } description: {
            Text(error)
          }
        } else {
          TextEditor(text: $fileContent)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(8)
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
      .alert("Saved", isPresented: $showingSaveSuccess) {
        Button("OK") { showingSaveSuccess = false }
      } message: {
        Text("File saved successfully!")
      }
      .onAppear {
        loadFile()
      }
    }
  }
  
  private func loadFile() {
    isLoading = true
    loadError = nil
    
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        DispatchQueue.main.async {
          self.fileContent = content
          self.isLoading = false
        }
      } catch {
        DispatchQueue.main.async {
          self.loadError = error.localizedDescription
          self.isLoading = false
        }
      }
    }
  }
  
  private func saveFile() {
    do {
      try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
      showingSaveSuccess = true
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
