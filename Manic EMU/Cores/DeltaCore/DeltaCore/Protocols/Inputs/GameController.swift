//
//  GameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import ObjectiveC

private var gameControllerStateManagerKey = 0

class NotificationDebouncer {
    static let shared = NotificationDebouncer()

    private struct PendingNotification {
        let name: Notification.Name
        let object: Any?
        let userInfo: [AnyHashable: Any]?
        let value: Double
    }

    private var pendingNotifications: [PendingNotification] = []
    private var workItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.1
    private let queue = DispatchQueue(label: "notification.debouncer")

    private init() {}

    func post(name: Notification.Name, value: Double, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        queue.async {
            // 记录本次通知
            let notification = PendingNotification(name: name, object: object, userInfo: userInfo, value: value)
            self.pendingNotifications.append(notification)

            // 取消之前的防抖任务
            self.workItem?.cancel()

            // 创建新的任务
            let task = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // 找到最大值的通知
                if let maxNotification = self.pendingNotifications.max(by: { $0.value < $1.value }) {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: maxNotification.name, object: maxNotification.object, userInfo: maxNotification.userInfo)
                    }
                }
                self.queue.async {
                    self.pendingNotifications.removeAll()
                    self.workItem = nil
                }
            }

            // 保存并调度任务
            self.workItem = task
            self.queue.asyncAfter(deadline: .now() + self.debounceInterval, execute: task)
        }
    }
}

//MARK: - GameControllerReceiver -
public protocol ControllerReceiverProtocol: class
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(_ gameController: GameController, didDeactivate input: Input)
}

//MARK: - GameController -
public protocol GameController: NSObjectProtocol
{
    var name: String { get }
        
    var playerIndex: Int? { get set }
    
    var inputType: GameControllerInputType { get }
    
    var defaultInputMapping: GameControllerInputMappingBase? { get }
}

public extension GameController
{
    private var stateManager: GameControllerStateUtils {
        var stateManager = objc_getAssociatedObject(self, &gameControllerStateManagerKey) as? GameControllerStateUtils
        
        if stateManager == nil
        {
            stateManager = GameControllerStateUtils(gameController: self)
            objc_setAssociatedObject(self, &gameControllerStateManagerKey, stateManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return stateManager!
    }
    
    var receivers: [ControllerReceiverProtocol] {
        return self.stateManager.receivers
    }
    
    var activatedInputs: [SomeInput: Double] {
        return self.stateManager.activatedInputs
    }
    
    var continueInputs: [SomeInput: Double] {
        return self.stateManager.continueInputs
    }
    
    func addReceiver(_ receiver: ControllerReceiverProtocol)
    {
        addReceiver(receiver, inputMapping: defaultInputMapping)
    }
    
    func addReceiver(_ receiver: ControllerReceiverProtocol, inputMapping: GameControllerInputMappingBase?)
    {
        stateManager.addReceiver(receiver, inputMapping: inputMapping)
    }
    
    func removeReceiver(_ receiver: ControllerReceiverProtocol)
    {
        stateManager.removeReceiver(receiver)
    }
    
    func activate(_ input: Input, value: Double = 1.0)
    {
        stateManager.activate(input, value: value)
        guard value > 0.5 else { return }
        NotificationDebouncer.shared.post(name: .externalGameControllerDidPress, value: value, userInfo: ["input": input, "value": value])
    }
    
    func deactivate(_ input: Input)
    {
        stateManager.deactivate(input)
        NotificationCenter.default.post(name: .externalGameControllerDidRelease, object: nil, userInfo: ["input": input])
    }
    
    func sustain(_ input: Input, value: Double = 1.0)
    {
        stateManager.makeContinue(input, value: value)
    }
    
    func unsustain(_ input: Input)
    {
        stateManager.stopContinue(input)
    }
    
    func inputMapping(for receiver: ControllerReceiverProtocol) -> GameControllerInputMappingBase?
    {
        return stateManager.inputMapping(for: receiver)
    }
    
    func mappedInput(for input: Input, receiver: ControllerReceiverProtocol) -> Input?
    {
        return stateManager.mappedInput(for: input, receiver: receiver)
    }
}

public func ==(lhs: GameController?, rhs: GameController?) -> Bool
{
    switch (lhs, rhs)
    {
    case (nil, nil): return true
    case (_?, nil): return false
    case (nil, _?): return false
    case (let lhs?, let rhs?): return lhs.isEqual(rhs)
    }
}

public func !=(lhs: GameController?, rhs: GameController?) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(pattern: GameController?, value: GameController?) -> Bool
{
    return pattern == value
}
