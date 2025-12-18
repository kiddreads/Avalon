//
//  ThreeDSKeyboardView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ProHUD
import IQKeyboardManagerSwift

struct ThreeDSKeyboardView {
    static func showForCitra(hintText: String?,
                             keyboardType: ThreeDSKeyboardType,
                             maxTextSize: UInt16) {
        
        Task { @MainActor in
            IQKeyboardManager.shared.isEnabled = true
            IQKeyboardManager.shared.keyboardDistance = 100
        }
        
        
        Alert { alert in
            alert.config.cardCornerRadius = 0
            alert.contentMaskView.alpha = 0
            alert.config.backgroundViewMask { mask in
                mask.backgroundColor = .clear
            }
            
            let textfiledWidth = UIDevice.isPhone ? 300 : 380

            let containerView = RoundAndBorderView(roundCorner: .allCorners)
            containerView.backgroundColor = Constants.Color.Background
            containerView.makeBlur()
            //标题
            let titleLabel = UILabel()
            titleLabel.textAlignment = .center
            let textTitle: String
            if let hintText, !hintText.isEmpty {
                textTitle = hintText
            } else {
                textTitle = R.string.localizable.game3DSInputTitle()
            }
            titleLabel.text = textTitle
            titleLabel.font = Constants.Font.title(size: .s)
            titleLabel.textColor = Constants.Color.LabelPrimary
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.leading.trailing.greaterThanOrEqualToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
            
            //输入框
            let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: Constants.Size.CornerRadiusMid, borderColor: Constants.Color.Border, borderWidth: 1)
            textFieldContainer.backgroundColor = Constants.Color.InputBackground
            containerView.addSubview(textFieldContainer)
            textFieldContainer.snp.makeConstraints { make in
                make.height.equalTo(Constants.Size.ItemHeightMid)
                make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMid)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                make.width.equalTo(textfiledWidth)
            }
            
            let textField = UITextField()
            if maxTextSize > 0 {
                textField.placeholder = R.string.localizable.maxTextSizeAllowDesc("\(maxTextSize)")
            }
            textField.tintColor = Constants.Color.Main
            textField.textColor = Constants.Color.LabelPrimary
            textField.font = Constants.Font.body()
            textField.clearButtonMode = .whileEditing
            textFieldContainer.addSubview(textField)
            textField.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceTiny)
            }
            textField.becomeFirstResponder()
            
            let line = UIView()
            line.backgroundColor = Constants.Color.Border
            containerView.addSubview(line)
            line.snp.makeConstraints { make in
                make.height.equalTo(1)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                make.top.equalTo(textFieldContainer.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            }
            
            //按钮
            /**
             Single, /// Ok button
             Dual,   /// Cancel | Ok buttons
             Triple, /// Cancel | I Forgot | Ok buttons
             None,   /// No button (returned by swkbdInputText in special cases)
             */
            func closeKeyboard(text: String?, buttonPressed: Int = 0) {
                alert.pop()
                if let text {
                    NotificationCenter.default.post(name: .init("closeKeyboard"), object: nil, userInfo: [
                        "buttonPressed" : buttonPressed,
                        "keyboardText" : text
                    ])
                }
                
                Task { @MainActor in
                    IQKeyboardManager.shared.isEnabled = false
                }
            }
            
            if keyboardType == .none {
                textField.onReturnKeyPress {
                    closeKeyboard(text: nil)
                }
            }
            
            let okButton = UILabel()
            okButton.isUserInteractionEnabled = true
            okButton.enableInteractive = true
            okButton.text = R.string.localizable.confirmTitle()
            okButton.textAlignment = .center
            okButton.font = Constants.Font.title(size: .s, weight: .regular)
            okButton.textColor = Constants.Color.LabelPrimary
            okButton.addTapGesture { gesture in
                if let text = textField.text, !text.isEmpty {
                    if maxTextSize > 0, text.count > maxTextSize {
                        textFieldContainer.shake()
                        UIView.makeToast(message: R.string.localizable.maxTextSizeAllowDesc("\(maxTextSize)"))
                    } else {
                        closeKeyboard(text: textField.text, buttonPressed: keyboardType == .single ? 0 : (keyboardType == .dual ? 1 : 2))
                    }
                } else {
                    textFieldContainer.shake()
                    
                }
            }
            
            containerView.addSubview(okButton)
            okButton.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(line.snp.bottom).offset(Constants.Size.ContentSpaceMax)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
            }
            
            alert.set(customView: containerView).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    static func showForAzahar(config: AzaharKeyboardConfig,
                              tapAction: ((_ buttonType: AzaharButtonType, _ inputText: String?)->Void)? = nil) {
        
        Task { @MainActor in
            IQKeyboardManager.shared.isEnabled = true
            IQKeyboardManager.shared.keyboardDistance = 100
        }
        
        Alert { alert in
            alert.config.cardCornerRadius = 0
            alert.contentMaskView.alpha = 0
            alert.config.backgroundViewMask { mask in
                mask.backgroundColor = .clear
            }
            
            let textfiledWidth = UIDevice.isPhone ? 300 : 380

            let containerView = RoundAndBorderView(roundCorner: .allCorners)
            containerView.backgroundColor = Constants.Color.Background
            containerView.makeBlur()
            
            // 标题
            let titleLabel = UILabel()
            titleLabel.textAlignment = .center
            let textTitle: String
            if let hintText = config.hintText, !hintText.isEmpty {
                textTitle = hintText
            } else {
                textTitle = R.string.localizable.game3DSInputTitle()
            }
            titleLabel.text = textTitle
            titleLabel.font = Constants.Font.title(size: .s)
            titleLabel.textColor = Constants.Color.LabelPrimary
            containerView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(Constants.Size.ContentSpaceMid)
                make.leading.trailing.greaterThanOrEqualToSuperview().inset(Constants.Size.ContentSpaceMid)
            }
            
            // 输入框容器高度根据是否多行模式调整
            let textFieldHeight = config.multilineMode ? Constants.Size.ItemHeightMid * 3 : Constants.Size.ItemHeightMid
            
            let textFieldContainer = RoundAndBorderView(roundCorner: .allCorners, radius: Constants.Size.CornerRadiusMid, borderColor: Constants.Color.Border, borderWidth: 1)
            textFieldContainer.backgroundColor = Constants.Color.InputBackground
            containerView.addSubview(textFieldContainer)
            textFieldContainer.snp.makeConstraints { make in
                make.height.equalTo(textFieldHeight)
                make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMid)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                make.width.equalTo(textfiledWidth)
            }
            
            // 创建输入控件 - 根据多行模式使用不同控件
            var inputText: () -> String? = { nil }
            
            if config.multilineMode {
                // 多行模式使用 UITextView
                let textView = UITextView()
                textView.backgroundColor = .clear
                textView.tintColor = Constants.Color.Main
                textView.textColor = Constants.Color.LabelPrimary
                textView.font = Constants.Font.body()
                textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
                textFieldContainer.addSubview(textView)
                textView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                textView.becomeFirstResponder()
                inputText = { textView.text }
            } else {
                // 单行模式使用 UITextField
                let textField = UITextField()
                
                // 设置placeholder - 显示最大长度限制或者固定长度要求
                if config.acceptedInput == .fixedLength, config.maxTextLength > 0 {
                    textField.placeholder = R.string.localizable.exactlyTextSizeAllowDesc("\(config.maxTextLength)")
                } else if config.maxTextLength > 0 {
                    textField.placeholder = R.string.localizable.maxTextSizeAllowDesc("\(config.maxTextLength)")
                }
                
                textField.tintColor = Constants.Color.Main
                textField.textColor = Constants.Color.LabelPrimary
                textField.font = Constants.Font.body()
                textField.clearButtonMode = .whileEditing
                
                // 根据过滤器设置键盘类型
                if config.preventDigit && config.maxDigits == 0 {
                    // 如果完全禁止数字，可以考虑使用默认键盘
                    textField.keyboardType = .default
                }
                
                textFieldContainer.addSubview(textField)
                textField.snp.makeConstraints { make in
                    make.top.bottom.equalToSuperview()
                    make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceTiny)
                }
                textField.becomeFirstResponder()
                inputText = { textField.text }
            }
            
            let line = UIView()
            line.backgroundColor = Constants.Color.Border
            containerView.addSubview(line)
            line.snp.makeConstraints { make in
                make.height.equalTo(1)
                make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceHuge)
                make.top.equalTo(textFieldContainer.snp.bottom).offset(Constants.Size.ContentSpaceMid)
            }
            
            // 输入验证函数
            func validateInput(_ text: String?) -> String? {
                guard let text = text else { return nil }
                
                // 检查是否为空
                if config.acceptedInput == .notEmpty || config.acceptedInput == .notEmptyAndNotBlank {
                    if text.isEmpty {
                        return R.string.localizable.emptyInputNotAllowed()
                    }
                }
                
                // 检查是否为空白
                if config.acceptedInput == .notBlank || config.acceptedInput == .notEmptyAndNotBlank {
                    if text.trimmingCharacters(in: .whitespaces).isEmpty && !text.isEmpty {
                        return R.string.localizable.blankInputNotAllowed()
                    }
                }
                
                // 检查固定长度
                if config.acceptedInput == .fixedLength {
                    if text.count != config.maxTextLength {
                        return R.string.localizable.exactlyTextSize("\(config.maxTextLength)")
                    }
                }
                
                // 检查最大长度
                if config.maxTextLength > 0, text.count > config.maxTextLength {
                    return R.string.localizable.maxTextSizeAllowDesc("\(config.maxTextLength)")
                }
                
                // 检查过滤器
                if config.preventAt, text.contains("@") {
                    return R.string.localizable.atSymbolNotAllowed()
                }
                
                if config.preventPercent, text.contains("%") {
                    return R.string.localizable.percentSymbolNotAllowed()
                }
                
                if config.preventBackslash, text.contains("\\") {
                    return R.string.localizable.backslashSymbolNotAllowed()
                }
                
                // 检查数字限制
                if config.preventDigit, config.maxDigits > 0 {
                    let digitCount = text.filter { $0.isNumber }.count
                    if digitCount > config.maxDigits {
                        return R.string.localizable.digitsMaximumAllowed("\(config.maxDigits)")
                    }
                }
                
                return nil
            }
            
            // 关闭键盘函数
            func closeKeyboard(text: String?, buttonType: AzaharButtonType) {
                alert.pop()
                tapAction?(buttonType, text)
                
                Task { @MainActor in
                    IQKeyboardManager.shared.isEnabled = false
                }
            }
            
            // 获取自定义按钮文本
            func getButtonText(at index: Int, defaultText: String) -> String {
                if let buttonTexts = config.buttonText, index < buttonTexts.count, !buttonTexts[index].isEmpty {
                    return buttonTexts[index]
                }
                return defaultText
            }
            
            // 创建按钮
            // buttonText数组顺序: [0]=Cancel, [1]=Forgot, [2]=Ok
            let okButton = UILabel()
            okButton.isUserInteractionEnabled = true
            okButton.enableInteractive = true
            okButton.text = getButtonText(at: 2, defaultText: R.string.localizable.confirmTitle())
            okButton.textAlignment = .center
            okButton.font = Constants.Font.title(size: .s, weight: .regular)
            okButton.textColor = Constants.Color.LabelPrimary
            okButton.addTapGesture { gesture in
                let text = inputText()
                
                // 验证输入
                if let errorMessage = validateInput(text) {
                    textFieldContainer.shake()
                    UIView.makeToast(message: errorMessage)
                    return
                }
                
                // 对于 Anything 模式允许空输入
                if config.acceptedInput == .anything || (text != nil && !text!.isEmpty) {
                    closeKeyboard(text: text, buttonType: .ok)
                } else {
                    textFieldContainer.shake()
                }
            }
            
            let cancelButton = UILabel()
            cancelButton.isUserInteractionEnabled = true
            cancelButton.enableInteractive = true
            cancelButton.text = getButtonText(at: 0, defaultText: R.string.localizable.cancelTitle())
            cancelButton.textAlignment = .center
            cancelButton.font = Constants.Font.title(size: .s, weight: .regular)
            cancelButton.textColor = Constants.Color.LabelSecondary
            cancelButton.addTapGesture { gesture in
                closeKeyboard(text: nil, buttonType: .cancel)
            }

            let forgetButton = UILabel()
            forgetButton.isUserInteractionEnabled = true
            forgetButton.enableInteractive = true
            forgetButton.text = getButtonText(at: 1, defaultText: R.string.localizable.inputForget())
            forgetButton.textAlignment = .center
            forgetButton.font = Constants.Font.title(size: .s, weight: .regular)
            forgetButton.textColor = Constants.Color.LabelSecondary
            forgetButton.addTapGesture { gesture in
                closeKeyboard(text: nil, buttonType: .forgot)
            }
            
            // 根据按钮配置布局
            if config.buttonConfig == .single {
                // 只有确定按钮
                containerView.addSubview(okButton)
                okButton.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.top.equalTo(line.snp.bottom).offset(Constants.Size.ContentSpaceMax)
                    make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                    make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
                }
            } else if config.buttonConfig == .dual {
                // 取消 | 确定
                containerView.addSubview(cancelButton)
                containerView.addSubview(okButton)

                let verticalLine = UIView()
                verticalLine.backgroundColor = Constants.Color.BackgroundSecondary
                containerView.addSubview(verticalLine)
                verticalLine.snp.makeConstraints { make in
                    make.size.equalTo(CGSize(width: 1, height: 26))
                    make.centerX.equalToSuperview()
                    make.centerY.equalTo(cancelButton)
                }

                cancelButton.snp.makeConstraints { make in
                    make.top.equalTo(line.snp.bottom).offset(Constants.Size.ContentSpaceMax)
                    make.leading.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                    make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
                    make.trailing.equalTo(verticalLine.snp.leading)
                }
                okButton.snp.makeConstraints { make in
                    make.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                    make.leading.equalTo(verticalLine.snp.trailing)
                    make.centerY.equalTo(cancelButton)
                }

            } else if config.buttonConfig == .triple {
                // 取消 | 忘记了 | 确定
                containerView.addSubview(cancelButton)
                containerView.addSubview(forgetButton)
                containerView.addSubview(okButton)

                forgetButton.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.top.equalTo(line.snp.bottom).offset(Constants.Size.ContentSpaceMax)
                    make.width.equalToSuperview().dividedBy(3)
                    make.bottom.equalToSuperview().inset(Constants.Size.ContentSpaceMax)
                }

                cancelButton.snp.makeConstraints { make in
                    make.leading.equalToSuperview()
                    make.trailing.equalTo(forgetButton.snp.leading)
                    make.centerY.equalTo(forgetButton)
                }

                okButton.snp.makeConstraints { make in
                    make.trailing.equalToSuperview()
                    make.leading.equalTo(forgetButton.snp.trailing)
                    make.centerY.equalTo(forgetButton)
                }
            } else {
                // None - 无按钮模式
                line.isHidden = true
                textFieldContainer.snp.remakeConstraints { make in
                    make.height.equalTo(textFieldHeight)
                    make.top.equalTo(titleLabel.snp.bottom).offset(Constants.Size.ContentSpaceMid)
                    make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMid)
                    make.width.equalTo(textfiledWidth)
                    make.bottom.equalToSuperview().offset(-Constants.Size.ContentSpaceMid)
                }
            }
            
            alert.set(customView: containerView).snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
}
