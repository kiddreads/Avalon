//
//  SS.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore
import AVFoundation

extension GameType
{
    static let ss = GameType("public.aoshuang.game.ss")
}

@objc enum SSGameInput: Int, Input {
    case a
    case b
    case c
    case x
    case y
    case z
    case l
    case r
    case start
    case select
    case up
    case down
    case left
    case right

    case flex
    case menu

    public var type: InputType {
        return .game(.ss)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l" { self = .l }
        else if stringValue == "r" { self = .r }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "c" { self = .c }
        else if stringValue == "z" { self = .z }
        else { return nil }
    }
}

struct SS: ManicEmuCoreProtocol {
    public static let core = SS()
    
    public var name: String { "SS" }
    public var identifier: String { "com.aoshuang.SSCore" }
    
    public var gameType: GameType { GameType.ss }
    public var gameInputType: Input.Type { SSGameInput.self }
    public var gameSaveExtension: String { "srm" }
        
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32040, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 330, height: 224))
    
    public var supportCheatFormats: Set<CheatFormat> {
        let codeBreakerFormat = CheatFormat(name: NSLocalizedString("Code Breaker", comment: ""), format: "XXXXXXXX YYYY", type: .codeBreaker)
        return [codeBreakerFormat]
    }
    
    public var emulatorConnector: EmulatorBase { SSEmulatorBridge.shared }
        
    private init()
    {
    }
}


class SSEmulatorBridge : NSObject, EmulatorBase {
    static let shared = SSEmulatorBridge()
    
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
        if let gameInput = SSGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: SSGameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .A }
        else if gameInput == .c { return .R1 }
        else if gameInput == .x { return .Y }
        else if gameInput == .y { return .X }
        else if gameInput == .z { return .L1 }
        else if gameInput == .l { return .L2 }
        else if gameInput == .r { return .R2 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = SSGameInput(rawValue: input),
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
