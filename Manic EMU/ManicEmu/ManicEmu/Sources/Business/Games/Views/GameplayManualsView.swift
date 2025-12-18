//
//  GameplayManualsView.swift
//  ManicEmu
//
//  Created by Aoshuang on 2025/10/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
import PDFKit
import ProHUD

class GameplayManualsView: UIView {
    var didTapClose: (()->Void)? = nil
    private var game: Game
    
    private var navigationBlurView: UIView = {
        let view = UIView()
        view.makeBlur()
        return view
    }()
    
    private var pdfView: PDFView = {
        let view = PDFView()
        view.backgroundColor = Constants.Color.Background
        view.autoScales = true
        return view
    }()
    
    private lazy var closeButton: SymbolButton = {
        let view = SymbolButton(image: UIImage(symbol: .xmark, font: Constants.Font.body(weight: .bold)), enableGlass: true)
        view.enableRoundCorner = true
        view.addTapGesture { [weak self] gesture in
            guard let self = self else { return }
            self.didTapClose?()
            // 记录当前阅读的页数
            if let currentPage = pdfView.currentPage, let document = pdfView.document {
                let pageIndex = document.index(for: currentPage)
                game.updateExtra(key: ExtraKey.manualPage.rawValue, value: pageIndex)
            }
        }
        return view
    }()
    
    init(game: Game) {
        self.game = game
        super.init(frame: .zero)
        backgroundColor = Constants.Color.Background
        
        addSubview(navigationBlurView)
        navigationBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        navigationBlurView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMax)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.Size.ItemHeightUltraTiny)
        }
        
        addSubview(pdfView)
        pdfView.snp.makeConstraints { make in
            make.top.equalTo(navigationBlurView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-Constants.Size.ContentInsetBottom)
        }
        
        if let manualsPath = game.manualsPath {
            pdfView.document = PDFDocument(url: URL(fileURLWithPath: manualsPath))
        }
        
        // 加载到上一次读取的位置
        if let lastReadPage = game.getExtraInt(key: ExtraKey.manualPage.rawValue),
           let document = pdfView.document,
           lastReadPage < document.pageCount,
           let page = document.page(at: lastReadPage) {
            DispatchQueue.main.asyncAfter(delay: 1, execute: { [weak self] in
                guard let self else { return }
                self.pdfView.go(to: page)
            })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GameplayManualsView {
    static var isShow: Bool {
        Sheet.find(identifier: String(describing: GameplayManualsView.self)).count > 0 ? true : false
    }
    
    static func show(game: Game, hideCompletion: (()->Void)? = nil) {
        Sheet { sheet in
            sheet.configGamePlayingStyle(hideCompletion: hideCompletion)
            
            let view = UIView()
            let containerView = RoundAndBorderView(roundCorner: (UIDevice.isPad || UIDevice.isLandscape || PlayViewController.menuInsets != nil) ? .allCorners : [.topLeft, .topRight])
            containerView.backgroundColor = Constants.Color.Background
            view.addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                if let maxHeight = sheet.config.cardMaxHeight {
                    make.height.equalTo(maxHeight)
                }
            }
            
            let manualView = GameplayManualsView(game: game)
            manualView.didTapClose = { [weak sheet] in
                sheet?.pop()
            }
            containerView.addSubview(manualView)
            manualView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            sheet.set(customView: view).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
}
