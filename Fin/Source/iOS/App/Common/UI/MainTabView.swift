// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

// MARK: - Shared adaptive background

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

private let kShowFilesTabKey = "fin.showFilesTab"

private enum MainTab: Int {
  case files = 0
  case games = 1
  case settings = 2
}

struct MainTabView: View {
  @AppStorage(kShowFilesTabKey) private var showFilesTab = true
  @State private var selectedTab: MainTab = .games
  @State private var showWelcome = WelcomeView.shouldShow

  var body: some View {
    TabView(selection: $selectedTab) {
      if showFilesTab {
        FileManagerView()
          .tabItem {
            Label("Files", systemImage: "square.stack.3d.up.fill")
          }
          .tag(MainTab.files)
      }

      SoftwareListView()
        .tabItem {
          Label("Games", systemImage: "gamecontroller.fill")
        }
        .tag(MainTab.games)

      SettingsRootView()
        .tabItem {
          Label("Settings", systemImage: "gearshape.fill")
        }
        .tag(MainTab.settings)
    }
    .toolbarBackground(.visible, for: .tabBar)
    .onChange(of: showFilesTab) { filesVisible in
      if !filesVisible, selectedTab == .files {
        selectedTab = .games
      }
    }
    .fullScreenCover(isPresented: $showWelcome) {
      WelcomeView {
        showWelcome = false
      }
    }
  }
}

/// Hosting controller for SwiftUI MainTabView
class MainTabViewHostingController: UIHostingController<MainTabView> {
  init() {
    super.init(rootView: MainTabView())
  }
  
  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder, rootView: MainTabView())
  }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
  static var previews: some View {
    MainTabView()
  }
}
#endif
