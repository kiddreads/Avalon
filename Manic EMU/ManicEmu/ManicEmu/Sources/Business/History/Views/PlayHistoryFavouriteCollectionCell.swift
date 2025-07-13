//
//  PlayHistoryFavouriteCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import Kingfisher

class PlayHistoryFavouriteCollectionCell: UICollectionViewCell {
    private var headerTitleLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.caption(size: .l)
        view.textColor = Constants.Color.LabelPrimary
        view.textAlignment = .center
        view.backgroundColor = Constants.Color.Background
        view.layerCornerRadius = Constants.Size.ItemHeightUltraTiny/2
        view.text = R.string.localizable.historyFavouriteTitle()
        return view
    }()
    
    private var infoContainerView: UIView = {
        let view = GradientView()
        view.setupGradient(colors: [.clear, .black.withAlphaComponent(0.4)], locations: [0.0, 1.0], direction: .topToBottom)
        view.backgroundColor = Constants.Color.Background
        view.layerCornerRadius = Constants.Size.CornerRadiusMax
        view.enableInteractive = true
        view.delayInteractiveTouchEnd = true
        return view
    }()
    
    private var iconViewContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Constants.Size.CornerRadiusMin
        view.makeShadow(ofColor: Constants.Color.BackgroundPrimary, radius: 15)
        return view
    }()
    
    private var iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleToFill
        view.layerCornerRadius = Constants.Size.CornerRadiusMin
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.body(size: .l)
        view.textColor = Constants.Color.LabelPrimary
        view.numberOfLines = 2
        view.layer.shadowColor = Constants.Color.Background.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = .init(width: 0, height: 2)
        view.layer.shadowRadius = 2
        return view
    }()
    
    private var subtitleIcon: UIImageView = {
        let view = UIImageView()
        view.image = .symbolImage(.starCircleFill)
        return view
    }()
    
    private var subTitleLabel: UILabel = {
        let view = UILabel()
        view.font = UIDevice.isPad ? Constants.Font.caption(size: .m) : Constants.Font.caption(size: .l)
        view.lineBreakMode = .byCharWrapping
        view.textColor = .white.withAlphaComponent(0.5)
        view.numberOfLines = 2
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(headerTitleLabel)
        headerTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightUltraTiny)
            make.width.greaterThanOrEqualTo(72)
        }
        
        addSubview(infoContainerView)
        infoContainerView.snp.makeConstraints { make in
            make.top.equalTo(headerTitleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            make.leading.trailing.equalToSuperview()
        }
        
        infoContainerView.addSubview(iconViewContainerView)
        iconViewContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.centerY.equalToSuperview()
            make.size.equalTo(106 * (UIDevice.isPad ? 0.8 : 1))
        }

        iconViewContainerView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        
        let titleContainerView = UIView()
        infoContainerView.addSubview(titleContainerView)
        titleContainerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconViewContainerView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMin)
        }
        
        titleContainerView.addSubviews([titleLabel, subtitleIcon, subTitleLabel])
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        
        subtitleIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeTiny)
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        subTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(subtitleIcon.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceUltraTiny)
        }
        
        let seperator = SparkleSeperatorView()
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(16)
            make.top.equalTo(infoContainerView.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
            make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceUltraTiny)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //TODO: 需要处理图片的尺寸
    func setData(game: Game) {
        let estimated = iconView.size == .zero ? .init((UIDevice.isPad ? 85 : 106)) : iconView.size
        iconView.setGameCover(game: game, size: estimated) { [weak self] image in
            self?.infoContainerView.backgroundColor = image.dominantBackground
        }
        if game.gameType == .nes || game.gameType == .snes || game.gameType == .psp {
            iconView.contentMode = .scaleAspectFill
        } else {
            iconView.contentMode = .scaleToFill
        }
        titleLabel.text = game.aliasName ?? game.name
        if let timeAgo = game.latestPlayDate?.timeAgo() {
            subTitleLabel.text = R.string.localizable.readyGameInfoSubTitle(timeAgo, Date.timeDuration(milliseconds: Int(game.totalPlayDuration))).replacingOccurrences(of: " · ", with: "\n")
        } else {
            subTitleLabel.text = ""
        }
    }
}
