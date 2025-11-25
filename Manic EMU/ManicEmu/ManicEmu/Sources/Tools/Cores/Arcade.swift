//
//  Arcade.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/18.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ManicEmuCore
import AVFoundation

extension GameType {
    static let arcade = GameType("public.aoshuang.game.arcade")
}

@objc enum ArcadeGameInput: Int, Input, CaseIterable {
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
    case l2
    case r2
    case l3
    case r3
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight

    case flex
    case menu

    public var type: InputType {
        return .game(.arcade)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a}
        else if stringValue == "b" { self = .b}
        else if stringValue == "x" { self = .x}
        else if stringValue == "y" { self = .y}
        else if stringValue == "start" { self = .start}
        else if stringValue == "select" { self = .select}
        else if stringValue == "up" { self = .up}
        else if stringValue == "down" { self = .down}
        else if stringValue == "left" { self = .left}
        else if stringValue == "right" { self = .right}
        else if stringValue == "l1" { self = .l1}
        else if stringValue == "r1" { self = .r1}
        else if stringValue == "l2" { self = .l2}
        else if stringValue == "r2" { self = .r2}
        else if stringValue == "l3" { self = .l3}
        else if stringValue == "r3" { self = .r3}
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp}
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown}
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft}
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight}
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp}
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown}
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft}
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight}
        else { return nil }
    }
}

struct Arcade: ManicEmuCoreProtocol {
    public static let core = Arcade()
    
    public var name: String { "Arcade" }
    public var identifier: String { "com.aoshuang.ArcadeCore" }
    
    public var gameType: GameType { GameType.arcade }
    public var gameInputType: Input.Type { ArcadeGameInput.self }
    var allInputs: [Input] { ArcadeGameInput.allCases }
    public var gameSaveExtension: String { "srm" }
        
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 640, height: 480))
    
    public var supportCheatFormats: Set<CheatFormat> {
        return []
    }
    
    public var emulatorConnector: EmulatorBase { ArcadeEmulatorBridge.shared }
    
    private init() {}
}


class ArcadeEmulatorBridge : NSObject, EmulatorBase {
    static let shared = ArcadeEmulatorBridge()
    
    var gameURL: URL?
    
    private(set) var frameDuration: TimeInterval = (1.0 / 60.0)
    
    var audioRenderer: (any ManicEmuCore.AudioRenderProtocol)?
    
    var videoRenderer: (any ManicEmuCore.VideoRenderProtocol)?
    
    var saveUpdateHandler: (() -> Void)?
    
    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    
    private var thumbstickPosition: CGPoint = .zero
    
    func start(withGameURL gameURL: URL) {}
    
    func stop() {}
    
    func pause() {}
    
    func resume() {}
    
    func runFrame(processVideo: Bool) {}
    
    func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == ArcadeGameInput.leftThumbstickUp || input == ArcadeGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = input == ArcadeGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ArcadeGameInput.leftThumbstickLeft || input == ArcadeGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = input == ArcadeGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ArcadeGameInput.rightThumbstickUp || input == ArcadeGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == ArcadeGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ArcadeGameInput.rightThumbstickLeft || input == ArcadeGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == ArcadeGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        }  else {
            if let gameInput = ArcadeGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("\(String(describing: Self.self))点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: ArcadeGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .l3 { return .L3 }
        else if gameInput == .r3 { return .R3 }
        return nil
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == ArcadeGameInput.leftThumbstickUp || input == ArcadeGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ArcadeGameInput.leftThumbstickLeft || input == ArcadeGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ArcadeGameInput.rightThumbstickUp || input == ArcadeGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == ArcadeGameInput.rightThumbstickLeft || input == ArcadeGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = ArcadeGameInput(rawValue: input),
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
