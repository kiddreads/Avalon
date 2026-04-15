//
//  GlobalCoreSwitchViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class GlobalCoreSwitchViewController: BaseViewController {
    
    private lazy var globalCoreSwitchView: GlobalCoreSwitchView = {
        let view = GlobalCoreSwitchView(showClose: showClose)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        return view
    }()
    
    private var showClose: Bool
    
    init(showClose: Bool = true) {
        self.showClose = showClose
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(globalCoreSwitchView)
        globalCoreSwitchView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
