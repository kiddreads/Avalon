//
//  FocusCollectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// UICollectionView 的焦点容器适配。
///
/// 无需子类替换：任意集合视图设置 `collectionView.isFocusable = true` 即作为容器参与导航。
/// 焦点进入容器时不高亮容器本身，而是寻找合适的 cell / header / footer 进行聚焦。
///
/// 设计要点：
/// - 焦点锚点：`FocusedElement`（cell 或 supplementary），视觉通过 `focusEffect` 呈现。
/// - cell / header / footer 均可聚焦整体或其内部 `isFocusable` 子视图。
/// - 跨元素寻径基于 layoutAttributes 空间搜索（同行左右 / 同列上下）。
/// - supplementary 滚动使用 `scrollRectToVisible`（`scrollToItem` 仅适用于 cell）。

// MARK: - 配置属性

private var FocusCollectionCoordinatorKey: UInt8 = 0
private var FocusOrthogonalProviderKey: UInt8 = 0
private var FocusCellFilterKey: UInt8 = 0
private var FocusOrthogonalWrapsKey: UInt8 = 0

/// 集合视图内的焦点锚点：普通 cell 或 section header/footer
private enum FocusedElement: Hashable {
    case cell(IndexPath)
    case supplementary(kind: String, section: Int)

    var section: Int {
        switch self {
        case .cell(let indexPath): return indexPath.section
        case .supplementary(_, let section): return section
        }
    }
}

extension UICollectionView {
    var focusOrthogonalSectionProvider: ((_ section: Int) -> Bool)? {
        get { objc_getAssociatedObject(self, &FocusOrthogonalProviderKey) as? (Int) -> Bool }
        set { objc_setAssociatedObject(self, &FocusOrthogonalProviderKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    var focusCellFilter: ((_ indexPath: IndexPath) -> Bool)? {
        get { objc_getAssociatedObject(self, &FocusCellFilterKey) as? (IndexPath) -> Bool }
        set { objc_setAssociatedObject(self, &FocusCellFilterKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    var focusOrthogonalWraps: Bool {
        get { (objc_getAssociatedObject(self, &FocusOrthogonalWrapsKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &FocusOrthogonalWrapsKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 当前聚焦的 cell indexPath（焦点在 header/footer 上时为 nil）
    var focusedIndexPath: IndexPath? {
        focusCoordinator.focusedIndexPath
    }

    fileprivate var focusCoordinator: FocusCollectionCoordinator {
        if let coordinator = objc_getAssociatedObject(self, &FocusCollectionCoordinatorKey) as? FocusCollectionCoordinator {
            return coordinator
        }
        let coordinator = FocusCollectionCoordinator(collectionView: self)
        objc_setAssociatedObject(self, &FocusCollectionCoordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN)
        return coordinator
    }
}

// MARK: - FocusContainer 实现

extension UICollectionView: FocusContainer {
    var canEnterFocus: Bool {
        guard window != nil, !isHidden, alpha > 0.01 else { return false }
        return focusCoordinator.firstFocusableElement() != nil
    }

    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView? {
        focusCoordinator.enter(from: direction, preferred: preferred)
    }

    func navigateFocus(_ direction: FocusDirection, current: UIView?) -> FocusContainerResult {
        focusCoordinator.navigate(direction)
    }

    var currentFocusedDescendant: UIView? {
        if let target = focusCoordinator.focusedTarget { return target }
        return focusCoordinator.hostViewForFocusedElement()
    }

    var lastFocusedDescendant: UIView? {
        focusCoordinator.hostViewForLastFocusedElement()
    }

    func resignFocus() {
        focusCoordinator.resign()
    }

    func performPrimaryActionOnFocused() -> Bool {
        focusCoordinator.performPrimaryAction()
    }

    func focusEntryFrame(from direction: FocusDirection) -> CGRect? {
        focusCoordinator.entryFrameInWindow(from: direction)
    }

    func containerFocusCommands() -> [FocusCommand] {
        focusCoordinator.containerFocusCommands()
    }
}

// MARK: - Coordinator

private final class FocusCollectionCoordinator: NSObject {
    private(set) var focusedElement: FocusedElement?
    private(set) var lastFocusedElement: FocusedElement?
    private(set) weak var focusedTarget: UIView?
    private weak var focusedHost: UIView?
    private weak var collectionView: UICollectionView?
    private var contentOffsetObservation: NSKeyValueObservation?

    private var pendingEntryDirection: FocusDirection?
    private var pendingEntryOriginFrame: CGRect?
    private var pendingProbe: (element: FocusedElement, direction: FocusDirection?, originFrame: CGRect?)?
    private var scrollAnchor: FocusedElement?

    var focusedIndexPath: IndexPath? {
        if case .cell(let indexPath)? = focusedElement { return indexPath }
        return nil
    }

    var lastFocusedIndexPath: IndexPath? {
        if case .cell(let indexPath)? = lastFocusedElement { return indexPath }
        return nil
    }

    init(collectionView: UICollectionView) {
        self.collectionView = collectionView
        super.init()
        contentOffsetObservation = collectionView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.reconcileFocusVisual()
        }
    }

    deinit {
        contentOffsetObservation?.invalidate()
    }

    // MARK: 进入 / 离开

    func enter(from direction: FocusDirection?, preferred: UIView? = nil) -> UIView? {
        guard let collectionView else { return nil }

        if let preferred, preferred !== collectionView,
           let element = focusedElement(containing: preferred), isFocusableElement(element) {
            let originFrame = FocusEngine.frameInWindow(of: preferred)
            switch moveTo(element, direction: direction, originFrame: originFrame, shouldFocus: true) {
            case .handled(let view): return view
            case .exit: return collectionView
            }
        }

        var target: FocusedElement?
        if let remembered = lastFocusedElement, isElementVisible(remembered), isFocusableElement(remembered) {
            target = remembered
        } else {
            target = entryElement(from: direction)
        }
        guard let target else { return collectionView }

        switch moveTo(target, direction: direction, originFrame: nil, shouldFocus: true) {
        case .handled(let view): return view
        case .exit: return collectionView
        }
    }

    func resign() {
        cancelInternalFocus()
        pendingProbe = nil
        scrollAnchor = nil
    }

    func hostViewForFocusedElement() -> UIView? {
        guard let element = focusedElement else { return nil }
        return hostView(for: element)
    }

    func hostViewForLastFocusedElement() -> UIView? {
        guard let element = lastFocusedElement else { return nil }
        return hostView(for: element)
    }

    func containerFocusCommands() -> [FocusCommand] {
        guard let host = focusedHost, let target = focusedTarget, target !== host else { return [] }
        return host.focusCommands
    }

    private func cancelInternalFocus() {
        if let focusedTarget {
            focusedTarget.fk_applyFocus(false)
        } else if let element = focusedElement, let host = hostView(for: element) {
            host.fk_applyFocus(false)
        }
        focusedTarget = nil
        focusedHost = nil
        focusedElement = nil
        pendingEntryDirection = nil
        pendingEntryOriginFrame = nil
    }

    // MARK: 方向导航

    func navigate(_ direction: FocusDirection) -> FocusContainerResult {
        guard let _ = collectionView else { return .exit }

        let position = focusedElement ?? scrollAnchor

        guard let current = position, isValidElement(current) else {
            cancelInternalFocus()
            scrollAnchor = nil
            pendingProbe = nil
            guard let target = entryElement(from: direction) else { return .exit }
            return moveTo(target, direction: direction, originFrame: nil, shouldFocus: true)
        }

        if let element = focusedElement,
           let host = hostView(for: element),
           let inner = focusedTarget, inner !== host, inner.isDescendant(of: host) {
            let candidates = FocusEngine.collectCandidates(in: host)
                .filter { $0 !== inner && !$0.isDescendant(of: inner) }
            if let next = FocusEngine.bestCandidate(from: FocusEngine.frameInWindow(of: inner),
                                                    direction: direction,
                                                    candidates: candidates) {
                inner.fk_applyFocus(false)
                next.fk_applyFocus(true)
                focusedTarget = next
                scrollToMakeVisible(element, focusedView: next)
                return .handled(next)
            }
        }

        guard let resolved = resolveNavigationTarget(from: current, direction: direction) else {
            return .exit
        }
        let originFrame = focusedTarget.map { FocusEngine.frameInWindow(of: $0) }
        return moveTo(resolved.element, direction: direction, originFrame: originFrame, shouldFocus: resolved.shouldFocus)
    }

    private func resolveNavigationTarget(from start: FocusedElement, direction: FocusDirection) -> (element: FocusedElement, shouldFocus: Bool)? {
        guard let collectionView else { return nil }

        if case .cell(let startIndexPath) = start,
           collectionView.focusOrthogonalSectionProvider?(startIndexPath.section) == true {
            return resolveOrthogonalNavigation(from: startIndexPath, direction: direction)
        }

        guard let _ = layoutAttributes(for: start) else { return nil }

        var current = start
        var farthest: FocusedElement?
        var visited = Set<FocusedElement>()

        while let next = nextElement(from: current, direction: direction) {
            guard visited.insert(next).inserted else { break }
            farthest = next

            if let _ = hostView(for: next) {
                if isFocusableElement(next) {
                    return (next, true)
                }
            } else if isNavigableElement(next) {
                return (next, true)
            }
            current = next
        }

        guard let farthest else { return nil }
        return (farthest, false)
    }

    private func resolveOrthogonalNavigation(from start: IndexPath, direction: FocusDirection) -> (element: FocusedElement, shouldFocus: Bool)? {
        switch direction {
        case .left, .right:
            guard let next = adjacentItem(from: start, direction: direction) else { return nil }
            return (FocusedElement.cell(next), isFocusableElement(.cell(next)) || hostView(for: .cell(next)) == nil)
        case .up, .down:
            guard let next = arithmeticNextSection(from: start, direction: direction) else { return nil }
            let element = FocusedElement.cell(next)
            return (element, isFocusableElement(element) || hostView(for: element) == nil)
        }
    }

    private func moveTo(_ element: FocusedElement, direction: FocusDirection?, originFrame: CGRect?, shouldFocus: Bool) -> FocusContainerResult {
        guard let collectionView else { return .exit }

        lastFocusedElement = element
        scrollToReveal(element, direction: direction)

        if shouldFocus, let host = hostView(for: element), isFocusableElement(element) {
            pendingProbe = nil
            scrollAnchor = nil
            focus(element, direction: direction, originFrame: originFrame, scroll: false)
            return .handled(focusedTarget ?? host)
        }

        cancelInternalFocus()
        scrollAnchor = element
        pendingProbe = shouldFocus && hostView(for: element) == nil
            ? (element, direction, originFrame)
            : nil
        return .handled(collectionView)
    }

    private func scrollPosition(for direction: FocusDirection?) -> UICollectionView.ScrollPosition {
        guard let direction else { return [] }
        return direction.isHorizontal ? .centeredHorizontally : .centeredVertically
    }

    // MARK: 确定键

    func performPrimaryAction() -> Bool {
        guard let collectionView, let element = focusedElement, isValidElement(element) else { return false }
        let host = hostView(for: element)

        if let inner = focusedTarget, let host, inner !== host, inner.isDescendant(of: host) {
            return inner.fk_performPrimaryAction()
        }

        if let host, let onConfirm = host.onFocusConfirm, onConfirm() {
            return true
        }

        if case .cell(let indexPath) = element,
           let delegate = collectionView.delegate,
           delegate.responds(to: #selector(UICollectionViewDelegate.collectionView(_:didSelectItemAt:))) {
            delegate.collectionView?(collectionView, didSelectItemAt: indexPath)
            return true
        }
        return false
    }

    // MARK: 聚焦

    private func focus(_ element: FocusedElement, direction: FocusDirection?, originFrame: CGRect?, scroll: Bool = true) {
        if focusedElement != element, let focusedTarget {
            focusedTarget.fk_applyFocus(false)
            self.focusedTarget = nil
            self.focusedHost = nil
        }
        focusedElement = element
        lastFocusedElement = element
        pendingEntryDirection = direction
        pendingEntryOriginFrame = originFrame
        if scroll {
            scrollToMakeVisible(element, focusedView: nil)
        }
        reconcileFocusVisual()
    }

    private func reconcileFocusVisual() {
        resolvePendingProbeIfPossible()
        guard let _ = collectionView, let element = focusedElement else { return }

        let currentHost = hostView(for: element)

        if let oldHost = focusedHost, oldHost !== currentHost {
            focusedTarget?.fk_applyFocus(false)
            if let focusedTarget, focusedTarget !== oldHost {
                oldHost.fk_applyFocus(false)
            }
            focusedTarget = nil
            focusedHost = nil
        }

        guard let currentHost else {
            focusedTarget = nil
            focusedHost = nil
            return
        }

        var target = focusedTarget
        if target == nil || (target !== currentHost && !(target!.isDescendant(of: currentHost))) {
            target = resolveFocusTarget(in: currentHost)
            pendingEntryDirection = nil
            pendingEntryOriginFrame = nil
        }
        guard let target else {
            focusedTarget?.fk_applyFocus(false)
            focusedTarget = nil
            focusedHost = nil
            scrollAnchor = element
            focusedElement = nil
            return
        }

        if focusedTarget !== target || !target.focusEffect {
            target.fk_applyFocus(true)
        }
        focusedHost = currentHost
        focusedTarget = target
    }

    private func resolvePendingProbeIfPossible() {
        guard let collectionView, let probe = pendingProbe else { return }
        guard hostView(for: probe.element) != nil else { return }
        pendingProbe = nil

        guard isFocusableElement(probe.element) else { return }
        scrollAnchor = nil
        focus(probe.element, direction: probe.direction, originFrame: probe.originFrame, scroll: false)
        FocusSystem.shared.containerDidUpdateFocus(collectionView, direction: probe.direction)
    }

    private func resolveFocusTarget(in host: UIView) -> UIView? {
        if host.fk_canFocus { return host }

        let candidates = FocusEngine.collectCandidates(in: host)
        guard !candidates.isEmpty else { return nil }
        if let direction = pendingEntryDirection, let origin = pendingEntryOriginFrame,
           let best = FocusEngine.bestCandidate(from: origin, direction: direction, candidates: candidates) {
            return best
        }
        return FocusEngine.initialCandidate(in: host) ?? host
    }

    // MARK: 可视区 / 滚动

    private func isElementVisible(_ element: FocusedElement) -> Bool {
        guard let collectionView,
              let attributes = layoutAttributes(for: element) else { return false }
        let visible = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        return attributes.frame.intersects(visible)
    }

    func entryFrameInWindow(from direction: FocusDirection) -> CGRect? {
        guard let collectionView, let window = collectionView.window else { return nil }

        let element: FocusedElement?
        if let remembered = lastFocusedElement, isElementVisible(remembered), isFocusableElement(remembered) {
            element = remembered
        } else {
            element = entryElement(from: direction)
        }
        if let element,
           let attributes = layoutAttributes(for: element) {
            return collectionView.convert(attributes.frame, to: window)
        }
        let frame = FocusEngine.frameInWindow(of: collectionView)
        return CGRect(x: frame.midX, y: frame.midY, width: 1, height: 1)
    }

    private func scrollToReveal(_ element: FocusedElement, direction: FocusDirection?) {
        guard let collectionView else { return }
        switch element {
        case .cell(let indexPath):
            collectionView.scrollToItem(at: indexPath, at: scrollPosition(for: direction), animated: true)
        case .supplementary:
            scrollToMakeVisible(element, focusedView: nil, animated: true)
        }
    }

    private func scrollToMakeVisible(_ element: FocusedElement, focusedView: UIView?, animated: Bool = true) {
        guard let collectionView else { return }

        let targetFrame: CGRect
        if let focusedView {
            targetFrame = focusedView.convert(focusedView.bounds, to: collectionView).insetBy(dx: -8, dy: -8)
        } else if let host = hostView(for: element) {
            targetFrame = host.convert(host.bounds, to: collectionView).insetBy(dx: -8, dy: -8)
        } else if let attributes = layoutAttributes(for: element) {
            targetFrame = attributes.frame.insetBy(dx: -8, dy: -8)
        } else {
            return
        }

        let visible = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        guard !visible.contains(targetFrame) else { return }
        collectionView.scrollRectToVisible(targetFrame, animated: animated)
    }

    // MARK: 寻径

    private func nextElement(from current: FocusedElement, direction: FocusDirection) -> FocusedElement? {
        guard let collectionView else { return nil }

        if case .cell(let indexPath) = current,
           collectionView.focusOrthogonalSectionProvider?(indexPath.section) == true {
            switch direction {
            case .left, .right:
                return adjacentItem(from: indexPath, direction: direction).map { .cell($0) }
            case .up, .down:
                return arithmeticNextSection(from: indexPath, direction: direction).map { .cell($0) }
            }
        }

        guard let attributes = layoutAttributes(for: current) else { return nil }

        if let found = spatialSearch(from: attributes, direction: direction) {
            return found
        }

        if direction.isHorizontal {
            return nil
        }

        if case .cell(let indexPath) = current,
           let next = arithmeticNextSection(from: indexPath, direction: direction) {
            return .cell(next)
        }
        return nil
    }

    private func adjacentItem(from current: IndexPath, direction: FocusDirection) -> IndexPath? {
        guard let collectionView else { return nil }
        let itemCount = collectionView.numberOfItems(inSection: current.section)
        let delta = direction == .right ? 1 : -1
        var item = current.item + delta
        if collectionView.focusOrthogonalWraps {
            if item < 0 { item = itemCount - 1 }
            if item >= itemCount { item = 0 }
        }
        guard item >= 0, item < itemCount else { return nil }
        return IndexPath(item: item, section: current.section)
    }

    private func arithmeticNextSection(from current: IndexPath, direction: FocusDirection) -> IndexPath? {
        guard let collectionView else { return nil }
        let sectionCount = collectionView.numberOfSections
        let delta = direction == .down ? 1 : -1
        let section = current.section + delta
        guard section >= 0, section < sectionCount else { return nil }

        let itemCount = collectionView.numberOfItems(inSection: section)
        guard itemCount > 0 else {
            return arithmeticNextSection(from: IndexPath(item: current.item, section: section), direction: direction)
        }

        let item = min(current.item, itemCount - 1)
        return IndexPath(item: item, section: section)
    }

    private func sharesRow(_ origin: CGRect, with candidate: CGRect, tolerance: CGFloat = 4) -> Bool {
        candidate.maxY > origin.minY + tolerance && candidate.minY < origin.maxY - tolerance
    }

    private func sharesColumn(_ origin: CGRect, with candidate: CGRect, tolerance: CGFloat = 4) -> Bool {
        candidate.maxX > origin.minX + tolerance && candidate.minX < origin.maxX - tolerance
    }

    private func spatialSearch(from origin: UICollectionViewLayoutAttributes, direction: FocusDirection) -> FocusedElement? {
        guard let collectionView else { return nil }
        let contentSize = collectionView.collectionViewLayout.collectionViewContentSize
        let limit = direction.isHorizontal ? contentSize.width : contentSize.height

        var offset: CGFloat = 0
        var distance: CGFloat = 600
        while offset < limit + distance {
            if let found = spatialSearch(from: origin, direction: direction, offset: offset, distance: distance) {
                return found
            }
            offset += distance
            distance = 3000
        }
        return nil
    }

    private func spatialSearch(from origin: UICollectionViewLayoutAttributes,
                               direction: FocusDirection,
                               offset: CGFloat,
                               distance: CGFloat) -> FocusedElement? {
        guard let collectionView else { return nil }
        let originFrame = origin.frame

        let searchRect: CGRect
        switch direction {
        case .up:
            searchRect = CGRect(x: originFrame.minX, y: originFrame.midY - offset - distance,
                                width: originFrame.width, height: distance)
        case .down:
            searchRect = CGRect(x: originFrame.minX, y: originFrame.midY + offset,
                                width: originFrame.width, height: distance)
        case .left:
            searchRect = CGRect(x: originFrame.midX - offset - distance, y: originFrame.minY,
                                width: distance, height: originFrame.height)
        case .right:
            searchRect = CGRect(x: originFrame.midX + offset, y: originFrame.minY,
                                width: distance, height: originFrame.height)
        }

        let candidates = collectionView.collectionViewLayout.layoutAttributesForElements(in: searchRect) ?? []

        var best: UICollectionViewLayoutAttributes?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestTransverse = CGFloat.greatestFiniteMagnitude

        for attributes in candidates {
            guard !attributes.isHidden, attributes.alpha > 0 else { continue }
            guard attributesElement(from: attributes) != attributesElement(from: origin) else { continue }
            guard isNavigableAttributes(attributes) else { continue }

            let mainDistance: CGFloat
            switch direction {
            case .up: mainDistance = origin.center.y - attributes.center.y
            case .down: mainDistance = attributes.center.y - origin.center.y
            case .left: mainDistance = origin.center.x - attributes.center.x
            case .right: mainDistance = attributes.center.x - origin.center.x
            }
            guard mainDistance > 0 else { continue }

            if direction.isHorizontal {
                guard sharesRow(originFrame, with: attributes.frame) else { continue }
            } else {
                guard sharesColumn(originFrame, with: attributes.frame) else { continue }
            }

            let transverse: CGFloat
            if direction.isHorizontal {
                transverse = abs(attributes.center.y - origin.center.y)
            } else {
                transverse = abs(attributes.center.x - origin.center.x)
            }

            if mainDistance < bestDistance
                || (mainDistance == bestDistance && (transverse < bestTransverse
                || (transverse == bestTransverse && attributes.indexPath.section < (best?.indexPath.section ?? Int.max)))) {
                best = attributes
                bestDistance = mainDistance
                bestTransverse = transverse
            }
        }
        return best.map { attributesElement(from: $0) }
    }

    private func entryElement(from direction: FocusDirection?) -> FocusedElement? {
        guard let collectionView else { return nil }

        let visibleRect = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        let visibleAttributes = (collectionView.collectionViewLayout.layoutAttributesForElements(in: visibleRect) ?? [])
            .filter { !$0.isHidden && $0.alpha > 0 && isNavigableAttributes($0) }

        guard !visibleAttributes.isEmpty else {
            return direction == nil ? firstFocusableElement() : nil
        }

        let best = visibleAttributes.min { lhs, rhs in
            switch direction {
            case .down, .none:
                if abs(lhs.frame.minY - rhs.frame.minY) > 1 { return lhs.frame.minY < rhs.frame.minY }
                return lhs.frame.minX < rhs.frame.minX
            case .up:
                if abs(lhs.frame.maxY - rhs.frame.maxY) > 1 { return lhs.frame.maxY > rhs.frame.maxY }
                return lhs.frame.minX < rhs.frame.minX
            case .right:
                if abs(lhs.frame.minX - rhs.frame.minX) > 1 { return lhs.frame.minX < rhs.frame.minX }
                return lhs.frame.minY < rhs.frame.minY
            case .left:
                if abs(lhs.frame.maxX - rhs.frame.maxX) > 1 { return lhs.frame.maxX > rhs.frame.maxX }
                return lhs.frame.minY < rhs.frame.minY
            }
        }
        return best.map { attributesElement(from: $0) }
    }

    // MARK: 元素解析

    private func attributesElement(from attributes: UICollectionViewLayoutAttributes) -> FocusedElement {
        switch attributes.representedElementCategory {
        case .cell:
            return .cell(attributes.indexPath)
        case .supplementaryView:
            let kind = attributes.representedElementKind ?? UICollectionView.elementKindSectionHeader
            return .supplementary(kind: kind, section: attributes.indexPath.section)
        default:
            return .cell(attributes.indexPath)
        }
    }

    private func layoutAttributes(for element: FocusedElement) -> UICollectionViewLayoutAttributes? {
        guard let collectionView else { return nil }
        switch element {
        case .cell(let indexPath):
            return collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)
        case .supplementary(let kind, let section):
            return collectionView.layoutAttributesForSupplementaryElement(
                ofKind: kind,
                at: IndexPath(item: 0, section: section)
            )
        }
    }

    private func hostView(for element: FocusedElement) -> UIView? {
        guard let collectionView else { return nil }
        switch element {
        case .cell(let indexPath):
            return collectionView.cellForItem(at: indexPath)
        case .supplementary(let kind, let section):
            return collectionView.supplementaryView(forElementKind: kind, at: IndexPath(item: 0, section: section))
        }
    }

    private func focusedElement(containing view: UIView) -> FocusedElement? {
        guard let collectionView else { return nil }
        var current: UIView? = view
        while let candidate = current {
            if let cell = candidate as? UICollectionViewCell, let indexPath = collectionView.indexPath(for: cell) {
                return .cell(indexPath)
            }
            if let reusable = candidate as? UICollectionReusableView,
               let match = supplementaryElement(for: reusable) {
                return match
            }
            if candidate === collectionView { break }
            current = candidate.superview
        }
        return nil
    }

    private func supplementaryElement(for reusableView: UICollectionReusableView) -> FocusedElement? {
        guard let collectionView else { return nil }
        for section in 0..<collectionView.numberOfSections {
            for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter] {
                let indexPath = IndexPath(item: 0, section: section)
                if collectionView.supplementaryView(forElementKind: kind, at: indexPath) === reusableView {
                    return .supplementary(kind: kind, section: section)
                }
            }
        }
        return nil
    }

    func firstFocusableElement() -> FocusedElement? {
        guard let collectionView else { return nil }
        for section in 0..<collectionView.numberOfSections {
            for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter] {
                let element = FocusedElement.supplementary(kind: kind, section: section)
                if isNavigableElement(element), isFocusableElement(element) {
                    return element
                }
            }
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let element = FocusedElement.cell(IndexPath(item: item, section: section))
                if isFocusableElement(element) {
                    return element
                }
            }
        }
        return nil
    }

    func firstFocusableIndexPath() -> IndexPath? {
        guard let collectionView else { return nil }
        for section in 0..<collectionView.numberOfSections {
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                if isFocusableElement(.cell(indexPath)) {
                    return indexPath
                }
            }
        }
        return nil
    }

    private func isNavigableAttributes(_ attributes: UICollectionViewLayoutAttributes) -> Bool {
        switch attributes.representedElementCategory {
        case .cell:
            return isNavigableItem(attributes.indexPath)
        case .supplementaryView:
            return layoutAttributes(for: attributesElement(from: attributes)) != nil
        default:
            return false
        }
    }

    private func isNavigableElement(_ element: FocusedElement) -> Bool {
        switch element {
        case .cell(let indexPath):
            return isNavigableItem(indexPath)
        case .supplementary:
            return layoutAttributes(for: element) != nil
        }
    }

    private func isValidElement(_ element: FocusedElement) -> Bool {
        switch element {
        case .cell(let indexPath):
            return isValid(indexPath)
        case .supplementary(_, let section):
            guard let collectionView else { return false }
            return section >= 0 && section < collectionView.numberOfSections
        }
    }

    private func isNavigableItem(_ indexPath: IndexPath) -> Bool {
        guard isValid(indexPath) else { return false }
        if let filter = collectionView?.focusCellFilter, !filter(indexPath) {
            return false
        }
        return true
    }

    private func isFocusableElement(_ element: FocusedElement) -> Bool {
        guard isNavigableElement(element) else { return false }
        guard let host = hostView(for: element) else { return false }
        return hasFocusableContent(in: host)
    }

    private func hasFocusableContent(in view: UIView) -> Bool {
        if view.fk_canFocus { return true }
        return !FocusEngine.collectCandidates(in: view).isEmpty
    }

    private func isValid(_ indexPath: IndexPath) -> Bool {
        guard let collectionView else { return false }
        return indexPath.section >= 0
            && indexPath.section < collectionView.numberOfSections
            && indexPath.item >= 0
            && indexPath.item < collectionView.numberOfItems(inSection: indexPath.section)
    }
}
