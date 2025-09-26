//
//  GBCCoreSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 8/1/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI

struct GBCCoreSettingsView: CoreSettingsView
{
    var system: System { .gbc }
    @Environment(\.openURL) var openURL
    
    @SwiftUI.State private var selectedColorPalette: GBCColorPalette?
        
    var additionalSections: some View {
        Section {
            Picker("Color Palette", selection: $selectedColorPalette) {
                Text("Default").tag(Optional<GBCColorPalette>.none)
                ForEach(GBCColorPalette.allCases, id: \.self) { palette in
                    Text(palette.localizedName).tag(palette)
                }
            }
            .onChange(of: selectedColorPalette) { newPalette in
                Settings.preferredGBColorPalette = newPalette
            }
        } header: {
            Text("Colors")
        }
        .onAppear() {
            selectedColorPalette = Settings.preferredGBColorPalette
        }
    }
}

#Preview {
    NavigationView {
        GBCCoreSettingsView()
    }
}
