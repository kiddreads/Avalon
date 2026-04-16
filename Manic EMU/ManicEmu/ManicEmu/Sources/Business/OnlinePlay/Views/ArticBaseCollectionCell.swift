//
//  ArticBaseCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ArticBaseCollectionCell: UICollectionViewCell {
    
    private lazy var descTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isUserInteractionEnabled = true
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0

        let text = R.string.localizable.articBaseDesc("Artic Setup Tool")
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: Constants.Font.body(size: .s),
                .foregroundColor: Constants.Color.LabelSecondary
            ]
        )

        if let range = text.range(of: "Artic Setup Tool") {
            let nsRange = NSRange(range, in: text)

            attr.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: URL(string: "https://github.com/azahar-emu/ArticSetupTool")!
            ], range: nsRange)
        }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = Constants.Size.ContentSpaceUltraTiny
        attr.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attr.length))

        tv.attributedText = attr

        tv.linkTextAttributes = [
            .foregroundColor: Constants.Color.Main,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        return tv
    }()
    
    private lazy var ipAddressTitleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = Constants.Color.LabelSecondary
        textField.font = Constants.Font.body(size: .s)
        textField.placeholder = "192.168.0.1:5543"
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.keyboardType = .numbersAndPunctuation
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            if let _ = self.ipAddressTitleTextField.text?.parseIPv4String() {
                self.button.titleLabel.textColor = Constants.Color.LabelPrimary
                self.button.backgroundColor = Constants.Color.Main
                self.button.isUserInteractionEnabled = true
                self.didIPAddressChange?(self.ipAddressTitleTextField.text!)
            } else {
                self.button.titleLabel.textColor = Constants.Color.LabelSecondary
                self.button.backgroundColor = Constants.Color.BackgroundSecondary
                self.button.isUserInteractionEnabled = false
                UIView.makeToast(message: R.string.localizable.badIpAddress())
            }
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
            make.trailing.equalTo(titleLabel.snp.trailing).inset(Constants.Size.ContentSpaceMin)
            make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMin)
            make.centerY.equalToSuperview()
        }
        
        return view
    }()
    
    private lazy var button: SymbolButton = {
        let view = SymbolButton(image: nil, title: R.string.localizable.startTransfer(), titleFont: Constants.Font.body(size: .m), titleColor: Constants.Color.LabelSecondary, titleAlignment: .right, horizontalContian: true)
        view.backgroundColor = Constants.Color.BackgroundSecondary
        view.isUserInteractionEnabled = false
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            if let ipAddress = self.ipAddressTitleTextField.text?.parseIPv4String() {
                UIView.makeAlert(title: R.string.localizable.headsUp(),
                                 detail: R.string.localizable.articBaseHeadsUp(),
                                 confirmTitle: R.string.localizable.confirmTitle(), confirmAction: {
                    let realm = Database.realm
                    let gameHash = Constants.Strings.AzaharArticBaseGameID
                    if let game = realm.object(ofType: Game.self, forPrimaryKey: gameHash) {
                        try? realm.write {
                            realm.delete(game)
                        }
                    }
                    
                    //Choose 3DS Region
                    ArticBaseRegionChooseView.show { region in
                        if let region {
                            self.didRegionChange?(region)
                            let regionOptions = Constants.Strings.ThreeDSConsoleLanguage.filter({ $0 != "Automatic" })
                            var regionValue = regionOptions.first!
                            if let index = Constants.Strings.ThreeDSHomeMenuRegions.firstIndex(where: { $0 == region }), index < regionOptions.count {
                                regionValue = regionOptions[index]
                            }
                            LibretroCore.sharedInstance().updateConfig(LibretroCore.Cores.Azahar.name, configs: ["citra_region_value": regionValue], reload: false)
                            let game = Game()
                            game.id = gameHash
                            game.name = ipAddress.ip + ":" + "\(ipAddress.port)"
                            game.fileExtension = "articbase"
                            game.gameType = ._3ds
                            game.importDate = Date()
                            game.defaultCore = 1
                            try? realm.write { realm.add(game) }
                            PlayViewController.startGame(game: game)
                        }
                    }
                })
            } else {
                UIView.makeToast(message: R.string.localizable.badIpAddress())
            }
        }
        return view
    }()
    
    var didIPAddressChange: ((_ ipAddress: String)->Void)? = nil
    var didRegionChange: ((_ region: String)->Void)? = nil
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = Constants.Size.CornerRadiusMax
        containerView.backgroundColor = Constants.Color.BackgroundPrimary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(descTextView)
        descTextView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
        }
        
        containerView.addSubview(ipAddressInputView)
        ipAddressInputView.snp.makeConstraints { make in
            make.top.equalTo(descTextView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.height.equalTo(Constants.Size.ItemHeightMax)
        }
        
        containerView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
            make.top.equalTo(ipAddressInputView.snp.bottom).offset(Constants.Size.ContentSpaceMax)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(config: PretendoNetworkingConfig) {
        ipAddressTitleTextField.text = config.articBaseIpAddress
        if let _ = config.articBaseIpAddress?.parseIPv4String() {
            button.titleLabel.textColor = Constants.Color.LabelPrimary
            button.backgroundColor = Constants.Color.Main
            button.isUserInteractionEnabled = true
        } else {
            button.titleLabel.textColor = Constants.Color.LabelSecondary
            button.backgroundColor = Constants.Color.BackgroundSecondary
            button.isUserInteractionEnabled = false
        }
    }
}
