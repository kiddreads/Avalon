//
//  PhotoSaver.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/16.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//

import Foundation
import Photos

struct PhotoSaver {
    static func save(photoPath: String) {
        if let image = UIImage(contentsOfFile: photoPath) {
            save(image: image)
        }
    }
    
    static func save(image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.7) {
            save(datas: [data])
        }
    }
    
    static func save(datas: [Data]) {
        PermissionKit.requestPhoto {
            PHPhotoLibrary.shared().performChanges({
                for imageData in datas {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: imageData, options: nil)
                }
            }) { (success, error) in
                DispatchQueue.main.asyncAfter(delay: UserDefaults.standard.bool(forKey: Constants.DefaultKey.HadSavedSnapshot) ? 0 : 1) {
                    UserDefaults.standard.setValue(true, forKey: Constants.DefaultKey.HadSavedSnapshot)
                    UIView.makeToast(message: success ? R.string.localizable.toastSuccess() : R.string.localizable.toastFailed(), identifier: "PhotoSaver")
                }
            }
        }
    }
    
    
}
