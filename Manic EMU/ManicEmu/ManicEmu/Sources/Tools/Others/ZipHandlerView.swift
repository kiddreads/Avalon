//
//  ZipHandlerView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import ProHUD
import ManicEmuCore

class ZipHandlerView: BaseView {
    static func show(urls: [URL],
                     completion: ((_ unzipUrls: [URL], _ noActionUrls: [URL])->Void)? = nil ) {
        Sheet { sheet in
            sheet.contentMaskView.alpha = 0
            sheet.config.windowEdgeInset = 0
            sheet.config.backgroundViewMask { mask in
                mask.backgroundColor = .black.withAlphaComponent(0.2)
            }
            
            let view = UIView()
            let grabber = UIImageView(image: R.image.grabber_icon())
            grabber.contentMode = .center
            view.addSubview(grabber)
            grabber.snp.makeConstraints { make in
                make.leading.top.trailing.equalToSuperview()
                make.height.equalTo(Constants.Size.ContentSpaceTiny*3)
            }
            
            let containerView = RoundAndBorderView(roundCorner: (UIDevice.isPad || UIDevice.isLandscape) ? .allCorners : [.topLeft, .topRight])
            containerView.backgroundColor = Constants.Color.Background
            containerView.makeBlur()
            view.addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.top.equalTo(grabber.snp.bottom)
                make.leading.bottom.trailing.equalToSuperview()
            }
            
            let titleLabel = UILabel()
            titleLabel.textAlignment = .center
            titleLabel.text = R.string.localizable.zipHandlerTitle()
            titleLabel.font = Constants.Font.title(size: .s, weight: .semibold)
            titleLabel.textColor = Constants.Color.LabelPrimary
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(30)
            }
            
            let detailLabel = UILabel()
            detailLabel.numberOfLines = 0
            detailLabel.text = R.string.localizable.zipHandlerDetail()
            detailLabel.font = Constants.Font.body(size: .m)
            detailLabel.textColor = Constants.Color.LabelPrimary
            containerView.addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            }
            
            let coreSelectionView = ZipHandlerView(urls: urls)
            containerView.addSubview(coreSelectionView)
            coreSelectionView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(detailLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
                let count = Double(urls.count)
                let estimatedHeight = count * Constants.Size.ItemHeightMid + ((count + 1) * Constants.Size.ContentSpaceMax)
                let maxHeight = Constants.Size.WindowHeight/2
                make.height.equalTo(min(estimatedHeight, maxHeight))
            }
            
            let confirmLabel = UILabel()
            confirmLabel.isUserInteractionEnabled = true
            confirmLabel.enableInteractive = true
            confirmLabel.text = R.string.localizable.confirmTitle()
            confirmLabel.textAlignment = .center
            confirmLabel.font = Constants.Font.title(size: .s, weight: .regular)
            confirmLabel.textColor = Constants.Color.LabelSecondary
            containerView.addSubview(confirmLabel)
            confirmLabel.snp.makeConstraints { make in
                make.height.equalTo(Constants.Size.ItemHeightMid)
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(coreSelectionView.snp.bottom)
                make.bottom.equalToSuperview().offset(-Constants.Size.ContentInsetBottom)
            }
            confirmLabel.addTapGesture { [weak sheet] gesture in
                let result = coreSelectionView.getResult()
                sheet?.pop {
                    completion?(result.unzipUrls, result.noActionUrls)
                }
            }
            
            sheet.set(customView: view).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ZipHandlerCollectionViewCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.allowsMultipleSelection = true
        return view
    }()
    
    private var urls: [URL]
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    init(urls: [URL]) {
        self.urls = urls
        super.init(frame: .zero)
        Log.debug("\(String(describing: Self.self)) init")
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            
            let itemHeight: CGFloat = Constants.Size.ItemHeightMid
            
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: Constants.Size.ContentSpaceMid * 2,
                                                            bottom: 0,
                                                            trailing: Constants.Size.ContentSpaceMid * 2)
            
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Constants.Size.ContentSpaceMax
            section.contentInsets = NSDirectionalEdgeInsets(top: Constants.Size.ContentSpaceMax, leading: 0, bottom: Constants.Size.ContentSpaceMax, trailing: 0)
            
            section.decorationItems = [NSCollectionLayoutDecorationItem.background(elementKind: String(describing: PlatformSelectionView.PlatformSelectionCollectionReusableView.self))]
            
            
            return section
        }
        
        layout.register(PlatformSelectionView.PlatformSelectionCollectionReusableView.self, forDecorationViewOfKind: String(describing: PlatformSelectionView.PlatformSelectionCollectionReusableView.self))
        return layout
    }
    
    func getResult() -> (unzipUrls: [URL], noActionUrls: [URL]) {
        if let indexPaths = collectionView.indexPathsForSelectedItems {
            var unzipUrls = [URL]()
            var noActionUrls = [URL]()
            for (row, url) in urls.enumerated() {
                if indexPaths.contains(where: { $0.row == row }) {
                    unzipUrls.append(url)
                } else {
                    noActionUrls.append(url)
                }
            }
            return (unzipUrls, noActionUrls)
        }
        return ([], urls)
    }
}

extension ZipHandlerView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return urls.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let url = urls[indexPath.row]
        let cell = collectionView.dequeueReusableCell(withClass: ZipHandlerCollectionViewCell.self, for: indexPath)
        cell.setData(fileName: url.lastPathComponent)
        return cell
    }
}

class ZipHandlerCollectionViewCell: UICollectionViewCell {
    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    private let selectedIcon = SymbolButton(image: .init(symbol: .checkmarkCircleFill,
                                                       size: Constants.Size.IconSizeTiny.height,
                                                       colors: [Constants.Color.LabelPrimary, Constants.Color.Main]))
    
    private let normalIcon = SymbolButton(image: .init(symbol: .circle,
                                                         size: Constants.Size.IconSizeTiny.height,
                                                         colors: [Constants.Color.LabelPrimary]))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layerCornerRadius = Constants.Size.CornerRadiusMid
        
        backgroundColor = Constants.Color.Background
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
        }
        
        normalIcon.backgroundColor = .clear
        addSubview(normalIcon)
        normalIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        selectedIcon.backgroundColor = .clear
        selectedIcon.isHidden = true
        addSubview(selectedIcon)
        selectedIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(fileName: String, hideIcon: Bool = false) {
        titleLabel.text = fileName
    }
    
    override var isSelected: Bool {
        willSet {
            normalIcon.isHidden = newValue
            selectedIcon.isHidden = !newValue
        }
    }
}
