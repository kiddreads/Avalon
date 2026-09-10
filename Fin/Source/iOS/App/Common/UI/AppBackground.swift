// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Shared adaptive background gradient used across all tabs.
/// Dark mode: cobalt blue-black gradient (matches Games tab).
/// Light mode: inverted warm light gradient.
struct AppBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
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
  }
}
