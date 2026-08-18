//
//  ASIconView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/13.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import Kingfisher

class ASIconView: BaseView {
    
    private let imageView = UIImageView()
    private var defaultContentSize: CGSize = .zero
    
    var icon: ASIcon? = nil {
        didSet {
            applyIconContent()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    var animated = false {
        didSet {
            applyAnimated()
        }
    }
    
    
    init(_ icon: ASIcon? = nil) {
        self.icon = icon
        super.init(frame: .zero)
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        applyIconContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override var intrinsicContentSize: CGSize {
        let size = computedIntrinsicContentSize()
        return size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyVectorSymbolConfigurationIfNeeded()
        applyCornerStyle()
        applyAnimated()
    }
    
    // MARK: - Intrinsic sizing
    
    private var contentAspectRatio: CGFloat {
        guard defaultContentSize.height > .ulpOfOne else { return 1 }
        return defaultContentSize.width / defaultContentSize.height
    }
    
    private var hasExplicitLayoutDimension: Bool {
        resolvedLayoutDimension(.width) != nil || resolvedLayoutDimension(.height) != nil
    }
    
    private func computedIntrinsicContentSize() -> CGSize {
        guard defaultContentSize.width > .ulpOfOne, defaultContentSize.height > .ulpOfOne else {
            return .zero
        }
        
        let width = resolvedLayoutDimension(.width)
        let height = resolvedLayoutDimension(.height)
        
        switch (width, height) {
        case (.some, .some):
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        case let (width?, nil):
            return CGSize(width: width, height: width / contentAspectRatio)
        case let (nil, height?):
            return CGSize(width: height * contentAspectRatio, height: height)
        case (nil, nil):
            return defaultContentSize
        }
    }
    
    // MARK: - Layout dimension resolution
    
    private func resolvedLayoutDimension(_ attribute: NSLayoutConstraint.Attribute) -> CGFloat? {
        switch attribute {
        case .width where bounds.width > .ulpOfOne:
            return bounds.width
        case .height where bounds.height > .ulpOfOne:
            return bounds.height
        default:
            break
        }
        
        if let value = explicitConstraintConstant(for: attribute, in: constraints) {
            return value
        }
        if let superview, let value = explicitConstraintConstant(for: attribute, in: superview.constraints) {
            return value
        }
        return nil
    }
    
    private func explicitConstraintConstant(
        for attribute: NSLayoutConstraint.Attribute,
        in constraints: [NSLayoutConstraint]
    ) -> CGFloat? {
        for constraint in constraints where constraint.isActive && constraint.relation == .equal {
            if constraint.firstItem as AnyObject === self,
               constraint.firstAttribute == attribute,
               constraint.secondItem == nil {
                return constraint.constant
            }
            if constraint.secondItem as AnyObject === self,
               constraint.secondAttribute == attribute,
               constraint.firstItem == nil {
                return constraint.constant
            }
        }
        return nil
    }
    
    // MARK: - Icon content
    
    private func applyIconContent() {
        imageView.contentMode = .scaleAspectFit
        
        guard let icon else {
            imageView.image = nil
            imageView.preferredSymbolConfiguration = nil
            defaultContentSize = .zero
            return
        }
        
        switch icon {
        case .symbol(let symbol, _, _, _, _):
            let defaultImage = UIImage(systemSymbol: symbol)
            defaultContentSize = defaultImage.size
            imageView.preferredSymbolConfiguration = nil
            imageView.image = defaultImage
            
        case .symbolImage(let symbolImage, _, _, _, _):
            let symbolImage = symbolImage ?? R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
            defaultContentSize = symbolImage.size
            imageView.preferredSymbolConfiguration = nil
            imageView.image = symbolImage
            
        case .image(let image, let color, _):
            let image = image ?? R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
            imageView.preferredSymbolConfiguration = nil
            imageView.contentMode = .scaleAspectFill
            defaultContentSize = image.size
            if let color {
                imageView.tintColor = color
                imageView.image = image.withRenderingMode(.alwaysTemplate)
            } else {
                imageView.tintColor = nil
                imageView.image = image
            }
            
        case .imageUrl(let url, let processSize, _):
            imageView.preferredSymbolConfiguration = nil
            imageView.contentMode = .scaleAspectFill
            defaultContentSize = processSize
            imageView.kf.setImage(with: url, options: [.processor(DownsamplingImageProcessor(size: processSize))])
        }
    }
    
    /// Only apply a SymbolConfiguration with pointSize to vector icons when the user specifies a width or height.
    private func applyVectorSymbolConfigurationIfNeeded() {
        guard let icon else { return }
        
        guard hasExplicitLayoutDimension, let pointSize = resolvedSymbolPointSize() else {
            switch icon {
            case .symbol(let symbol, _, _, _, _):
                imageView.preferredSymbolConfiguration = nil
                imageView.image = UIImage(symbol: symbol)
                
            case .symbolImage(let symbolImage, _, _, _, _):
                imageView.preferredSymbolConfiguration = nil
                imageView.image = symbolImage
                
            case .image, .imageUrl:
                break
            }
            return
        }
        
        switch icon {
        case .symbol(let symbol, let weight, let colors, _, _):
            let symbolImage = UIImage(systemSymbol: symbol)
            imageView.image = symbolImage
            imageView.preferredSymbolConfiguration = ASIcon.imageConfig(
                size: pointSize,
                weight: weight,
                colors: colors
            )
            
        case .symbolImage(let symbolImage, let weight, let colors, _, _):
            imageView.image = symbolImage
            imageView.preferredSymbolConfiguration = ASIcon.imageConfig(
                size: pointSize,
                weight: weight,
                colors: colors
            )
        case .image, .imageUrl:
            break
        }
    }
    
    private func resolvedSymbolPointSize() -> CGFloat? {
        guard hasExplicitLayoutDimension else { return nil }
        
        let width = resolvedLayoutDimension(.width)
        let height = resolvedLayoutDimension(.height)
        
        switch (width, height) {
        case let (width?, height?):
            return min(width, height)
        case let (width?, nil):
            let resolvedHeight = width / contentAspectRatio
            return min(width, resolvedHeight)
        case let (nil, height?):
            let resolvedWidth = height * contentAspectRatio
            return min(resolvedWidth, height)
        case (nil, nil):
            return nil
        }
    }
    
    private func applyCornerStyle() {
        guard let icon else { return }
        
        func setCornerStyle(_ cornerStyle: ASCornerStyle) {
            switch cornerStyle {
            case .circle:
                layerCornerRadius = height/2
            case .radius(let cGFloat):
                layerCornerRadius = cGFloat
            }
        }
        
        switch icon {
        case .symbol(_, _, _, let cornerStyle, _):
            setCornerStyle(cornerStyle)
        case .symbolImage(_, _, _, let cornerStyle, _):
            setCornerStyle(cornerStyle)
        case .image(_, _, let cornerStyle):
            setCornerStyle(cornerStyle)
        case .imageUrl(_, _, let cornerStyle):
            setCornerStyle(cornerStyle)
        }
    }
    
    private func applyAnimated() {
        func setAnimated(_ animated: Bool) {
            if animated {
                if #available(iOS 18.0, *) {
                    imageView.addSymbolEffect(.pulse, options: .repeat(.continuous))
                }
            } else {
                if #available(iOS 18.0, *) {
                    imageView.removeSymbolEffect(ofType: .pulse)
                }
            }
        }
        
        switch icon {
        case .symbol(_, _, _, _, let animated):
            setAnimated(animated)
            
        case .symbolImage(_, _, _, _, let animated):
            setAnimated(animated)
            
        default:
            setAnimated(false)
            
        }
        
    }
}
