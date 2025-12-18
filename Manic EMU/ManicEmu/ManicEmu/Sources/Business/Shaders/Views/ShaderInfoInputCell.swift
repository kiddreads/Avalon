//
//  ShaderInfoInputCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ShaderInfoInputCell: UICollectionViewCell {
    var shouldGoNext: (()->Void)? = nil
    lazy var editTextField: UITextField = {
        let view = UITextField()
        view.textColor = Constants.Color.LabelPrimary
        view.font = Constants.Font.body(size: .l)
        view.clearButtonMode = .whileEditing
        view.onReturnKeyPress { [weak self] in
            guard let self = self else { return }
            self.shouldGoNext?()
        }
        view.attributedPlaceholder = NSAttributedString(string: R.string.localizable.cheatCodeNamePlaceHolder(), attributes: [.font: Constants.Font.body(size: .l), .foregroundColor: Constants.Color.LabelTertiary])
        view .returnKeyType = .done
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enableInteractive = true
        delayInteractiveTouchEnd = true
        
        let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: Constants.Size.CornerRadiusMid)
        textFieldContainer.backgroundColor = Constants.Color.InputBackground
        addSubview(textFieldContainer)
        textFieldContainer.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        
        textFieldContainer.addSubview(editTextField)
        editTextField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
