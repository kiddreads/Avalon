//
//  MembershipCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class MembershipCollectionViewCell: UICollectionViewCell {
    
    private let backgroundImageView = UIImageView()
    
    private lazy var animatedGradientView: AnimatedGradientView = {
        let view = AnimatedGradientView(notifiedUpadate: true, alphaComponent: 0.9)
        return view
    }()
    
    private var membershipInfoView = MembershipInfoView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = Constants.Size.CornerRadiusMax
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceTiny)
        }
        
        containerView.addSubview(backgroundImageView)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        backgroundImageView.image = R.image.game_cover_bg()?.scaled(toWidth: 366)?.cropped(to: CGRect(origin: .zero, size: CGSize(width: 366, height: 130)))
        
        containerView.addSubview(animatedGradientView)
        animatedGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(membershipInfoView)
        membershipInfoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
