//
//  Durian.swift
//  Durian
//
//  Created by Jarrod Norwell on 2/9/2026.
//

import Foundation
import UIKit

public enum DurianButton : UInt32 {
    case up = 0x1
    case down = 0x2
    case left = 0x4
    case right = 0x8
    case up2 = 0x10
    case down2 = 0x20
    case left2 = 0x40
    case right2 = 0x80
    case sound = 0x100
    case start = 0x200
    case b = 0x400
    case a = 0x800
    
    var uint32: UInt32 { rawValue }
}

public enum SoundVolume : Sendable {
    case full, half, soft, muted
    
    public var next: SoundVolume {
        switch self {
        case .full:
            SoundVolume.half
        case .half:
            SoundVolume.soft
        case .soft:
            SoundVolume.muted
        case .muted:
            SoundVolume.full
        }
    }
    
    public var image: UIImage? {
        switch self {
        case .full:
            UIImage(systemName: "speaker.wave.3")
        case .half:
            UIImage(systemName: "speaker.wave.2")
        case .soft:
            UIImage(systemName: "speaker.wave.1")
        case .muted:
            UIImage(systemName: "speaker.slash.fill")
        }
    }
}

public class DurianCommon {
    public init() {}
    
    public static var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    public static var durianDirectoryURL: String? {
        if let documentDirectoryURL {
            documentDirectoryURL.appending(component: "Durian").path
        } else {
            nil
        }
    }
}

public actor DurianSystem {
    private var fileManager: FileManager = .default
    
    private var _soundVolume: SoundVolume = .full
    public var soundVolume: SoundVolume {
        get {
            return _soundVolume
        }
        
        set {
            _soundVolume = newValue
        }
    }
    
    public func set(soundVolume: SoundVolume) {
        _soundVolume = soundVolume
    }
    
    public init() {}
    
    public func printAbout() {
        durian.print_about()
    }
    
    public func initializePaths() {
        durian.initialize_paths()
    }
    
    public func initializeSystem() {
        durian.initialize_system()
    }
    
    public func destroySystem() {
        durian.destroy_system()
    }
    
    public func insertDisc(at url: URL) {
        durian.insert_disc(std.string(url.path))
    }
    
    public func set(change: Bool = false, isRunning: Bool = false) {
        if change {
            running = isRunning
        }
    }
    
    public var running: Bool {
        get {
            durian.is_running()
        }
        set {
            durian.is_running(true, newValue)
        }
    }
    
    public func set(change: Bool = false, isPaused: Bool = false) {
        if change {
            paused = isPaused
        }
    }
    
    public var paused: Bool {
        get {
            durian.is_paused()
        }
        set {
            durian.is_paused(true, newValue)
        }
    }
    
    
    public func start() {
        durian.start()
    }
    
    public func stop() {
        durian.stop()
    }
    
    
    public var framebufferHeight: Int32 {
        durian.framebuffer_height()
    }
    
    public var framebufferWidth: Int32 {
        durian.framebuffer_width()
    }
    
    
    public nonisolated func press(button: DurianButton) {
        durian.press_button(button.uint32)
    }
    
    public nonisolated func release(button: DurianButton) {
        durian.release_button(button.uint32)
    }
    
    
    public nonisolated func audioBuffer(callback: durian.AudioVideoBufferCallback) {
        durian.audio_buffer_callback(callback)
    }
    
    public nonisolated func videoBuffer(callback: durian.AudioVideoBufferCallback) {
        durian.video_buffer_callback(callback)
    }
    
    
    public func setContext(context: UnsafeMutableRawPointer) {
        durian.set_context(context)
    }
    
    
    public nonisolated func boxartURLString(for url: URL) -> String? {
        let title: String = url.deletingPathExtension().lastPathComponent

        let endpoint: String = "https://raw.githubusercontent.com/libretro/libretro-thumbnails/refs/heads/master"
        return if url.pathExtension.lowercased() == "wsc" {
            "\(endpoint)/Bandai - WonderSwan Color/Named_Boxarts/\(title).png"
        } else {
            "\(endpoint)/Bandai - WonderSwan/Named_Boxarts/\(title).png"
        }
    }
}
