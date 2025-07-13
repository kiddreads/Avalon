//
//  NES.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/25.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore
import AVFoundation

extension GameType
{
    static let nes = GameType("public.aoshuang.game.nes")
}

extension CheatType
{
    static let gameGenie6 = CheatType("GameGenie6")
    static let gameGenie8 = CheatType("GameGenie8")
}

@objc enum NESGameInput: Int, Input {
    case a
    case b
    case start
    case select
    case up
    case down
    case left
    case right

    case flex
    case menu

    public var type: InputType {
        return .game(.nes)
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

struct NES: ManicEmuCoreProtocol {
    public static let core = NES()
    
    public var name: String { "NES" }
    public var identifier: String { "com.aoshuang.NESCore" }
    
    public var gameType: GameType { GameType.nes }
    public var gameInputType: Input.Type { NESGameInput.self }
    public var gameSaveExtension: String { "srm" }
        
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 256, height: 240))
    
    public var supportCheatFormats: Set<CheatFormat> {
        let gameGenie6Format = CheatFormat(name: NSLocalizedString("Game Genie (6)", comment: ""), format: "XXXXXX", type: .gameGenie6, allowedCodeCharacters: .letters)
        let gameGenie8Format = CheatFormat(name: NSLocalizedString("Game Genie (8)", comment: ""), format: "XXXXXXXX", type: .gameGenie8, allowedCodeCharacters: .letters)
        return [gameGenie6Format, gameGenie8Format]
    }
    
    public var emulatorConnector: EmulatorBase { NESEmulatorBridge.shared }
    
    private init() {}
}


class NESEmulatorBridge : NSObject, EmulatorBase {
    static let shared = NESEmulatorBridge()
    
    var gameURL: URL?
    
    private(set) var frameDuration: TimeInterval = (1.0 / 60.0)
    
    var audioRenderer: (any ManicEmuCore.AudioRenderProtocol)?
    
    var videoRenderer: (any ManicEmuCore.VideoRenderProtocol)?
    
    var saveUpdateHandler: (() -> Void)?
    
    private var thumbstickPosition: CGPoint = .zero
    
    func start(withGameURL gameURL: URL) {}
    
    func stop() {}
    
    func pause() {}
    
    func resume() {}
    
    func runFrame(processVideo: Bool) {}
    
    func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = NESGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: NESGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = NESGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func resetInputs() {}
    
    func saveSaveState(to url: URL) {}
    
    func loadSaveState(from url: URL) {}
    
    func saveGameSave(to url: URL) {}
    
    func loadGameSave(from url: URL) {}
    
    func addCheatCode(_ cheatCode: String, type: String) -> Bool {
        return false
    }
    
    func resetCheats() {}
    
    func updateCheats() {}
    
}
