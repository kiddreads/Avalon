//
//  WelcomeViewController.swift
//  iCloud Example
//
//  Created by Oskari Rauta on 26/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import UIKit
import iCloudSync

class WelcomeViewController: UIViewController, iCloudDelegate {

    lazy var image: UIImageView = {
        var _image: UIImageView = UIImageView(image: UIImage(named: "Banner"))
        _image.translatesAutoresizingMaskIntoConstraints = false
        return _image
    }()
    
    lazy var header: UILabel = {
        var _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.font = UIFont.boldSystemFont(ofSize: 14.0)
        _label.textColor = UIColor.darkText
        _label.textAlignment = .center
        _label.text = "Welcome to iCloud"
        return _label
    }()
    
    lazy var text: UILabel = {
        var _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.font = UIFont.systemFont(ofSize: 12.0)
        _label.textColor = UIColor.darkText
        _label.textAlignment = .left
        _label.numberOfLines = 0
        _label.text = """
This iCloud demo app demonstrates how to use many features of iCloud with the iCloudSync project available on GitHub.
        
To properly use this project please do the following:
• Make sure this demo app's entitlements are valid
• Sign into an iCloud account on the current device
• Turn ON iCloud in the Settings app
"""
        return _label
    }()
    
    lazy var startButton: UIButton = {
        var _button: UIButton = UIButton()
        _button.translatesAutoresizingMaskIntoConstraints = false
        _button.setTitleColor(UIColor.white, for: UIControl.State())
        _button.backgroundColor = UIColor(red: 0, green: 164.0 / 255.0, blue: 1.0, alpha: 1.0)
        _button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15.0)
        _button.setTitle("Start Using iCloud", for: UIControl.State())
        _button.isHidden = true
        _button.addTarget(self, action: #selector(self.startCloud(_:)), for: .touchUpInside)
        return _button
    }()

    lazy var setupButton: UIButton = {
        var _button: UIButton = UIButton()
        _button.translatesAutoresizingMaskIntoConstraints = false
        _button.setTitleColor(UIColor.white, for: UIControl.State())
        _button.backgroundColor = UIColor(red: 0, green: 164.0 / 255.0, blue: 1.0, alpha: 1.0)
        _button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15.0)
        _button.setTitle("Setup iCloud Before Continuing", for: UIControl.State())
        _button.isHidden = true
        _button.addTarget(self, action: #selector(self.setupCloud(_:)), for: .touchUpInside)
        return _button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Welcome"
        self.view.backgroundColor = UIColor.white
        
        self.view.addSubview(self.image)
        self.view.addSubview(self.header)
        self.view.addSubview(self.text)
        self.view.addSubview(self.setupButton)
        self.view.addSubview(self.startButton)
        
        self.image.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 12.0).isActive = true
        self.image.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.image.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 25.0).isActive = true
        self.image.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -25.0).isActive = true
        self.image.heightAnchor.constraint(lessThanOrEqualToConstant: 180.0).isActive = true
        
        self.header.topAnchor.constraint(equalTo: self.image.bottomAnchor, constant: 2.0).isActive = true
        self.header.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true

        self.text.topAnchor.constraint(equalTo: self.header.bottomAnchor, constant: 4.0).isActive = true
        self.text.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 6.0).isActive = true
        self.text.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -6.0).isActive = true

        
        self.startButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        self.startButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        self.startButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -30.0).isActive = true

        self.setupButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        self.setupButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        self.setupButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -30.0).isActive = true
        
        iCloud.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupButton.isHidden = true
        self.startButton.isHidden = true

        if iCloud.shared.cloudAvailable && UserDefaults.standard.bool(forKey: "userCloudPref") {
            self.startButton.isHidden = false
        } else {
            self.setupButton.isHidden = false
        }
    }

    @objc func startCloud(_ sender: Any) {
        
        self.dismiss(animated: true, completion: {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "iCloud Ready"), object: self)
        })

    }

    @objc func setupCloud(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "userCloudPref") == false {
            let alert: UIAlertController = UIAlertController(title: "iCloud Disabled", message: "You have disabled iCloud for this app. Would you like to turn it on again?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            alert.addAction(UIAlertAction(title: "Turn on", style: .default, handler: {
                _ in
                UserDefaults.standard.set(true, forKey: "userCloudPref")
                UserDefaults.standard.synchronize()

                if iCloud.shared.cloudAvailable, UserDefaults.standard.bool(forKey: "userCloudPref") == true {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.startButton.isHidden = false
                        self.setupButton.isHidden = true
                    })
                } else {
                    self.setupButton.isHidden = false
                    self.startButton.isHidden = true
                }
            }))
            
            self.present(alert, animated: true, completion: nil)
            
        } else {
            
            let alert: UIAlertController = UIAlertController(title: "Setup iCloud", message: "iCloud is not available. Sign into iCloud account on this device and check that app has valid entitlements.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) {

        if isAvailable, UserDefaults.standard.bool(forKey: "userCloudPref") == true {
            UIView.animate(withDuration: 0.25, animations: {
                self.startButton.isHidden = false
                self.setupButton.isHidden = true
            })
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.startButton.isHidden = true
                self.setupButton.isHidden = false
            })
        }
    }
    
}
