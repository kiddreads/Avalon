//
//  RetroAchievementsDetailView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementsDetailView: BaseView {
    init(achievement: CheevosAchievement, didTapClose: @escaping (()->Void)) {
        super.init(frame: .zero)
        let coverImageView = UIImageView()
        coverImageView.contentMode = .scaleAspectFill
        addSubview(coverImageView)
        coverImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(160)
            make.top.equalToSuperview()
        }
        coverImageView.kf.setImage(with: URL(string: achievement.unlocked ? achievement.unlockedBadgeUrl : achievement.activeBadgeUrl), placeholder: UIImage.placeHolder(preferenceSize: .init(160)))
        
        let titleLabel: UILabel = {
            let view = UILabel()
            view.numberOfLines = 0
            let matt = NSMutableAttributedString(string: achievement.title ?? "", attributes: [.font: Constants.Font.title(weight: .semibold), .foregroundColor: UIColor.white])
            matt.append(NSAttributedString(string: "\n\(achievement._description ?? "")", attributes: [.font: Constants.Font.body(size: .l), .foregroundColor: Constants.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            style.alignment = .center
            view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            return view
        }()
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.equalTo(coverImageView.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
        }
        
        let seperator = SparkleSeperatorView(color: Constants.Color.BackgroundTertiary, lineColor: Constants.Color.BackgroundSecondary)
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(24)
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
        }
        
        let infoLabel: UILabel = {
            let view = UILabel()
            view.textAlignment = .center
            view.numberOfLines = 0
            let matt = NSMutableAttributedString(string: "\(achievement.points) points", attributes: [.font: Constants.Font.body(size: .l), .foregroundColor: UIColor.white])
            if achievement.unlocked, let unlockDate = achievement.unlockTime {
                matt.append(NSAttributedString(string: "\n\(unlockDate.dateTimeString())", attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelSecondary]))
            }
            let style = NSMutableParagraphStyle()
            style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
            style.alignment = .center
            view.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            return view
        }()
        addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.equalTo(seperator.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
        }
        
        let roundContainer = RoundAndBorderView(roundCorner: .allCorners, borderColor: UIColor.white.withAlphaComponent(0.1), borderWidth: 2)
        roundContainer.addTapGesture { gesture in
            didTapClose()
        }
        roundContainer.enableInteractive = true
        roundContainer.delayInteractiveTouchEnd = true
        addSubview(roundContainer)
        roundContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.Size.ItemHeightMid)
            make.centerX.equalToSuperview()
            make.top.equalTo(infoLabel.snp.bottom).offset(Constants.Size.ItemHeightMax)
            make.bottom.equalToSuperview()
        }
        let okLabel = UILabel()
        okLabel.text = R.string.localizable.gotIt()
        okLabel.font = Constants.Font.title(size: .s, weight: .semibold)
        okLabel.textColor = .white
        roundContainer.addSubview(okLabel)
        okLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
