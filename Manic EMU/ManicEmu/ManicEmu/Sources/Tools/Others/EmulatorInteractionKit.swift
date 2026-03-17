//
//  EmulatorInteractionKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ManicEmuCore
import IceCream

extension GameType {
    static let ns = GameType("public.aoshuang.game.ns")
    static let xbox360 = GameType("public.aoshuang.game.xbox360")
}

struct EmulatorInteractionKit {
    enum EmulatorType {
        case meloNX, xeniOS
    }
    
    static func isInstalled(type: EmulatorType) -> Bool {
        switch type {
        case .meloNX:
            return UIApplication.shared.canOpenURL(Constants.URLs.FetchMeloNXGames)
        case .xeniOS:
            return UIApplication.shared.canOpenURL(Constants.URLs.FetchXeniOSGames)
        }
    }
    
    static func startGame(type: EmulatorType, id: String) {
        if isInstalled(type: type) {
            switch type {
            case .meloNX:
                UIApplication.shared.open(Constants.URLs.MeloNXGameLaunch(gameId: id))
            case .xeniOS:
                UIApplication.shared.open(Constants.URLs.XeniOSGameLaunch(gameId: id))
            }
        } else {
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                switch type {
                case .meloNX:
                    UIView.makeToast(message: R.string.localizable.notInstallMeloNX())
                case .xeniOS:
                    UIView.makeToast(message: R.string.localizable.notInstall("XeniOS"))
                }
            }
        }
    }
    
    static func fetchGames(type: EmulatorType) {
        if isInstalled(type: type) {
            switch type {
            case .meloNX:
                UIApplication.shared.open(Constants.URLs.FetchMeloNXGames)
            case .xeniOS:
                UIApplication.shared.open(Constants.URLs.FetchXeniOSGames)
            }
            
        } else {
            switch type {
            case .meloNX:
                UIView.makeToast(message: R.string.localizable.notInstallMeloNX())
            case .xeniOS:
                UIView.makeToast(message: R.string.localizable.notInstall("XeniOS"))
            }
        }
    }
    
    static func processGames(type: EmulatorType, callbackUrl: URL) {
        var delay: Double
        if let _ = ApplicationSceneDelegate.applicationWindow {
            delay = 0.0
        } else {
            delay = 3.0
        }
        DispatchQueue.global().asyncAfter(delay: delay) {
            let fromGames = GameScheme.pullFromURL(callbackUrl)
            var games = [Game]()
            let realm = Database.realm
            for mg in fromGames {
                if let _ = realm.object(ofType: Game.self, forPrimaryKey: mg.titleId) {
                    Log.debug("MeloNX游戏已存在:\(mg.titleId) \(mg.titleName)")
                } else {
                    let game = Game()
                    switch type {
                    case .meloNX:
                        game.fileExtension = "xci"
                        game.gameType = .ns
                    case .xeniOS:
                        game.fileExtension = "iso"
                        game.gameType = .xbox360
                    }
                    game.id = mg.titleId
                    game.name = mg.titleName
                    game.importDate = Date()
                    if let icon = mg.iconData {
                        game.gameCover = CreamAsset.create(objectID: game.id, propName: "gameCover", data: icon)
                    } else {
                        
                    }
                    games.append(game)
                }
            }
            if games.count > 0 {
                try? realm.write({
                    realm.add(games)
                })
                DispatchQueue.main.asyncAfter(delay: 1) {
                    switch type {
                    case .meloNX:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("MeloNX Games"))
                    case .xeniOS:
                        UIView.makeToast(message: R.string.localizable.biosImportSuccess("Xenios Games"))
                    }
                }
            }
        }
    }
}

struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID().uuidString
    
    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    
    static func pullFromURL(_ url: URL) -> [GameScheme] {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            if let text = components.queryItems?.first(where: { $0.name == "games" })?.value, let data = GameScheme.base64URLDecode(text) {
                
                if let decoded = try? JSONDecoder().decode([GameScheme].self, from: data) {
                    return decoded
                }
            }
        }
        return []
    }
    
    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        return Data(base64Encoded: base64)
    }
}
