//
//  UIImageViewExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Kingfisher

extension UIImageView {
    func setGameCover(game: Game, size: CGSize? = nil, completion: ((UIImage)->Void)? = nil) {
        if game.isNDSHomeMenuGame || game.is3DSHomeMenuGame {
            //Home Menu的图标进行特殊处理
            self.kf.cancelDownloadTask()
            self.contentMode = .scaleAspectFill
            self.image = HomeMenuImage(size: size ?? .init(300), gameType: game.gameType, isDSi: game.isDSiHomeMenuGame)
            completion?(UIImage.tryDataImageOrPlaceholder(tryData: image?.jpegData(compressionQuality: 0.7)))
            return
        }
        
        self.contentMode = .scaleAspectFit
        if let onlineCoverUrl = game.onlineCoverUrl, let url = URL(string: onlineCoverUrl), game.gameCover == nil {
            self.kf.setImage(with: url, placeholder: UIImage.placeHolder(preferenceSize: size)) { result in
                switch result {
                case .success(let successResult):
                    self.contentMode = .scaleAspectFill
                    completion?(successResult.image)
                case .failure(_):
                    self.contentMode = .scaleAspectFit
                    completion?(UIImage.placeHolder())
                }
            }
        } else {
            self.kf.cancelDownloadTask()
            let data = game.gameCover?.storedData()
            if let data {
                self.contentMode = .scaleAspectFill
                let cache = KingfisherManager.shared.cache
                let cacheKey = data.md5String
                cache.retrieveImage(forKey: cacheKey, completionHandler: { result in
                    DispatchQueue.main.async {
                        func storeCache() {
                            let image = UIImage.tryDataImageOrPlaceholder(tryData: data, preferenceSize: size)
                            cache.store(image, forKey: cacheKey, processorIdentifier: DefaultImageProcessor.default.identifier)
                            self.image = image
                            completion?(UIImage.tryDataImageOrPlaceholder(tryData: data))
                        }
                        switch result {
                        case .success(let value):
                            if let image = value.image {
                                self.image = image
                                completion?(UIImage.tryDataImageOrPlaceholder(tryData: data))
                            } else {
                                storeCache()
                            }
                        case .failure(_):
                            storeCache()
                        }
                    }
                })
            } else {
                self.contentMode = .scaleAspectFit
                self.image = UIImage.tryDataImageOrPlaceholder(tryData: nil, preferenceSize: size)
                completion?(UIImage.tryDataImageOrPlaceholder(tryData: nil))
            }
        }
    }
}
