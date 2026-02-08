// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import Combine

// MARK: - Mapping Type Enum (Swift)

enum MappingType: Int {
  case pad = 0
  case wiimote = 1
  
  var dolMappingType: DOLMappingType {
    switch self {
    case .pad: return .pad
    case .wiimote: return .wiimote
    }
  }
}

// MARK: - Mapping View Model

@MainActor
final class MappingViewModel: ObservableObject {
  let mappingType: MappingType
  let port: Int
  
  @Published var defaultDevice: String = ""
  @Published var sections: [[String: Any]] = []
  @Published var currentExtension: DOLWiimoteExtension = .none
  @Published var isInputDetecting = false
  @Published var showInputAlert = false
  @Published var inputDetectionTimer: Timer?
  
  // For input detection
  var pendingControlSection: Int = 0
  var pendingControlRow: Int = 0
  var pendingControlIndex: Int = 0
  
  init(mappingType: MappingType, port: Int) {
    self.mappingType = mappingType
    self.port = port
    
    DOLMappingBridge.initialize(for: mappingType.dolMappingType, port: port)
    reload()
  }
  
  func reload() {
    defaultDevice = DOLMappingBridge.defaultDevice()
    sections = DOLMappingBridge.controlGroupSections()
    if mappingType == .wiimote {
      currentExtension = DOLMappingBridge.currentExtension()
    }
  }
  
  func save() {
    DOLMappingBridge.saveConfig()
  }
  
  func setDevice(_ device: String) {
    DOLMappingBridge.setDefaultDevice(device)
    defaultDevice = device
    save()
  }
  
  func setExtension(_ index: Int) {
    DOLMappingBridge.setExtension(index)
    currentExtension = DOLMappingBridge.currentExtension()
    sections = DOLMappingBridge.controlGroupSections()
    save()
  }
  
  func startInputDetection(section: Int, row: Int, controlIndex: Int) {
    pendingControlSection = section
    pendingControlRow = row
    pendingControlIndex = controlIndex
    
    guard DOLMappingBridge.startInputDetection() else { return }
    
    isInputDetecting = true
    showInputAlert = true
    
    // Start polling timer
    inputDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.checkInputDetection()
      }
    }
  }
  
  func checkInputDetection() {
    guard isInputDetecting else { return }
    
    if DOLMappingBridge.isInputDetectionComplete() {
      inputDetectionTimer?.invalidate()
      inputDetectionTimer = nil
      isInputDetecting = false
      showInputAlert = false
      
      if let expression = DOLMappingBridge.detectedInputExpression() {
        DOLMappingBridge.setExpression(expression, forControlAtSection: pendingControlSection, row: pendingControlRow, controlIndex: pendingControlIndex)
        save()
        // Refresh to show updated expression
        sections = DOLMappingBridge.controlGroupSections()
      }
    }
  }
  
  func cancelInputDetection() {
    DOLMappingBridge.cancelInputDetection()
    inputDetectionTimer?.invalidate()
    inputDetectionTimer = nil
    isInputDetecting = false
    showInputAlert = false
  }

  func setTouchscreenInput(_ inputName: String, section: Int, row: Int, controlIndex: Int) {
    let expr = "`\(inputName)`"
    DOLMappingBridge.setExpression(expr, forControlAtSection: section, row: row, controlIndex: controlIndex)
    save()
    sections = DOLMappingBridge.controlGroupSections()
  }
  
  func clearControl(section: Int, row: Int, controlIndex: Int) {
    DOLMappingBridge.clearExpressionForControl(atSection: section, row: row, controlIndex: controlIndex)
    save()
    sections = DOLMappingBridge.controlGroupSections()
  }
  
  func setEnabled(_ enabled: Bool, section: Int, row: Int) {
    DOLMappingBridge.setEnabled(enabled, forGroupAtSection: section, row: row)
    save()
  }
  
  func setDoubleValue(_ value: Double, section: Int, row: Int, settingIndex: Int) {
    DOLMappingBridge.setDoubleValue(value, forSettingAtSection: section, row: row, settingIndex: settingIndex)
    save()
  }
  
  func setBoolValue(_ value: Bool, section: Int, row: Int, settingIndex: Int) {
    DOLMappingBridge.setBoolValue(value, forSettingAtSection: section, row: row, settingIndex: settingIndex)
    save()
  }
}

// MARK: - Main Mapping Root View

struct MappingRootView: View {
  @StateObject private var viewModel: MappingViewModel
  @Environment(\.dismiss) private var dismiss
  
  @State private var showDeviceSheet = false
  @State private var showProfileSheet = false
  @State private var showSaveProfileAlert = false
  @State private var profileName = ""
  @State private var showSaveSuccessAlert = false
  @State private var showSaveErrorAlert = false
  
  init(mappingType: MappingType, port: Int) {
    _viewModel = StateObject(wrappedValue: MappingViewModel(mappingType: mappingType, port: port))
  }
  
  private var mappingTitle: String {
    switch viewModel.mappingType {
    case .pad: return "Port \(viewModel.port + 1) – GameCube"
    case .wiimote: return "Wii Remote \(viewModel.port + 1)"
    }
  }
  
  private var deviceDisplayName: String {
    let raw = viewModel.defaultDevice
    guard !raw.isEmpty else { return "Touchscreen" }
    let parts = raw.components(separatedBy: "/")
    if parts.count >= 3 { return parts[2] }
    return raw
  }
  
  private var deviceIconName: String {
    let raw = viewModel.defaultDevice
    if raw.isEmpty { return "hand.draw.fill" }
    if raw.contains("Touchscreen") { return "hand.draw.fill" }
    if raw.contains("DualSense") || raw.contains("DualShock") || raw.contains("MFi") { return "gamecontroller.fill" }
    return "gamecontroller"
  }
  
  var body: some View {
    NavigationView {
      List {
        // Top: Device + Load profile (DS4-style: pick device and load profile in one place)
        Section {
          Button {
            showDeviceSheet = true
          } label: {
            HStack(spacing: 12) {
              Image(systemName: deviceIconName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
              VStack(alignment: .leading, spacing: 2) {
                Text("Device")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                Text(deviceDisplayName)
                  .font(.body.weight(.medium))
                  .foregroundColor(.primary)
                  .lineLimit(1)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 6)
          }
          .buttonStyle(.plain)
          Button {
            showProfileSheet = true
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "square.and.arrow.down")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
              Text("Load profile")
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 6)
          }
          .buttonStyle(.plain)
        } header: {
          Text("Device & profile")
        }
        
        // Controller map – all buttons/groups, tap one to edit
        if !viewModel.sections.isEmpty {
          Section(header: Text("Controller map")) {
            MappingQuickMapView(viewModel: viewModel)
          }
        }
        
        // Save profile
        Section {
          Button {
            showSaveProfileAlert = true
          } label: {
            Label("Save profile", systemImage: "square.and.arrow.up")
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle(mappingTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showDeviceSheet) {
        NavigationView {
          MappingDeviceView(viewModel: viewModel)
        }
      }
      .sheet(isPresented: $showProfileSheet) {
        NavigationView {
          MappingProfileLoadView(viewModel: viewModel, isPresented: $showProfileSheet)
        }
      }
      .alert("Enter Name", isPresented: $showSaveProfileAlert) {
        TextField("Profile Name", text: $profileName)
        Button("Cancel", role: .cancel) {
          profileName = ""
        }
        Button("Save") {
          if DOLMappingBridge.saveProfile(withName: profileName) {
            showSaveSuccessAlert = true
          } else {
            showSaveErrorAlert = true
          }
          profileName = ""
        }
      } message: {
        Text("Please enter a name for this profile.")
      }
      .alert("Saved", isPresented: $showSaveSuccessAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Profile saved successfully.")
      }
      .alert("Error", isPresented: $showSaveErrorAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Failed to save profile. Please enter a valid name.")
      }
      .alert("Press Now", isPresented: $viewModel.showInputAlert) {
        Button("Cancel", role: .cancel) {
          viewModel.cancelInputDetection()
        }
      } message: {
        Text("Press a button or move an axis on your controller...")
      }
    }
    .navigationViewStyle(.stack)
    .onAppear {
      viewModel.reload()
    }
  }
}

// MARK: - Quick Map (individual button icons, tap to remap)

private enum ControlMapItem: Identifiable {
  case extensionGroup(id: String, sectionIndex: Int, rowIndex: Int, group: DOLControlGroup)
  case control(id: String, sectionIndex: Int, rowIndex: Int, controlIndex: Int, control: DOLControl, groupUiName: String)
  
  var id: String {
    switch self {
    case .extensionGroup(let id, _, _, _): return id
    case .control(let id, _, _, _, _, _): return id
    }
  }
}

private func iconForControl(_ uiName: String) -> String {
  let lower = uiName.lowercased()
  if lower == "a" || lower.hasPrefix("a ") { return "a.circle.fill" }
  if lower == "b" || lower.hasPrefix("b ") { return "b.circle.fill" }
  if lower == "x" || lower.hasPrefix("x ") { return "xmark.circle.fill" }
  if lower == "y" || lower.hasPrefix("y ") { return "y.circle.fill" }
  if lower.contains("start") { return "play.circle.fill" }
  if lower.contains("home") { return "house.circle.fill" }
  if lower.contains("z") && !lower.contains("zl") && !lower.contains("zr") { return "z.circle.fill" }
  if lower.contains("zl") || lower.contains("l ") { return "l.circle.fill" }
  if lower.contains("zr") || lower.contains("r ") { return "r.circle.fill" }
  if lower.contains("up") || lower == "d-pad up" { return "chevron.up.circle.fill" }
  if lower.contains("down") || lower == "d-pad down" { return "chevron.down.circle.fill" }
  if lower.contains("left") || lower == "d-pad left" { return "chevron.left.circle.fill" }
  if lower.contains("right") || lower == "d-pad right" { return "chevron.right.circle.fill" }
  if lower.contains("stick") && (lower.contains("x") || lower.contains("left") || lower.contains("right")) { return "circle.lefthalf.filled" }
  if lower.contains("stick") && (lower.contains("y") || lower.contains("up") || lower.contains("down")) { return "circle.bottomhalf.filled" }
  if lower.contains("trigger") || lower.contains("shoulder") { return "l1.rectangle.roundedbottom.fill" }
  if lower.contains("motor") || lower.contains("rumble") { return "iphone.radiowaves.left.and.right" }
  if lower.contains("modifier") { return "circle.lefthalf.filled" }
  if lower.contains("minus") { return "minus.circle.fill" }
  if lower.contains("plus") { return "plus.circle.fill" }
  if lower.contains("1") && lower.contains("button") { return "1.circle.fill" }
  if lower.contains("2") && lower.contains("button") { return "2.circle.fill" }
  return "circle.fill"
}

private func isMotorControl(_ uiName: String) -> Bool {
  uiName.lowercased().contains("motor")
}

private func isModifierControl(_ uiName: String) -> Bool {
  uiName.lowercased().contains("modifier")
}

/// Stick/axis groups: Control Stick, C Stick, Stick, Left Stick, Right Stick (axes are not remappable).
private func isStickAxisGroup(_ groupUiName: String) -> Bool {
  let lower = groupUiName.lowercased()
  return lower.contains("stick") || lower.contains("control stick") || lower == "c stick"
}

private struct MappingQuickMapView: View {
  @ObservedObject var viewModel: MappingViewModel

  private struct PendingTouchControl: Identifiable {
    let sectionIndex: Int
    let rowIndex: Int
    let controlIndex: Int
    let controlName: String
    var id: String { "\(sectionIndex)-\(rowIndex)-\(controlIndex)" }
  }

  @State private var pendingTouchControl: PendingTouchControl?
  
  private var isTouchDevice: Bool {
    let dev = viewModel.defaultDevice
    return dev.isEmpty || DOLMappingBridge.isTouchscreenDevice(dev)
  }
  
  private func isRemappable(control: DOLControl, groupUiName: String) -> Bool {
    if isTouchDevice { return true }
    if isMotorControl(control.uiName) { return false }
    if isModifierControl(control.uiName) { return false }
    if isStickAxisGroup(groupUiName) { return false }
    return true
  }
  
  private func triggerMotorHaptic() {
    let gen = UIImpactFeedbackGenerator(style: .medium)
    gen.impactOccurred()
    // Brief rumble feel; real device motor would require bridge support
  }
  
  private var allMapItems: [ControlMapItem] {
    var items: [ControlMapItem] = []
    for (sectionIndex, section) in viewModel.sections.enumerated() {
      let groups = section["groups"] as? [DOLControlGroup] ?? []
      for (rowIndex, group) in groups.enumerated() {
        if group.isExtensionGroup && viewModel.mappingType == .wiimote {
          items.append(.extensionGroup(id: "ext-\(sectionIndex)-\(rowIndex)", sectionIndex: sectionIndex, rowIndex: rowIndex, group: group))
        } else {
          let controls = DOLMappingBridge.controlsForGroup(atSection: sectionIndex, row: rowIndex)
          let groupUiName = group.uiName
          for control in controls {
            items.append(.control(id: "\(sectionIndex)-\(rowIndex)-\(control.controlIndex)", sectionIndex: sectionIndex, rowIndex: rowIndex, controlIndex: control.controlIndex, control: control, groupUiName: groupUiName))
          }
        }
      }
    }
    return items
  }
  
  var body: some View {
    let items = allMapItems
    if items.isEmpty {
      EmptyView()
    } else {
      LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
      ], spacing: 8) {
        ForEach(items) { item in
          switch item {
          case .extensionGroup(_, let sectionIndex, let rowIndex, let group):
            NavigationLink {
              MappingExtensionView(viewModel: viewModel)
            } label: {
              controlMapCell(icon: "rectangle.stack", title: group.uiName, expression: nil)
            }
            .buttonStyle(.plain)
          case .control(_, let sectionIndex, let rowIndex, let controlIndex, let control, let groupUiName):
            Button {
              if isTouchDevice {
                pendingTouchControl = PendingTouchControl(sectionIndex: sectionIndex, rowIndex: rowIndex, controlIndex: controlIndex, controlName: control.uiName)
                return
              }
              if isMotorControl(control.uiName) {
                triggerMotorHaptic()
                return
              }
              if isModifierControl(control.uiName) || isStickAxisGroup(groupUiName) {
                return
              }
              viewModel.startInputDetection(section: sectionIndex, row: rowIndex, controlIndex: controlIndex)
            } label: {
              controlMapCell(icon: iconForControl(control.uiName), title: control.uiName, expression: control.expression.isEmpty ? nil : control.expression)
            }
            .buttonStyle(.plain)
            .contextMenu {
              if isRemappable(control: control, groupUiName: groupUiName) {
                Button(role: .destructive) {
                  viewModel.clearControl(section: sectionIndex, row: rowIndex, controlIndex: controlIndex)
                } label: {
                  Label("Clear", systemImage: "trash")
                }
              }
            }
          }
        }
      }
      .padding(.vertical, 4)
      .sheet(item: $pendingTouchControl) { pending in
        NavigationView {
          TouchscreenInputPickerView(
            viewModel: viewModel,
            sectionIndex: pending.sectionIndex,
            rowIndex: pending.rowIndex,
            controlIndex: pending.controlIndex,
            controlName: pending.controlName
          )
        }
      }
    }
  }
  
  private func controlMapCell(icon: String, title: String, expression: String?) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(.tint)
      Text(title)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      if let expr = expression, !expr.isEmpty {
        Text(expr)
          .font(.system(size: 8))
          .foregroundColor(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

private struct TouchscreenInputPickerView: View {
  @ObservedObject var viewModel: MappingViewModel
  @Environment(\.dismiss) private var dismiss

  let sectionIndex: Int
  let rowIndex: Int
  let controlIndex: Int
  let controlName: String

  @State private var inputs: [DOLInput] = []

  private var filteredInputs: [DOLInput] {
    inputs
      .filter { input in
        input.name.hasPrefix("Button ") || input.name.hasPrefix("Axis ") || input.name.hasPrefix("Rumble ")
      }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  var body: some View {
    List {
      ForEach(filteredInputs, id: \.name) { input in
        Button {
          viewModel.setTouchscreenInput(input.name, section: sectionIndex, row: rowIndex, controlIndex: controlIndex)
          dismiss()
        } label: {
          HStack {
            Text(input.name)
              .foregroundColor(.primary)
            Spacer()
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(controlName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
          dismiss()
        }
      }
    }
    .onAppear {
      inputs = DOLMappingBridge.inputsForCurrentDevice()
    }
  }
}

// MARK: - Device Selection View

struct MappingDeviceView: View {
  @ObservedObject var viewModel: MappingViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var devices: [DOLDevice] = []

  var body: some View {
    List {
      ForEach(devices, id: \.name) { device in
        Button {
          selectDevice(device)
        } label: {
          HStack {
            Text(device.displayName)
              .foregroundColor(.primary)
            Spacer()
            if device.name == viewModel.defaultDevice {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Device")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
          dismiss()
        }
      }
    }
    .onAppear {
      refreshDevices()
    }
  }

  private func refreshDevices() {
    // Port 0: physical controllers only (Touch is chosen via Input preference, not device list).
    let filterType: DOLDeviceFilterType = viewModel.port == 0
      ? .physicalOnly
      : DOLMappingBridge.deviceFilterType(forPort: viewModel.port, mappingType: viewModel.mappingType.dolMappingType)
    devices = DOLMappingBridge.devices(with: filterType)
  }

  private func selectDevice(_ device: DOLDevice) {
    guard device.name != viewModel.defaultDevice else { return }
    viewModel.setDevice(device.name)
  }
}

// MARK: - Extension Selection View (Wiimote)

struct MappingExtensionView: View {
  @ObservedObject var viewModel: MappingViewModel
  @Environment(\.dismiss) private var dismiss
  
  @State private var attachments: [DOLExtensionAttachment] = []
  
  var body: some View {
    List {
      ForEach(attachments, id: \.index) { attachment in
        Button {
          viewModel.setExtension(attachment.index)
          dismiss()
        } label: {
          HStack {
            Text(attachment.displayName)
              .foregroundColor(.primary)
            Spacer()
            if attachment.index == Int(viewModel.currentExtension.rawValue) {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Extension")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      attachments = DOLMappingBridge.extensionAttachments()
    }
  }
}

// MARK: - Group Edit View

struct MappingGroupEditView: View {
  @ObservedObject var viewModel: MappingViewModel
  let sectionIndex: Int
  let rowIndex: Int
  let groupName: String
  
  @State private var controls: [DOLControl] = []
  @State private var numericSettings: [DOLNumericSetting] = []
  @State private var isEnabled: Bool = true
  @State private var hasEnabledSetting: Bool = false
  @State private var showHelpAlert = false
  @State private var helpMessage = ""
  
  private var isTouchDevice: Bool {
    let dev = viewModel.defaultDevice
    return dev.isEmpty || DOLMappingBridge.isTouchscreenDevice(dev)
  }
  
  private func isRemappable(control: DOLControl) -> Bool {
    if isTouchDevice { return false }
    if isMotorControl(control.uiName) { return false }
    if isModifierControl(control.uiName) { return false }
    if isStickAxisGroup(groupName) { return false }
    return true
  }
  
  private func triggerMotorHaptic() {
    let gen = UIImpactFeedbackGenerator(style: .medium)
    gen.impactOccurred()
  }
  
  var body: some View {
    List {
      // Enabled Switch Section (if applicable)
      if hasEnabledSetting {
        Section {
          Toggle("Enabled", isOn: Binding(
            get: { isEnabled },
            set: { newValue in
              isEnabled = newValue
              viewModel.setEnabled(newValue, section: sectionIndex, row: rowIndex)
            }
          ))
        }
      }
      
      // Controls Section
      if !controls.isEmpty {
        Section(header: Text("Controls")) {
          ForEach(controls, id: \.controlIndex) { control in
            Button {
              if isTouchDevice { return }
              if isMotorControl(control.uiName) {
                triggerMotorHaptic()
                return
              }
              if isModifierControl(control.uiName) || isStickAxisGroup(groupName) { return }
              viewModel.startInputDetection(section: sectionIndex, row: rowIndex, controlIndex: control.controlIndex)
            } label: {
              HStack {
                Text(control.uiName)
                  .foregroundColor(isEnabled ? .primary : .secondary)
                Spacer()
                Text(control.expression.isEmpty ? "—" : control.expression)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
            .disabled(!isEnabled)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              if isRemappable(control: control) {
                Button(role: .destructive) {
                  viewModel.clearControl(section: sectionIndex, row: rowIndex, controlIndex: control.controlIndex)
                  refreshControls()
                } label: {
                  Label("Clear", systemImage: "trash")
                }
              }
            }
          }
        }
      }
      
      // Numeric Settings Section
      if !numericSettings.isEmpty {
        Section(header: Text("Settings")) {
          ForEach(numericSettings, id: \.settingIndex) { setting in
            if setting.settingType == .bool {
              // Boolean setting
              HStack {
                Text(setting.uiName)
                  .foregroundColor(isEnabled ? .primary : .secondary)
                Spacer()
                if setting.uiDescription != nil {
                  Button {
                    helpMessage = setting.uiDescription ?? ""
                    showHelpAlert = true
                  } label: {
                    Image(systemName: "info.circle")
                      .foregroundColor(.accentColor)
                  }
                  .buttonStyle(.plain)
                }
                Toggle("", isOn: Binding(
                  get: { setting.boolValue },
                  set: { newValue in
                    viewModel.setBoolValue(newValue, section: sectionIndex, row: rowIndex, settingIndex: setting.settingIndex)
                    refreshSettings()
                  }
                ))
                .disabled(!isEnabled)
                .labelsHidden()
              }
            } else {
              // Double setting
              HStack {
                Text(setting.uiName)
                  .foregroundColor(isEnabled ? .primary : .secondary)
                Spacer()
                if setting.uiDescription != nil {
                  Button {
                    helpMessage = setting.uiDescription ?? ""
                    showHelpAlert = true
                  } label: {
                    Image(systemName: "info.circle")
                      .foregroundColor(.accentColor)
                  }
                  .buttonStyle(.plain)
                }
                TextField("", value: Binding(
                  get: { setting.doubleValue },
                  set: { newValue in
                    let clampedValue = min(max(newValue, setting.minValue), setting.maxValue)
                    viewModel.setDoubleValue(clampedValue, section: sectionIndex, row: rowIndex, settingIndex: setting.settingIndex)
                    refreshSettings()
                  }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .disabled(!isEnabled)
                
                if let suffix = setting.uiSuffix, !suffix.isEmpty {
                  Text(suffix)
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(groupName)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      refreshData()
    }
    .alert("Help", isPresented: $showHelpAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(helpMessage)
    }
  }
  
  private func refreshData() {
    refreshControls()
    refreshSettings()
    isEnabled = DOLMappingBridge.enabledForGroup(atSection: sectionIndex, row: rowIndex)
    
    // Check if group has enabled setting (bounds-check to avoid crashes)
    guard sectionIndex >= 0, sectionIndex < viewModel.sections.count,
          let groups = viewModel.sections[sectionIndex]["groups"] as? [DOLControlGroup],
          rowIndex >= 0, rowIndex < groups.count else {
      hasEnabledSetting = false
      return
    }
    hasEnabledSetting = groups[rowIndex].hasEnabledSetting
  }
  
  private func refreshControls() {
    controls = DOLMappingBridge.controlsForGroup(atSection: sectionIndex, row: rowIndex)
  }
  
  private func refreshSettings() {
    numericSettings = DOLMappingBridge.numericSettingsForGroup(atSection: sectionIndex, row: rowIndex)
  }
}

// MARK: - Profile Load View

struct MappingProfileLoadView: View {
  @ObservedObject var viewModel: MappingViewModel
  @Binding var isPresented: Bool
  
  @State private var profiles: [DOLProfile] = []
  @State private var showLoadedAlert = false
  @State private var loadedProfileName = ""
  
  /// Show all profiles; no automatic touch vs controller profile switching.
  private var filterTouchscreen: Bool { false }

  var body: some View {
    List {
      ForEach(profiles, id: \.path) { profile in
        Button {
          loadProfile(profile)
        } label: {
          HStack {
            Text(profile.isStock ? "\(profile.name) (Stock)" : profile.name)
              .foregroundColor(.primary)
          }
        }
      }
      .onDelete { indexSet in
        deleteProfiles(at: indexSet)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Load Profile")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") {
          isPresented = false
        }
      }
    }
    .onAppear {
      refreshProfiles()
    }
    .alert("Loaded", isPresented: $showLoadedAlert) {
      Button("OK") {
        isPresented = false
      }
    } message: {
      Text("The profile \"\(loadedProfileName)\" was loaded.")
    }
  }
  
  private func refreshProfiles() {
    profiles = DOLMappingBridge.profilesFilteringTouchscreen(filterTouchscreen)
  }
  
  private func loadProfile(_ profile: DOLProfile) {
    DOLMappingBridge.load(profile)
    viewModel.reload()
    loadedProfileName = profile.name
    showLoadedAlert = true
  }
  
  private func deleteProfiles(at offsets: IndexSet) {
    for index in offsets {
      let profile = profiles[index]
      if !profile.isStock {
        DOLMappingBridge.delete(profile)
      }
    }
    refreshProfiles()
  }
}

// MARK: - SwiftUI Wrapper for presenting from UIKit/existing code

struct MappingViewWrapper: View {
  let isPad: Bool
  let port: Int
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    MappingRootView(
      mappingType: isPad ? .pad : .wiimote,
      port: port
    )
  }
}

// MARK: - UIKit Hosting Controller

@objc class MappingHostingController: UIViewController {
  private var hostingController: UIHostingController<MappingViewWrapper>?
  
  @objc var isPad: Bool = true
  @objc var port: Int = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let mappingView = MappingViewWrapper(isPad: isPad, port: port)
    let hostingController = UIHostingController(rootView: mappingView)
    
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    
    hostingController.didMove(toParent: self)
    self.hostingController = hostingController
  }
}

// MARK: - Preview

#if DEBUG
struct MappingRootView_Previews: PreviewProvider {
  static var previews: some View {
    MappingRootView(mappingType: .pad, port: 0)
  }
}
#endif
