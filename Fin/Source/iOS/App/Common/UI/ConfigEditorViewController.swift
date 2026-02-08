// Copyright 2024 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

/// A simple view controller to view and edit Dolphin configuration INI files
class ConfigEditorViewController: UIViewController {
    
    private let textView = UITextView()
    private let toolbar = UIToolbar()
    private var currentFilename: String = "GFX.ini"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Config Editor"
        view.backgroundColor = .systemBackground
        
        setupTextView()
        setupToolbar()
        setupNavigationBar()
        
        loadConfigFile(currentFilename)
    }
    
    private func setupTextView() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.keyboardType = .asciiCapable
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44)
        ])
    }
    
    private func setupToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        let selectFileButton = UIBarButtonItem(title: "Select File", style: .plain, target: self, action: #selector(selectFile))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let exportButton = UIBarButtonItem(title: "Export", style: .plain, target: self, action: #selector(exportConfig))
        let importButton = UIBarButtonItem(title: "Import", style: .plain, target: self, action: #selector(importConfig))
        
        toolbar.items = [selectFileButton, flexSpace, exportButton, importButton]
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveConfig))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeEditor))
    }
    
    private func loadConfigFile(_ filename: String) {
        currentFilename = filename
        title = filename
        
        if let contents = ConfigFileManager.readConfigFile(filename) {
            textView.text = contents
        } else {
            textView.text = "# \(filename) does not exist yet.\n# It will be created when you save.\n\n"
        }
    }
    
    @objc private func selectFile() {
        let alert = UIAlertController(title: "Select Config File", message: nil, preferredStyle: .actionSheet)
        
        let configFiles = [
            "GFX.ini",
            "Dolphin.ini",
            "GCPadNew.ini",
            "WiimoteNew.ini",
            "Logger.ini",
            "FreeLook.ini",
            "RetroAchievements.ini"
        ]
        
        for filename in configFiles {
            let action = UIAlertAction(title: filename, style: .default) { [weak self] _ in
                self?.loadConfigFile(filename)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = toolbar.items?.first
        }
        
        present(alert, animated: true)
    }
    
    @objc private func saveConfig() {
        guard let text = textView.text else { return }
        
        if ConfigFileManager.writeConfigFile(currentFilename, contents: text) {
            let alert = UIAlertController(title: "Saved", message: "\(currentFilename) has been saved successfully.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Error", message: "Failed to save \(currentFilename)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func exportConfig() {
        if let exportedPath = ConfigFileManager.exportConfigToDocuments(currentFilename) {
            let alert = UIAlertController(
                title: "Exported",
                message: "Config file exported to Documents folder:\n\(exportedPath)\n\nYou can access it via the Files app.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Error", message: "Failed to export config", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func importConfig() {
        let alert = UIAlertController(
            title: "Import Config",
            message: "Place a config file in the Documents folder (via Files app) and enter its name:",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Exported_GFX.ini"
            textField.text = "Exported_\(self.currentFilename)"
        }
        
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            guard let filename = alert.textFields?.first?.text, !filename.isEmpty else { return }
            
            if ConfigFileManager.importConfigFromDocuments(filename) {
                self?.loadConfigFile(self?.currentFilename ?? "GFX.ini")
                let successAlert = UIAlertController(title: "Success", message: "Config imported successfully", preferredStyle: .alert)
                successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(successAlert, animated: true)
            } else {
                let errorAlert = UIAlertController(title: "Error", message: "Failed to import config", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(errorAlert, animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func closeEditor() {
        dismiss(animated: true)
    }
}
