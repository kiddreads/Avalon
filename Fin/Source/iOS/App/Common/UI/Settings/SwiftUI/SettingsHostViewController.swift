// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import UIKit

@objc class SettingsHostViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let settingsView = SettingsRootView()
    let hostingController = UIHostingController(rootView: settingsView)
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    
    hostingController.didMove(toParent: self)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    Task { @MainActor in
      ConfigBridge.shared.reload()
    }
  }
}

@objc class SettingsNavigationController: UINavigationController {
  
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    setupTabBarItem()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setupTabBarItem()
  }
  
  private func setupTabBarItem() {
    tabBarItem = UITabBarItem(
      title: "Settings",
      image: UIImage(systemName: "gear"),
      selectedImage: nil
    )
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationBar.prefersLargeTitles = true
    let hostVC = SettingsHostViewController()
    setViewControllers([hostVC], animated: false)
  }
}
