//
//  ImportServiceListView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift

class ImportServiceListView: BaseView {
    
    private var topBlurView: UIView = {
        let view = UIView()
        view.makeBlur(blurColor: Constants.Color.Background)
        return view
    }()
    
    var addServiceButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .plus, font: Constants.Font.body(size: .m, weight: .bold)))
        view.enableRoundCorner = true
        return view
    }()
    
    private var howToImportButton: HowToButton = {
        let view = HowToButton(title: R.string.localizable.importHowTo()) {
            topViewController()?.present(WebViewController(url: Constants.URLs.GameImportGuide), animated: true)
        }
        return view
    }()
    
    private var multiDiscButton: HowToButton = {
        let view = HowToButton(title: R.string.localizable.multiDiscBuilder()) {
            topViewController()?.present(MultiDiscBuilderViewController(), animated: true)
        }
        view.label.textColor = Constants.Color.LabelPrimary
        view.label.font = Constants.Font.caption(size: .l, weight: .semibold)
        return view
    }()
    
    private var downloadManageButton: DownloadButton = {
        let view = DownloadButton()
        view.addTapGesture { gesture in
            topViewController()?.present(DownloadViewController(), animated: true)
        }
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ImportFileCollectionViewCell.self)
        view.register(cellWithClass: ImportServiceListCollectionViewCell.self)
        view.register(supplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withClass: ImportFooterCollectionReusableView.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        let top = Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid
        let bottom = Constants.Size.ContentInsetBottom + Constants.Size.HomeTabBarSize.height + Constants.Size.ContentSpaceMax
        view.contentInset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        return view
    }()
    
    //文件单独一个section
    private let fileService = ImportService.genService(type: .files, detail: R.string.localizable.importServiceListFilesDetail())
    
    private var serviceUpdateToken: NotificationToken? = nil
    private var services: [ImportService] = {
        var services: [ImportService] = []
        //默认添加wifi、粘贴板
        services.append(ImportService.genService(type: .wifi, detail: WebServer.shard.isRunning ? R.string.localizable.importServiceListWiFiOnDetail(WebServer.shard.ipAddress) : R.string.localizable.importServiceListWiFiOffDetail()))
        
        services.append(ImportService.genService(type: .paste, detail: R.string.localizable.importServiceListPasteDetail()))
        return services
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        //访问数据库
        let realm = Database.realm
        let objects = realm.objects(ImportService.self).where { !$0.isDeleted }
        serviceUpdateToken = objects.observe(keyPaths: [\ImportService.detail]) { [weak self] changes in
            guard let self = self else { return }
            if case .update(_, let deletions, let insertions, let modifications) = changes {
                Log.debug("更新服务列表")
                if !deletions.isEmpty || !insertions.isEmpty {
                    self.updateServices(objects: objects)
                }
                if !modifications.isEmpty {
                    self.collectionView.reloadData()
                }
            }
        }
        updateServices(objects: objects)
        
        //渐变背景
        let gradientSize = CGSize(width: 495, height: 307)
        let backgroundGradientView = UIView(frame: CGRect(origin: .zero, size: gradientSize))
        let ovalLayer = CAShapeLayer()
        ovalLayer.path = UIBezierPath(ovalIn: backgroundGradientView.frame).cgPath
        backgroundGradientView.layer.mask = ovalLayer
        
        let colors = Constants.Color.Gradient.reversed()
        backgroundGradientView.addGradient(colors: Array(colors),
                                           locations: [0, 0.27, 0.62, 1],
                                           direction: UIView.GradientDirection(startPoint: CGPoint(x: 1, y: 0),
                                                                               endPoint: CGPoint(x: 0, y: 1)))
        let maskGradientView = UIView(frame: CGRect(origin: .zero, size: gradientSize))
        maskGradientView.addGradient(colors: [Constants.Color.Background.withAlphaComponent(0.95),
                                              Constants.Color.Background,
                                              Constants.Color.Background],
                                     locations: [0, 0.62, 1],
                                     direction: UIView.GradientDirection(startPoint: CGPoint(x: 0, y: 0),
                                                                         endPoint: CGPoint(x: 1, y: 1)))
        
        backgroundGradientView.addSubview(maskGradientView)
        maskGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let maskView = UIView()
        maskView.masksToBounds = true
        maskView.addSubview(backgroundGradientView)
        backgroundGradientView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(gradientSize)
        }
        addSubview(maskView)
        maskView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid)
            make.width.equalToSuperview()
            make.height.equalTo(gradientSize.height)
        }
        
        
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(topBlurView)
        topBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(Constants.Size.ContentInsetTop + Constants.Size.ItemHeightMid)
        }
        
        let navigationContainer = UIView()
        topBlurView.addSubview(navigationContainer)
        navigationContainer.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        navigationContainer.addSubview(addServiceButton)
        addServiceButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax)
        }
        
        navigationContainer.addSubview(howToImportButton)
        howToImportButton.snp.makeConstraints { make in
            make.height.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
        }
        
        navigationContainer.addSubview(multiDiscButton)
        multiDiscButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.trailing.equalTo(howToImportButton.snp.leading).offset(-Constants.Size.ContentSpaceMin)
        }
        
        navigationContainer.addSubview(downloadManageButton)
        downloadManageButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.trailing.equalTo(multiDiscButton.snp.leading).offset(-Constants.Size.ContentSpaceMin)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(sectionIndex == 0 ? 1 : 0.5),
                                                                                 heightDimension: .fractionalHeight(1)))
            
            let group: NSCollectionLayoutGroup = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension:  sectionIndex == 0 ? .absolute(164) : .absolute(154)), subitem: item, count: sectionIndex == 0 ? 1 : 2)
            
            group.interItemSpacing = .fixed(Constants.Size.ContentSpaceMid)//item间距
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            
            section.interGroupSpacing = Constants.Size.ContentSpaceMax
            
            section.contentInsets = NSDirectionalEdgeInsets(top: sectionIndex == 0 ? 0 : Constants.Size.ContentSpaceMax,
                                                            leading: Constants.Size.ContentSpaceHuge,
                                                            bottom: sectionIndex == 0 ? 0 : Constants.Size.ContentSpaceMax,
                                                            trailing: Constants.Size.ContentSpaceHuge)
            if sectionIndex == 1 {
                let footerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                                heightDimension: .absolute(150)),
                                                                             elementKind: UICollectionView.elementKindSectionFooter,
                                                                             alignment: .bottom)
                section.boundarySupplementaryItems.append(footerItem)
            }
            return section
            
        }
        return layout
    }
    
    private func updateServices(objects: Results<ImportService>) {
        services.removeSubrange(2...)
        services.append(contentsOf: objects.map({ $0 }))
        collectionView.reloadSections([1])
    }
}

extension ImportServiceListView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : services.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withClass: ImportFileCollectionViewCell.self, for: indexPath)
            cell.setData(service: fileService)
            cell.infoContainerView.addTapGesture { _ in
                //打开系统文件浏览器
                FilesImporter.shared.presentImportController()
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withClass: ImportServiceListCollectionViewCell.self, for: indexPath)
            let service = services[indexPath.row]
            cell.setData(service: service)
            if service.type == .wifi {
                let enableSelectedEffect = WebServer.shard.isRunning ? true : false
                cell.enableInteractive = enableSelectedEffect
                cell.delayInteractiveTouchEnd = enableSelectedEffect
                cell.switchButton.onChange { [weak service, weak self, weak cell] isOn in
                    let enableSelectedEffect = WebServer.shard.isRunning ? true : false
                    if isOn {
                        cell?.enableInteractive = enableSelectedEffect
                        cell?.delayInteractiveTouchEnd = enableSelectedEffect
                        WebServer.shard.start()
                        service?.detail = R.string.localizable.importServiceListWiFiOnDetail(WebServer.shard.ipAddress)
                    } else {
                        cell?.enableInteractive = enableSelectedEffect
                        cell?.delayInteractiveTouchEnd = enableSelectedEffect
                        WebServer.shard.stop()
                        service?.detail = R.string.localizable.importServiceListWiFiOffDetail()
                    }
                    self?.collectionView.reloadItems(at: [indexPath])
                }
            } else {
                cell.enableInteractive = true
                cell.delayInteractiveTouchEnd = true
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        //随机游戏footer
        let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: ImportFooterCollectionReusableView.self, for: indexPath)
        footer.channelButton.addTapGesture { gesture in
            if Locale.prefersCN {
                UIApplication.shared.open(Constants.URLs.JoinQQ)
            } else {
                UIApplication.shared.open(Constants.URLs.JoinTelegram)
            }
        }
        return footer
    }
}

extension ImportServiceListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        let service = services[indexPath.row]
        switch service.type {
        case .files:
            break
        case .wifi:
            if WebServer.shard.isRunning {
                UIPasteboard.general.string = WebServer.shard.ipAddress
                UIView.makeToast(message: R.string.localizable.ipCopy())
            }
        case .paste:
            //读取粘贴板
            PasteImporter.paste()
        case .googledrive, .dropbox, .onedrive, .baiduyun, .aliyun:
            
            if !PurchaseManager.isMember {
                topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
                return
            }
            
            //打开文件浏览器
            if let provider = service.cloudDriveProvider {
                UIView.makeLoading()
                CloudDriveConnetor.shard.renewToken(service: service, provider: provider) {
                    UIView.hideLoading()
                    topViewController(appController: true)?.present(BaseNavigationController(rootViewController: CloudDriveBrowserViewController(provider: provider, directory: provider.rootItem, navigationTitle: service.title)), animated: true)
                }
            }
        case .samba, .webdav:
            
            if !PurchaseManager.isMember {
                topViewController()?.present(PurchaseViewController(featuresType: .import), animated: true)
                return
            }
            
            if let provider = service.lanDriveProvider {
                topViewController()?.present(BaseNavigationController(rootViewController: CloudDriveBrowserViewController(provider: provider, directory: provider.rootItem, navigationTitle: service.title)), animated: true)
            }
        }
    }
    
    //长按弹出可交互菜单
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first, indexPath.section == 1 else { return nil }
        let service = services[indexPath.row]
        guard service.type != .wifi && service.type != .paste else { return nil }
        return UIContextMenuConfiguration(actionProvider:  { _ in
            UIMenu(children: [UIAction(title: R.string.localizable.importServiceDelete(), image: UIImage(systemSymbol: .trash), attributes: .destructive, handler: { _ in
                ImportService.change { realm in
                    if Settings.defalut.iCloudSyncEnable {
                        service.isDeleted = true
                    } else {
                        realm.delete(service)
                    }
                }
            })])
        })
    }
}
