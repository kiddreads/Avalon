//
//  ConflictViewController.swift
//  iCloud Example
//
//  Created by Oskari Rauta on 26/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import UIKit
import iCloudSync

class ConflictViewController: UITableViewController {

    var filename: String? = nil
    var versions: [NSFileVersion] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Conflict Resolver"
        self.tableView = UITableView(frame: .zero, style: .grouped)
        self.tableView.register(FileCell.self, forCellReuseIdentifier: "fileCell")
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let name: String = self.filename else { return 0 }
        self.versions = iCloud.shared.findUnresolvedConflictingVersionsOfFile(name) ?? []
        return self.versions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell: FileCell = tableView.dequeueReusableCell(withIdentifier: "fileCell") as! FileCell
        let version: NSFileVersion = self.versions[indexPath.row]
        let filesize: NSNumber = iCloud.shared.fileSize(self.filename!) ?? NSNumber(value: 0)
        let updated: Date = iCloud.shared.fileModified(self.filename!) ?? Date(timeIntervalSinceReferenceDate: 0)
        cell.title = self.filename
        cell.detail = filesize.description + " bytes, updated: " + updated.description + "\n" + version.description
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        iCloud.shared.resolveConflictForFile(self.filename!, with: self.versions[indexPath.row])
        iCloud.shared.updateFiles()
        self.navigationController?.popViewController(animated: true)
    }
    
}
