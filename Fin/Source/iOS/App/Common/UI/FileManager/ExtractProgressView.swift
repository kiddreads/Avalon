// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Modal shown while extracting a ZIP or 7z archive. Shows progress for ZIP (when `progress` is set), indeterminate for 7z.
struct ExtractProgressView: View {
  let fileName: String
  /// When non-nil, a determinate progress bar is shown (ZIP). When nil, spinner only (7z).
  let progress: Progress?

  var body: some View {
    VStack(spacing: 20) {
      ProgressView()
        .progressViewStyle(.circular)
        .scaleEffect(1.2)
      if let progress = progress, progress.totalUnitCount > 0 {
        ProgressView(progress)
          .progressViewStyle(.linear)
          .frame(maxWidth: 280)
      }
      Text("Extracting \(fileName)...")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
  }
}
