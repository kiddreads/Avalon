// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SafariServices
import SwiftUI

// MARK: - Default URL (Google Search)

/// Default URL when opening the in-app browser. Google Search.
let kWebBrowserDefaultURL = URL(string: "https://www.google.com")!

// MARK: - Safari in-app browser (SwiftUI)

struct SafariView: UIViewControllerRepresentable {
  let url: URL
  var onDismiss: (() -> Void)?

  func makeUIViewController(context: Context) -> SFSafariViewController {
    let config = SFSafariViewController.Configuration()
    config.entersReaderIfAvailable = false
    config.barCollapsingEnabled = true
    let vc = SFSafariViewController(url: url, configuration: config)
    vc.preferredBarTintColor = UIColor(white: 0.22, alpha: 1)
    vc.preferredControlTintColor = .systemBlue
    vc.delegate = context.coordinator
    return vc
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  class Coordinator: NSObject, SFSafariViewControllerDelegate {
    var onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)?) {
      self.onDismiss = onDismiss
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
      onDismiss?()
    }
  }
}

// MARK: - Web Browser card (same shape and size as game cards: one rounded card, art top-only clip, info strip flat)

private let kWebBrowserCardArtHeight: CGFloat = 140
private let kWebBrowserCardInfoHeight: CGFloat = 60
private let kWebBrowserCardCornerRadius: CGFloat = 10

private struct WebBrowserCardShape: Shape {
  var radius: CGFloat
  var topCornersOnly: Bool
  func path(in rect: CGRect) -> Path {
    let r = min(radius, rect.width / 2, rect.height / 2)
    var path = Path()
    if topCornersOnly {
      path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
      path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
      path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
      path.closeSubpath()
    } else {
      path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
      path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
      path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
      path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
      path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
      path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
      path.closeSubpath()
    }
    return path
  }
}

struct WebBrowserCard: View {
  var fullIcon: Bool = false
  var onArtTap: () -> Void
  var onInfoTap: () -> Void

  private var playTimeSeconds: Int64 {
    DOLConfigBridge.playTimeSeconds(forGameID: "BROWSER")
  }

  private var cardShapeFull: WebBrowserCardShape {
    WebBrowserCardShape(radius: kWebBrowserCardCornerRadius, topCornersOnly: false)
  }
  private var artClipShape: WebBrowserCardShape {
    WebBrowserCardShape(radius: kWebBrowserCardCornerRadius, topCornersOnly: true)
  }
  private var imageHeight: CGFloat { fullIcon ? kWebBrowserCardArtHeight + kWebBrowserCardInfoHeight : kWebBrowserCardArtHeight }

  private var playTimeText: String {
    if playTimeSeconds > 0 { return formatPlayTime(playTimeSeconds) }
    return "Play time: —"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Art: full icon = fill whole card (like game cards); else art + info strip
      ZStack {
        Rectangle()
          .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        Image(systemName: "network")
          .font(.system(size: fullIcon ? 56 : 48, weight: .medium))
          .foregroundColor(.secondary)
        if fullIcon {
          VStack {
            Spacer()
            Text("Browser")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundColor(.primary.opacity(0.85))
              .padding(.bottom, 6)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: imageHeight)
      .clipShape(fullIcon ? cardShapeFull : artClipShape)
      .contentShape(Rectangle())
      .onTapGesture(perform: onArtTap)

      if !fullIcon {
        // Info strip: same spacing as game cards (padding 6, height 60)
        VStack(alignment: .leading, spacing: 2) {
          Text("Browser")
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.primary)

          HStack(spacing: 4) {
            Image(systemName: "globe")
              .font(.system(size: 9))
            Text("iOS")
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
        .frame(height: kWebBrowserCardInfoHeight)
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
    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
  }
}

// MARK: - Web Browser detail sheet (same layout and logic as game detail: cover, title, play button, about, details card)

private let kWebBrowserDetailCoverHeight: CGFloat = 200

private struct HomebrewLink {
  let name: String
  let url: String
  let icon: String
}

private let homebrewLinks: [HomebrewLink] = [
  HomebrewLink(name: "WiiBrew (Wii Homebrew)", url: "https://wiibrew.org", icon: "globe"),
  HomebrewLink(name: "Open Shop Channel (Wii)", url: "https://oscwii.org", icon: "cart"),
  HomebrewLink(name: "GC-Forever (GameCube Homebrew)", url: "https://www.gc-forever.com", icon: "opticaldisc"),
  HomebrewLink(name: "PDROMs (Public Domain ROMs)", url: "https://pdroms.de", icon: "archivebox"),
  HomebrewLink(name: "Zophar’s Domain (Homebrew / PD)", url: "https://www.zophar.net", icon: "link")
]

struct WebBrowserDetailView: View {
  var onOpenBrowser: () -> Void
  var onOpenURL: (URL) -> Void
  var onDismiss: () -> Void

  private var playTimeSeconds: Int64 {
    DOLConfigBridge.playTimeSeconds(forGameID: "BROWSER")
  }

  var body: some View {
    GeometryReader { geometry in
      let isLandscape = geometry.size.width > geometry.size.height
      ZStack {
        LinearGradient(
          colors: [
            Color(hue: 0.55, saturation: 0.4, brightness: 0.1),
            Color(hue: 0.58, saturation: 0.35, brightness: 0.06)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        if isLandscape {
          VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
              VStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                  Text("Browser")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                }
                .frame(width: 140)

                Button(action: onOpenBrowser) {
                  ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                      .fill(Color(white: 0.22))
                    Image(systemName: "network")
                      .font(.system(size: 52, weight: .medium))
                      .foregroundStyle(
                        LinearGradient(
                          colors: [.white.opacity(0.95), .white.opacity(0.75)],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                        )
                      )
                  }
                  .frame(width: 140, height: 200)
                  .clipped()
                  .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                  .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
              }

              VStack(alignment: .leading, spacing: 6) {
                Text("About")
                  .font(.caption)
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                ScrollView(.vertical, showsIndicators: true) {
                  Text("Built-in browser opens to Google Search. Use only for legal, licensed, or author-approved content.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
              }
              .frame(maxWidth: .infinity)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white.opacity(0.05))
              )

              VStack(alignment: .leading, spacing: 6) {
                Text("Homebrew")
                  .font(.caption)
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                ForEach(homebrewLinks.prefix(5), id: \.name) { link in
                  Button {
                    if let url = URL(string: link.url) {
                      onOpenURL(url)
                    }
                  } label: {
                    HStack(spacing: 8) {
                      Image(systemName: link.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.blue.opacity(0.9))
                        .frame(width: 22, alignment: .center)
                      Text(link.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                      Spacer(minLength: 0)
                      Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                      RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.6))
                        .overlay(
                          RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    )
                  }
                  .buttonStyle(.plain)
                }
              }
              .frame(maxWidth: .infinity)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(Color.white.opacity(0.05))
              )

              VStack(spacing: 6) {
                WebBrowserDetailInfoRow(icon: "globe", label: "System", value: "iOS")
                WebBrowserDetailInfoRow(icon: "safari", label: "Opens to", value: "Google Search")
                WebBrowserDetailInfoRow(icon: "clock", label: "Play Time", value: playTimeSeconds > 0 ? formatPlayTime(playTimeSeconds) : "—")
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
          ScrollView {
            VStack(spacing: 10) {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                  Spacer(minLength: 0)
                  Text("Browser")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                  Spacer(minLength: 0)
                }
              }
              .frame(maxWidth: .infinity)

              HStack(alignment: .top, spacing: 8) {
                let coverWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 180 : 120
                let coverHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 260 : 200
                Button(action: onOpenBrowser) {
                  ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .fill(Color(white: 0.22))
                    Image(systemName: "network")
                      .font(.system(size: 48, weight: .medium))
                      .foregroundStyle(
                        LinearGradient(
                          colors: [.white.opacity(0.95), .white.opacity(0.75)],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                        )
                      )
                  }
                  .frame(width: coverWidth, height: coverHeight)
                  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                  .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                VStack(spacing: 4) {
                  ForEach(homebrewLinks.prefix(5), id: \.name) { link in
                    Button {
                      if let url = URL(string: link.url) {
                        onOpenURL(url)
                      }
                    } label: {
                      HStack(spacing: 8) {
                        Image(systemName: link.icon)
                          .font(.system(size: 14, weight: .medium))
                          .foregroundStyle(Color.blue.opacity(0.9))
                          .frame(width: 22, alignment: .center)
                        Text(link.name)
                          .font(.caption)
                          .fontWeight(.medium)
                          .foregroundColor(.white)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                          .font(.system(size: 10))
                          .foregroundColor(.white.opacity(0.4))
                      }
                      .padding(.horizontal, 10)
                      .padding(.vertical, 8)
                      .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                          .fill(.ultraThinMaterial.opacity(0.6))
                          .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                              .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                          )
                      )
                    }
                    .buttonStyle(.plain)
                    .frame(maxHeight: .infinity)
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: coverHeight)
              }

              VStack(alignment: .leading, spacing: 8) {
                Text("About")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                Text("Built-in browser opens to Google Search. Use only for legal, licensed, or author-approved content.")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.9))
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(10)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color.white.opacity(0.05))
              )

              VStack(spacing: 8) {
                WebBrowserDetailInfoRow(icon: "globe", label: "System", value: "iOS")
                WebBrowserDetailInfoRow(icon: "safari", label: "Opens to", value: "Google Search")
                WebBrowserDetailInfoRow(icon: "clock", label: "Play Time", value: playTimeSeconds > 0 ? formatPlayTime(playTimeSeconds) : "—")
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
  }
}

private struct WebBrowserDetailInfoRow: View {
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

private func formatPlayTime(_ seconds: Int64) -> String {
  let h = seconds / 3600
  let m = (seconds % 3600) / 60
  if h > 0 { return "\(h)h \(m)m" }
  return "\(m)m"
}
