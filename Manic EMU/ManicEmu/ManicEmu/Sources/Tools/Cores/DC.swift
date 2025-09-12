//
//  DC.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import AVFoundation

extension GameType
{
    static let dc = GameType("public.aoshuang.game.dc")
}

@objc enum DCGameInput: Int, Input {
    case a
    case b
    case x
    case y
    case l1
    case r1
    case start
    case up
    case down
    case left
    case right
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight

    case flex
    case menu

    public var type: InputType {
        return .game(.dc)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct DC: ManicEmuCoreProtocol {
    public static let core = DC()
    
    public var name: String { "DC" }
    public var identifier: String { "com.aoshuang.DCCore" }
    
    public var gameType: GameType { GameType.dc }
    public var gameInputType: Input.Type { DCGameInput.self }
    public var gameSaveExtension: String { "srm" }
        
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32040, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 640, height: 480))
    
    public var supportCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX", type: .actionReplay)
        return [actionReplayFormat]
    }
    
    public var emulatorConnector: EmulatorBase { DCEmulatorBridge.shared }
        
    private init()
    {
    }
}


class DCEmulatorBridge : NSObject, EmulatorBase {
    static let shared = DCEmulatorBridge()
    
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
        
        if input == DCGameInput.leftThumbstickUp || input == DCGameInput.leftThumbstickDown {
            thumbstickPosition.y = input == DCGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DCGameInput.leftThumbstickLeft || input == DCGameInput.leftThumbstickRight {
            thumbstickPosition.x = input == DCGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = DCGameInput(rawValue: input),
               let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
                Log.debug("\(String(describing: Self.self))点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: DCGameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .A }
        else if gameInput == .x { return .Y }
        else if gameInput == .y { return .X }
        else if gameInput == .l1 { return .L2 }
        else if gameInput == .r1 { return .R2 }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == DCGameInput.leftThumbstickUp || input == DCGameInput.leftThumbstickDown {
            thumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DCGameInput.leftThumbstickLeft || input == DCGameInput.leftThumbstickRight {
            thumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = DCGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
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
