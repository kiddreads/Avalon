//
//  CoreConfigsOptionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import UIKit
import ProHUD

class CoreConfigsOptionView: BaseView {
    static func show(coreOption: CoreOption,
                     defaultOption: Options,
                     optionChange: ((_ value: String)->Void)? = nil ) {
        Sheet { sheet in
            sheet.contentMaskView.alpha = 0
            sheet.config.windowEdgeInset = 0
            sheet.config.backgroundViewMask { mask in
                mask.backgroundColor = .black.withAlphaComponent(0.2)
            }
            
            let view = UIView()
            let grabber = UIImageView(image: R.image.grabber_icon())
            grabber.isUserInteractionEnabled = true
            grabber.contentMode = .center
            view.addPanGesture { [weak view, weak sheet] gesture in
                guard let view = view, let sheet = sheet else { return }
                let point = gesture.translation(in: gesture.view)
                view.transform = .init(translationX: 0, y: point.y <= 0 ? 0 : point.y)
                if gesture.state == .recognized {
                    let v = gesture.velocity(in: gesture.view)
                    if (view.y > view.height*2/3 && v.y > 0) || v.y > 1200 {
                        sheet.pop()
                    }
                    UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .curveEaseOut], animations: {
                        view.transform = .identity
                    })
                }
            }
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
            titleLabel.text = coreOption.desc
            titleLabel.font = Constants.Font.title(size: .s, weight: .semibold)
            titleLabel.textColor = Constants.Color.LabelPrimary
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(30)
            }
            
            let detailLabel = UILabel()
            detailLabel.numberOfLines = 0
            detailLabel.text = coreOption.info
            detailLabel.font = Constants.Font.body(size: .m)
            detailLabel.textColor = Constants.Color.LabelPrimary
            containerView.addSubview(detailLabel)
            detailLabel.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            }
            
            let optionView = CoreConfigsOptionView(coreOption: coreOption, defaultOption: defaultOption)
            optionView.didOptionChange = { value in
                optionChange?(value)
            }
            containerView.addSubview(optionView)
            optionView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(detailLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
                let count = CGFloat(coreOption.options.count)
                let estimatedHeight = count * Constants.Size.ItemHeightMax + ((count + 1) * Constants.Size.ContentSpaceMax)
                let maxHeight = Constants.Size.WindowHeight*3/4
                make.height.equalTo(min(estimatedHeight, maxHeight))
                make.bottom.equalToSuperview().offset(-Constants.Size.ContentInsetBottom)
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
        view.register(cellWithClass: CoreConfigsOptionCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    private var coreOption: CoreOption
    private var defaultOption: Options
    
    var didOptionChange: ((_ value: String)->Void)? = nil
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    init(coreOption: CoreOption, defaultOption: Options) {
        self.coreOption = coreOption
        self.defaultOption = defaultOption
        super.init(frame: .zero)
        Log.debug("\(String(describing: Self.self)) init")
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
            if let selectedIndex = coreOption.options.firstIndex(where: { $0.value == defaultOption.value }) {
                self?.collectionView.selectItem(at: IndexPath(row: selectedIndex, section: 0), animated: true, scrollPosition: .centeredVertically)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .estimated(Constants.Size.ItemHeightMax)))
            
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(Constants.Size.ItemHeightMax)), subitems: [item])
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
}

extension CoreConfigsOptionView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return coreOption.options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: CoreConfigsOptionCell.self, for: indexPath)
        cell.setData(title: coreOption.options[indexPath.row].label)
        return cell
    }
}

extension CoreConfigsOptionView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didOptionChange?(coreOption.options[indexPath.row].value)
    }
}

class CoreConfigsOptionCell: UICollectionViewCell {
    private var titleLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .l)
        label.textColor = Constants.Color.LabelPrimary
        label.numberOfLines = 0
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
            make.top.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
        }
        
        normalIcon.backgroundColor = .clear
        addSubview(normalIcon)
        normalIcon.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        selectedIcon.backgroundColor = .clear
        selectedIcon.isHidden = true
        addSubview(selectedIcon)
        selectedIcon.snp.makeConstraints { make in
            make.edges.equalTo(normalIcon)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(title: String) {
        titleLabel.text = title
    }
    
    override var isSelected: Bool {
        willSet {
            normalIcon.isHidden = newValue
            selectedIcon.isHidden = !newValue
        }
    }
}
