//
//  PSPNetworkingConfigOnlineView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingConfigOnlineView: UIView {
    private lazy var ipAddressTitleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelSecondary
        textField.font = Constants.Font.caption(size: .l)
        textField.placeholder = "socom.cc"
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.didConnectedHostChange?(self.ipAddressTitleTextField.text)
        }
        return textField
    }()
    
    private lazy var ipAddressInputView: UIView = {
        let view = UIView()
        view.layerCornerRadius = Constants.Size.CornerRadiusMid
        view.backgroundColor = Constants.Color.Background
        
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.layerCornerRadius = 6
        iconView.image = UIImage(symbol: .globe, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        iconView.backgroundColor = Constants.Color.Red
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.serverAddress()
        titleLabel.textColor = Constants.Color.LabelPrimary
        titleLabel.font = Constants.Font.body(size: .l, weight: .semibold)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        view.addSubview(ipAddressTitleTextField)
        ipAddressTitleTextField.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
        }
        
        let chevronIconView: UIImageView = {
            let view = UIImageView()
            view.image = UIImage(symbol: .ellipsisCircle, font: Constants.Font.body(size: .l, weight: .semibold), color: Constants.Color.BackgroundSecondary)
            return view
        }()
        
        var moreContextMenuButton: ContextMenuButton = {
            var servers = ["socom.cc", "psp.gameplayer.club", "myneighborsushicat.com", R.string.localizable.custom()]
            var actions = [UIMenuElement]()
            for (index, server) in servers.enumerated() {
                actions.append((UIAction(title: server) { [weak self] _ in
                    guard let self else { return }
                    if index == 3 {
                        self.ipAddressTitleTextField.becomeFirstResponder()
                    } else {
                        self.ipAddressTitleTextField.resignFirstResponder()
                        self.ipAddressTitleTextField.text = server
                        self.didConnectedHostChange?(server)
                    }
                }))
            }
            let view = ContextMenuButton(image: nil, menu: UIMenu(children: actions))
            return view
        }()
        
        view.addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(ipAddressTitleTextField.snp.trailing).offset(Constants.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(CGSize(width: 24, height: 24))
        }
        
        view.addSubview(moreContextMenuButton)
        moreContextMenuButton.snp.makeConstraints { make in
            make.leading.equalTo(chevronIconView)
            make.top.bottom.trailing.equalToSuperview()
        }
        
        return view
    }()
    
    var didConnectedHostChange: ((String?)->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(ipAddressInputView)
        ipAddressInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
    }
    
    func setData(config: PSPNetworkingConfig) {
        guard config.type == .online else { return }
        ipAddressTitleTextField.text = config.connectedHost
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
