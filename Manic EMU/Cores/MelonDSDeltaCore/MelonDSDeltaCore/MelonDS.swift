//
//  MelonDS.swift
//  MelonDSDeltaCore
//
//  Created by Riley Testut on 10/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import ManicEmuCore

#if !STATIC_LIBRARY
public extension GameType
{
    static let ds = GameType("public.aoshuang.game.ds")
}

public extension CheatType
{
    static let actionReplay = CheatType("ActionReplay")
}
#endif

public extension MelonDS
{
    static let didConnectToWFCNotification = NSNotification.Name.__MelonDSDidConnectToWFC
    static let didDisconnectFromWFCNotification = NSNotification.Name.__MelonDSDidDisconnectFromWFC
    static let wfcIDUserDefaultsKey = __MelonDSWFCIDUserDefaultsKey
    static let wfcFlagsUserDefaultsKey = __MelonDSWFCFlagsUserDefaultsKey
}

@objc public enum MelonDSGameInput: Int, Input
{
    case a = 1
    case b = 2
    case select = 4
    case start = 8
    case right = 16
    case left = 32
    case up = 64
    case down = 128
    case r = 256
    case l = 512
    case x = 1024
    case y = 2048
    
    case touchScreenX = 4096
    case touchScreenY = 8192
    
    case lid = 16_384
    
    public var type: InputType {
        return .game(.ds)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .touchScreenX, .touchScreenY: return true
        default: return false
        }
    }
}

public struct MelonDS: ManicEmuCoreProtocol
{
    public static let core = MelonDS()
    
    public var name: String { "DS" }
    public var identifier: String { "com.aoshuang.DSCore" }
    public var version: String? { "0.9.5" }
    
    public var gameType: GameType { GameType.ds }
    public var gameInputType: Input.Type { MelonDSGameInput.self }
    public var gameSaveCustomPath: String? {
        let document = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return document.appending("/3DS/sdmc/saves/nds")
    }
    public var gameSaveExtension: String { "srm" }
    
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32768, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 256, height: 384))
    
    public var supportCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        return [actionReplayFormat]
    }
    
    public var emulatorConnector: EmulatorBase { MelonDSEmulatorBridge.shared }
    
    private init()
    {
    }
}

// Expose DeltaCore properties to Objective-C.
public extension MelonDSEmulatorBridge
{
    @objc(dsResources) class var __dsResources: Bundle {
        return MelonDS.core.resourceBundle
    }
    
    @objc(coreDirectoryURL) class var __coreDirectoryURL: URL {
        return _coreDirectoryURL
    }
    
    @objc(biosDirectoryURL) class var __biosDirectoryURL: URL {
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!.appending("/Libretro/system"))
    }
}

private let _coreDirectoryURL = MelonDS.core.directoryURL
