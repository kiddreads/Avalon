//
//  NimbusCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class NimbusCollectionCell: UICollectionViewCell {
    
    private lazy var descLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        let text = R.string.localizable.pretendoNimbusDesc()
        let matt = NSMutableAttributedString(string: text, attributes: [.font: Constants.Font.body(size: .s), .foregroundColor: Constants.Color.LabelSecondary])
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Constants.Size.ContentSpaceUltraTiny
        style.alignment = .left
        label.attributedText = matt.applying(attributes: [.paragraphStyle: style])
        return label
    }()
    
    private lazy var button: SymbolButton = {
        let view = SymbolButton(image: nil,
                                title: R.string.localizable.installNimbus(),
                                titleFont: Constants.Font.body(size: .m),
                                titleColor: Constants.Color.LabelSecondary,
                                titleAlignment: .right,
                                horizontalContian: true)
        view.backgroundColor = Constants.Color.BackgroundSecondary
        view.isUserInteractionEnabled = false
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didTapButton?()
        }
        return view
    }()
    
    var didTapButton: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = Constants.Size.CornerRadiusMax
        containerView.backgroundColor = Constants.Color.BackgroundPrimary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        containerView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(descLabel.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(config: PretendoNetworkingConfig) {
        if config.articBaseDone {
            button.isUserInteractionEnabled = true
            button.titleLabel.textColor = Constants.Color.LabelPrimary
            button.backgroundColor = Constants.Color.Main
        } else {
            button.isUserInteractionEnabled = false
            button.titleLabel.textColor = Constants.Color.LabelSecondary
            button.backgroundColor = Constants.Color.BackgroundSecondary
        }
    }
}
