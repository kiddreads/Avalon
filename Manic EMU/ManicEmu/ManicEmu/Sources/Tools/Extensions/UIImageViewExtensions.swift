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
            if let _ = data {
                self.contentMode = .scaleAspectFill
            } else {
                self.contentMode = .scaleAspectFit
            }
            self.image = UIImage.tryDataImageOrPlaceholder(tryData: data, preferenceSize: size)
            completion?(UIImage.tryDataImageOrPlaceholder(tryData: data))
        }
    }
}
