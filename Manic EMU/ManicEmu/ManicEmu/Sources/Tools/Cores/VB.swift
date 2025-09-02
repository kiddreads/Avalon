//
//  VB.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import AVFoundation

extension GameType
{
    static let vb = GameType("public.aoshuang.game.vb")
}

@objc enum VBGameInput: Int, Input {
    case a
    case b
    case l
    case r
    case start
    case select
    case up
    case down
    case left
    case right
    case rightDpadUp
    case rightDpadDown
    case rightDpadLeft
    case rightDpadRight

    case flex
    case menu

    public var type: InputType {
        return .game(.vb)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "l" { self = .l }
        else if stringValue == "r" { self = .r }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "rightDpadUp" { self = .rightDpadUp }
        else if stringValue == "rightDpadDown" { self = .rightDpadDown }
        else if stringValue == "rightDpadLeft" { self = .rightDpadLeft }
        else if stringValue == "rightDpadRight" { self = .rightDpadRight }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

struct VB: ManicEmuCoreProtocol {
    public static let core = VB()
    
    public var name: String { "VB" }
    public var identifier: String { "com.aoshuang.VBCore" }
    
    public var gameType: GameType { GameType.vb }
    public var gameInputType: Input.Type { VBGameInput.self }
    public var gameSaveExtension: String { "srm" }
        
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32040, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 384, height: 224))
    
    public var supportCheatFormats: Set<CheatFormat> {
        return []
    }
    
    public var emulatorConnector: EmulatorBase { VBEmulatorBridge.shared }
        
    private init()
    {
    }
}


class VBEmulatorBridge : NSObject, EmulatorBase {
    static let shared = VBEmulatorBridge()
    
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
        if let gameInput = VBGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("\(String(describing: Self.self))点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: VBGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .l { return .L1 }
        else if gameInput == .r { return .R1 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .rightDpadUp { return .L2 }
        else if gameInput == .rightDpadDown { return .L3 }
        else if gameInput == .rightDpadLeft { return .R2 }
        else if gameInput == .rightDpadRight { return .R3 }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = VBGameInput(rawValue: input),
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
