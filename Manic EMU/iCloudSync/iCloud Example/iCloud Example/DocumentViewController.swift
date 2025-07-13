//
//  DocumentViewController.swift
//  iCloud Example
//
//  Created by Oskari Rauta on 26/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import UIKit
import iCloudSync

class DocumentViewController: UIViewController {

    lazy var textView: UITextView = {
        var _textView: UITextView = UITextView()
        _textView.translatesAutoresizingMaskIntoConstraints = false
        return _textView
    }()
    
    var filename: String? = nil
    var text: String! {
        get { return self.textView.text }
        set { self.textView.text = newValue }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "iCloud Document"
        
        self.view.addSubview(self.textView)
        self.textView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        self.textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        self.textView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.shareDocument(_:)))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard
            let filename: String = self.filename,
            !filename.isEmpty
            else {
                self.filename = self.generateFilename(with: "txt")
                self.title = self.filename
                return
        }
        
        self.title = self.filename
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        guard let filedata: Data = (self.text.isEmpty ? "Empty file" : self.text)?.data(using: .utf8) else {
            NSLog("File saving cancelled. Cannot cast content data.")
            return
        }
        
        if self.title == "iCloud Document" ||
            self.filename == nil || (self.filename ?? "").isEmpty {
            self.filename = self.generateFilename(with: "txt")
        }

        let filename: String = self.filename!
        
        iCloud.shared.saveAndCloseDocument(filename, with: filedata, completion: {
            document, data, error in
            
            if let err: Error = error {
                NSLog("iCloud Document save error: " + err.localizedDescription)
            } else {
                NSLog("iCloud Document, " + document!.fileURL.lastPathComponent + ", saved with text: " + String(data: data!, encoding: .utf8)!)
            }
            
        })
        
    }
    
    func generateFilename(with extension: String) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy-hh-mm-ss"
        return formatter.string(from: Date()) + "." + `extension`
    }

    @objc func shareDocument(_ sender: Any) {
        
        guard let filedata: Data = (self.text.isEmpty ? "Empty file" : self.text)?.data(using: .utf8) else {
            NSLog("File saving cancelled. Cannot cast content data.")
            return
        }
        
        if self.title == "iCloud Document" ||
            self.filename == nil || (self.filename ?? "").isEmpty {
            self.filename = self.generateFilename(with: "txt")
        }
        
        let filename: String = self.filename!

        iCloud.shared.saveAndCloseDocument(filename, with: filedata, completion: {
            document, data, error in
            
            if let err: Error = error {
                NSLog("iCloud Document save error: " + err.localizedDescription)
            } else {
                NSLog("iCloud Document, " + document!.fileURL.lastPathComponent + ", saved with text: " + String(data: data!, encoding: .utf8)!)
                
                iCloud.shared.shareDocument(filename, completion: {
                    sharedUrl, expirationDate, shareError in
                    
                    if let err: Error = shareError {
                        NSLog("iCloud Document share error: " + err.localizedDescription)
                    } else {
                        
                        NSLog("iCloud Document, " + filename + ", shared to public URL: " + sharedUrl!.absoluteString + " until expiration date: " + expirationDate!.description)

                        let vc: ShareViewController = ShareViewController()
                        vc.link = sharedUrl?.absoluteString
                        vc.date = expirationDate
                        self.present(vc, animated: true, completion: nil)
                    }
                })
            }
        })
    }
    
}
