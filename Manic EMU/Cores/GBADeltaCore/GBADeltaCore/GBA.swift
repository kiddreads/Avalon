//
//  GBA.swift
//  GBADeltaCore
//
//  Created by Riley Testut on 6/3/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import ManicEmuCore

//public extension GBA
//{
//    static let didActivateGyroNotification = NSNotification.Name.__GBADidActivateGyro
//    static let didDeactivateGyroNotification = NSNotification.Name.__GBADidDeactivateGyro
//}

@objc public enum GBAGameInput: Int, Input
{
    case up = 64
    case down = 128
    case left = 32
    case right = 16
    case a = 1
    case b = 2
    case l = 512
    case r = 256
    case start = 8
    case select = 4
    
    public var type: InputType {
        return .game(.gba)
    }
}

public struct GBA: ManicEmuCoreProtocol
{
    public static let core = GBA()
    
    public var name: String { "GBA" }
    public var identifier: String { "com.aoshuang.GBACore" }
    
    public var gameType: GameType { GameType.gba }
    public var gameInputType: Input.Type { GBAGameInput.self }
    public var gameSaveExtension: String { "gba.sav" }
    
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32768, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 240, height: 160))
    
    public var supportCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .gameShark)
        let codeBreakerFormat = CheatFormat(name: NSLocalizedString("Code Breaker", comment: ""), format: "XXXXXXXX YYYY", type: .codeBreaker)
        return [actionReplayFormat, gameSharkFormat, codeBreakerFormat]
    }
    
    public let emulatorConnector: EmulatorBase = GBAEmulatorBridge.shared
    
    private init()
    {
    }
}

// Expose DeltaCore properties to Objective-C.
public extension GBAEmulatorBridge
{
    @objc(resourcesBundle) class var resourcesBundle: Bundle {
        return GBA.core.resourceBundle
    }
    
//    @objc(coreDirectoryURL) class var __coreDirectoryURL: URL {
//        return _coreDirectoryURL
//    }
}

//private let _coreDirectoryURL = GBA.core.directoryURL
