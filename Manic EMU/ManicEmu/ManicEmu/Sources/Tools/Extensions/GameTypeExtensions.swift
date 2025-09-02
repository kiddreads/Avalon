//
//  GameTypeExtensions.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import RealmSwift
import GBADeltaCore
import GBCDeltaCore
import MelonDSDeltaCore

///通过文件名后缀生成GameType
extension GameType {
    static var multiPlatformFileExtensions = ["chd", "iso", "bin", "cue", "m3u"]
    
    static func gameTypes(multiPlatformFileExtension: String) -> [GameType] {
        let ext = multiPlatformFileExtension.lowercased()
        guard multiPlatformFileExtensions.contains(ext) else { return [] }
        switch ext {
        case "chd":
            return [.psp, .mcd, .ss]
        case "iso":
            return [.psp, .mcd, .ss]
        case "bin":
            return [.md, .gg, .ms, ._32x]
        case "cue":
            return [.mcd, .ss]
        case "m3u":
            return [.mcd, .ss]
        default:
            return []
        }
    }
    
    init(fileExtension: String) {
        let ext = fileExtension.lowercased()
        if GameType.multiPlatformFileExtensions.contains(ext) {
            //会混淆的后缀 多个平台都用这个后缀，则返回unknown
            self = .unknown
        } else if ["gba"].contains(ext)  {
            self = .gba
        } else if ["gbc"].contains(ext) {
            self = .gbc
        } else if ["gb"].contains(ext) {
            self = .gb
        }  else if ["ds", "nds"].contains(ext) {
            self = .ds
        } else if ["nes", "fc"].contains(ext)  {
            self = .nes
        } else if ["smc", "sfc", "fig", "snes"].contains(ext) {
            self = .snes
        } else if ["3ds", "cia", "app", "cci", "cxi", "3dsx"].contains(ext) {
            self = ._3ds
        } else if ["elf", "iso", "cso", "prx", "pbp", "chd"].contains(ext) {
            self = .psp
        } else if ["md", "gen", "smd", "bin"].contains(ext) {
            self = .md
        } else if ["chd", "iso", "mcd", "cue", "m3u"].contains(ext) {
            self = .mcd
        } else if ["32x"].contains(ext) {
            self = ._32x
        } else if ["sg"].contains(ext) {
            self = .sg1000
        } else if ["gg", "bin"].contains(ext) {
            self = .gg
        } else if ["sms", "bms", "bin"].contains(ext) {
            self = .ms
        } else if ["iso", "chd", "ccd", "cue", "m3u"].contains(ext) {
            self = .ss
        } else if ["n64", "v64", "z64"].contains(ext) {
            self = .n64
        } else {
            self = .notSupport
        }
    }
    
    init?(saveFileExtension: String) {
        switch saveFileExtension.lowercased() {
        case "dsv": self = .ds
        case "bkr": self = .ss
        default: return nil
        }
    }
    
    init?(shortName: String) {
        if shortName.uppercased() == "3DS" {
            self = ._3ds
        } else if shortName.uppercased() == "NDS" {
            self = .ds
        } else if shortName.uppercased() == "GBA" {
            self = .gba
        } else if shortName.uppercased() == "GBC" {
            self = .gbc
        } else if shortName.uppercased() == "GB" {
            self = .gb
        }  else if shortName.uppercased() == "NES" {
            self = .nes
        } else if shortName.uppercased() == "SNES" {
            self = .snes
        } else if shortName.uppercased() == "PSP" {
            self = .psp
        } else if shortName.uppercased() == "MD" {
            self = .md
        } else if shortName.uppercased() == "MCD" {
            self = .mcd
        } else if shortName.uppercased() == "32X" {
            self = ._32x
        } else if shortName.uppercased() == "SG-1000" {
            self = .sg1000
        } else if shortName.uppercased() == "GG" {
            self = .gg
        } else if shortName.uppercased() == "MS" {
            self = .ms
        } else if shortName.uppercased() == "SS" {
            self = .ss
        } else if shortName.uppercased() == "N64" {
            self = .n64
        }  else {
            return nil
        }
    }
    
    var isLibretroType: Bool {
        if self == ._3ds || self == .ds || self == .gba || self == .gbc || self == .gb {
            return false
        }
        return true
    }
    
    var localizedName: String {
        switch self
        {
        case .nes: return "Nintendo"
        case .snes: return "Super Nintendo"
        case ._3ds: return "Nintendo 3DS"
        case .gbc: return "Game Boy Color"
        case .gb: return "Game Boy"
        case .gba: return "Game Boy Advance"
        case .ds: return "Nintendo DS"
        case .psp: return "PlayStation Portable"
        case .md: return Locale.prefersUS ? "Sega Genesis" : "Mega Drive"
        case .mcd: return Locale.prefersUS ? "Sega CD" : "Mega-CD"
        case ._32x: return Locale.prefersUS ? "Genesis 32X" : "Super 32X"
        case .sg1000: return "SG-1000"
        case .gg: return "Game Gear"
        case .ms: return "Sega Master System"
        case .ss: return "Sega Saturn"
        case .n64: return "Nintendo 64"
        default: return ""
        }
    }
    
    var localizedShortName: String {
        switch self
        {
        case .nes: return NSLocalizedString("NES", comment: "")
        case .snes: return NSLocalizedString("SNES", comment: "")
        case ._3ds: return NSLocalizedString("3DS", comment: "")
        case .gbc: return NSLocalizedString("GBC", comment: "")
        case .gb: return NSLocalizedString("GB", comment: "")
        case .gba: return NSLocalizedString("GBA", comment: "")
        case .ds: return NSLocalizedString("NDS", comment: "")
        case .psp: return NSLocalizedString("PSP", comment: "")
        case .md: return NSLocalizedString("MD", comment: "")
        case .mcd: return NSLocalizedString("MCD", comment: "")
        case ._32x: return NSLocalizedString("32X", comment: "")
        case .sg1000: return NSLocalizedString("SG-1000", comment: "")
        case .gg: return NSLocalizedString("GG", comment: "")
        case .ms: return NSLocalizedString("MS", comment: "")
        case .ss: return NSLocalizedString("SS", comment: "")
        case .n64: return NSLocalizedString("N64", comment: "")
        case .unknown: return R.string.localizable.unknownPlatform()
        default: return ""
        }
    }
    
    var year: Int {
        switch self
        {
        case .nes: return 1985
        case .snes: return 1990
        case ._3ds: return 2011
        case .gb: return 1989
        case .gbc: return 1998
        case .gba: return 2001
        case .ds: return 2004
        case .psp: return 2004
        case .md: return 1988
        case .mcd: return 1991
        case ._32x: return 1994
        case .sg1000: return 1983
        case .gg: return 1990
        case .ms: return 1985
        case .ss: return 1994
        case .n64: return 1996
        default: return 0
        }
    }
    
    var manicEmuCore: ManicEmuCoreProtocol? {
        switch self
        {
        case .nes: return NES.core
        case .snes: return SNES.core
        case ._3ds: return ThreeDS.core
        case .gbc: return GBC.core
        case .gb: return GB.core
        case .gba: return GBA.core
        case .ds: return MelonDS.core
        case .psp: return PSP.core
        case .md: return MD.core
        case .mcd: return MCD.core
        case ._32x: return S2X.core
        case .sg1000: return SG1000.core
        case .gg: return GG.core
        case .ms: return MS.core
        case .ss: return SS.core
        case .n64: return N64.core
        default: return nil
        }
    }
    
    func reuseGameType() -> GameType {
        if self == .mcd || self == ._32x {
            return .md
        } else if self == .sg1000 || self == .gg {
            return .ms
        } else if self == .gb {
            return .gbc
        }
        return self
    }
    
    var supportCores: [String] {
        if self == .ss {
            return ["Beetle Saturn", "Yabause"]
        }
        return []
    }
    
    var reuseSkinGameType: [GameType] {
        if self == .gb || self == .gbc {
            return [.gb, .gbc]
        } else if self == .md || self == .mcd || self == ._32x {
            return [.md, .mcd, ._32x]
        } else if self == .ms || self == .gg || self == .sg1000 {
            return [.ms, .gg, .sg1000]
        }
        return [self]
    }
    
}

///让GameType支持realm的存储
extension GameType: @retroactive PersistableEnum {
    public static var allCases: [GameType] {
        System.allCases.map { $0.gameType }
    }
}
