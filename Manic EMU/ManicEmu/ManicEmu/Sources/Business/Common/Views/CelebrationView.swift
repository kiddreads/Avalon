//
//  LetterView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import ProHUD

struct CelebrationView {
//    static func showFirstAnniversaryLetterIfNeed() {
//        var calendar = Calendar(identifier: .gregorian)
//        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
//        
//        // beginDate
//        var startComponents = DateComponents()
//        startComponents.year = 2026
//        startComponents.month = 4
//        startComponents.day = 3
//        startComponents.hour = 0
//        startComponents.minute = 0
//        startComponents.second = 0
//        let startDate = calendar.date(from: startComponents)!
//        
//        // endDate
//        var endComponents = DateComponents()
//        endComponents.year = 2026
//        endComponents.month = 4
//        endComponents.day = 4
//        endComponents.hour = 0
//        let endDate = calendar.date(from: endComponents)!
//        
//        let now = Date()
//        
//        if now >= startDate &&
//            now < endDate &&
//            !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShowFirstAnniversaryLetter) {
//            UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowFirstAnniversaryLetter)
//            DispatchQueue.main.asyncAfter(delay: 0.35) {
//                CheersView.makeNormalCheers(userTopWindow: true)
//            }
//            
//            Sheet.lazyPush(identifier: String(describing: CelebrationView.self)) { sheet in
//                sheet.configGamePlayingStyle(hideCompletion: nil)
//                sheet.onTappedBackground(action: { _ in })
//                
//                sheet.config.backgroundViewMask { mask in
//                    mask.backgroundColor = .black.withAlphaComponent(0.5)
//                }
//                
//                let view = UIView()
//                let containerView = RoundAndBorderView(roundCorner: (UIDevice.isPad || UIDevice.isLandscape || PlayViewController.menuInsets != nil) ? .allCorners : [.topLeft, .topRight])
//                containerView.makeBlur()
//                view.addSubview(containerView)
//                containerView.snp.makeConstraints { make in
//                    make.edges.equalToSuperview()
//                    make.height.equalTo(406)
//                }
//                view.addPanGesture { [weak view, weak sheet] gesture in
//                    guard let view = view, let sheet = sheet else { return }
//                    let point = gesture.translation(in: gesture.view)
//                    view.transform = .init(translationX: 0, y: point.y <= 0 ? 0 : point.y)
//                    if gesture.state == .recognized {
//                        let v = gesture.velocity(in: gesture.view)
//                        if (view.y > view.height*2/3 && v.y > 0) || v.y > 1200 {
//                            // 达到移除的速度
//                            sheet.pop()
//                        }
//                        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .curveEaseOut], animations: {
//                            view.transform = .identity
//                        })
//                    }
//                }
//                
//                let backgroundImageView = UIImageView(image: R.image.letter_bg())
//                containerView.addSubview(backgroundImageView)
//                backgroundImageView.snp.makeConstraints { make in
//                    make.edges.equalToSuperview()
//                }
//                
//                
//                let topView = UIImageView()
//                topView.isUserInteractionEnabled = true
//                containerView.addSubview(topView)
//                topView.snp.makeConstraints { make in
//                    make.leading.top.trailing.equalToSuperview()
//                    make.height.equalTo(Constants.Size.ItemHeightMid)
//                }
//                
//                let closeButton = SymbolButton(image: UIImage(symbol: .xmark, font: Constants.Font.body(weight: .bold)))
//                closeButton.addTapGesture { [weak sheet] gesture in
//                    sheet?.pop()
//                }
//                closeButton.enableRoundCorner = true
//                topView.addSubview(closeButton)
//                closeButton.snp.makeConstraints { make in
//                    make.centerY.equalToSuperview()
//                    make.size.equalTo(Constants.Size.IconSizeMid)
//                    make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
//                }
//                
//                let letterView = UIView()
//                letterView.alpha = 0
//                containerView.addSubview(letterView)
//                letterView.snp.makeConstraints { make in
//                    make.leading.bottom.trailing.equalToSuperview()
//                    make.top.equalTo(topView.snp.bottom)
//                }
//                
//                let avatarView = UIView()
//                avatarView.layerCornerRadius = 28
//                avatarView.backgroundColor = Constants.Color.Border
//                letterView.addSubview(avatarView)
//                avatarView.snp.makeConstraints { make in
//                    make.size.equalTo(56)
//                    make.leading.top.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
//                    
//                }
//                
//                let avatarImageView = IconView()
//                avatarImageView.layerCornerRadius = 24
//                avatarImageView.image = R.image.appicon()?.scaled(toSize: .init(48))
//                avatarView.addSubview(avatarImageView)
//                avatarImageView.snp.makeConstraints { make in
//                    make.edges.equalToSuperview().inset(4)
//                }
//                
//                let teamLabel = UILabel()
//                teamLabel.numberOfLines = 0
//                let matt = NSMutableAttributedString(string: "Manic EMU Team", attributes: [.font: Constants.Font.title(size: .s), .foregroundColor: Constants.Color.LabelPrimary])
//                matt.append(NSAttributedString(string: "\n\(Date.now.dateString(ofStyle: .medium))",
//                                               attributes: [
//                                                .font: UIFont(descriptor: UIFont.systemFont(ofSize: 12).fontDescriptor.withSymbolicTraits(.traitItalic)!, size: 12),
//                                                .foregroundColor: Constants.Color.LabelSecondary
//                                               ]))
//                let style = NSMutableParagraphStyle()
//                style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
//                style.alignment = .left
//                teamLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
//                letterView.addSubview(teamLabel)
//                teamLabel.snp.makeConstraints { make in
//                    make.centerY.equalTo(avatarView)
//                    make.leading.equalTo(avatarView.snp.trailing).offset(8)
//                    make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
//                }
//                
//                let letterPaperView = UIImageView(image: R.image.letter_paper())
//                letterView.addSubview(letterPaperView)
//                letterPaperView.snp.makeConstraints { make in
//                    make.leading.trailing.equalToSuperview().inset(24)
//                    make.top.equalTo(avatarView.snp.bottom).offset(25)
//                }
//                
//                let letterLabel = UITextView()
//                letterLabel.backgroundColor = .clear
//                letterLabel.showsVerticalScrollIndicator = false
//                letterLabel.showsHorizontalScrollIndicator = false
//                letterLabel.isEditable = false
//                letterLabel.font = Constants.Font.body(size: .l)
//                letterLabel.textColor = Constants.Color.LabelPrimary.forceStyle(.light)
//                if let lettersData = try? Data(contentsOf: Bundle.main.url(forResource: "letter", withExtension: "json")!),
//                   let letters = try? JSONSerialization.jsonObject(with: lettersData) as? [String: String] {
//                    let language = Locale.preferredLanguages.first ?? "en"
//                    letterLabel.text = letters[language] ?? letters["en"]
//                }
//                
//                letterView.addSubview(letterLabel)
//                letterLabel.snp.makeConstraints { make in
//                    make.edges.equalTo(letterPaperView).inset(24)
//                }
//                
//                let bestWishImageView = UIImageView(image: R.image.best_wish())
//                letterView.addSubview(bestWishImageView)
//                bestWishImageView.snp.makeConstraints { make in
//                    make.centerX.equalToSuperview()
//                    make.top.equalTo(letterPaperView.snp.bottom).offset(40)
//                }
//                
//                let envolopeImageView = UIImageView(image: R.image.letter_icon())
//                envolopeImageView.isUserInteractionEnabled = true
//                envolopeImageView.enableInteractive = true
//                containerView.addSubview(envolopeImageView)
//                envolopeImageView.snp.makeConstraints { make in
//                    make.center.equalToSuperview()
//                }
//                
//                let bottomLabel = UILabel()
//                bottomLabel.text = R.string.localizable.firstAnniversary()
//                bottomLabel.numberOfLines = 0
//                bottomLabel.font = Constants.Font.body(size: .l)
//                bottomLabel.textColor = Constants.Color.LabelPrimary
//                bottomLabel.textAlignment = .center
//                containerView.addSubview(bottomLabel)
//                bottomLabel.snp.makeConstraints { make in
//                    make.centerX.equalToSuperview()
//                    make.top.equalTo(envolopeImageView.snp.bottom).offset(10)
//                }
//                
//                envolopeImageView.addTapGesture { [weak containerView, weak sheet, weak view, weak envolopeImageView] gesture in
//                    guard let containerView, let sheet else { return }
//                    containerView.snp.updateConstraints { make in
//                        make.height.equalTo(sheet.config.cardMaxHeight!)
//                    }
//                    if UIDevice.isPhone, UIDevice.isLandscape {
//                        letterLabel.snp.updateConstraints { make in
//                            make.bottom.equalTo(letterPaperView).inset( UIDevice.isProMaxPhone ? 224 : 244)
//                        }
//                    }
//                    UIView.springAnimate {
//                        view?.layoutIfNeeded()
//                        backgroundImageView.alpha = 0
//                        envolopeImageView?.alpha = 0
//                        bottomLabel.alpha = 0
//                        letterView.alpha = 1
//                        topView.image = R.image.navigation_bar_bg()
//                    }
//                }
//                
//                sheet.set(customView: view).snp.makeConstraints { make in
//                    make.edges.equalToSuperview()
//                }
//            }
//        }
//    }
    
//    static func prank2026AprilFools() -> Bool {
//        let now = Date()
//        
//        let is2026FoolsDay =  now.year == 2026 && now.month == 4 && now.day == 1
//        let count = UserDefaults.standard.integer(forKey: Constants.DefaultKey.FoolsDayTrickCount)
//        
//        if is2026FoolsDay, count <= 2 {
//            UserDefaults.standard.set(count + 1, forKey: Constants.DefaultKey.FoolsDayTrickCount)
//            UserDefaults.standard.synchronize()
//            if count == 2 {
//                Sheet.lazyPush(identifier: String(describing: CelebrationView.self)) { sheet in
//                    sheet.configGamePlayingStyle(hideCompletion: nil)
//                    sheet.onTappedBackground(action: { _ in })
//                    
//                    sheet.config.backgroundViewMask { mask in
//                        mask.backgroundColor = .black.withAlphaComponent(0.5)
//                    }
//                    
//                    let view = UIView()
//                    let containerView = RoundAndBorderView(roundCorner: (UIDevice.isPad || UIDevice.isLandscape || PlayViewController.menuInsets != nil) ? .allCorners : [.topLeft, .topRight])
//                    containerView.makeBlur()
//                    view.addSubview(containerView)
//                    containerView.snp.makeConstraints { make in
//                        make.edges.equalToSuperview()
//                        make.height.equalTo(380)
//                    }
//                    view.addPanGesture { [weak view, weak sheet] gesture in
//                        guard let view = view, let sheet = sheet else { return }
//                        let point = gesture.translation(in: gesture.view)
//                        view.transform = .init(translationX: 0, y: point.y <= 0 ? 0 : point.y)
//                        if gesture.state == .recognized {
//                            let v = gesture.velocity(in: gesture.view)
//                            if (view.y > view.height*2/3 && v.y > 0) || v.y > 1200 {
//                                // 达到移除的速度
//                                sheet.pop()
//                            }
//                            UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .curveEaseOut], animations: {
//                                view.transform = .identity
//                            })
//                        }
//                    }
//                    
//                    let topView = UIImageView(image: R.image.navigation_bar_bg())
//                    topView.isUserInteractionEnabled = true
//                    containerView.addSubview(topView)
//                    topView.snp.makeConstraints { make in
//                        make.leading.top.trailing.equalToSuperview()
//                        make.height.equalTo(Constants.Size.ItemHeightMid)
//                    }
//                    
//                    let closeButton = SymbolButton(image: UIImage(symbol: .xmark, font: Constants.Font.body(weight: .bold)))
//                    closeButton.addTapGesture { [weak sheet] gesture in
//                        sheet?.pop()
//                    }
//                    closeButton.enableRoundCorner = true
//                    topView.addSubview(closeButton)
//                    closeButton.snp.makeConstraints { make in
//                        make.centerY.equalToSuperview()
//                        make.size.equalTo(Constants.Size.IconSizeMid)
//                        make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
//                    }
//                    
//                    let label = UILabel()
//                    label.textAlignment = .center
//                    label.text = R.string.localizable.apirlFoolsDayTitle()
//                    label.textColor = Constants.Color.LabelPrimary
//                    label.font = Constants.Font.title(size: .s)
//                    containerView.addSubview(label)
//                    label.snp.makeConstraints { make in
//                        make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
//                        make.top.equalTo(topView.snp.bottom).offset(Constants.Size.ContentSpaceMid)
//                    }
//                    
//                    let imageView = UIImageView(image: R.image.surprise_box())
//                    imageView.isUserInteractionEnabled = true
//                    imageView.enableInteractive = true
//                    containerView.addSubview(imageView)
//                    imageView.snp.makeConstraints { make in
//                        make.top.equalTo(label.snp.bottom).offset(Constants.Size.ContentSpaceMid)
//                        make.centerX.equalToSuperview()
//                    }
//                    imageView.addTapGesture { [weak sheet] gesture in
//                        guard let sheet else { return }
//                        CheersView.makeNormalCheers()
//                        sheet.pop()
//                    }
//                    
//                    let bottomLabel = UILabel()
//                    bottomLabel.textAlignment = .center
//                    bottomLabel.numberOfLines = 0
//                    bottomLabel.text = R.string.localizable.apirlFoolsDayDetail()
//                    bottomLabel.textColor = Constants.Color.LabelPrimary
//                    bottomLabel.font = Constants.Font.body(size: .l)
//                    containerView.addSubview(bottomLabel)
//                    bottomLabel.snp.makeConstraints { make in
//                        make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
//                        make.top.equalTo(imageView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
//                    }
//                    
//                    sheet.set(customView: view).snp.makeConstraints { make in
//                        make.edges.equalToSuperview()
//                    }
//                }
//            }
//            return true
//        }
//        return false
//    }
}
