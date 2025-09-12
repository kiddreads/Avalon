//
//  RetroAchievementsDetailView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementsDetailView: BaseView {
    init(achievement: CheevosAchievement, shaereMode: Bool = false, didTapClose: @escaping (()->Void)) {
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
        
        var iconSymbol: SFSymbol? = nil
        var iconAlert: String? = nil
        if achievement.isMissable &&  achievement.isProgression {
            iconSymbol = .starCircle
            iconAlert = R.string.localizable.achievementsWinAlert()
        } else if achievement.isMissable {
            iconSymbol = .exclamationmarkCircle
            iconAlert = R.string.localizable.achievementsMissableAlert()
        } else if achievement.isProgression {
            iconSymbol = .clockBadgeCheckmark
            iconAlert = R.string.localizable.achievementsProgressionAlert()
        }
        if let iconSymbol {
            let iconImageView = SymbolButton(image: UIImage(symbol: iconSymbol, color: .white))
            iconImageView.enableRoundCorner = true
            iconImageView.backgroundColor = UIColor.black
            addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.top.trailing.equalTo(coverImageView).inset(Constants.Size.ContentSpaceTiny)
                make.size.equalTo(20)
            }
            iconImageView.addTapGesture { gesture in
                if let iconAlert {
                    UIView.makeAlert(detail: iconAlert)
                }
            }
        }
        
        
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
        
        var enableProgressView: RetroAchievementsListCell.AchievementsProgressView? = nil
        if let measuredProgress = achievement.measuredProgress, !measuredProgress.isEmpty {
            let progressView = RetroAchievementsListCell.AchievementsProgressView()
            enableProgressView = progressView
            progressView.progress = achievement.measuredPercent
            addSubview(progressView)
            progressView.snp.makeConstraints { make in
                make.leading.equalTo(titleLabel)
                make.height.equalTo(2)
                make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            }
            
            let progressLabel = UILabel()
            progressLabel.font = Constants.Font.body()
            progressLabel.textColor = Constants.Color.Yellow
            progressLabel.text = measuredProgress
            addSubview(progressLabel)
            progressLabel.snp.makeConstraints { make in
                make.leading.equalTo(progressView.snp.trailing).offset(Constants.Size.ContentSpaceTiny)
                make.centerY.equalTo(progressView)
                make.trailing.equalTo(titleLabel)
            }
        }
        
        let seperator = SparkleSeperatorView(color: Constants.Color.BackgroundTertiary, lineColor: Constants.Color.BackgroundSecondary)
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(24)
            if let enableProgressView {
                make.top.equalTo(enableProgressView.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
            } else {
                make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceHuge)
            }
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
            make.top.equalTo(seperator.snp.bottom).offset(Constants.Size.ContentSpaceMax)
        }
        
        if shaereMode {
            let brandImageView = UIImageView(image: R.image.app_title())
            brandImageView.contentMode = .scaleAspectFit
            addSubview(brandImageView)
            brandImageView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                if let _ = enableProgressView {
                    make.top.equalTo(infoLabel.snp.bottom).offset(Constants.Size.ItemHeightUltraTiny)
                } else {
                    make.top.equalTo(infoLabel.snp.bottom).offset(Constants.Size.ItemHeightMin)
                }
                
                make.bottom.equalToSuperview()
            }
        } else {
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
                if let _ = enableProgressView {
                    make.top.equalTo(infoLabel.snp.bottom).offset(Constants.Size.ItemHeightUltraTiny)
                } else {
                    make.top.equalTo(infoLabel.snp.bottom).offset(Constants.Size.ItemHeightMin)
                }
                
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
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
