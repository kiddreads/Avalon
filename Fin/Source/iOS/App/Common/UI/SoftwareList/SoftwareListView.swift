// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Games list (SwiftUI)

private let kImportFileFinished = NSNotification.Name.DOLImportFileFinished

enum SoftwareSortOption: String, CaseIterable {
  case title = "Title"
  case console = "Console"
}

private struct MarqueeWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct MarqueeText: View {
  let text: String
  var font: Font = .caption
  var fontWeight: Font.Weight = .semibold
  var color: Color = .white
  var speed: CGFloat = 30
  var spacing: CGFloat = 24

  @State private var textWidth: CGFloat = 0
  @State private var containerWidth: CGFloat = 0
  @State private var offset: CGFloat = 0

  var body: some View {
    GeometryReader { geo in
      let container = geo.size.width
      ZStack(alignment: .leading) {
        if textWidth > container {
          HStack(spacing: spacing) {
            marqueeLabel
            marqueeLabel
          }
          .offset(x: offset)
          .clipped()
          .onAppear {
            containerWidth = container
            offset = 0
            startAnimation()
          }
          .onChange(of: container) { _, newValue in
            containerWidth = newValue
            offset = 0
            startAnimation()
          }
          .onChange(of: textWidth) { _, _ in
            offset = 0
            startAnimation()
          }
        } else {
          marqueeLabel
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear { containerWidth = container }
            .onChange(of: container) { _, newValue in containerWidth = newValue }
        }
      }
    }
    .frame(height: 16)
    .clipped()
  }

  private var marqueeLabel: some View {
    Text(text)
      .font(font)
      .fontWeight(fontWeight)
      .foregroundColor(color)
      .lineLimit(1)
      .background(
        GeometryReader { geo in
          Color.clear
            .preference(key: MarqueeWidthKey.self, value: geo.size.width)
        }
      )
      .onPreferenceChange(MarqueeWidthKey.self) { newValue in
        textWidth = newValue
      }
  }

  private func startAnimation() {
    guard textWidth > containerWidth, containerWidth > 0 else { return }
    let distance = textWidth + spacing
    let duration = distance / max(speed, 1)
    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
      offset = -distance
    }
  }
}

private let kShowHomeManagerKey = "fin.showHomeManager"
private let kFullGameIconKey = "fin.fullGameIcon"

struct SoftwareListView: View {
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @AppStorage(kShowHomeManagerKey) private var showHomeManager = true
  @AppStorage(kFullGameIconKey) private var fullGameIcon = false

  @State private var games: [GameFilePtrWrapper] = []
  @State private var searchText = ""
  @State private var sortOption: SoftwareSortOption = .title
  @State private var bootParameter: EmulationBootParameter?
  @State private var propertiesGame: GameFilePtrWrapper?
  @State private var wiiUpdateSource: String?
  @State private var wiiUpdateOnline = false
  @State private var documentPickerMode: DocumentPickerMode?
  @State private var showDeleteConfirm: (game: GameFilePtrWrapper, name: String)?
  @State private var showNandPicker = false
  @State private var selectedGameForDetail: GameFilePtrWrapper?
  @State private var showWebBrowser = false
  @State private var webBrowserURL = kWebBrowserDefaultURL
  @State private var showWebBrowserDetail = false
  @State private var showBrowserLegalNotice = false
  @State private var showDownloads = false

  private func platformFor(_ wrapper: GameFilePtrWrapper) -> String {
    let id = wrapper.gameID()
    return (id.hasPrefix("R") || id.hasPrefix("S")) ? "Wii" : "GameCube"
  }

  private func requestOpenBrowser() {
    if BrowserLegalNotice.hasAccepted {
      showWebBrowser = true
    } else {
      showBrowserLegalNotice = true
    }
  }

  private var filteredGames: [GameFilePtrWrapper] {
    var list = games
    if !searchText.isEmpty {
      list = list.filter { $0.displayName().localizedCaseInsensitiveContains(searchText) }
    }
    switch sortOption {
    case .title:
      list.sort { $0.displayName().localizedCaseInsensitiveCompare($1.displayName()) == .orderedAscending }
    case .console:
      list.sort { w1, w2 in
        let p1 = platformFor(w1)
        let p2 = platformFor(w2)
        if p1 != p2 { return p1 < p2 }
        return w1.displayName().localizedCaseInsensitiveCompare(w2.displayName()) == .orderedAscending
      }
    }
    return list
  }

  private let gridColumns = [
    GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 14)
  ]

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        AppBackground()

        VStack(spacing: 0) {
          // In portrait, full search bar; in landscape search is in toolbar (principal).
          if verticalSizeClass != .compact {
            searchBar
          } else {
            sortAndCountRow
          }

          // Show list/grid differently for portrait and landscape:
          if verticalSizeClass != .compact {
            // Portrait: no ScrollView wrapping the grid; grid expands to fit content without forcing maxHeight infinity
            if filteredGames.isEmpty {
              emptyStateWithBrowserPortrait
            } else {
              gameGridWithBrowserPortrait
            }
          } else {
            // Landscape: scrollable grid as before
            if filteredGames.isEmpty {
              emptyStateWithBrowser
            } else {
              gameGridWithBrowser
            }
          }
        }
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          if showHomeManager {
            Menu {
              Toggle("Full Icon", isOn: $fullGameIcon)
              Button {
                documentPickerMode = .openExternal
              } label: {
                Label("Open", systemImage: "externaldrive")
              }
              Menu {
                Button("NTSC-J") { presentGCIPL(region: 0) }
                Button("NTSC-U") { presentGCIPL(region: 1) }
                Button("PAL") { presentGCIPL(region: 2) }
              } label: {
                Text("Load GameCube Main Menu")
              }
              Menu {
                Button {
                  wiiUpdateSource = ""
                  wiiUpdateOnline = true
                } label: {
                  Label("Perform Online System Update", systemImage: "icloud.and.arrow.down")
                }
                Button {
                  showNandPicker = true
                } label: {
                  Label("Import BootMii NAND Backup…", systemImage: "square.and.arrow.down")
                }
              } label: {
                Text("Wii")
              }
            } label: {
              Label("Home Manager", systemImage: "house.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white.opacity(0.9))
            }
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            documentPickerMode = .importSoftware
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.title2)
              .foregroundStyle(
                LinearGradient(
                  colors: [.blue, Color(red: 0.25, green: 0.45, blue: 0.95)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
          }
        }
        // In landscape, put search in the center toolbar (where the blue/title area is).
        ToolbarItem(placement: .principal) {
          if verticalSizeClass == .compact {
            HStack(spacing: 8) {
              Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
              TextField("Search games...", text: $searchText)
                .textFieldStyle(.plain)
              if !searchText.isEmpty {
                Button { searchText = "" } label: {
                  Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                }
              }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
              RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .frame(minWidth: 220, maxWidth: 520)
          }
        }
      }
      // .refreshable { await reloadGames() }
      .onAppear {
        reloadGamesSync()
        NotificationCenter.default.addObserver(
          forName: kImportFileFinished,
          object: nil,
          queue: .main
        ) { _ in
          reloadGamesSync()
        }
      }
      .fullScreenCover(isPresented: Binding(
        get: { bootParameter != nil },
        set: { if !$0 { bootParameter = nil } }
      )) {
        if let param = bootParameter {
          EmulationHostingView(bootParameter: param)
        }
      }
      .overlay {
        if let wrapper = selectedGameForDetail {
          GeometryReader { geometry in
            ZStack {
              Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { selectedGameForDetail = nil }
              VStack(spacing: 12) {
                GameDetailFullView(
                  wrapper: wrapper,
                  platform: platformFor(wrapper),
                  playTimeSeconds: playTimeSeconds(for: wrapper),
                  onPlay: {
                    selectedGameForDetail = nil
                    bootGame(wrapper)
                  },
                  onPlayWithSavestateSlot: { slot in
                    selectedGameForDetail = nil
                    bootGame(wrapper, savestateSlot: slot)
                  }
                )
                .frame(maxWidth: geometry.size.width > geometry.size.height ? geometry.size.width - 32 : 420, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
                Text("Tap anywhere to close")
                  .font(.system(size: 13, weight: .medium))
                  .foregroundColor(.white.opacity(0.7))
              }
              .padding(16)
            }
          }
        }
      }
      .sheet(isPresented: Binding(
        get: { propertiesGame != nil },
        set: { if !$0 { propertiesGame = nil } }
      )) {
        if let wrapper = propertiesGame {
          SoftwarePropertiesSheet(gameFileWrapper: wrapper) {
            propertiesGame = nil
          }
        }
      }
      .sheet(isPresented: Binding(
        get: { wiiUpdateSource != nil },
        set: { if !$0 { wiiUpdateSource = nil } }
      )) {
        if let source = wiiUpdateSource {
          WiiUpdateView(source: source, isOnline: wiiUpdateOnline) {
            wiiUpdateSource = nil
          }
        }
      }
      .sheet(isPresented: $showNandPicker) {
        DocumentPickerView(contentTypes: [.data], onPick: { url in
          showNandPicker = false
          importNand(at: url)
        }, onDismiss: {
          showNandPicker = false
        })
      }
      .sheet(isPresented: Binding(
        get: { documentPickerMode != nil },
        set: { if !$0 { documentPickerMode = nil } }
      )) {
        if let mode = documentPickerMode {
          documentPickerSheet(mode: mode)
        }
      }
      .fullScreenCover(isPresented: $showWebBrowser) {
        SafariView(url: webBrowserURL) {
          showWebBrowser = false
        }
        .ignoresSafeArea(.all)
      }
      .sheet(isPresented: $showBrowserLegalNotice) {
        BrowserLegalNoticeView(
          onAccept: {
            showBrowserLegalNotice = false
            showWebBrowser = true
          },
          onCancel: { showBrowserLegalNotice = false }
        )
      }
      .overlay {
        if showWebBrowserDetail {
          GeometryReader { geometry in
            ZStack {
              Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { showWebBrowserDetail = false }
              WebBrowserDetailView(
                onOpenBrowser: {
                  showWebBrowserDetail = false
                  webBrowserURL = kWebBrowserDefaultURL
                  requestOpenBrowser()
                },
                onOpenURL: { url in
                  showWebBrowserDetail = false
                  webBrowserURL = url
                  requestOpenBrowser()
                },
                onDismiss: { showWebBrowserDetail = false }
              )
              .frame(maxWidth: geometry.size.width > geometry.size.height ? geometry.size.width - 32 : 420, maxHeight: .infinity)
              .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
              .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
              .padding(16)
            }
          }
        }
      }
      .sheet(isPresented: $showDownloads) {
        DownloadsView(
          onOpenBrowser: {
            webBrowserURL = kWebBrowserDefaultURL
            showDownloads = false
            requestOpenBrowser()
          },
          onOpenURL: { url in
            webBrowserURL = url
            showDownloads = false
            requestOpenBrowser()
          },
          onDismiss: { showDownloads = false }
        )
      }
      .alert("Delete game?", isPresented: Binding(
        get: { showDeleteConfirm != nil },
        set: { if !$0 { showDeleteConfirm = nil } }
      )) {
        Button("Cancel", role: .cancel) { showDeleteConfirm = nil }
        Button("Delete", role: .destructive) {
          if let (game, _) = showDeleteConfirm {
            if game.deleteFile() {
              reloadGamesSync()
            }
            showDeleteConfirm = nil
          }
        }
      } message: {
        if let (_, name) = showDeleteConfirm {
          Text("Are you sure you want to delete \"\(name)\"?")
        }
      }
    }
  }

  private var searchBar: some View {
    VStack(spacing: 12) {
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.gray)

        TextField("Search games...", text: $searchText)
          .textFieldStyle(.plain)

        if !searchText.isEmpty {
          Button {
            searchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.gray)
          }
        }
      }
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(uiColor: .secondarySystemGroupedBackground))
      )
      .padding(.horizontal)

      HStack {
        Text("Sort by:")
          .font(.subheadline)
          .foregroundColor(.gray)

        Picker("Sort", selection: $sortOption) {
          ForEach(SoftwareSortOption.allCases, id: \.self) { option in
            Text(option.rawValue).tag(option)
          }
        }
        .pickerStyle(.menu)
        .tint(.blue)

        Spacer()

        Text("\(filteredGames.count) games")
          .font(.subheadline)
          .foregroundColor(.gray)
      }
      .padding(.horizontal)
    }
    .padding(.vertical)
  }

  private var sortAndCountRow: some View {
    HStack {
      Text("Sort by:")
        .font(.subheadline)
        .foregroundColor(.gray)
      Picker("Sort", selection: $sortOption) {
        ForEach(SoftwareSortOption.allCases, id: \.self) { option in
          Text(option.rawValue).tag(option)
        }
      }
      .pickerStyle(.menu)
      .tint(.blue)
      Spacer()
      Text("\(filteredGames.count) games")
        .font(.subheadline)
        .foregroundColor(.gray)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  // Landscape: horizontal-only scrolling, single row, no vertical scroll
  private var gameGridWithBrowser: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHGrid(rows: [GridItem(.flexible())], alignment: .center, spacing: 12) {
        WebBrowserCard(
          fullIcon: fullGameIcon,
          onArtTap: {
            webBrowserURL = kWebBrowserDefaultURL
            requestOpenBrowser()
          },
          onInfoTap: { showWebBrowserDetail = true }
        )
        .frame(width: 130)
        .contextMenu {
          Button {
            webBrowserURL = kWebBrowserDefaultURL
            requestOpenBrowser()
          } label: {
            Label("Open Browser", systemImage: "safari")
          }
          Button {
            showWebBrowserDetail = true
          } label: {
            Label("About", systemImage: "info.circle")
          }
        }
        ForEach(Array(filteredGames.enumerated()), id: \.offset) { _, wrapper in
          GameCell(
            wrapper: wrapper,
            playTimeSeconds: playTimeSeconds(for: wrapper),
            fullIcon: fullGameIcon,
            onArtTap: { bootGame(wrapper) },
            onInfoTap: { selectedGameForDetail = wrapper }
          )
          .frame(width: 130)
          .contextMenu {
              Button {
                selectedGameForDetail = wrapper
              } label: {
                Label("Details", systemImage: "info.circle")
              }
              Button {
                propertiesGame = wrapper
              } label: {
                Label("Properties", systemImage: "square.and.pencil")
              }
              Button(role: .destructive) {
                showDeleteConfirm = (wrapper, wrapper.displayName())
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
        }
      }
      .padding(.horizontal, 8)
    }
    .frame(maxHeight: .infinity)
  }

  // Landscape: horizontal-only empty state with browser card
  private var emptyStateWithBrowser: some View {
    VStack {
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHGrid(rows: [GridItem(.flexible())], alignment: .center, spacing: 12) {
          WebBrowserCard(
            fullIcon: fullGameIcon,
            onArtTap: {
              webBrowserURL = kWebBrowserDefaultURL
              requestOpenBrowser()
            },
            onInfoTap: { showWebBrowserDetail = true }
          )
          .frame(width: 130)
          .contextMenu {
            Button {
              webBrowserURL = kWebBrowserDefaultURL
              requestOpenBrowser()
            } label: {
              Label("Open Browser", systemImage: "safari")
            }
            Button {
              showWebBrowserDetail = true
            } label: {
              Label("About", systemImage: "info.circle")
            }
          }
        }
        .padding(.horizontal, 8)
      }
      .frame(maxHeight: .infinity)
      emptyStateView
    }
  }

  // Portrait: LazyVGrid without ScrollView, so it sizes to content (no maxHeight infinity)
  private var gameGridWithBrowserPortrait: some View {
    LazyVGrid(columns: gridColumns, spacing: 12) {
      WebBrowserCard(
        fullIcon: fullGameIcon,
        onArtTap: {
          webBrowserURL = kWebBrowserDefaultURL
          requestOpenBrowser()
        },
        onInfoTap: { showWebBrowserDetail = true }
      )
      .contextMenu {
        Button {
          webBrowserURL = kWebBrowserDefaultURL
          requestOpenBrowser()
        } label: {
          Label("Open Browser", systemImage: "safari")
        }
        Button {
          showWebBrowserDetail = true
        } label: {
          Label("About", systemImage: "info.circle")
        }
      }
      ForEach(Array(filteredGames.enumerated()), id: \.offset) { _, wrapper in
        GameCell(
          wrapper: wrapper,
          playTimeSeconds: playTimeSeconds(for: wrapper),
          fullIcon: fullGameIcon,
          onArtTap: { bootGame(wrapper) },
          onInfoTap: { selectedGameForDetail = wrapper }
        )
        .contextMenu {
            Button {
              selectedGameForDetail = wrapper
            } label: {
              Label("Details", systemImage: "info.circle")
            }
            Button {
              propertiesGame = wrapper
            } label: {
              Label("Properties", systemImage: "square.and.pencil")
            }
            Button(role: .destructive) {
              showDeleteConfirm = (wrapper, wrapper.displayName())
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
      }
    }
    .padding()
  }

  // Portrait: LazyVGrid without ScrollView for empty state with browser card
  private var emptyStateWithBrowserPortrait: some View {
    LazyVGrid(columns: gridColumns, spacing: 12) {
      WebBrowserCard(
        fullIcon: fullGameIcon,
        onArtTap: {
          webBrowserURL = kWebBrowserDefaultURL
          requestOpenBrowser()
        },
        onInfoTap: { showWebBrowserDetail = true }
      )
      .contextMenu {
        Button {
          webBrowserURL = kWebBrowserDefaultURL
          requestOpenBrowser()
        } label: {
          Label("Open Browser", systemImage: "safari")
        }
        Button {
          showWebBrowserDetail = true
        } label: {
          Label("About", systemImage: "info.circle")
        }
      }
    }
    .padding()
    return emptyStateView
  }

  private var emptyStateView: some View {
    VStack(spacing: 20) {
      Image(systemName: "gamecontroller.fill")
        .font(.system(size: 80))
        .foregroundStyle(
          LinearGradient(
            colors: [.blue.opacity(0.7), Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      Text("No Games Yet")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(.primary)

      Text("Tap the + button to add games, or open from the menu.")
        .font(.subheadline)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)

      Button {
        documentPickerMode = .importSoftware
      } label: {
        Label("Add Games", systemImage: "plus.circle.fill")
          .font(.headline)
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(
            LinearGradient(
              colors: [.blue, Color(red: 0.25, green: 0.45, blue: 0.95)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .cornerRadius(12)
      }
      .padding(.top)
    }
    .frame(maxWidth: .infinity)
  }

  private func reloadGamesSync() {
    // Show list immediately from current cache (art if already cached, else placeholder).
    games = (GameFileCacheManager.shared().getGames() as? [GameFilePtrWrapper]) ?? []
    // Then refresh library when metadata/cover art is done loading.
    GameFileCacheManager.shared().rescanAndFetchMetadata(completionHandler: {
      DispatchQueue.main.async {
        self.games = (GameFileCacheManager.shared().getGames() as? [GameFilePtrWrapper]) ?? []
      }
    })
  }

  private func reloadGames() async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
      GameFileCacheManager.shared().rescanAndFetchMetadata(completionHandler: {
        DispatchQueue.main.async {
          self.games = (GameFileCacheManager.shared().getGames() as? [GameFilePtrWrapper]) ?? []
          cont.resume()
        }
      })
    }
  }

  private func playTimeSeconds(for wrapper: GameFilePtrWrapper) -> Int64 {
    DOLConfigBridge.playTimeSeconds(forGameID: wrapper.gameID())
  }

  private func bootGame(_ wrapper: GameFilePtrWrapper, savestateSlot: Int? = nil) {
    let path = wrapper.filePath()
    var secondPath: String?
    let gid = wrapper.gameID()
    let dnum = wrapper.discNumber()
    for other in games {
      if other.gameID() == gid && other.discNumber() != dnum {
        secondPath = other.filePath()
        break
      }
    }
    let param = EmulationBootParameter()
    param.bootType = .file
    param.path = path
    param.secondPath = secondPath ?? ""
    param.isNKit = wrapper.isNKit()
    if let slot = savestateSlot, slot >= 1, slot <= 5 {
      let statePath = saveStatePathForGame(gameID: gid, slot: slot)
      if FileManager.default.fileExists(atPath: statePath) {
        param.savestatePath = statePath
      }
    }
    bootParameter = param
  }

  private func presentGCIPL(region: Int) {
    let param = EmulationBootParameter()
    param.bootType = EmulationBootType(rawValue: 2)!  // EmulationBootTypeGCIPL
    param.iplRegion = Int32(region)
    bootParameter = param
  }

  private func importNand(at url: URL) {
    let path = url.path
    url.startAccessingSecurityScopedResource()
    NandImporterHelper.importNand(atPath: path) {
      url.stopAccessingSecurityScopedResource()
      DispatchQueue.main.async { reloadGamesSync() }
    }
  }

  @ViewBuilder
  private func documentPickerSheet(mode: DocumentPickerMode) -> some View {
    let types: [UTType] = [
      UTType("com.example.fin.generic-software"),
      UTType("com.example.fin.gamecube-software"),
      UTType("com.example.fin.wii-software"),
      .data,
    ].compactMap { $0 }
    DocumentPickerView(contentTypes: types, onPick: { url in
      documentPickerMode = nil
      switch mode {
      case .importSoftware:
        ImportFileManager.shared().importFile(at: url)
      case .openExternal:
        if (url as NSURL).startAccessingSecurityScopedResource() {
          if let wrapper = GameFilePtrWrapper(path: url.path) {
            bootGame(wrapper)
          }
        }
      case .importNAND:
        break
      }
    }, onDismiss: {
      documentPickerMode = nil
    })
  }
}

// MARK: - Card shape (full card = one rounded rect; art area = top corners only for clip)

private struct GameCardShape: Shape {
  var radius: CGFloat
  /// If true, only top corners are rounded (for clipping the cover art so the card’s bottom isn’t rounded by the art).
  var topCornersOnly: Bool

  func path(in rect: CGRect) -> Path {
    if topCornersOnly {
      var path = Path()
      let r = min(radius, rect.width / 2, rect.height / 2)
      path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
      path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
      path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
      path.closeSubpath()
      return path
    }
    var path = Path()
    path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
    return path
  }
}

private extension Path {
  mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle) {
    let r = min(cornerSize.width, rect.width / 2, rect.height / 2)
    move(to: CGPoint(x: rect.minX + r, y: rect.minY))
    addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
    addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
    addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
    addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
    addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
    addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
    closeSubpath()
  }
}

// MARK: - Game cell (art fills icon; text forced to resize and not extend card)

private struct GameCell: View {
  let wrapper: GameFilePtrWrapper
  let playTimeSeconds: Int64
  let fullIcon: Bool
  let onArtTap: () -> Void
  let onInfoTap: () -> Void

  private var cardCornerRadius: CGFloat { 10 }
  /// Height of cover area in non–full-icon mode.
  private var coverHeight: CGFloat { 140 }
  /// Approximate height of the title/platform/playtime strip so full-icon can fill the same total card.
  private var infoStripHeight: CGFloat { 60 }
  /// In full-icon mode, image fills the whole card (cover + strip area).
  private var imageHeight: CGFloat { fullIcon ? coverHeight + infoStripHeight : coverHeight }

  /// Full card outline: one rounded rect (all four corners).
  private var cardShapeFull: GameCardShape {
    GameCardShape(radius: cardCornerRadius, topCornersOnly: false)
  }
  /// Clip for cover art only: rounded top, flat bottom so the card’s bottom isn’t rounded by the art.
  private var artClipShape: GameCardShape {
    GameCardShape(radius: cardCornerRadius, topCornersOnly: true)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Art: fills the icon; in full-icon mode fills entire card (cover + former info area)
      GeometryReader { geo in
        Image(uiImage: wrapper.coverImage())
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: geo.size.width, height: geo.size.height)
          .clipped()
      }
      .frame(height: imageHeight)
      .clipped()
      .clipShape(fullIcon ? cardShapeFull : artClipShape)
      .contentShape(Rectangle())
      .onTapGesture(perform: onArtTap)

      if !fullIcon {
        // Info: title, platform, playtime; no rounding here — card itself is rounded
        VStack(alignment: .leading, spacing: 2) {
          Text(wrapper.displayName())
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .foregroundColor(.primary)

          HStack(spacing: 4) {
            Image(systemName: "opticaldisc")
              .font(.system(size: 9))
            Text(platformLabel)
              .font(.caption2)
          }
          .foregroundColor(.gray)

          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.system(size: 9))
            Text(playTimeText)
              .font(.caption2)
          }
          .foregroundColor(.gray)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: infoStripHeight)
        .background(
          Rectangle()
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onInfoTap)
      }
    }
    .frame(height: fullIcon ? imageHeight : nil)
    .background(
      cardShapeFull.fill(Color(uiColor: .secondarySystemGroupedBackground))
    )
    .clipShape(cardShapeFull)
    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
  }

  private var platformLabel: String {
    let id = wrapper.gameID()
    if id.hasPrefix("R") || id.hasPrefix("S") { return "Wii" }
    return "GameCube"
  }

  private var playTimeText: String {
    if playTimeSeconds > 0 { return formatPlayTime(playTimeSeconds) }
    return "Play time: —"
  }
}

private func formatPlayTime(_ seconds: Int64) -> String {
  let h = seconds / 3600
  let m = (seconds % 3600) / 60
  if h > 0 { return "\(h)h \(m)m" }
  return "\(m)m"
}

// MARK: - Colors from game art (for play button and background reflection)

private func colorsFromCoverImage(_ image: UIImage) -> (Color, Color) {
  let size = image.size
  guard size.width > 0, size.height > 0 else {
    return (Color.blue, Color(red: 0.25, green: 0.45, blue: 0.95))
  }
  let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
  let onePixel = renderer.image { _ in
    image.draw(in: CGRect(origin: .zero, size: CGSize(width: 1, height: 1)))
  }
  guard let cgImage = onePixel.cgImage else { return (Color.blue, Color(red: 0.25, green: 0.45, blue: 0.95)) }
  let w = cgImage.width
  let h = cgImage.height
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bytesPerPixel = 4
  let bytesPerRow = bytesPerPixel * w
  var pixelData = [UInt8](repeating: 0, count: w * h * bytesPerPixel)
  guard let ctx = CGContext(
    data: &pixelData,
    width: w,
    height: h,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { return (Color.blue, Color(red: 0.25, green: 0.45, blue: 0.95)) }
  ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
  let r = CGFloat(pixelData[0]) / 255
  let g = CGFloat(pixelData[1]) / 255
  let b = CGFloat(pixelData[2]) / 255
  let main = Color(red: r, green: g, blue: b)
  let darker = Color(red: max(0, r - 0.15), green: max(0, g - 0.15), blue: max(0, b - 0.15))
  return (main, darker)
}

private func saveStatePathForGame(gameID: String, slot: Int) -> String {
  let dir = (UserFolderUtil.getUserFolder() as NSString).appendingPathComponent("StateSaves")
  return (dir as NSString).appendingPathComponent("\(gameID).s\(String(format: "%02d", slot))")
}

private func gameInfoCacheURL(gameID: String) -> URL {
  let dir = (UserFolderUtil.getUserFolder() as NSString).appendingPathComponent("Game Info")
  let path = (dir as NSString).appendingPathComponent("\(gameID).txt")
  return URL(fileURLWithPath: path)
}

// MARK: - Game detail (sheet; dismiss by swipe down; no X; art like light on background; play button from game colors; Wikipedia info)

private struct GameDetailFullView: View {
  let wrapper: GameFilePtrWrapper
  let platform: String
  let playTimeSeconds: Int64
  let onPlay: () -> Void
  var onPlayWithSavestateSlot: ((Int) -> Void)?

  @State private var playButtonColor: Color = .blue
  @State private var playButtonColor2: Color = Color(red: 0.25, green: 0.45, blue: 0.95)
  @State private var bgTint1: Color = Color(hue: 0.55, saturation: 0.4, brightness: 0.12)
  @State private var bgTint2: Color = Color(hue: 0.58, saturation: 0.35, brightness: 0.08)
  @State private var wikiText: String?
  @State private var wikiLoading = false

  var body: some View {
    GeometryReader { geometry in
      let isLandscape = geometry.size.width > geometry.size.height
      ZStack {
        // Dark base
        LinearGradient(
          colors: [
            Color(hue: 0.55, saturation: 0.4, brightness: 0.1),
            Color(hue: 0.58, saturation: 0.35, brightness: 0.06)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        // Game-art reflection (tint from cover)
        LinearGradient(
          colors: [bgTint1, bgTint2],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        if isLandscape {
          // Landscape: no main scroll; title scrollable when long; About/Save/File extend equally (icon fixed)
          VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
              // 1. Game icon — fixed size; title scrollable horizontally when too long
              VStack(spacing: 4) {
                MarqueeText(text: wrapper.displayName(), font: .caption, fontWeight: .semibold, color: .white)
                  .frame(width: 140)
                
                Button(action: onPlay) {
                  Image(uiImage: wrapper.coverImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
              }

              // 2. About — extends with extra space
              VStack(alignment: .leading, spacing: 6) {
                Text("About")
                  .font(.caption)
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                ScrollView(.vertical, showsIndicators: true) {
                  if wikiLoading {
                    ProgressView()
                      .tint(.white)
                      .frame(maxWidth: .infinity)
                      .padding(.top, 8)
                  } else if let text = wikiText, !text.isEmpty {
                    Text(text)
                      .font(.caption2)
                      .foregroundColor(.white.opacity(0.9))
                      .frame(maxWidth: .infinity, alignment: .leading)
                  } else {
                    Text("No description available.")
                      .font(.caption2)
                      .foregroundColor(.gray)
                  }
                }
                .frame(height: 200)
              }
              .frame(maxWidth: .infinity)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white.opacity(0.05))
              )

              // 3. Save states — extends with extra space
              VStack(alignment: .leading, spacing: 6) {
                Text("Save states")
                  .font(.caption)
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                ForEach([1, 2, 3, 4, 5], id: \.self) { slot in
                  GameDetailSaveStateSlotView(
                    slot: slot,
                    exists: FileManager.default.fileExists(atPath: saveStatePathForGame(gameID: wrapper.gameID(), slot: slot)),
                    onTap: {
                      guard FileManager.default.fileExists(atPath: saveStatePathForGame(gameID: wrapper.gameID(), slot: slot)) else { return }
                      onPlayWithSavestateSlot?(slot)
                    }
                  )
                }
              }
              .frame(maxWidth: .infinity)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white.opacity(0.05))
              )

              // 4. File logic — extends with extra space
              VStack(spacing: 6) {
                GameDetailInfoRow(icon: "opticaldisc", label: "System", value: platform)
                GameDetailInfoRow(icon: "doc.fill", label: "File", value: (wrapper.filePath() as NSString).lastPathComponent)
                if let size = fileSizeString {
                  GameDetailInfoRow(icon: "internaldrive", label: "File Size", value: size)
                }
                GameDetailInfoRow(icon: "clock", label: "Play Time", value: playTimeSeconds > 0 ? formatPlayTime(playTimeSeconds) : "—")
                GameDetailInfoRow(icon: "calendar", label: "Last played", value: "—")
              }
              .frame(maxWidth: .infinity)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white.opacity(0.05))
              )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
          }
          .frame(maxWidth: .infinity)
        } else {
          // Portrait: smaller popup (no bottom space), icon moved left, save state UI extended
          ScrollView {
            VStack(spacing: 10) {
              // Game name — scrollable if too long (purple)
              ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                  Spacer(minLength: 0)
                  Text(wrapper.displayName())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                  Spacer(minLength: 0)
                }
              }
              .frame(maxWidth: .infinity)

              // Game icon (moved left) + save state slots (extended longer)
              HStack(alignment: .top, spacing: 8) {
                let coverWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 180 : 120
                let coverHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 260 : 200
                // Game icon — moved to the left
                Button(action: onPlay) {
                  Image(uiImage: wrapper.coverImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverWidth)
                    .frame(height: coverHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                // Save state slots — extended longer to fill remaining space
                VStack(spacing: 4) {
                  ForEach([1, 2, 3, 4, 5], id: \.self) { slot in
                    GameDetailSaveStateSlotView(
                      slot: slot,
                      exists: FileManager.default.fileExists(atPath: saveStatePathForGame(gameID: wrapper.gameID(), slot: slot)),
                      onTap: {
                        guard FileManager.default.fileExists(atPath: saveStatePathForGame(gameID: wrapper.gameID(), slot: slot)) else { return }
                        onPlayWithSavestateSlot?(slot)
                      },
                      large: false
                    )
                    .frame(maxHeight: .infinity)
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: coverHeight)
              }

              // Play Game button
              Button(action: onPlay) {
                HStack {
                  Image(systemName: "play.fill")
                  Text("Play Game")
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                  LinearGradient(
                    colors: [playButtonColor, playButtonColor2],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .cornerRadius(12)
              }
              .shadow(color: playButtonColor.opacity(0.5), radius: 8, x: 0, y: 4)

              // About — compact
              VStack(alignment: .leading, spacing: 8) {
                Text("About")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                if wikiLoading {
                  ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                } else if let text = wikiText, !text.isEmpty {
                  Text(text)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                } else {
                  Text("No description available.")
                    .font(.caption)
                    .foregroundColor(.gray)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color.white.opacity(0.05))
              )

              // Metadata — compact
              VStack(spacing: 8) {
                GameDetailInfoRow(icon: "opticaldisc", label: "System", value: platform)
                GameDetailInfoRow(icon: "doc.fill", label: "File", value: (wrapper.filePath() as NSString).lastPathComponent)
                if let size = fileSizeString {
                  GameDetailInfoRow(icon: "internaldrive", label: "File Size", value: size)
                }
                GameDetailInfoRow(icon: "clock", label: "Play Time", value: playTimeSeconds > 0 ? formatPlayTime(playTimeSeconds) : "—")
                GameDetailInfoRow(icon: "calendar", label: "Last played", value: "—")
              }
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color.white.opacity(0.05))
              )
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 0)
          }
        }
      }
    }
    .onAppear {
      let img = wrapper.coverImage()
      let (c1, c2) = colorsFromCoverImage(img)
      playButtonColor = c1
      playButtonColor2 = c2
      bgTint1 = c1.opacity(0.35)
      bgTint2 = c2.opacity(0.3)
      Task { await loadWikipedia() }
    }
  }

  private var fileSizeString: String? {
    let path = wrapper.filePath()
    guard !path.isEmpty else { return nil }
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let bytes = attrs[.size] as? Int64 else { return nil }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  private func loadWikipedia() async {
    wikiLoading = true
    defer { wikiLoading = false }
    let gameID = wrapper.gameID()

    // 1. Try cache: Game Info/<gameID>.txt
    let cacheURL = gameInfoCacheURL(gameID: gameID)
    if let cached = try? String(contentsOf: cacheURL, encoding: .utf8), !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      await MainActor.run { wikiText = cached.trimmingCharacters(in: .whitespacesAndNewlines) }
      return
    }

    // 2. Fetch from Wikipedia
    let name = wrapper.displayName()
    let clean = name
      .replacingOccurrences(of: " (USA)", with: "")
      .replacingOccurrences(of: " (Europe)", with: "")
      .replacingOccurrences(of: " (Japan)", with: "")
      .replacingOccurrences(of: " (Video Game)", with: "")
      .trimmingCharacters(in: .whitespaces)
    let titlePath = clean.replacingOccurrences(of: " ", with: "_")
    let title = titlePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? titlePath
    let fallbackPath = (clean + " (video game)").replacingOccurrences(of: " ", with: "_")
    let fallback = fallbackPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fallbackPath
    var extract: String?
    let urlString = "https://en.wikipedia.org/api/rest_v1/page/summary/\(title)"
    guard let url = URL(string: urlString) else { return }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
         let s = json["extract"] as? String { extract = s }
    } catch {}
    if extract == nil, fallbackPath != titlePath, let url2 = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(fallback)") {
      do {
        let (data, _) = try await URLSession.shared.data(from: url2)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let s = json["extract"] as? String { extract = s }
      } catch {}
    }

    guard let text = extract, !text.isEmpty else { return }
    await MainActor.run { wikiText = text }

    // 3. Save to cache (Game Info folder, one info.txt per game)
    let dirURL = cacheURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    try? text.write(to: cacheURL, atomically: true, encoding: .utf8)
  }
}


private struct GameDetailSaveStateSlotView: View {
  let slot: Int
  let exists: Bool
  let onTap: () -> Void
  var large: Bool = false

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: large ? 16 : 8) {
        Image(systemName: exists ? "internaldrive.fill" : "square.dashed")
          .font(.system(size: large ? 28 : 14, weight: .medium))
          .foregroundStyle(exists ? Color.blue.opacity(0.9) : Color.white.opacity(0.25))
          .frame(width: large ? 40 : 22, alignment: .center)
        Text(exists ? "Slot \(slot)" : "Slot \(slot) — None")
          .font(large ? .title3 : .caption)
          .fontWeight(.medium)
          .foregroundColor(exists ? .white : .white.opacity(0.5))
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right")
          .font(.system(size: large ? 12 : 10))
          .foregroundColor(.white.opacity(exists ? 0.4 : 0))
      }
      .padding(.horizontal, large ? 20 : 10)
      .padding(.vertical, large ? 18 : 8)
      .background(
        RoundedRectangle(cornerRadius: large ? 14 : 10, style: .continuous)
          .fill(.ultraThinMaterial.opacity(0.6))
          .overlay(
            RoundedRectangle(cornerRadius: large ? 14 : 10, style: .continuous)
              .strokeBorder(Color.white.opacity(exists ? 0.12 : 0.06), lineWidth: 1)
          )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!exists)
    .opacity(exists ? 1 : 0.85)
  }
}

private struct GameDetailInfoRow: View {
  let icon: String
  let label: String
  let value: String

  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundColor(.blue)
        .frame(width: 24)
      Text(label)
        .foregroundColor(.gray)
      Spacer()
      Text(value)
        .foregroundColor(.white)
        .fontWeight(.medium)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(.subheadline)
  }
}

// MARK: - Emulation hosting (full screen)

struct EmulationHostingView: UIViewControllerRepresentable {
  let bootParameter: EmulationBootParameter

  func makeUIViewController(context: Context) -> UIViewController {
    EmulationSwiftUIHostingController(bootParameter: bootParameter)
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Document picker mode

private enum DocumentPickerMode {
  case importSoftware
  case openExternal
  case importNAND
}

// MARK: - Document picker (SwiftUI wrapper)

struct DocumentPickerView: UIViewControllerRepresentable {
  let contentTypes: [UTType]
  let onPick: (URL) -> Void
  let onDismiss: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onPick: onPick, onDismiss: onDismiss)
  }

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
    picker.delegate = context.coordinator
    picker.allowsMultipleSelection = false
    return picker
  }

  func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

  class Coordinator: NSObject, UIDocumentPickerDelegate {
    let onPick: (URL) -> Void
    let onDismiss: () -> Void
    init(onPick: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
      self.onPick = onPick
      self.onDismiss = onDismiss
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
      if let url = urls.first { onPick(url) }
      else { onDismiss() }
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      onDismiss()
    }
  }
}

// MARK: - Wii update (SwiftUI placeholder)

struct WiiUpdateView: View {
  let source: String
  let isOnline: Bool
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Image(systemName: "icloud.and.arrow.down")
          .font(.largeTitle)
        Text("Wii System Update")
          .font(.title2)
        Text("Online update is not available in this build. Use the desktop Dolphin to perform system updates.")
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .padding()
        Button("Done", action: onDismiss)
          .buttonStyle(.borderedProminent)
      }
      .padding()
      .navigationTitle("Wii Update")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done", action: onDismiss)
        }
      }
    }
  }
}

// MARK: - Software properties (SwiftUI)

struct SoftwarePropertiesSheet: View {
  let gameFileWrapper: GameFilePtrWrapper
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      List {
        Section("Game") {
          LabeledContent("Name", value: gameFileWrapper.displayName())
          LabeledContent("Game ID", value: gameFileWrapper.gameID())
          LabeledContent("Path", value: gameFileWrapper.filePath())
        }
      }
      .navigationTitle(gameFileWrapper.gameID())
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: onDismiss)
        }
      }
    }
  }
}
