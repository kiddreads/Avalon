//
//  CheevosProgressView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/7.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class CheevosProgressDetailView: UIView {
    let coverImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layerCornerRadius = 4
        return view
    }()
    
    let titleLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.caption(size: .l)
        view.textColor = Constants.Color.LabelPrimary
        return view
    }()
    
    private let progressLabel: UILabel = {
        let view = UILabel()
        view.font = Constants.Font.caption(size: .s)
        view.textColor = Constants.Color.Yellow
        return view
    }()
    
    let progressView: RetroAchievementsListCell.AchievementsProgressView = {
        let view = RetroAchievementsListCell.AchievementsProgressView()
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        alpha = 0.75
        
        addSubview(coverImageView)
        coverImageView.snp.makeConstraints { make in
            make.width.equalTo(28)
            make.top.bottom.leading.equalToSuperview().inset(2)
        }
        
        addSubview(titleLabel)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.top.equalToSuperview().offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.lessThanOrEqualToSuperview()
        }
        
        addSubview(progressView)
        progressView.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.height.equalTo(2)
            make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceTiny)
        }
        
        addSubview(progressLabel)
        progressLabel.snp.makeConstraints { make in
            make.leading.equalTo(progressView.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.centerY.equalTo(progressView)
            make.trailing.equalToSuperview()
        }
        
        // 给最小宽度避免系统加 width == 0 的临时约束
        self.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(60)
        }
    }
    
    func updateProgress(_ progress: CheevosProgress) {
        coverImageView.kf.setImage(
            with: URL(string: progress.unlockedBadgeUrl),
            placeholder: UIImage.placeHolder(preferenceSize: .init(32))
        )
        titleLabel.text = (progress.title ?? "") + " (\(progress.points) points)"
        progressView.progress = progress.measuredPercent
        progressLabel.text = progress.measuredProgress ?? ""
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Scroll Container
// MARK: - 容器
class CheevosProgressView: UIView {
    
    private let stackView = UIStackView()
    private var progressViewDict: [Int: CheevosProgressDetailView] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = Constants.Color.BackgroundPrimary.withAlphaComponent(0.4)
        
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually   // 平分宽度
        stackView.spacing = Constants.Size.ContentSpaceMin
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Public API
    
    func updateProgress(_ progress: CheevosProgress) {
        if isHidden { isHidden = false }
        
        if let view = progressViewDict[progress._id] {
            view.updateProgress(progress)
        } else {
            let view = CheevosProgressDetailView()
            view.updateProgress(progress)
            configureCompressionResistance(for: view)
            stackView.addArrangedSubview(view)
            progressViewDict[progress._id] = view
        }
        updateLayoutForSingleView()
    }
    
    func removeProgress(id: Int) {
        if let view = progressViewDict[id] {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
            progressViewDict.removeValue(forKey: id)
        }
        if progressViewDict.isEmpty {
            isHidden = true
        }
        updateLayoutForSingleView()
    }
    
    // MARK: - Layout
    
    private func updateLayoutForSingleView() {
        if stackView.arrangedSubviews.count == 1 {
            stackView.distribution = .fill
            stackView.alignment = .center
            stackView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.centerX.equalToSuperview()
                make.width.equalTo(285)
            }
        } else {
            stackView.distribution = .fillEqually
            stackView.alignment = .fill
            stackView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    private func configureCompressionResistance(for view: CheevosProgressDetailView) {
        // coverImageView 保证最优先显示
        view.coverImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.coverImageView.setContentHuggingPriority(.required, for: .horizontal)
        
        // titleLabel 允许压缩，字体可缩小
        view.titleLabel.adjustsFontSizeToFitWidth = true
        view.titleLabel.minimumScaleFactor = 0.6
        view.titleLabel.lineBreakMode = .byTruncatingTail
        view.titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // progressView 次要，可以被压缩
        view.progressView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
