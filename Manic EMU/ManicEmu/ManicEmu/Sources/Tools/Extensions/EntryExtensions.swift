//
//  EntryExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ZIPFoundation

extension Entry {
    var decodedPath: String {
        let detector = UniversalDetector()
        detector.analyze(pathData)
        if let string = NSString(data: pathData, encoding: detector.encoding()) {
            return string as String
        }
        return path
    }
}
