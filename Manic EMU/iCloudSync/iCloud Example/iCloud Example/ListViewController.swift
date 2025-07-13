//
//  ListViewController.swift
//  iCloud Example
//
//  Created by Oskari Rauta on 26/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import UIKit
import iCloudSync

class ListViewController: UITableViewController, iCloudDelegate {

    var fileNameList: [String] = []
    var fileObjectList: [NSMetadataItem] = []
    
    var fileText: String = ""
    var fileTitle: String = ""
    
    var alert: UIAlertController? = nil
    
    var appIsRunningForFirstTime: Bool {
        get {
            if UserDefaults.standard.bool(forKey: "HasLaunchedOnce") {
                return false
            }
            UserDefaults.standard.set(true, forKey: "HasLaunchedOnce")
            UserDefaults.standard.synchronize()
            return true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "iCloud files"
        
        // Setup iCloud
        iCloud.shared.verboseLogging = true // Enable detailed feedback
        iCloud.shared.setupiCloud() // This method must be called before performing any document operations
        iCloud.shared.delegate = self // Set this if you plan to use the delegate
        
        self.tableView = UITableView(frame: .zero, style: .grouped)
        self.tableView.register(FileCell.self, forCellReuseIdentifier: "fileCell")
        self.tableView.dataSource = self
        self.tableView.delegate = self

        // Display add button in the navigation bar for this view controller
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addDocument(_:)))
        
        // Display an Edit button in the navigation bar for this view controller.
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        // Create refresh control
        self.refreshControl = UIRefreshControl()
        
        self.refreshControl?.addTarget(self, action: #selector(self.refreshCloudList), for: UIControl.Event.valueChanged)
        
        // Subscribe to iCloud Ready Notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshCloudListAfterSetup), name: NSNotification.Name(rawValue: "iCloud Ready"), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Present Welcome Screen
        if self.appIsRunningForFirstTime || !iCloud.shared.cloudAvailable || UserDefaults.standard.bool(forKey: "userCloudPref") == false {
            self.showWelcome()
        }
        
        /* --- Force iCloud Update ---
         This is done automatically when changes are made, but we want to make sure the view is always updated when presented */
        iCloud.shared.updateFiles()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.fileNameList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell: FileCell = tableView.dequeueReusableCell(withIdentifier: "fileCell") as! FileCell
        let filename: String = fileNameList[indexPath.row]
        let filesize: NSNumber = iCloud.shared.fileSize(filename) ?? NSNumber(value: 0)
        let updated: Date = iCloud.shared.fileModified(filename) ?? Date(timeIntervalSinceReferenceDate: 0)
        var documentState: String = ""
        iCloud.shared.documentState(filename, completion: {
            state, desc, error in
            if error == nil, desc != nil { documentState = desc! }
        })

        cell.title = filename
        cell.detail = filesize.description + " bytes, updated: " + updated.description + "\n" + documentState
        cell.detailLabel.textColor = documentState.uppercased() == "DOCUMENT IS IN CONFLICT" ? UIColor.red : UIColor.black
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        var fileText: String? = nil
        var fileTitle: String? = nil
        
        iCloud.shared.retrieveCloudDocument(self.fileNameList[indexPath.row], completion: {
            document, data, error in
            
            if error == nil {
                fileText = String(data: data!, encoding: .utf8)
                fileTitle = document!.fileURL.lastPathComponent
                
                iCloud.shared.documentState(fileTitle!, completion: {
                    state, desc, err in
                    if err != nil {
                        NSLog("Error retrieveing document state: " + err!.localizedDescription);
                        return
                    } else if err == nil, state! == .inConflict {
                        print("File is in a conflict..")
                        return
                    } else {
                        let vc: DocumentViewController = DocumentViewController()
                        vc.filename = fileTitle
                        vc.text = fileText
                        self.navigationController?.pushViewController(vc, animated: true)
                        return
                    }
                })
            } else if error != nil {
                NSLog("Error retrieving document: " + error!.localizedDescription)
            }
        })
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        guard editingStyle == .delete else { return }

        iCloud.shared.deleteDocument(self.fileNameList[indexPath.row], completion: {
            error in
            if error != nil {
                NSLog("Error deleting document: " + error!.localizedDescription)
            } else {
                self.fileObjectList.remove(at: indexPath.row)
                self.fileNameList.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    iCloud.shared.updateFiles()
                })
            }
        })
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func showWelcome() {
        
        if self.alert?.isBeingPresented ?? false {
            return
        } else {
            let vc: WelcomeViewController = WelcomeViewController()
            vc.modalPresentationStyle = .currentContext
            self.present(vc, animated: true, completion: nil)
        }
    }

    @objc func addDocument(_ sender: Any) {
        let vc: DocumentViewController = DocumentViewController()
        vc.filename = nil
        vc.text = "Document text"
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func refreshCloudList() {
        iCloud.shared.updateFiles()
    }

    @objc func refreshCloudListAfterSetup() {
        // Reclaim delegate and then update files
        iCloud.shared.delegate = self
        iCloud.shared.updateFiles()
    }
    
    // MARK: - iCloudSync delegate
    
    func iCloudDidFinishInitializing(with ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) {
        NSLog("Ubiquity container initialized. You may proceed to perform document operations.")
    }

    func iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) {
        
        if !isAvailable {
            
            self.alert = UIAlertController(title: "iCloud unavailable", message: "iCloud is no longer available. Make sure that you are signed into a valid iCloud account.", preferredStyle: .alert)
            
            self.alert?.addAction(UIAlertAction(title: "OK", style: .default, handler: {
                _ in
                self.alert?.dismiss(animated: true, completion: nil)
                DispatchQueue.main.async {
                    self.showWelcome()
                }
            }))
            
            self.present(self.alert!, animated: true, completion: nil)
        }
    }

    func iCloudFilesDidChange(_ files: [NSMetadataItem], with filenames: [String]) {
        // Get the query results
        
        guard filenames != self.fileNameList, files != self.fileObjectList else {
            if self.refreshControl?.isRefreshing ?? false {
                self.refreshControl?.endRefreshing()
            }
            return
        }
        
        if !filenames.isEmpty {
            NSLog("Files: " + filenames.joined(separator: ","))
        }
        
        self.fileNameList = filenames
        self.fileObjectList = files

        if self.refreshControl?.isRefreshing ?? false {
            self.refreshControl?.endRefreshing()
        }
        if self.tableView.contentOffset.y == -self.tableView.adjustedContentInset.top {
            self.tableView.contentOffset = CGPoint(x: 0, y: self.tableView.contentOffset.y + 1.0)
        }
        self.tableView.setContentOffset(CGPoint(x: 0, y:-self.tableView.adjustedContentInset.top), animated: true)
        self.tableView.reloadData()
    }

    
    
}
