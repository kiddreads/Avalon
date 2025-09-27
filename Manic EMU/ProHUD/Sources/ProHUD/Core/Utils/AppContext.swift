//
//  AppContext.swift
//
//
//  Created by xaoxuu on 2023/8/5.
//

import UIKit

public protocol Workspace {}

extension UIWindowScene: Workspace {}
extension UIView: Workspace {}
extension UIViewController: Workspace {}

extension Workspace {
    var windowScene: UIWindowScene? {
        if let self = self as? UIWindowScene {
            return self
        } else if let self = self as? UIWindow {
            return self.windowScene
        } else if let self = self as? UIView {
            return self.window?.windowScene
        } else if let self = self as? UIViewController {
            return self.view.window?.windowScene
        }
        return nil
    }
}

public struct AppContext {
    
    private static var storedAppWindowScene: UIWindowScene?
    
    /// 一个scene关联一个toast
    static var toastWindows: [UIWindowScene: [ToastWindow]] = [:]
    static var alertWindow: [UIWindowScene: AlertWindow] = [:]
    static var sheetWindows: [UIWindowScene: [SheetWindow]] = [:]
    static var capsuleWindows: [UIWindowScene: [CapsuleViewModel.Position: CapsuleWindow]] = [:]
    static var capsuleInQueue: [CapsuleTarget] = []
    
    static var current: AppContext? {
        guard let windowScene = windowScene else { return nil }
        if let ctx = allContexts[windowScene] {
            return ctx
        } else {
            let ctx: AppContext = .init(windowScene: windowScene)
            allContexts[windowScene] = ctx
            return ctx
        }
    }
    static var allContexts = [UIWindowScene: AppContext]()
    private let windowScene: UIWindowScene
    
    private init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }
    
    /// 单窗口应用无需设置，多窗口应用需要指定显示到哪个windowScene上
    /// workspace可以是windowScene/window/view/viewController
    public static var workspace: Workspace? {
        get { windowScene }
        set {
            windowScene = newValue?.windowScene
        }
    }
    
}

extension AppContext {
    
    static var foregroundActiveWindowScenes: [UIWindowScene] {
        return UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).filter({ scene in
            if #available(iOS 16.0, *) {
                if scene.activationState == .foregroundActive && scene.session.role != .windowExternalDisplayNonInteractive {
                    return true
                }
            } else {
                if scene.activationState == .foregroundActive && scene.session.role != .windowExternalDisplay {
                    return true
                }
            }
            return false
        })
    }
    
    /// 获取所有外部显示的WindowScene（包括AirPlay）
    static var externalWindowScenes: [UIWindowScene] {
        return UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).filter({ scene in
            if #available(iOS 16.0, *) {
                return scene.activationState == .foregroundActive && scene.session.role == .windowExternalDisplayNonInteractive
            } else {
                return scene.activationState == .foregroundActive && scene.session.role == .windowExternalDisplay
            }
        })
    }
    
    /// 外部窗口信息（由外部设置）
    private static var externalWindowInfo: (window: UIWindow, isActive: Bool)?
    
    /// 设置外部窗口信息
    /// - Parameters:
    ///   - window: 外部窗口
    ///   - isActive: 是否激活外部窗口显示
    public static func setExternalWindow(_ window: UIWindow?, isActive: Bool) {
        if let window = window, isActive {
            externalWindowInfo = (window: window, isActive: true)
        } else {
            externalWindowInfo = nil
        }
    }
    
    /// 检查是否应该使用外部窗口显示ProHUD内容
    static var shouldUseExternalWindow: Bool {
        guard let info = externalWindowInfo else { return false }
        return info.isActive && !info.window.isHidden
    }
    
    /// 获取外部窗口的WindowScene
    static var externalWindowScene: UIWindowScene? {
        guard shouldUseExternalWindow else { return nil }
        return externalWindowInfo?.window.windowScene
    }
    
    /// 如果设置了workspace，就是workspace所对应的windowScene，否则就是最后一个打开的应用程序窗口的windowScene
    /// 当AirPlay投屏且外部窗口可见时，优先使用外部窗口场景
    static var windowScene: UIWindowScene? {
        set { storedAppWindowScene = newValue }
        get {
            // 如果有明确设置的workspace，使用它
            if let ws = storedAppWindowScene {
                return ws
            }
            
            // 检查是否应该使用外部窗口
            if let externalScene = externalWindowScene {
                return externalScene
            }
            
            // 默认使用最后一个前台活跃的窗口场景
            return foregroundActiveWindowScenes.last
        }
    }
    
    /// 所有的窗口
    static var windows: [UIWindow] {
        windowScene?.windows ?? UIApplication.shared.windows
    }
    
    /// 可见的窗口
    static var visibleWindows: [UIWindow] {
        windows.filter { $0.isHidden == false }
    }
    
    /// App主程序窗口
    static var appWindow: UIWindow? {
        // 如果应该使用外部窗口，优先返回外部窗口
        if shouldUseExternalWindow, let info = externalWindowInfo {
            return info.window
        }
        
        // 否则返回正常的主程序窗口
        return visibleWindows.filter { window in
            return "\(type(of: window))" == "UIWindow" && window.windowLevel == .normal
        }.first
    }
    
    /// App主程序窗口的尺寸
    static var appBounds: CGRect {
        appWindow?.bounds ?? UIScreen.main.bounds
    }
    
    /// App主程序窗口的安全边距
    static var safeAreaInsets: UIEdgeInsets { 
        // 外部窗口通常没有安全边距，或者使用iPad的逻辑
        if shouldUseExternalWindow {
            return .zero // 外部显示器通常没有安全边距
        }
        return appWindow?.safeAreaInsets ?? .zero 
    }
    
}

// MARK: - instance manage

extension AppContext {
    var sheetWindows: [SheetWindow] {
        Self.sheetWindows[windowScene] ?? []
    }
    var toastWindows: [ToastWindow] {
        Self.toastWindows[windowScene] ?? []
    }
    var capsuleWindows: [CapsuleViewModel.Position: CapsuleWindow] {
        Self.capsuleWindows[windowScene] ?? [:]
    }
    var alertWindow: AlertWindow? {
        Self.alertWindow[windowScene]
    }
}
 
