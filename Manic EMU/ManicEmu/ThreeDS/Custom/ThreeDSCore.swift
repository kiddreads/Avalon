//
//  ThreeDSCore.swift
//  Citra
//
//  Created by Daiuno on 4/15/2025.
//

import Foundation
import MetalKit
import UIKit

public struct ThreeDSCore : @unchecked Sendable {
    public static var shared = ThreeDSCore()
    
    public static var currentGameInfo: ThreeDSGameInformation? = nil
    
    private static var openKeyboardNotification: Any? = nil
    
    public static var openKeyboardAction: ((_ hintText:String?, _ keyboardType: UInt, _ maxTextSize: UInt16) -> Void)? = nil
    
    public init() {}
    
    fileprivate let threeDSObjC = ThreeDSObjC.shared()
    
    public func information(for cartridge: URL) -> ThreeDSGameInformation? {
        threeDSObjC.informationForGame(at: cartridge)
    }
    
    public func allocateVulkanLibrary() {
        threeDSObjC.allocateVulkanLibrary()
        Self.openKeyboardNotification = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "openKeyboard"), object: nil, queue: .main) { notification in
            //打开键盘输入内容
            guard let config = notification.object as? KeyboardConfig else {
                return
            }
            Self.openKeyboardAction?(config.hintText, config.buttonConfig.rawValue, config.maxTextSize)
        }
    }
    
    public func deallocateVulkanLibrary() {
        threeDSObjC.deallocateVulkanLibrary()
        if let openKeyboardNotification = Self.openKeyboardNotification {
            NotificationCenter.default.removeObserver(openKeyboardNotification)
        }
        Self.openKeyboardAction = nil
    }
    
    public func allocateMetalLayer(for layer: CAMetalLayer, with size: CGSize, isSecondary: Bool = false) {
        threeDSObjC.allocateMetalLayer(layer, with: size, isSecondary: isSecondary)
    }
    
    public func deallocateMetalLayers() {
        threeDSObjC.deallocateMetalLayers()
    }
    
    public func insertCartridgeAndBoot(with url: URL, advancedMode: Bool = false, jitSupport: Bool) {
        assignGameInfo(with: url)
        threeDSObjC.insertCartridgeAndBoot(url, advancedMode: advancedMode, jitSupport: jitSupport)
    }
    
    public func assignGameInfo(with url: URL?) {
        if let url {
            Self.currentGameInfo = information(for: url)
        } else {
            Self.currentGameInfo = nil
        }
    }
    
    public func importGame(at url: URL) -> ImportResultStatus {
        threeDSObjC.importGame(at: url)
    }
    
    public func touchBegan(at point: CGPoint) {
        threeDSObjC.touchBegan(at: point)
    }
    
    public func touchEnded() {
        threeDSObjC.touchEnded()
    }
    
    public func touchMoved(at point: CGPoint) {
        threeDSObjC.touchMoved(at: point)
    }
    
    public func virtualControllerButtonDown(_ button: VirtualControllerButtonType) {
        threeDSObjC.virtualControllerButtonDown(button)
    }
    
    public func virtualControllerButtonUp(_ button: VirtualControllerButtonType) {
        threeDSObjC.virtualControllerButtonUp(button)
    }
    
    public func thumbstickMoved(_ thumbstick: VirtualControllerAnalogType, _ x: Float, _ y: Float) {
        threeDSObjC.thumbstickMoved(thumbstick, x: CGFloat(x), y: CGFloat(y))
    }
    
    public func isPaused() -> Bool {
        threeDSObjC.isPaused()
    }
    
    public func pausePlay(_ pausePlay: Bool) {
        threeDSObjC.pausePlay(pausePlay)
    }
    
    public func stop() {
        assignGameInfo(with: nil)
        threeDSObjC.stop()
    }
    
    public func reset() {
        threeDSObjC.reset()
    }
    
    public func running() -> Bool {
        threeDSObjC.running()
    }
    
    public func stopped() -> Bool {
        threeDSObjC.stopped()
    }
    
    public func orientationChange(with orientation: UIInterfaceOrientation, using mtkView: UIView) {
        threeDSObjC.orientationChanged(orientation, metalView: mtkView)
    }
    
    public func getCIAInfo(url: URL) -> (identifier: UInt64, contentPath: String?, titlePath: String?) {
        let identifier = threeDSObjC.getCIAIdentifier(at: url)
        return (identifier, threeDSObjC.getCIAContentPath(withIdentifier: identifier), threeDSObjC.getCIATitlePath(withIdentifier: identifier))
    }
    
    public func installed() -> [URL] {
        threeDSObjC.installedGamePaths() as? [URL] ?? []
    }
        
    public func system() -> [URL] {
        threeDSObjC.systemGamePaths() as? [URL] ?? []
    }
    
    public func updateSettings(advancedMode: Bool = false) {
        threeDSObjC.updateSettings(advancedMode)
    }
    
    public var stepsPerHour: UInt16 {
        get {
            threeDSObjC.stepsPerHour()
        }
        
        set {
            threeDSObjC.setStepsPerHour(newValue)
        }
    }
    
    public var saveStateCount: Int {
        if let currentGameInfo = Self.currentGameInfo {
            return saves(for: currentGameInfo.identifier).count
        }
        return 0
    }
    
    public func loadState(_ slot: UInt32? = nil) -> Bool {
        if let currentGameInfo = Self.currentGameInfo {
            if let slot {
                //传入了slot 则尝试加载slot
                return threeDSObjC.loadState(slot)
            } else {
                let states = saves(for: currentGameInfo.identifier).sorted { $0.time > $1.time }
                let newSlot = states[states.startIndex].slot
                return threeDSObjC.loadState(newSlot)
            }
        } else {
            return threeDSObjC.loadState()
        }
    }
    
    //slot需要从1开始
    public func saveState() -> (isSuccess: Bool, path: String) {
        if let currentGameInfo = Self.currentGameInfo {
            let states = saves(for: currentGameInfo.identifier)//slot由小到大 0-50
            if states.count == 0 { //目前还没有存档 直接存储
                return (threeDSObjC.saveState(), threeDSObjC.saveStatePath(currentGameInfo.identifier, slot: 1))
            } else { //已经有存档
                //找到最大的slot
                let maxSlot = states[states.endIndex-1].slot
                if maxSlot >= 50 {
                    //存储槽已满 覆盖最老的存储
                    let oldSlot = states.sorted(by: { $0.time < $1.time })[states.startIndex].slot
                    return (threeDSObjC.saveState(oldSlot), threeDSObjC.saveStatePath(currentGameInfo.identifier, slot: oldSlot))
                } else {
                    return (threeDSObjC.saveState(maxSlot+1), threeDSObjC.saveStatePath(currentGameInfo.identifier, slot: maxSlot+1))
                }
            }
        } else {
            
            if let currentGameInfo = Self.currentGameInfo {
                return (threeDSObjC.saveState(), threeDSObjC.saveStatePath(currentGameInfo.identifier, slot: 1))
            } else {
                return (false, "")
            }
        }
    }
    
    public func saves(for identifier: UInt64) -> [SaveStateInfo] { threeDSObjC.saveStates(identifier) }
    
    public func saveStatePath(for identifier: UInt64, slot: UInt32) -> String {
        threeDSObjC.saveStatePath(identifier, slot: slot)
    }
    
    public func saveStatePathForRunningGame(slot: UInt32) -> String? {
        if let currentGameInfo = Self.currentGameInfo {
            return threeDSObjC.saveStatePath(currentGameInfo.identifier, slot: slot)
        } else {
            return nil
        }
    }
    
    @discardableResult
    public func loadAmiibo(path: String) -> Bool {
        return threeDSObjC.loadAmiibo(path)
    }

    public func isSearchingAmiibo() -> Bool {
        return threeDSObjC.isSearchingAmiibo()
    }
    
    public func jumpToHome() {
        threeDSObjC.jumpToHome()
    }
    
    public func getTitlePath(identifier: UInt64) -> String? {
        return threeDSObjC.getCIATitlePath(withIdentifier: identifier)
    }
    
    public func getCIAContentPath(identifier: UInt64) -> String? {
        return threeDSObjC.getCIAContentPath(withIdentifier: identifier)
    }
    
    public func setSimBlowing(start: Bool) {
        threeDSObjC.setSimBlowing(start)
    }
}
