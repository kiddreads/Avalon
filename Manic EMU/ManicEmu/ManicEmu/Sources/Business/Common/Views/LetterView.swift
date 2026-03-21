//
//  LetterView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import ProHUD

struct LetterView {
    static func showFirstAnniversaryLetterIfNeed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        
        // beginDate
        var startComponents = DateComponents()
        startComponents.year = 2026
        startComponents.month = 4
        startComponents.day = 3
        startComponents.hour = 0
        startComponents.minute = 0
        startComponents.second = 0
        let startDate = calendar.date(from: startComponents)!
        
        // endDate
        var endComponents = DateComponents()
        endComponents.year = 2026
        endComponents.month = 4
        endComponents.day = 4
        endComponents.hour = 0
        let endDate = calendar.date(from: endComponents)!
        
        let now = Date()
        
        if now >= startDate &&
            now < endDate &&
            !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShowFreeJ2meAlert) {
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                CheersView.makeNormalCheers(userTopWindow: true)
            }
            
            Sheet.lazyPush(identifier: String(describing: LetterView.self)) { sheet in
                sheet.configGamePlayingStyle(hideCompletion: nil)
                
                sheet.config.backgroundViewMask { mask in
                    mask.backgroundColor = .black.withAlphaComponent(0.5)
                }
                
                let view = UIView()
                let containerView = RoundAndBorderView(roundCorner: (UIDevice.isPad || UIDevice.isLandscape || PlayViewController.menuInsets != nil) ? .allCorners : [.topLeft, .topRight])
                containerView.makeBlur()
                view.addSubview(containerView)
                containerView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                    make.height.equalTo(Constants.Size.WindowHeight/2)
                }
                view.addPanGesture { [weak view, weak sheet] gesture in
                    guard let view = view, let sheet = sheet else { return }
                    let point = gesture.translation(in: gesture.view)
                    view.transform = .init(translationX: 0, y: point.y <= 0 ? 0 : point.y)
                    if gesture.state == .recognized {
                        let v = gesture.velocity(in: gesture.view)
                        if (view.y > view.height*2/3 && v.y > 0) || v.y > 1200 {
                            // 达到移除的速度
                            sheet.pop()
                        }
                        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .curveEaseOut], animations: {
                            view.transform = .identity
                        })
                    }
                }
                
                let topView = UIView()
                containerView.addSubview(topView)
                topView.snp.makeConstraints { make in
                    make.leading.top.trailing.equalToSuperview()
                    make.height.equalTo(Constants.Size.ItemHeightMid)
                }
                
                let closeButton = SymbolButton(image: UIImage(symbol: .xmark, font: Constants.Font.body(weight: .bold)))
                closeButton.addTapGesture { [weak sheet] gesture in
                    sheet?.pop()
                }
                closeButton.enableRoundCorner = true
                topView.addSubview(closeButton)
                closeButton.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.size.equalTo(Constants.Size.IconSizeMid)
                    make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
                }
                
                let envolopeImageView = UIImageView(image: R.image.appicon())
                envolopeImageView.isUserInteractionEnabled = true
                envolopeImageView.addTapGesture { [weak containerView, weak sheet, weak view] gesture in
                    guard let containerView, let sheet else { return }
                    containerView.snp.updateConstraints { make in
                        make.height.equalTo(sheet.config.cardMaxHeight!)
                    }
                    UIView.springAnimate {
                        view?.layoutIfNeeded()
                    }
                }
                envolopeImageView.enableInteractive = true
                containerView.addSubview(envolopeImageView)
                envolopeImageView.snp.makeConstraints { make in
                    make.size.equalTo(100)
                    make.center.equalToSuperview()
                }
                
                sheet.set(customView: view).snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
            }
        }
    }
}
