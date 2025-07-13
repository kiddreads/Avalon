//
//  GB.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore
import AVFoundation
import GBCDeltaCore

extension GameType {
    static let gb = GameType("public.aoshuang.game.gb")
}

enum GBGameInput: Int, Input {
    case up = 0x40
    case down = 0x80
    case left = 0x20
    case right = 0x10
    case a = 0x01
    case b = 0x02
    case start = 0x08
    case select = 0x04
    
    case flex
    case menu
    
    public var type: InputType {
        return .game(.gb)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

public struct GB: ManicEmuCoreProtocol
{
    public static let core = GB()
    
    public var name: String { "GB" }
    public var identifier: String { "com.aoshuang.GBCore" }
    
    public var gameType: GameType { GameType.gb }
    public var gameInputType: Input.Type { GBGameInput.self }
    public var gameSaveExtension: String { "gb.sav" }
    
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 35112 * 60, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 160, height: 144))
    
    public var supportCheatFormats: Set<CheatFormat> {
        let gameGenieFormat = CheatFormat(name: NSLocalizedString("Game Genie", comment: ""), format: "XXX-YYY-ZZZ", type: .gameGenie)
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX", type: .gameShark)
        return [gameGenieFormat, gameSharkFormat]
    }
    
    public var emulatorConnector: EmulatorBase { GBCEmulatorBridge.shared }
    
    private init()
    {
    }
}
