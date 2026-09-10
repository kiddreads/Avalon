// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// About tab with app versions, Fin disclaimer, and a richer legal & credits presentation.
struct AboutView: View {
  var body: some View {
    List {
      // App Info
      Section("App") {
        HStack {
          Text("Version")
          Spacer()
          Text(VersionManager.shared().appVersion.userFacing)
            .foregroundColor(.secondary)
        }

        HStack {
          Text("Dolphin Core")
          Spacer()
          Text(VersionManager.shared().coreVersion)
            .foregroundColor(.secondary)
        }
      }

      // Fin disclaimer + legal link
      Section("About Fin") {
        VStack(alignment: .leading, spacing: 6) {
          Text("This project is a fork of the open-source DolphiniOS codebase and is not affiliated with, endorsed by, or associated with DolphiniOS, the Dolphin Emulator Project, or Nintendo.")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("Fin does not include games, firmware, encryption keys, or copyrighted content. Users must legally own any games or content they choose to use with this application.")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("“Nintendo”, “GameCube”, and “Wii” are trademarks of Nintendo Co., Ltd. All trademarks and registered trademarks belong to their respective owners. Please do not seek help, report errors, crashes, or suggestions to Nintendo, the Dolphin Emulator Project, or DolphiniOS, as this application is not associated with them.")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        NavigationLink(destination: LegalAndLicensesView()) {
          Label("Legal & Licenses", systemImage: "doc.text")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("About")
  }
}

// MARK: - Legal, Licenses & Credits

struct LegalAndLicensesView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Group {
          Text("Fin")
            .font(.headline)
          Text("Fin is built on the open-source DolphiniOS codebase. This project is entirely independent and is not affiliated with, endorsed by, or associated with DolphiniOS, the Dolphin Emulator Project, or Nintendo.")
            .font(.body)
          Text("Fin ships without games, firmware, encryption keys, or any copyrighted content. Users must own or hold the rights to any games they run with this application.")
            .font(.body)
        }

        Divider()

        Group {
          Text("Wikipedia Notice")
            .font(.headline)
          Text("Game descriptions may be sourced from Wikipedia. Content is licensed under CC BY-SA 3.0 and GFDL. Wikipedia® is a trademark of the Wikimedia Foundation, Inc.")
            .font(.body)
          Link("Wikipedia licensing", destination: URL(string: "https://en.wikipedia.org/wiki/Wikipedia:Text_of_the_Creative_Commons_Attribution-ShareAlike_3.0_Unported_License")!)
        }
        Divider()

        Group {
          Text("Trademarks & Disclaimer")
            .font(.headline)
          Text("“Nintendo”, “GameCube”, and “Wii” are trademarks of Nintendo Co., Ltd. All trademarks and registered trademarks are the property of their respective owners. This project is not associated with Nintendo or any rights holder.")
            .font(.body)
        }
        Divider()

        Group {
          Text("Browser & Download Policy")
            .font(.headline)
          Text("Fin includes a built-in browser solely for downloading legal, user-provided assets. This browser is intended only for downloading texture packs, shader files, and configuration files. Fin does not include games, firmware, encryption keys, save data, or copyrighted content.")
            .font(.body)
          Text("You must NOT use the browser to download or access game ROMs or disc images, save data, firmware or BIOS files, ROM hacks or modified game content, game assets extracted from commercial games, or any copyrighted or licensed material without explicit permission from the rights holder.")
            .font(.body)
            .foregroundColor(.red)
          Text("You are solely responsible for ensuring that any content you download or use is legal, licensed, or author-approved. Fin does not host, distribute, verify, or endorse third-party content.")
            .font(.body)
        }
        Divider()

        Group {
          Text("Credits & Links")
            .font(.headline)
          VStack(alignment: .leading, spacing: 8) {
            Link("DolphiniOS (OatmealDome)", destination: URL(string: "https://github.com/OatmealDome/Dolphin-iOS")!)
            Link("Dolphin Emulator Project", destination: URL(string: "https://dolphin-emu.org/")!)
          }
          .font(.body)
        }
        Divider()

        Group {
          Text("Licenses")
            .font(.headline)
          Text("Fin, DolphiniOS, and the Dolphin emulator are licensed under the GNU General Public License v2.0 or later (GPL-2.0-or-later). You can copy, distribute, and modify the software under the terms of the GPL; consult the repositories for the full legal text.")
            .font(.body)
          Link("GPL-2.0-or-later", destination: URL(string: "https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html")!)
        }
        Divider()

        Group {
          Text("Third-Party Notices")
            .font(.headline)
          Text("Additional open source libraries are included. Refer to the source repository for the complete list of third-party licenses.")
            .font(.body)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Legal & Licenses")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AboutView()
    }
  }
}
#endif
