// Copyright 2023 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

class UpdateCheckService : UIResponder, UIApplicationDelegate {
  func createUpdateRequiredViewController() -> UIViewController {
    return UpdateRequiredNoticeViewController(nibName: "UpdateRequiredNotice", bundle: nil)
  }
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    return true
  }
}

