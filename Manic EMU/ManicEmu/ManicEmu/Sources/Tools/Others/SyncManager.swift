//
//  SyncManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/12.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Foundation
import IceCream
import CloudKit
import SwiftCloudDrive

class SyncManager: NSObject {
    static let shared = SyncManager()
    //数据库与CloudKit同步
    private var realmSyncEngine: SyncEngine?
    
    private var cloudDrive: CloudDrive?
    
    var iCloudServiceEnable: Bool? = nil
    
    var hasDownloadTask: Bool {
        downloadingFiles.count > 0
    }
    
    private var downloadingFiles: [String] = []
    
    private var stopGameNotification: Any? = nil
    
    private var iCloudAccountChangedNotification: Any? = nil
    
    enum SyncState: String {
        case undefine
        case idle
        case syncing //上传文件到iCloud drive 或 从iCloud Drive下载文件 或 正在删除iCloud Drive的文件
    }
    
    private(set) var syncState: SyncState = .undefine {
        didSet {
            if oldValue != syncState {
                NotificationCenter.default.post(name: Constants.NotificationName.iCloudDriveSyncChange, object: syncState)
                Log.debug("[iCloud Sync] 同步状态变化: \(oldValue.rawValue) -> \(syncState.rawValue)")
            }
        }
    }
    
    // MARK: - iCloud 文件状态监控
    private let metadataQuery = NSMetadataQuery()
    private var metadataQueryNotificationTokens: [NSObjectProtocol] = []
    private var isMonitoring = false
    private var monitoredUploadingFiles = Set<URL>()
    private var monitoredDownloadingFiles = Set<URL>()
    private let monitoringQueue = DispatchQueue(label: "com.manicemu.syncmanager.monitoring")
    
    deinit {
        stopiCloudFileMonitoring()
        if let iCloudAccountChangedNotification = iCloudAccountChangedNotification {
            NotificationCenter.default.removeObserver(iCloudAccountChangedNotification)
        }
        metadataQueryNotificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private override init() {
        super.init()
        updateiCloudAccountstatus()
        iCloudAccountChangedNotification = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.updateiCloudAccountstatus()
        }
    }
    
    /// 开始同步
    func startSync() {
        if realmSyncEngine == nil {
            setupRealmSync()
            setupDocumentSync()
            // 启动 iCloud 文件监控
            startiCloudFileMonitoring()
            stopGameNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.StopPlayGame, object: nil, queue: .main) { notification in
                SyncManager.syncDocument()
            }
        }
    }
    
    //停止同步
    func stopSync() {
        realmSyncEngine = nil
        // 停止 iCloud 文件监控
        stopiCloudFileMonitoring()
        if let stopGameNotification = stopGameNotification {
            NotificationCenter.default.removeObserver(stopGameNotification)
        }
    }
    
    private func setupDocumentSync() {
        Task {
            cloudDrive = try await CloudDrive()
            SyncManager.syncDocument()
        }
    }

    private func setupRealmSync() {
        guard realmSyncEngine == nil else { return }
        IceCream.shared.logAction = { Log.debug($0) }
        //注册Realm同步管理器
        let configuration = Database.realm.configuration
        realmSyncEngine = SyncEngine(objects: [
            SyncObject(realmConfiguration: configuration, type: Game.self, uListElementType: GameSaveState.self, vListElementType: GameCheat.self),
            SyncObject(realmConfiguration: configuration, type: GameCheat.self),
            SyncObject(realmConfiguration: configuration, type: Skin.self),
            SyncObject(realmConfiguration: configuration, type: GameSaveState.self),
            SyncObject(realmConfiguration: configuration, type: ImportService.self),
            SyncObject(realmConfiguration: configuration, type: Settings.self),
            SyncObject(realmConfiguration: configuration, type: ControllerMapping.self),
            SyncObject(realmConfiguration: configuration, type: Theme.self),
            SyncObject(realmConfiguration: configuration, type: Trigger.self, uListElementType: TriggerItem.self),
            SyncObject(realmConfiguration: configuration, type: TriggerItem.self)
        ])
        realmSyncEngine?.setupCompletion = { error in
            //同步设定完成之后 尝试将本地所有数据推到云端
            if let error = error {
                Log.debug("[iCloud Sync]数据库同步初始化结束 error:\(error)")
            } else {
                Log.debug("[iCloud Sync]数据库同步初始化结束")
            }
        }
    }
    
    private func updateiCloudAccountstatus() {
#if !SIDE_LOAD
        CKContainer.default().accountStatus { [weak self] status, error in
            guard let self = self else { return }
            self.iCloudServiceEnable = status == .available
        }
#endif
    }
    
    // MARK: - iCloud 文件状态监控方法
    private func startiCloudFileMonitoring() {
        guard !isMonitoring else { return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            Log.debug("[iCloud Sync] 未检测到iCloud账户，无法开启文件状态监控")
            return
        }
        
        isMonitoring = true
        DispatchQueue.main.async { [weak self] in
            self?.configureMetadataQuery()
            self?.metadataQuery.enableUpdates()
            self?.metadataQuery.start()
            Log.debug("[iCloud Sync] 开始监控iCloud文件状态")
        }
    }
    
    private func stopiCloudFileMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        DispatchQueue.main.async { [weak self] in
            self?.metadataQuery.stop()
            self?.metadataQuery.disableUpdates()
            self?.teardownMetadataQueryObservers()
            Log.debug("[iCloud Sync] 停止监控iCloud文件状态")
        }
        monitoringQueue.async { [weak self] in
            self?.resetTrackingState()
        }
    }
    
    private func configureMetadataQuery() {
        guard metadataQueryNotificationTokens.isEmpty else { return }
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(value: true)
        metadataQuery.notificationBatchingInterval = 0.5
        
        let center = NotificationCenter.default
        let finishToken = center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { [weak self] _ in
            self?.metadataQuery.disableUpdates()
            self?.processMetadataQueryResults()
            self?.metadataQuery.enableUpdates()
        }
        
        let updateToken = center.addObserver(forName: .NSMetadataQueryDidUpdate, object: metadataQuery, queue: .main) { [weak self] _ in
            self?.processMetadataQueryResults()
        }
        
        metadataQueryNotificationTokens.append(contentsOf: [finishToken, updateToken])
    }
    
    private func teardownMetadataQueryObservers() {
        metadataQueryNotificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        metadataQueryNotificationTokens.removeAll()
    }
    
    private func processMetadataQueryResults() {
        guard isMonitoring else { return }
        let results = metadataQuery.results
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            for case let item as NSMetadataItem in results {
                self.handleMetadataItem(item)
            }
            self.updateSyncState()
        }
    }
    
    private func handleMetadataItem(_ item: NSMetadataItem) {
        guard let fileURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return }
        
        // 过滤掉目录，只处理文件
        // 方法1: 检查 URL 路径是否以 / 结尾（目录通常以 / 结尾）
        if fileURL.path.hasSuffix("/") {
            return
        }
        
        // 方法2: 使用 FileManager 检查（如果文件已存在）
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return
        }
        
        // 方法3: 检查内容类型（如果可用）
        if let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String,
           contentType == "public.directory" || contentType == "public.folder" {
            return
        }
        
        let wasUploading = monitoredUploadingFiles.contains(fileURL)
        let wasDownloading = monitoredDownloadingFiles.contains(fileURL)
        
        let uploading = isUploading(item)
        let downloading = isDownloading(item, cloudFileUrl: fileURL)
        
        // 处理上传状态
        if uploading {
            if !wasUploading {
                monitoredUploadingFiles.insert(fileURL)
            }
        } else {
            if wasUploading {
                monitoredUploadingFiles.remove(fileURL)
            }
        }
        
        // 处理下载状态
        if downloading {
            if !wasDownloading {
                monitoredDownloadingFiles.insert(fileURL)
            }
        } else {
            if wasDownloading {
                monitoredDownloadingFiles.remove(fileURL)
            }
        }
    }
    
    private func isUploading(_ item: NSMetadataItem) -> Bool {
        if let uploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool, uploading {
            return true
        }
        if let percent = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double, percent > 0.0 && percent < 100.0 {
            return true
        }
        return false
    }
    
    private func isDownloading(_ item: NSMetadataItem, cloudFileUrl: URL) -> Bool {
        if let downloading = item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool, downloading {
            return true
        } else if let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
            if status == NSMetadataUbiquitousItemDownloadingStatusDownloaded || status == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                return false
            } else if status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                //该item尚未进行下载 检查一下本地是否已经存在
                if let localUrl = SyncManager.convertToLocalUrl(fromCloudUrl: cloudFileUrl) {
                    //url合法
                    if FileManager.default.fileExists(atPath: localUrl.path) {
                        //本地文件已经存在
                        return false
                    } else {
                        //本地文件不存在 则进行下载
                        SyncManager.download(to: localUrl.path)
                        return true
                    }
                } else {
                    //url不合法
                    return false
                }
            }
        }
        return false
    }
    
    private func resetTrackingState() {
        monitoredUploadingFiles.removeAll()
        monitoredDownloadingFiles.removeAll()
        updateSyncState()
    }
    
    private func updateSyncState() {
        let hasActiveTasks = !monitoredUploadingFiles.isEmpty || !monitoredDownloadingFiles.isEmpty
        let newState: SyncState = hasActiveTasks ? .syncing : .idle
        guard newState != syncState else { return }
        DispatchQueue.main.async { [weak self] in
            self?.syncState = newState
        }
    }
    
    static func upload(localFilePath: String) {
        guard Settings.defalut.iCloudSyncEnable else { return }
        if let range = localFilePath.range(of: "/Documents/") {
            let cloudFilePath = RootRelativePath(path: String(localFilePath[range.lowerBound...]))
            if let cloudDrive = SyncManager.shared.cloudDrive {
                Task {
                    Log.debug("[iCloud Sync]开始上传文件到iCloud:\(localFilePath)")
                    let parentDirectory = RootRelativePath(path: String(localFilePath.deletingLastPathComponent[range.lowerBound...]))
                    let directoryExists = try await cloudDrive.directoryExists(at: parentDirectory)
                    if !directoryExists {
                        try await cloudDrive.createDirectory(at: parentDirectory)
                    }
                    try? await cloudDrive.upload(from: URL(fileURLWithPath: localFilePath), to: cloudFilePath)
                    Log.debug("[iCloud Sync]文件已提交到iCloud上传队列:\(cloudFilePath.path)")
                    // 注意：文件可能还在上传中，真实状态由 NSMetadataQuery 监控
                }
            }
        }
    }
    
    static func download(to localFilePath: String, completion: ((Error?)->Void)? = nil) {
        if SyncManager.shared.downloadingFiles.contains(localFilePath) {
            UIView.makeToast(message: R.string.localizable.filesDownloadErrorFileExist(localFilePath.deletingPathExtension.lastPathComponent))
            return
        }
        
        if let range = localFilePath.range(of: "/Documents/") {
            let cloudFilePath = RootRelativePath(path: String(localFilePath[range.lowerBound...]))
            Task {
                do {
                    let cloudDrive: CloudDrive
                    if let cd = SyncManager.shared.cloudDrive {
                        cloudDrive = cd
                    } else {
                        cloudDrive = try await CloudDrive()
                        SyncManager.shared.cloudDrive = cloudDrive
                    }
                    Log.debug("[iCloud Sync]开始从iCloud下载文件:\(cloudFilePath.path)")
                    if !FileManager.default.fileExists(atPath: localFilePath.deletingLastPathComponent) {
                        try? FileManager.default.createDirectory(atPath: localFilePath.deletingLastPathComponent, withIntermediateDirectories: true)
                    }
                    SyncManager.shared.downloadingFiles.append(localFilePath)
                    try await cloudDrive.download(from: cloudFilePath, toURL: URL(fileURLWithPath: localFilePath))
                    Log.debug("[iCloud Sync]文件已提交到iCloud下载队列:\(localFilePath)")
                    // 注意：文件可能还在下载中，真实状态由 NSMetadataQuery 监控
                    SyncManager.shared.downloadingFiles.removeAll { $0 == localFilePath }
                    await MainActor.run {
                        completion?(nil)
                    }
                } catch {
                    SyncManager.shared.downloadingFiles.removeAll { $0 == localFilePath }
                    await MainActor.run {
                        completion?(error as? Error)
                    }
                }
            }
        }
    }
    
    static func delete(localFilePath: String) {
        guard Settings.defalut.iCloudSyncEnable else { return }
        if let range = localFilePath.range(of: "/Documents/") {
            let cloudFilePath = RootRelativePath(path: String(localFilePath[range.lowerBound...]))
            if let cloudDrive = SyncManager.shared.cloudDrive {
                Task {
                    Log.debug("[iCloud Sync]开始删除iCloud文件:\(localFilePath)")
                    try? await cloudDrive.removeFile(at: cloudFilePath)
                    Log.debug("[iCloud Sync]删除iCloud文件成功:\(cloudFilePath.path)")
                }
            }
        }
    }
    
    static func deletePath(localPath: String) {
        guard Settings.defalut.iCloudSyncEnable else { return }
        if let range = localPath.range(of: "/Documents/") {
            let cloudFilePath = RootRelativePath(path: String(localPath[range.lowerBound...]))
            if let cloudDrive = SyncManager.shared.cloudDrive {
                Task {
                    Log.debug("[iCloud Sync]开始删除iCloud目录:\(localPath)")
                    try? await cloudDrive.removeDirectory(at: cloudFilePath)
                    Log.debug("[iCloud Sync]删除iCloud目录成功:\(cloudFilePath.path)")
                }
            }
        }
    }
    
    static func isiCloudFileExist(localFilePath: String, completion: ((Bool)->Void)? = nil) {
        if let range = localFilePath.range(of: "/Documents/") {
            let cloudFilePath = RootRelativePath(path: String(localFilePath[range.lowerBound...]))
            Task {
                let cloudDrive: CloudDrive
                if let cd = SyncManager.shared.cloudDrive {
                    cloudDrive = cd
                } else {
                    cloudDrive = try await CloudDrive()
                    SyncManager.shared.cloudDrive = cloudDrive
                }
                if let fileExists = try? await cloudDrive.fileExists(at: cloudFilePath) {
                    await MainActor.run {
                        completion?(fileExists)
                    }
                } else {
                    await MainActor.run {
                        completion?(false)
                    }
                }
            }
        }
    }
    
    static func syncDocument() {
        if !Settings.defalut.iCloudSyncEnable && PlayViewController.isGaming {
            return;
        }
        Task {
            if let cloudDrive = SyncManager.shared.cloudDrive {
                var handledFiles = [String]()
                var conflictFiles = [String]()
                Log.debug("[iCloud Sync] 开始同步iCloud文件....")
                //遍历云文件
                if let cloudFileUrls = try? await fetchAllCloudFiles(at: .init(path: "Documents"), cloudDrive: cloudDrive) {
                    for cloudFileUrl in cloudFileUrls {
                        if let cloudFileModificationDate = (try cloudFileUrl.resourceValues(forKeys: [.contentModificationDateKey])).contentModificationDate {
                            if let range = cloudFileUrl.path.range(of: "/Documents/") {
                                let cloudFileRelativePath = String(cloudFileUrl.path[range.upperBound...])
                                let cloudFilePath = RootRelativePath(path: "Documents/\(cloudFileRelativePath)")
                                let localFilePath = Constants.Path.Document.appendingPathComponent(cloudFileRelativePath)
                                if FileManager.default.fileExists(atPath: localFilePath) {
                                    if let localFileModificationDate = try FileManager.default.attributesOfItem(atPath: localFilePath)[.modificationDate] as? Date {
                                        if localFileModificationDate > cloudFileModificationDate {
                                            Log.debug("[iCloud Sync]本地文件比较新, 本地覆盖云端 \(cloudFileRelativePath)")
                                            try? await cloudDrive.removeFile(at: cloudFilePath)
                                            do {
                                                try await cloudDrive.upload(from: URL(fileURLWithPath: localFilePath), to: cloudFilePath)
                                            } catch {
                                                Log.debug("[iCloud Sync]\(cloudFilePath.path) 上传失败:\(error)")
                                            }
                                        } else if localFileModificationDate < cloudFileModificationDate {
                                            Log.debug("[iCloud Sync]云端文件比较新, 云端覆盖本地 \(cloudFileRelativePath)")
                                            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: localFilePath))
                                            do {
                                                try await cloudDrive.download(from: cloudFilePath, toURL: URL(fileURLWithPath: localFilePath))
                                            } catch {
                                                Log.debug("[iCloud Sync]\(cloudFilePath.path) 下载失败:\(error)")
                                            }
                                            
                                        } else {
                                            //文件没有更新，忽略
                                        }
                                    } else {
                                        Log.debug("[iCloud Sync]无法获取本地文件修改时间，记录冲突，让用户来决定")
                                        conflictFiles.append(cloudFileRelativePath)
                                    }
                                } else {
                                    Log.debug("[iCloud Sync]本地文件不存在，下载到本地... \(cloudFileRelativePath)")
                                    do {
                                        if !FileManager.default.fileExists(atPath: localFilePath.deletingLastPathComponent) {
                                            try? FileManager.default.createDirectory(atPath: localFilePath.deletingLastPathComponent, withIntermediateDirectories: true)
                                        }
                                        try await cloudDrive.download(from: cloudFilePath, toURL: URL(fileURLWithPath: localFilePath))
                                    } catch {
                                        Log.debug("[iCloud Sync]\(cloudFilePath.path) 下载失败:\(error)")
                                    }
                                }
                                handledFiles.append(cloudFileRelativePath)
                            } else {
                                Log.debug("[iCloud Sync]无法获取云端文件的相对路径")
                            }
                        } else {
                            Log.debug("[iCloud Sync]无法获取云端文件修改时间")
                        }
                    }
                }
                //遍历本地
                let localFileUrls = fetchAllLocalFiles(at: URL(fileURLWithPath: Constants.Path.Document))
                for localFileUrl in localFileUrls {
                    if let range = localFileUrl.path.range(of: "/Documents/") {
                        let localFileRelativePath = String(localFileUrl.path[range.upperBound...])
                        if !handledFiles.contains(localFileRelativePath) {
                            do {
                                Log.debug("[iCloud Sync]本地存在的文件，但是云端还没有 进行上传... \(localFileRelativePath)")
                                let directoryExists = try await cloudDrive.directoryExists(at: RootRelativePath(path: "Documents/\(localFileRelativePath.deletingLastPathComponent)"))
                                if !directoryExists {
                                    try await cloudDrive.createDirectory(at: RootRelativePath(path: "Documents/\(localFileRelativePath.deletingLastPathComponent)"))
                                }
                                try await cloudDrive.upload(from: localFileUrl, to: RootRelativePath(path: "Documents/\(localFileRelativePath)"))
                                Log.debug("[iCloud Sync]文件上传成功 \(localFileRelativePath)")
                            } catch {
                                Log.debug("\(localFileRelativePath)上传失败:\(error)")
                            }
                        } else {
                            //文件无需处理
                        }
                    }
                }
                //处理冲突
                for conflictFile in conflictFiles {
                    Log.debug("[iCloud Sync]处理冲突文件:\(conflictFile)")
                    Task { @MainActor in
                        let cloudFilePath = RootRelativePath(path: "Documents/\(conflictFile)")
                        let localFilePath = Constants.Path.Document.appendingPathComponent(conflictFile)
                        UIView.makeAlert(title: R.string.localizable.iCloudSyncConfilictTitle(),
                                         detail: conflictFile,
                                         cancelTitle: R.string.localizable.iCloudSyncConfilictSaveiCloud(),
                                         confirmTitle: R.string.localizable.iCloudSyncConfilictSaveLocal(),
                                         enableForceHide: false,
                                         cancelAction: {
                            Task {
                                //保留云端 则删除本地的
                                try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: localFilePath))
                                try await cloudDrive.download(from: cloudFilePath, toURL: URL(fileURLWithPath: localFilePath))
                                // 注意：文件可能还在下载中，真实状态由 NSMetadataQuery 监控
                            }
                        },
                                         confirmAction: {
                            //保留本地的 则删除云端的
                            Task {
                                try? await cloudDrive.removeFile(at: cloudFilePath)
                                try await cloudDrive.upload(from: URL(fileURLWithPath: localFilePath), to: cloudFilePath)
                                // 注意：文件可能还在上传中，真实状态由 NSMetadataQuery 监控
                            }
                        })
                    }
                }
            }
        }
    }

    private static func fetchAllLocalFiles(at url: URL, resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey]) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default
        do {
            let items = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
            for item in items {
                let values = try item.resourceValues(forKeys: Set(resourceKeys))
                if values.isDirectory == true {
                    if item.path.contains("/wpkdata") || item.path.contains("/Datas/") {
                        //特殊目录不需要进行遍历
                        continue
                    }
                    // 递归进入子目录
                    let subFiles = fetchAllLocalFiles(at: item, resourceKeys: resourceKeys)
                    result.append(contentsOf: subFiles)
                } else if values.isRegularFile == true {
                    if !item.path.contains("/SYSTEM/CACHE/") {
                        result.append(item)
                    }
                }
            }
        } catch {
            Log.debug("遍历本地文件失败:\(error)")
        }
        return result
    }
    
    private static func fetchAllCloudFiles(at path: RootRelativePath, cloudDrive: CloudDrive, resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey]) async throws -> [URL] {
        var result: [URL] = []
        do {
            let items = try await cloudDrive.contentsOfDirectory(at: path, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
            for item in items {
                let values = try item.resourceValues(forKeys: Set(resourceKeys))
                if values.isDirectory == true {
                    if item.path.contains("/wpkdata") || item.path.contains("/Datas/") {
                        //特殊目录不需要进行遍历
                        continue
                    }
                    // 递归进入子目录
                    if let range = item.path.range(of: "/Documents/") {
                        let subFiles = try await fetchAllCloudFiles(at: RootRelativePath(path: String(item.path[range.lowerBound...])), cloudDrive: cloudDrive, resourceKeys: resourceKeys)
                        result.append(contentsOf: subFiles)
                    }
                    
                } else if values.isRegularFile == true {
                    result.append(item)
                }
            }
        } catch {
            Log.debug("[iCloud Sync]遍历云端文件失败:\(error)")
            throw error
        }
        return result
    }
    
    static func convertToLocalUrl(fromCloudUrl: URL) -> URL? {
        if let range = fromCloudUrl.path.range(of: "/Documents/") {
            let cloudFileRelativePath = String(fromCloudUrl.path[range.upperBound...])
            return URL(fileURLWithPath: Constants.Path.Document.appendingPathComponent(cloudFileRelativePath))
        }
        return nil
    }
    
    static func convertToCloudPath(url: URL) -> RootRelativePath? {
        if let range = url.path.range(of: "/Documents/") {
            return RootRelativePath(path: String(url.path[range.lowerBound...]))
        }
        return nil
    }
}
