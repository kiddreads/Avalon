//
//  ShareViewController.swift
//  iCloud Example
//
//  Created by Oskari Rauta on 26/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import UIKit

class ShareViewController: UIViewController {
    
    var link: String? {
        get { return self.linkLabel.text }
        set { self.linkLabel.text = newValue }
    }

    var date: Date? = nil {
        didSet {
            guard let date: Date = self.date else {
                self.dateLabel.text = "---"
                return
            }
            let formatter: DateFormatter = DateFormatter()
            formatter.dateFormat = "E d MMM YYYY"
            self.dateLabel.text = "Document available until\n" + formatter.string(from: date)
        }
    }
    
    lazy var innerView: UIView = {
        let _view: UIView = UIView()
        _view.translatesAutoresizingMaskIntoConstraints = false
        _view.backgroundColor = UIColor(red: 0, green: 164.0 / 255.0, blue: 1.0, alpha: 1.0)
        return _view
    }()
    
    lazy var titleLabel: UILabel = {
        let _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.numberOfLines = 2
        _label.textAlignment = .center
        _label.font = UIFont(name: "HelveticaNeue-Light", size: 19.0)
        _label.textColor = UIColor.white
        _label.allowsDefaultTighteningForTruncation = false
        _label.lineBreakMode = .byTruncatingTail
        _label.text = "Document successfully\npublished to iCloud"
        return _label
    }()

    lazy var linkLabel: UILabel = {
        var _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.numberOfLines = 2
        _label.textAlignment = .center
        _label.font = UIFont.boldSystemFont(ofSize: 10.5)
        _label.textColor = UIColor(red: 240.0/255.0, green: 240.0/255.0, blue: 240.0/255.0, alpha: 1.0)
        _label.allowsDefaultTighteningForTruncation = true
        _label.minimumScaleFactor = 0.4
        _label.adjustsFontSizeToFitWidth = true
        _label.lineBreakMode = .byTruncatingTail
        _label.text = "https://www.icloud.com/download/documents/?p=01&t=c1BADRReSHO0CQB-PkMY5MnC0-SsYP6dS0lbeII"
        return _label
    }()
    
    lazy var dateLabel: UILabel = {
        let _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.numberOfLines = 2
        _label.textAlignment = .center
        _label.font = UIFont.systemFont(ofSize: 13.0)
        _label.textColor = UIColor.white
        _label.allowsDefaultTighteningForTruncation = false
        _label.lineBreakMode = .byTruncatingTail
        _label.text = "Document available until\nDecember 20, 2013"
        return _label
    }()

    lazy var shareButton: UIButton = {
        let _button: UIButton = UIButton()
        _button.translatesAutoresizingMaskIntoConstraints = false
        _button.titleLabel?.font = UIFont.systemFont(ofSize: 15.0)
        _button.setTitleColor(UIColor.white, for: UIControl.State())
        _button.backgroundColor = UIColor(red: 51.0/255.0, green: 74.0/255.0, blue: 109.0/255.0, alpha: 1.0)
        _button.titleLabel?.textAlignment = .center
        _button.setTitle("Share Link", for: UIControl.State())
        _button.addTarget(self, action: #selector(self.shareAction(_:)), for: .touchUpInside)
        return _button
    }()

    lazy var dismissButton: UIButton = {
        let _button: UIButton = UIButton()
        _button.translatesAutoresizingMaskIntoConstraints = false
        _button.titleLabel?.font = UIFont.systemFont(ofSize: 15.0)
        _button.setTitleColor(UIColor.white, for: UIControl.State())
        _button.backgroundColor = UIColor(red: 51.0/255.0, green: 74.0/255.0, blue: 109.0/255.0, alpha: 1.0)
        _button.titleLabel?.textAlignment = .center
        _button.setTitle("X", for: UIControl.State())
        _button.addTarget(self, action: #selector(self.dismissAction(_:)), for: .touchUpInside)
        return _button
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.modalPresentationStyle = .overCurrentContext
        self.view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 0.9)
        
        self.view.addSubview(self.innerView)
        
        self.innerView.addSubview(self.titleLabel)
        self.innerView.addSubview(self.dateLabel)
        self.innerView.addSubview(self.linkLabel)

        self.innerView.addSubview(self.dismissButton)
        self.innerView.addSubview(self.shareButton)

        self.innerView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.innerView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -40.0).isActive = true

        self.innerView.heightAnchor.constraint(equalToConstant: 250.0).isActive = true
        self.innerView.widthAnchor.constraint(equalToConstant: 230.0).isActive = true
        
        self.titleLabel.leadingAnchor.constraint(equalTo: self.innerView.leadingAnchor, constant: 4.0).isActive = true
        self.titleLabel.trailingAnchor.constraint(equalTo: self.innerView.trailingAnchor, constant: -4.0).isActive = true
        self.titleLabel.topAnchor.constraint(equalTo: self.innerView.topAnchor, constant: 40.0).isActive = true
        
        self.dateLabel.leadingAnchor.constraint(equalTo: self.innerView.leadingAnchor, constant: 4.0).isActive = true
        self.dateLabel.trailingAnchor.constraint(equalTo: self.innerView.trailingAnchor, constant: -4.0).isActive = true
        self.dateLabel.topAnchor.constraint(equalTo: self.innerView.topAnchor, constant: 100.0).isActive = true
        
        self.linkLabel.leadingAnchor.constraint(equalTo: self.innerView.leadingAnchor, constant: 5.0).isActive = true
        self.linkLabel.trailingAnchor.constraint(equalTo: self.innerView.trailingAnchor, constant: -5.0).isActive = true
        self.linkLabel.bottomAnchor.constraint(equalTo: self.innerView.bottomAnchor, constant: -16.0).isActive = true
        
        self.shareButton.leadingAnchor.constraint(equalTo: self.innerView.leadingAnchor).isActive = true
        self.shareButton.trailingAnchor.constraint(equalTo: self.innerView.trailingAnchor).isActive = true
        self.shareButton.bottomAnchor.constraint(equalTo: self.linkLabel.topAnchor, constant: -12.0).isActive = true

        self.dismissButton.leadingAnchor.constraint(equalTo: self.innerView.leadingAnchor).isActive = true
        self.dismissButton.topAnchor.constraint(equalTo: self.innerView.topAnchor).isActive = true
    }
    
    @objc func shareAction(_ sender: Any) {
        if let link: String = self.link {
            self.present(UIActivityViewController(activityItems: [link], applicationActivities: nil), animated: true, completion: nil)
        }
    }

    @objc func dismissAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
