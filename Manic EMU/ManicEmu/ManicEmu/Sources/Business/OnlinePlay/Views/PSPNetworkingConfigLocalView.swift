//
//  PSPNetworkingConfigLocalView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingConfigLocalView: UIView {
    private var asHost: Bool = false
    
    private let setAsHostSelectImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layerCornerRadius = Constants.Size.IconSizeMin.height/2
        view.layer.shadowColor = Constants.Color.Shadow.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 2
        view.image = UIImage(symbol: .circle,
                             size: Constants.Size.IconSizeMin.height,
                             weight: .regular,
                             color: Constants.Color.LabelTertiary)
        return view
    }()
    
    private let setAsHostTitleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(string: R.string.localizable.setAsHost(), attributes: [.foregroundColor: Constants.Color.LabelPrimary, .font: Constants.Font.body(size: .l, weight: .semibold)])
        titleLabel.numberOfLines = 2
        return titleLabel
    }()
    
    private lazy var setAsHostView: UIView = {
        let view = UIView()
        view.layerCornerRadius = Constants.Size.CornerRadiusMid
        view.backgroundColor = Constants.Color.Background
        
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.layerCornerRadius = 6
        iconView.image = UIImage(symbol: .person2Wave2Fill, font: Constants.Font.body(size: .s, weight: .medium), color: Constants.Color.LabelPrimary.forceStyle(.dark))
        iconView.backgroundColor = Constants.Color.Red
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMid)
            make.centerY.equalToSuperview()
        }
        
        view.addSubview(setAsHostTitleLabel)
        setAsHostTitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.Size.ContentSpaceMin)
        }
        
        view.addSubview(setAsHostSelectImageView)
        setAsHostSelectImageView.snp.makeConstraints { make in
            make.leading.equalTo(setAsHostTitleLabel.snp.trailing).offset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(Constants.Size.IconSizeMin)
        }
        
        let button = UIButton(type: .custom)
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        button.onTap { [weak self] in
            guard let self else { return }
            //点击设置为主机
            self.asHost = !self.asHost
            self.didAsHostChange?(self.asHost)
        }
        
        return view
    }()
    
    private lazy var ipAddressTitleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelSecondary
        textField.font = Constants.Font.caption(size: .l)
        textField.placeholder = "192.168.1.1"
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
            self.didConnectedIPChange?(self.ipAddressTitleTextField.text)
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
        titleLabel.text = R.string.localizable.ipAddress()
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
        
        var chevronIconView: UIImageView = {
            let view = UIImageView()
            view.image = UIImage(symbol: .chevronRight, font: Constants.Font.caption(size: .l, weight: .bold), color: Constants.Color.BackgroundSecondary)
            if Locale.isRTLLanguage {
                view.transform = CGAffineTransform(scaleX: -1, y: 1)
            }
            return view
        }()
        
        view.addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(ipAddressTitleTextField.snp.trailing).offset(Constants.Size.ContentSpaceUltraTiny)
            make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
            make.size.equalTo(CGSize(width: 10, height: 14))
        }
        
        return view
    }()
    
    private lazy var portOffsetView: AddTriggerButtonStyleCell.SliderView = {
        let view = AddTriggerButtonStyleCell.SliderView(title: R.string.localizable.portOffset(), valueSufix: nil, minimumValue: 1000, maximumValue: 65000, numberOfDecimalPlaces: -1)
        view.didChangeEnd = { [weak self ] port in
            guard let self else { return }
            self.didPortChange?(Int32(port))
        }
        return view
    }()
    
    private let hostIPLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .s)
        label.textColor = Constants.Color.LabelSecondary
        label.text = R.string.localizable.hostAddress()
        return label
    }()
    
    private let serviceFoundLabel: UILabel = {
        let label = UILabel()
        label.font = Constants.Font.body(size: .s)
        label.textColor = Constants.Color.LabelSecondary
        label.text = R.string.localizable.serviceFound()
        return label
    }()
    
    private let loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.color = Constants.Color.LabelSecondary
        view.startAnimating()
        return view
    }()
    
    private var serviceListView: UIView = {
        let view = UIView()
        return view
    }()
    
    var didAsHostChange: ((Bool)->Void)? = nil
    var didPortChange: ((Int32)->Void)? = nil
    var didConnectedIPChange: ((String?)->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(setAsHostView)
        setAsHostView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalToSuperview()
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        portOffsetView.isHidden = true
        addSubview(portOffsetView)
        portOffsetView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(setAsHostView.snp.bottom).offset(-Constants.Size.ItemHeightMax)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        addSubview(hostIPLabel)
        hostIPLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceHuge)
            make.top.equalTo(portOffsetView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
        }
        
        addSubview(ipAddressInputView)
        ipAddressInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(hostIPLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        addSubview(serviceFoundLabel)
        serviceFoundLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceHuge)
            make.top.equalTo(ipAddressInputView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
        }
        
        addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.size.equalTo(Constants.Size.IconSizeMin)
            make.leading.equalTo(serviceFoundLabel.snp.trailing).offset(Constants.Size.ContentSpaceTiny)
            make.centerY.equalTo(serviceFoundLabel)
        }
        
        addSubview(serviceListView)
        serviceListView.snp.makeConstraints { make in
            make.top.equalTo(serviceFoundLabel.snp.bottom).offset(Constants.Size.ContentSpaceMin)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class ServiceItemView: UIView {
        var titleLabel: UILabel = {
            let title = UILabel()
            title.textColor = Constants.Color.LabelPrimary
            title.font = Constants.Font.body(size: .l)
            return title
        }()
        
        var button: UIButton = {
            let button = UIButton(type: .custom)
            button.titleLabel?.font = Constants.Font.body(size: .m, weight: .semibold)
            button.setTitle( R.string.localizable.connect(), for: .normal)
            button.setTitle( R.string.localizable.connected(), for: .selected)
            button.setTitleColor(Constants.Color.Red, for: .normal)
            button.setTitleColor(Constants.Color.Green, for: .selected)
            return button
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            layerCornerRadius = Constants.Size.CornerRadiusMid
            backgroundColor = Constants.Color.Background
            
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.centerY.equalToSuperview()
            }
            
            addSubview(button)
            button.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
                make.centerY.equalToSuperview()
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private func updateSelectImageView() {
        if asHost {
            setAsHostSelectImageView.image = UIImage(symbol: .checkmarkCircleFill,
                                                     size: Constants.Size.IconSizeMin.height,
                                                     weight: .bold,
                                                     colors: [Constants.Color.LabelPrimary.forceStyle(.dark), Constants.Color.Main])
        } else {
            setAsHostSelectImageView.image = UIImage(symbol: .circle,
                                                     size: Constants.Size.IconSizeMin.height,
                                                     weight: .regular,
                                                     color: Constants.Color.LabelTertiary)
        }
        
    }
    
    func setData(config: PSPNetworkingConfig) {
        guard config.type == .local else { return }
        asHost = config.asHost
        
        updateSelectImageView()
        
        if asHost {
            let matt = NSMutableAttributedString(string: R.string.localizable.setAsHost(), attributes: [.font: Constants.Font.body(size: .l), .foregroundColor: Constants.Color.LabelPrimary])
            if let ipAddress = BonjourKit.shared.currentIPAddress {
                matt.append(NSAttributedString(string: "\n\(ipAddress)", attributes: [.font: Constants.Font.body(size: .s), .foregroundColor: Constants.Color.LabelSecondary]))
                let style = NSMutableParagraphStyle()
                style.lineSpacing = Constants.Size.ContentSpaceUltraTiny/2
                style.alignment = .left
                setAsHostTitleLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            } else {
                setAsHostTitleLabel.attributedText = matt
            }
            
            portOffsetView.value = Float(config.asHostPort)
            portOffsetView.isHidden = false
            portOffsetView.snp.updateConstraints { make in
                make.top.equalTo(setAsHostView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            }
            
            hostIPLabel.isHidden = true
            ipAddressInputView.isHidden = true
            
            serviceFoundLabel.isHidden = true
            loadingView.isHidden = true
            serviceListView.isHidden = true
            
        } else {
            setAsHostTitleLabel.attributedText = NSMutableAttributedString(string: R.string.localizable.setAsHost(), attributes: [.font: Constants.Font.body(size: .l), .foregroundColor: Constants.Color.LabelPrimary])
            
            portOffsetView.isHidden = true
            portOffsetView.snp.updateConstraints { make in
                make.top.equalTo(setAsHostView.snp.bottom).offset(-Constants.Size.ItemHeightMax)
            }
            
            hostIPLabel.isHidden = false
            ipAddressInputView.isHidden = false
            ipAddressTitleTextField.text = config.connectedLocalIP
            
            serviceFoundLabel.isHidden = false
            loadingView.isHidden = false
            loadingView.startAnimating()
            serviceListView.isHidden = false
            
            serviceListView.subviews.forEach({ $0.removeFromSuperview() })
            for (index, service) in config.hostList.enumerated() {
                let itemView = ServiceItemView()
                itemView.titleLabel.text = service
                let isConnected = config.connectedLocalIP == service
                itemView.button.isSelected = isConnected
                itemView.button.onTap { [weak self, weak itemView] in
                    guard let self, !isConnected else { return }
                    self.serviceListView.subviews.forEach {
                        ($0 as? ServiceItemView)?.button.isSelected = false
                    }
                    self.ipAddressTitleTextField.text = service
                    itemView?.button.isSelected = true
                    self.didConnectedIPChange?(service)
                }
                serviceListView.addSubview(itemView)
                itemView.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    if index == 0 {
                        make.top.equalToSuperview()
                    } else {
                        make.top.equalTo(serviceListView.subviews[index-1].snp.bottom).offset(Constants.Size.ContentSpaceMax)
                    }
                    make.height.equalTo(Constants.Size.ItemHeightMid)
                    if index == config.hostList.count - 1 {
                        make.bottom.equalToSuperview()
                    }
                }
            }
        }
    }
}
