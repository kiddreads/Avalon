//
//  LeaderboardView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/1.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class LeaderboardView: UIScrollView {
    
    private let stackView = UIStackView()
    private var labelDict: [Int: UILabel] = [:]
    
    private var stackLeadingConstraint: Constraint?
    private var stackTrailingConstraint: Constraint?
    private var stackCenterXConstraint: Constraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
        bounces = false
        isScrollEnabled = true
        
        backgroundColor = Constants.Color.BackgroundPrimary.withAlphaComponent(0.4)
        layerCornerRadius = Constants.Size.CornerRadiusMid
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Constants.Size.ContentSpaceMin
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.height.equalToSuperview() // 固定高度
            stackLeadingConstraint = make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMax).constraint
            stackTrailingConstraint = make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax).constraint
        }
    }
    
    // MARK: - Public API
    
    func updateLeaderboard(id: Int, content: String) {
        if self.isHidden {
            self.isHidden = false
        }
        let matt = NSMutableAttributedString(string: "\(R.string.localizable.leaderboard())-\(id)", attributes: [.font: Constants.Font.caption(size: .s), .foregroundColor: Constants.Color.LabelSecondary])
        matt.append(NSAttributedString(string: "\n\(content)", attributes: [.font: Constants.Font.caption(size: .l), .foregroundColor: Constants.Color.LabelPrimary]))
        if let label = labelDict[id] {
            label.attributedText = matt
        } else {
            let label = UILabel()
            label.numberOfLines = 2
            label.attributedText = matt
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            stackView.addArrangedSubview(label)
            labelDict[id] = label
        }
        setNeedsLayout()
        layoutIfNeeded()
        updateLayout()
    }
    
    func removeLeaderboard(id: Int) {
        if let label = labelDict[id] {
            stackView.removeArrangedSubview(label)
            label.removeFromSuperview()
            labelDict.removeValue(forKey: id)
        }
        if labelDict.isEmpty {
            self.isHidden = true
        }
        setNeedsLayout()
        layoutIfNeeded()
        updateLayout()
    }
    
    // MARK: - Layout Update
    
    private func updateLayout() {
        // 计算 stackView 的总宽度
        let totalWidth = stackView.arrangedSubviews.reduce(0) { $0 + $1.intrinsicContentSize.width } + CGFloat(max(0, stackView.arrangedSubviews.count - 1)) * stackView.spacing
        let scrollWidth = bounds.width - Constants.Size.ContentSpaceMax*2
        
        if totalWidth <= scrollWidth {
            // 居中显示，不可滚动
            isScrollEnabled = false
            stackLeadingConstraint?.deactivate()
            stackTrailingConstraint?.deactivate()
            
            if stackCenterXConstraint == nil {
                stackView.snp.makeConstraints { make in
                    stackCenterXConstraint = make.centerX.equalToSuperview().constraint
                }
            }
            stackCenterXConstraint?.activate()
            
        } else {
            // 左对齐，可滚动
            isScrollEnabled = true
            stackCenterXConstraint?.deactivate()
            
            stackLeadingConstraint?.activate()
            stackTrailingConstraint?.activate()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
}
