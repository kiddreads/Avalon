//
//  PSP.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore
import AVFoundation

extension GameType
{
    static let psp = GameType("public.aoshuang.game.psp")
}

extension CheatType
{
    static let cwCheat = CheatType("CWCheat")
}

@objc enum PSPGameInput: Int, Input {
    case a
    case b
    case x
    case y
    case start
    case select
    case up
    case down
    case left
    case right
    case l1
    case r1
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight

    case flex
    case menu

    public var type: InputType {
        return .game(.psp)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct PSP: ManicEmuCoreProtocol {
    static let core = PSP()
    
    var name: String { "PSP" }
    var identifier: String { "com.aoshuang.PSPCore" }
    var version: String? { "1.0.0" }
    
    var gameType: GameType { GameType.psp }
    var gameInputType: Input.Type { PSPGameInput.self }
    var gameSaveExtension: String { "psp.sav" }
    
    let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32768, channels: 2, interleaved: true)!
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 480, height: 272))
    
    var supportCheatFormats: Set<CheatFormat> {
        let cwCheatFormat = CheatFormat(name: NSLocalizedString("CWCheat", comment: ""), format: "_L 0xXXXXXXXX 0xYYYYYYYY", type: .cwCheat)
        return [cwCheatFormat]
    }
    
    var emulatorConnector: EmulatorBase { PSPEmulatorBridge.shared }
    
    private init() {}
}


class PSPEmulatorBridge : NSObject, EmulatorBase {
    static let shared = PSPEmulatorBridge()
    
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
        if input == PSPGameInput.leftThumbstickUp || input == PSPGameInput.leftThumbstickDown {
            thumbstickPosition.y = input == PSPGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PSPGameInput.leftThumbstickLeft || input == PSPGameInput.leftThumbstickRight {
            thumbstickPosition.x = input == PSPGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = PSPGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: PSPGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == PSPGameInput.leftThumbstickUp || input == PSPGameInput.leftThumbstickDown {
            thumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PSPGameInput.leftThumbstickLeft || input == PSPGameInput.leftThumbstickRight {
            thumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = PSPGameInput(rawValue: input),
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


