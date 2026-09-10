// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

// MARK: - UserDefaults

private let kBrowserLegalAcceptedKey = "fin.browserLegalNotice.accepted"

enum BrowserLegalNotice {
  static var hasAccepted: Bool {
    get { UserDefaults.standard.bool(forKey: kBrowserLegalAcceptedKey) }
    set { UserDefaults.standard.set(newValue, forKey: kBrowserLegalAcceptedKey) }
  }
  
  /// Call once to force the legal notice to appear again.
  static func resetAcceptance() {
    UserDefaults.standard.removeObject(forKey: kBrowserLegalAcceptedKey)
  }
}

// MARK: - First-time browser legal notice (10s timer, button fills before OK; cannot swipe/tap off to dismiss)

struct BrowserLegalNoticeView: View {
  var onAccept: () -> Void
  var onCancel: () -> Void

  @State private var canDismiss = false
  @State private var fillProgress: Double = 0
  @State private var countdownSeconds: Int = 10
  @State private var timer: Timer?

  private let requiredSeconds: TimeInterval = 10

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Important Legal Notice")
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)

          Group {
            Text("Fin includes a built-in browser solely for downloading legal textures,Shaders, and Configuration files.")
            VStack(alignment: .leading, spacing: 4) {
              bullet("Texture packs")
              bullet("Shader files")
              bullet("Configuration files")
            }
            Text("Fin does not include games, firmware, encryption keys, save data, or copyrighted content.")
          }
          .font(.subheadline)
          .foregroundColor(.secondary)

          Group {
            Text("Trademark & non-affiliation")
              .font(.subheadline)
              .fontWeight(.semibold)
            Text("Fin is not affiliated with, endorsed by, or associated with Nintendo, the Dolphin Emulator Project, or DolphiniOS.")
            Text("\"Nintendo\", \"GameCube\", and \"Wii\" are trademarks of Nintendo Co., Ltd. All trademarks are the property of their respective owners.")
          }
          .font(.subheadline)
          .foregroundColor(.secondary)

          VStack(alignment: .leading, spacing: 8) {
            Text("You must NOT use this browser to download or access:")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
              bulletRed("Game ROMs or disc images")
              bulletRed("Save data")
              bulletRed("Firmware or BIOS files")
              bulletRed("ROM hacks or modified game content")
              bulletRed("Game assets extracted from commercial games")
              bulletRed("Any copyrighted or licensed material without explicit permission from the rights holder")
            }
            .font(.subheadline)
            .foregroundColor(.red)
          }
          .padding(.vertical, 4)

          Group {
            Text("Responsibility & liability")
              .font(.subheadline)
              .fontWeight(.semibold)
            Text("You are solely responsible for ensuring that any content you download or use is legal, licensed, or author-approved.")
            Text("Fin does not host, distribute, verify, or endorse third-party content and is not responsible for how the browser is used.")
          }
          .font(.subheadline)
          .foregroundColor(.secondary)

          if !canDismiss {
            Text("Please read the notice above. You may accept in \(countdownSeconds) second\(countdownSeconds == 1 ? "" : "s").")
              .font(.caption)
              .foregroundColor(.orange)
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
          }
          .disabled(!canDismiss)
        }
      }
      .safeAreaInset(edge: .bottom) {
        acceptButton
      }
      .interactiveDismissDisabled(true)
      .onAppear {
        startCountdown()
      }
      .onDisappear {
        timer?.invalidate()
        timer = nil
      }
    }
  }

  private var acceptButton: some View {
    Button {
      BrowserLegalNotice.hasAccepted = true
      onAccept()
    } label: {
      Text("I Understand and Accept Responsibility")
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(canDismiss ? 1 : 0.3))
              RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.2))
                .frame(width: geo.size.width * fillProgress)
            }
          }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .disabled(!canDismiss)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private func bullet(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Text("•")
      Text(text)
    }
  }

  private func bulletRed(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Text("•")
        .foregroundColor(.red)
      Text(text)
        .foregroundColor(.red)
    }
  }

  private func startCountdown() {
    canDismiss = false
    fillProgress = 0
    countdownSeconds = Int(requiredSeconds)
    let start = Date()
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [start] _ in
      Task { @MainActor in
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= self.requiredSeconds {
          self.timer?.invalidate()
          self.timer = nil
          self.canDismiss = true
          self.fillProgress = 1
          self.countdownSeconds = 0
          return
        }
        self.fillProgress = elapsed / self.requiredSeconds
        self.countdownSeconds = max(0, Int(self.requiredSeconds) - Int(elapsed))
      }
    }
    RunLoop.main.add(timer!, forMode: .common)
  }
}
