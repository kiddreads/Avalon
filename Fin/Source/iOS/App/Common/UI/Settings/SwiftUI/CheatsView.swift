// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

// MARK: - Cheats View Model

@MainActor
final class CheatsViewModel: ObservableObject {
  @Published var codes: [DOLGeckoCode] = []
  @Published var isLoading = false
  @Published var isDownloading = false
  @Published var gameName: String = ""
  @Published var gameId: String = ""
  @Published var showDownloadResult = false
  @Published var downloadResultTitle = ""
  @Published var downloadResultMessage = ""
  
  init() {
    loadCodes()
  }
  
  func loadCodes() {
    DOLGeckoBridge.loadCodesForCurrentGame()
    codes = DOLGeckoBridge.codes()
    gameName = DOLGeckoBridge.currentGameName()
    gameId = DOLGeckoBridge.currentGameId()
  }
  
  func setEnabled(_ enabled: Bool, at index: Int) {
    guard index >= 0 && index < codes.count else { return }
    DOLGeckoBridge.setEnabled(enabled, forCodeAt: index)
    codes[index].enabled = enabled
  }
  
  func deleteCode(at index: Int) {
    guard index >= 0 && index < codes.count else { return }
    DOLGeckoBridge.deleteCode(at: index)
    codes.remove(at: index)
  }
  
  func downloadCodes() {
    isDownloading = true
    
    DOLGeckoBridge.downloadCodes { [weak self] success, downloadedCount, addedCount, errorMessage in
      Task { @MainActor in
        guard let self = self else { return }
        self.isDownloading = false
        if success {
          self.downloadResultTitle = "Download Complete"
          self.downloadResultMessage = "Downloaded \(downloadedCount) codes. Added \(addedCount) new codes."
          self.loadCodes()
        } else {
          self.downloadResultTitle = "Download Failed"
          self.downloadResultMessage = errorMessage ?? "Unknown error"
        }
        self.showDownloadResult = true
      }
    }
  }
  
  func enableAllCodes() {
    for i in 0..<codes.count {
      DOLGeckoBridge.setEnabled(true, forCodeAt: i)
      codes[i].enabled = true
    }
  }
  
  func disableAllCodes() {
    for i in 0..<codes.count {
      DOLGeckoBridge.setEnabled(false, forCodeAt: i)
      codes[i].enabled = false
    }
  }
}

// MARK: - Cheats View

struct CheatsView: View {
  @StateObject private var viewModel = CheatsViewModel()
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      List {
        // Game info header
        if !viewModel.gameId.isEmpty {
          Section {
            VStack(alignment: .leading, spacing: 4) {
              Text(viewModel.gameName)
                .font(.headline)
              Text("ID: \(viewModel.gameId)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
          }
        }
        
        // Actions section
        Section {
          Button(action: { viewModel.downloadCodes() }) {
            HStack {
              Label("Download Codes", systemImage: "arrow.down.circle")
              if viewModel.isDownloading {
                Spacer()
                ProgressView()
              }
            }
          }
          .disabled(viewModel.isDownloading || viewModel.gameId.isEmpty)
          
          if !viewModel.codes.isEmpty {
            Button(action: { viewModel.enableAllCodes() }) {
              Label("Enable All", systemImage: "checkmark.circle")
            }
            
            Button(action: { viewModel.disableAllCodes() }) {
              Label("Disable All", systemImage: "xmark.circle")
            }
          }
        }
        
        // Codes section
        if viewModel.codes.isEmpty {
          Section {
            VStack(spacing: 12) {
              Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
              Text("No Cheats Available")
                .font(.headline)
              Text("Tap \"Download Codes\" to fetch cheats for this game from the internet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
          }
        } else {
          Section(header: Text("Available Cheats (\(viewModel.codes.count))")) {
            ForEach(Array(viewModel.codes.enumerated()), id: \.element.codeIndex) { index, code in
              CheatRow(code: code) { enabled in
                viewModel.setEnabled(enabled, at: index)
              }
            }
            .onDelete { indexSet in
              for index in indexSet.sorted().reversed() {
                viewModel.deleteCode(at: index)
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Cheats")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          if !viewModel.codes.isEmpty {
            EditButton()
          }
        }
      }
      .refreshable {
        viewModel.loadCodes()
      }
      .alert(viewModel.downloadResultTitle, isPresented: $viewModel.showDownloadResult) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.downloadResultMessage)
      }
    }
  }
}

// MARK: - Cheat Row

struct CheatRow: View {
  let code: DOLGeckoCode
  let onToggle: (Bool) -> Void
  
  @State private var isExpanded = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(code.name)
            .font(.body)
          
          if !code.creator.isEmpty {
            Text("by \(code.creator)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        
        Spacer()
        
        Toggle("", isOn: Binding(
          get: { code.enabled },
          set: { onToggle($0) }
        ))
        .labelsHidden()
      }
      
      if let notes = code.notes, !notes.isEmpty {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
          HStack {
            Text(isExpanded ? "Hide Details" : "Show Details")
              .font(.caption)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption)
          }
          .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        
        if isExpanded {
          Text(notes)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
      }
      
      if code.userDefined {
        Text("User-defined")
          .font(.caption2)
          .foregroundColor(.orange)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Compact Cheats View (for quick access in emulation)

struct CompactCheatsView: View {
  @StateObject private var viewModel = CheatsViewModel()
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      Group {
        if viewModel.codes.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
              .font(.system(size: 48))
              .foregroundColor(.secondary)
            
            Text("No Cheats Available")
              .font(.headline)
            
            Text("Tap below to download cheats")
              .font(.subheadline)
              .foregroundColor(.secondary)
            
            Button(action: { viewModel.downloadCodes() }) {
              HStack {
                if viewModel.isDownloading {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                  Image(systemName: "arrow.down.circle")
                }
                Text("Download Codes")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.accentColor)
              .foregroundColor(.white)
              .cornerRadius(10)
            }
            .disabled(viewModel.isDownloading)
            .padding(.horizontal, 40)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List {
            ForEach(Array(viewModel.codes.enumerated()), id: \.element.codeIndex) { index, code in
              HStack {
                VStack(alignment: .leading) {
                  Text(code.name)
                    .font(.body)
                  if !code.creator.isEmpty {
                    Text("by \(code.creator)")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                  get: { code.enabled },
                  set: { viewModel.setEnabled($0, at: index) }
                ))
                .labelsHidden()
              }
            }
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("Cheats")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          if !viewModel.codes.isEmpty {
            Menu {
              Button(action: { viewModel.enableAllCodes() }) {
                Label("Enable All", systemImage: "checkmark.circle")
              }
              Button(action: { viewModel.disableAllCodes() }) {
                Label("Disable All", systemImage: "xmark.circle")
              }
              Divider()
              Button(action: { viewModel.downloadCodes() }) {
                Label("Download More", systemImage: "arrow.down.circle")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
            }
          }
        }
      }
      .alert(viewModel.downloadResultTitle, isPresented: $viewModel.showDownloadResult) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.downloadResultMessage)
      }
    }
  }
}

// MARK: - Preview

#if DEBUG
struct CheatsView_Previews: PreviewProvider {
  static var previews: some View {
    CheatsView()
  }
}
#endif
