//
//  ColorPickerViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ColorPickerViewController: BaseViewController {
    
    private lazy var colorPickerView: ColorPickerView = {
        let view = ColorPickerView(color: self.themeColor)
        view.didTapClose = {[weak self] in
            self?.dismiss(animated: true)
        }
        view.didSaveAction = self.completion
        return view
    }()
    
    private var completion: ((ThemeColor)->Void)? = nil
    private var themeColor: ThemeColor? = nil
    
    init(themeColor: ThemeColor? = nil, completion: ((ThemeColor)->Void)? = nil) {
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
        self.completion = completion
        self.themeColor = themeColor
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(colorPickerView)
        colorPickerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 禁用系统的下滑关闭手势
        if let presentationController = self.presentationController,
           let gestureRecognizers = presentationController.presentedView?.gestureRecognizers {
            for gesture in gestureRecognizers {
                if let panGesture = gesture as? UIPanGestureRecognizer {
                    panGesture.isEnabled = false
                }
            }
        }
    }
}
