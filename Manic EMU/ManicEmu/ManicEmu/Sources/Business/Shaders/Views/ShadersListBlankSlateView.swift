//
//  ShadersListBlankSlateView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ShadersListBlankSlateView: BaseView {
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
    }
    
    let detailLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = Constants.Color.LabelSecondary
        titleLabel.font = Constants.Font.body(size: .l)
        return titleLabel
    }()
    
    let button: SymbolButton = {
        let view = SymbolButton(image: nil, title: "", titleFont: Constants.Font.body(size: .l, weight: .medium), titleColor: Constants.Color.LabelPrimary.forceStyle(.dark), edgeInsets: UIEdgeInsets(top: 0, left: Constants.Size.ContentSpaceHuge, bottom: 0, right: Constants.Size.ContentSpaceHuge), horizontalContian: true, titlePosition: .right)
        view.enableRoundCorner = true
        view.backgroundColor = Constants.Color.Red
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        Log.debug("\(String(describing: Self.self)) init")
        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        let iconImageView = UIImageView(image: R.image.empty_icon())
        iconImageView.contentMode = .center
        containerView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(-66)
            make.centerX.equalToSuperview()
            make.size.equalTo(100)
        }
        
        let titleLabel = UILabel()
        titleLabel.textColor = Constants.Color.LabelPrimary
        titleLabel.font = Constants.Font.title(size: .s, weight: .semibold)
        titleLabel.text = R.string.localizable.noShaders()
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
        }
        
        containerView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceTiny)
        }
        
        containerView.addSubview(button)
        button.snp.makeConstraints { make in
            make.height.equalTo(42)
            make.top.equalTo(detailLabel.snp.bottom).offset(28)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
