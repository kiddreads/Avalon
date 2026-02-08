// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// View for managing save states - list, rename, delete.
struct SaveStatesView: View {
  @State private var saveStates: [SaveStateItem] = []
  @State private var showingDeleteAlert = false
  @State private var stateToDelete: SaveStateItem?
  @State private var showingRenameAlert = false
  @State private var stateToRename: SaveStateItem?
  @State private var newName = ""
  
  var body: some View {
    List {
      if saveStates.isEmpty {
        Section {
          Text("No save states found")
            .foregroundColor(.secondary)
        }
      } else {
        ForEach(saveStates) { state in
          SaveStateRow(state: state, onRename: {
            stateToRename = state
            newName = state.name
            showingRenameAlert = true
          }, onDelete: {
            stateToDelete = state
            showingDeleteAlert = true
          })
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Save States")
    .onAppear {
      loadSaveStates()
    }
    .alert("Delete Save State", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        if let state = stateToDelete {
          deleteSaveState(state)
        }
      }
    } message: {
      Text("Are you sure you want to delete this save state?")
    }
    .alert("Rename Save State", isPresented: $showingRenameAlert) {
      TextField("Name", text: $newName)
      Button("Cancel", role: .cancel) { }
      Button("Rename") {
        if let state = stateToRename {
          renameSaveState(state, to: newName)
        }
      }
    } message: {
      Text("Enter a new name for this save state.")
    }
  }
  
  private func loadSaveStates() {
    // TODO: Implement actual save state loading from Dolphin
    // This is a placeholder that would integrate with the emulator's save state system
    saveStates = []
  }
  
  private func deleteSaveState(_ state: SaveStateItem) {
    // TODO: Implement actual deletion
    saveStates.removeAll { $0.id == state.id }
  }
  
  private func renameSaveState(_ state: SaveStateItem, to newName: String) {
    // TODO: Implement actual renaming
    if let index = saveStates.firstIndex(where: { $0.id == state.id }) {
      saveStates[index].name = newName
    }
  }
}

// MARK: - Save State Item

struct SaveStateItem: Identifiable {
  let id: String
  var name: String
  let gameTitle: String
  let slot: Int
  let date: Date
  let thumbnailPath: String?
}

// MARK: - Save State Row

struct SaveStateRow: View {
  let state: SaveStateItem
  let onRename: () -> Void
  let onDelete: () -> Void
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(state.name)
          .font(.headline)
        Text(state.gameTitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
        Text("Slot \(state.slot) - \(state.date.formatted())")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive, action: onDelete) {
        Label("Delete", systemImage: "trash")
      }
      Button(action: onRename) {
        Label("Rename", systemImage: "pencil")
      }
      .tint(.orange)
    }
  }
}

#if DEBUG
struct SaveStatesView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SaveStatesView()
    }
  }
}
#endif
