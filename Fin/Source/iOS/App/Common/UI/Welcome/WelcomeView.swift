// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

private let kHasSeenWelcomeKey = "fin.hasSeenWelcome"

private enum Preset: String, CaseIterable {
  case balanced = "Balanced"
  case performance = "Performance"
  case quality = "Quality"

  var description: String {
    switch self {
    case .balanced:   return "1x resolution, default hacks. Good for most devices (iPhone 12+)."
    case .performance: return "1x resolution, skip EFB access, fast depth. Best for older devices or heavy games."
    case .quality:     return "2x resolution, anti-aliasing, per-pixel lighting. Needs A15+ chip."
    }
  }

  var icon: String {
    switch self {
    case .balanced:   return "equal.circle.fill"
    case .performance: return "hare.fill"
    case .quality:     return "sparkles"
    }
  }

  func apply() {
    switch self {
    case .balanced:
      DOLConfigBridge.setInternalResolution(1)
      DOLConfigBridge.setSkipEFBAccess(false)
      DOLConfigBridge.setFastDepthCalc(true)
      DOLConfigBridge.setMsaa(1)
      DOLConfigBridge.setSsaa(false)
      DOLConfigBridge.setPixelLighting(false)
      DOLConfigBridge.setBackendMultithreading(true)
      DOLConfigBridge.setDeferEFBCopies(true)
      DOLConfigBridge.setSkipEFBCopyToRAM(true)
    case .performance:
      DOLConfigBridge.setInternalResolution(1)
      DOLConfigBridge.setSkipEFBAccess(true)
      DOLConfigBridge.setFastDepthCalc(true)
      DOLConfigBridge.setMsaa(1)
      DOLConfigBridge.setSsaa(false)
      DOLConfigBridge.setPixelLighting(false)
      DOLConfigBridge.setBackendMultithreading(true)
      DOLConfigBridge.setDeferEFBCopies(true)
      DOLConfigBridge.setDeferEFBInvalidation(true)
      DOLConfigBridge.setSkipEFBCopyToRAM(true)
      DOLConfigBridge.setSkipDuplicateXFBs(true)
      DOLConfigBridge.setViSkip(true)
    case .quality:
      DOLConfigBridge.setInternalResolution(2)
      DOLConfigBridge.setSkipEFBAccess(false)
      DOLConfigBridge.setFastDepthCalc(true)
      DOLConfigBridge.setMsaa(4)
      DOLConfigBridge.setSsaa(false)
      DOLConfigBridge.setPixelLighting(true)
      DOLConfigBridge.setForceTrueColor(true)
      DOLConfigBridge.setBackendMultithreading(true)
      DOLConfigBridge.setDeferEFBCopies(true)
      DOLConfigBridge.setSkipEFBCopyToRAM(true)
    }
    DOLConfigBridge.saveConfig()
  }
}

struct WelcomeView: View {
  var onDismiss: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedPreset: Preset? = nil
  @State private var showPresetApplied = false

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {

        // MARK: - Header
        VStack(spacing: 8) {
          Image(systemName: "gamecontroller.fill")
            .font(.system(size: 56))
            .foregroundStyle(.linearGradient(
              colors: [.blue, .cyan],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("Welcome to Fin")
            .font(.system(size: 32, weight: .bold, design: .rounded))
          Text("A GameCube & Wii emulator for iOS")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.top, 32)

        // MARK: - Getting Started
        cardSection(title: "Getting Started", icon: "arrow.down.circle.fill", color: .blue) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Fin plays GameCube and Wii game files. You can load your own game backups (ISO, WBFS, RVZ, GCM, etc.) through the Files tab or by using Share → Open in Fin.")
              .font(.callout)
            Text("Supported formats: .iso, .gcm, .gcz, .ciso, .wbfs, .wad, .wia, .rvz, .nkit, .dol, .elf, .m3u")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        // MARK: - Try Free Homebrew Games
        cardSection(title: "Try Free Homebrew Games", icon: "star.fill", color: .orange) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Download free, community-made games to try right away:")
              .font(.callout)

            Text("GAMECUBE")
              .font(.caption)
              .fontWeight(.bold)
              .foregroundColor(.secondary)

            homebrewLink(
              title: "Ascii-Pong",
              subtitle: "ASCII-style pong for GameCube — download page",
              url: "https://wiibrew.org/wiki/Ascii-Pong"
            )

            homebrewLink(
              title: "BlastGuy",
              subtitle: "Platformer homebrew game — download page",
              url: "https://wiibrew.org/wiki/BlastGuy"
            )

            Text("WII")
              .font(.caption)
              .fontWeight(.bold)
              .foregroundColor(.secondary)
              .padding(.top, 4)

            homebrewLink(
              title: "OpenTyrianWii",
              subtitle: "Arcade shoot-em-up homebrew game — download page",
              url: "https://wiibrew.org/wiki/OpenTyrianWii"
            )

            homebrewLink(
              title: "WiiXplorer",
              subtitle: "Homebrew utility and file manager — download page",
              url: "https://wiibrew.org/wiki/WiiXplorer"
            )

            Divider()

            Text("Browse more:")
              .font(.caption)
              .foregroundColor(.secondary)

            homebrewLink(
              title: "GameBrew — Homebrew Library",
              subtitle: "GameCube & Wii homebrew games",
              url: "https://www.gamebrew.org/wiki/List_of_GameCube_homebrew_games"
            )

            homebrewLink(
              title: "WiiBrew — Wii Homebrew",
              subtitle: "Community Wii games & apps",
              url: "https://wiibrew.org/wiki/List_of_homebrew_games"
            )
          }
        }

        // MARK: - Presets & Performance
        cardSection(title: "Choose a Preset", icon: "slider.horizontal.3", color: .purple) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Tap a preset to apply it now. You can change these anytime in Settings → Graphics.")
              .font(.callout)
              .padding(.bottom, 4)

            ForEach(Preset.allCases, id: \.self) { preset in
              presetButton(preset)
            }

            if showPresetApplied, let preset = selectedPreset {
              HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
                  .font(.caption)
                Text("\(preset.rawValue) preset applied!")
                  .font(.caption)
                  .foregroundColor(.green)
              }
              .transition(.opacity)
              .padding(.top, 4)
            }
          }
        }

        // MARK: - For App Reviewers
        cardSection(title: "For App Reviewers", icon: "person.badge.shield.checkmark.fill", color: .green) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Hey — thanks for taking the time to review Fin. Here are a few things that might help:")
              .font(.callout)

            bulletPoint("To try it out, grab any of the free homebrew games above. Just tap a link, download the file, and open it in Fin.")
            bulletPoint("You can also import your own game backups through the Files tab or via Share → Open in Fin.")
            bulletPoint("Works with MFi and Bluetooth controllers out of the box. On-screen touch controls are there too.")
            bulletPoint("Networking is used for online co-op multiplayer and for the built-in browser to grab homebrew.")
            bulletPoint("All JIT and jailbreak-related code has been removed. Fin runs entirely in interpreted mode within the App Store sandbox.")
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, -2)
              VStack(alignment: .leading, spacing: 4) {
                Text("Built on the open-source Dolphin emulator engine (GPL-2.0-or-later).")
                  .font(.callout)
                if let url = URL(string: "https://github.com/example/Fin") {
                  Link(destination: url) {
                    HStack(spacing: 4) {
                      Text("View source on GitHub")
                        .font(.callout)
                        .fontWeight(.medium)
                      Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                    }
                  }
                }
              }
            }
          }
        }

        // MARK: - Continue Button
        Button(action: {
          UserDefaults.standard.set(true, forKey: kHasSeenWelcomeKey)
          onDismiss()
        }) {
          Text("Get Started")
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
              LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 40)
      }
      .padding(.horizontal, 20)
    }
    .background(
      LinearGradient(
        colors: colorScheme == .dark ? [
          Color(hue: 0.55, saturation: 0.4, brightness: 0.12),
          Color(hue: 0.58, saturation: 0.35, brightness: 0.08)
        ] : [
          Color(hue: 0.58, saturation: 0.08, brightness: 0.96),
          Color(hue: 0.55, saturation: 0.06, brightness: 0.92)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    )
  }

  // MARK: - Helpers

  @ViewBuilder
  private func cardSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: icon)
        .font(.headline)
        .foregroundColor(color)
      content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder
  private func homebrewLink(title: String, subtitle: String, url: String) -> some View {
    if let linkURL = URL(string: url) {
      Link(destination: linkURL) {
        HStack(spacing: 10) {
          Image(systemName: "arrow.down.circle")
            .foregroundColor(.blue)
            .font(.title3)
          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.callout)
              .fontWeight(.medium)
              .foregroundColor(.primary)
            Text(subtitle)
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Spacer()
          Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
      }
    }
  }

  @ViewBuilder
  private func presetButton(_ preset: Preset) -> some View {
    let isSelected = selectedPreset == preset
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedPreset = preset
        showPresetApplied = false
      }
      preset.apply()
      withAnimation(.easeInOut(duration: 0.3)) {
        showPresetApplied = true
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: preset.icon)
          .font(.title3)
          .foregroundColor(isSelected ? .white : .purple)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(preset.rawValue)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .white : .primary)
          Text(preset.description)
            .font(.caption)
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.white)
        }
      }
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(isSelected ? Color.purple : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(isSelected ? Color.clear : Color.purple.opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func bulletPoint(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Text("•")
        .font(.system(size: 18, weight: .bold))
        .foregroundColor(.secondary)
        .padding(.top, -2)
      Text(text)
        .font(.callout)
    }
  }

  static var shouldShow: Bool {
    !UserDefaults.standard.bool(forKey: kHasSeenWelcomeKey)
  }
}
