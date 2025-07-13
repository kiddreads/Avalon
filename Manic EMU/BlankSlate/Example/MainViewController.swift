//
//  MainViewController.swift
//  Example iOS
//
//  Created by liam on 2024/3/11.
//  Copyright © 2024 Liam. All rights reserved.
//

import UIKit

class MainViewController: UITableViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
}
