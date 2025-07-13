//
//  ExternalSceneDelegate.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
import RealmSwift

/// 连接屏幕镜像的时候使用这个场景
class ExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    static var isAirPlaying = false
    var window: UIWindow?
    private var settingsUpdateToken: Any? = nil
    private var membershipNotification: Any? = nil
    private var startPlayGameNotification: Any? = nil
    private var stopPlayGameNotification: Any? = nil
    static weak var airPlayViewController: AirPlayViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            ExternalSceneDelegate.isAirPlaying = true
            window = UIWindow(windowScene: windowScene)
            window?.tintColor = Constants.Color.Main
            let airPlayViewController = AirPlayViewController()
            window?.rootViewController = airPlayViewController
            ExternalSceneDelegate.airPlayViewController = airPlayViewController
            window?.makeKeyAndVisible()
            updateScene()
            //监听设置airPlay开关
            settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.airPlay]) { [weak self] change in
                guard let self = self else { return }
                switch change {
                case .change(_, _):
                    Log.debug("airPlay开关变化，更新Scene")
                    self.updateScene()
                default:
                    break
                }
            }
            
            //监听会员资格变化
            membershipNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
                self?.updateScene()
            }
            //监听开始游戏
            startPlayGameNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.StartPlayGame, object: nil, queue: .main) { [weak self] notification in
                self?.updateScene()
            }
            //监听结束游戏
            stopPlayGameNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.StopPlayGame, object: nil, queue: .main) { [weak self] notification in
                self?.updateScene()
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        window?.isHidden = true
        window?.removeFromSuperview()
        window = nil
        settingsUpdateToken = nil
        if let membershipNotification = membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let startPlayGameNotification = startPlayGameNotification {
            NotificationCenter.default.removeObserver(startPlayGameNotification)
        }
        if let stopPlayGameNotification = stopPlayGameNotification {
            NotificationCenter.default.removeObserver(stopPlayGameNotification)
        }
        membershipNotification = nil
        ExternalSceneDelegate.isAirPlaying = false
    }
    
    private func updateScene() {
        if PurchaseManager.isMember, Settings.defalut.airPlay, PlayViewController.isGaming, PlayViewController.playingGameType != ._3ds {
            //开启了airPlay的全屏模式
            window?.isHidden = false
        } else {
            //没有开启 正常显示手机镜像即可
            window?.isHidden = true
        }
    }
}
