//
//  FocusEngine.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// 空间寻径引擎：负责候选收集与"按下方向键后该聚焦谁"的核心算法。
///
/// 设计原则（视觉优先）：
/// - 所有候选使用 window 坐标系下的真实 frame 打分；
/// - 可见面积不足 1/3（≥2/3 在屏外）的候选不参与寻径，避免 PageView 邻页露边被误选；
/// - 页面级寻径时展开 FocusContainer 内部已实例化的可聚焦后代，用真实 frame 与悬浮层竞争；
///   命中后代后由 FocusSystem 折叠为 enterContainer，容器内仍走 indexPath 导航；
/// - 离开容器时排除该容器整棵子树，只与页面级 sibling 竞争；
/// - 半平面 + 投影重叠 + 主轴距离的经典空间寻径，不做屏外兜底。
enum FocusEngine {

    /// 判定"在方向半平面内"时允许的边缘重叠容差
    private static let overlapTolerance: CGFloat = 4

    /// 视图面积中处于屏幕外的比例 ≥ 此值时视为屏外（可见面积须 > 1/3）
    private static let offScreenAreaThreshold: CGFloat = 2.0 / 3.0

    // MARK: - 候选收集

    /// 深度遍历 root 子树，收集可聚焦视图。
    /// - `excludingContainerSubtree`：容器退出时的页面级寻径，整棵子树不参与候选。
    static func collectCandidates(in root: UIView, excludingContainerSubtree: UIView? = nil) -> [UIView] {
        var result: [UIView] = []
        collect(from: root, into: &result, excludingContainerSubtree: excludingContainerSubtree)
        return result
    }

    private static func collect(from view: UIView, into result: inout [UIView], excludingContainerSubtree: UIView?) {
        guard !view.isHidden, view.alpha > 0.01 else { return }

        if let excluded = excludingContainerSubtree, view === excluded || view.isDescendant(of: excluded) {
            return
        }

        if let container = view as? FocusContainer, view.isFocusable {
            if container.canEnterFocus {
                var flattened: [UIView] = []
                collectFlattenedInterior(from: view, into: &flattened)
                if flattened.isEmpty {
                    result.append(view)
                } else {
                    result.append(contentsOf: flattened)
                }
            } else {
                // Empty collections still host overlays (blank slate). Keep walking children.
                for subview in view.subviews {
                    collect(from: subview, into: &result, excludingContainerSubtree: excludingContainerSubtree)
                }
            }
            return
        }

        if view.fk_canFocus {
            result.append(view)
            return
        }

        for subview in view.subviews {
            collect(from: subview, into: &result, excludingContainerSubtree: excludingContainerSubtree)
        }
    }

    /// 展开容器内部已实例化的可聚焦后代（嵌套容器递归展开）
    private static func collectFlattenedInterior(from view: UIView, into result: inout [UIView]) {
        for subview in view.subviews {
            guard !subview.isHidden, subview.alpha > 0.01 else { continue }

            if let nested = subview as? FocusContainer, subview.isFocusable, nested.canEnterFocus {
                var inner: [UIView] = []
                collectFlattenedInterior(from: subview, into: &inner)
                if inner.isEmpty {
                    result.append(subview)
                } else {
                    result.append(contentsOf: inner)
                }
                continue
            }

            if subview.fk_canFocus {
                result.append(subview)
                continue
            }

            collectFlattenedInterior(from: subview, into: &result)
        }
    }

    /// 向上查找可进入的 FocusContainer 祖先
    static func focusContainer(for view: UIView) -> (UIView & FocusContainer)? {
        var current: UIView? = view
        while let candidate = current {
            if let _ = candidate as? FocusContainer, candidate.isFocusable {
                return candidate as? (UIView & FocusContainer)
            }
            current = candidate.superview
        }
        return nil
    }

    // MARK: - 初始焦点

    /// 选择初始焦点：屏内候选里尽可能靠近左上角（x、y 同等权重）
    static func initialCandidate(in root: UIView) -> UIView? {
        let visibleBounds = root.window?.bounds
        let candidates = onScreenCandidates(from: collectCandidates(in: root), visibleBounds: visibleBounds)
        guard !candidates.isEmpty else { return nil }

        return candidates.min { lhs, rhs in
            preferTopLeft(frameInWindow(of: lhs), frameInWindow(of: rhs))
        }
    }

    private static func preferTopLeft(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let lhsMetric = lhs.minY + lhs.minX
        let rhsMetric = rhs.minY + rhs.minX
        if abs(lhsMetric - rhsMetric) > 0.5 { return lhsMetric < rhsMetric }
        if abs(lhs.minY - rhs.minY) > 0.5 { return lhs.minY < rhs.minY }
        return lhs.minX < rhs.minX
    }

    // MARK: - 方向寻径

    /// 从 origin 出发，在 root 子树内寻找 direction 方向上最合适的下一个焦点。
    /// 仅返回屏内候选；无候选时返回 nil（由 FocusSystem 通知业务方滚动）。
    static func nextCandidate(
        from origin: UIView,
        direction: FocusDirection,
        in root: UIView,
        originFrame: CGRect? = nil,
        excludingContainerSubtree: UIView? = nil
    ) -> UIView? {
        let frame = originFrame ?? frameInWindow(of: origin)
        let visibleBounds = origin.window?.bounds
        let candidates = onScreenCandidates(
            from: collectCandidates(in: root, excludingContainerSubtree: excludingContainerSubtree).filter {
                !$0.isDescendant(of: origin) && !origin.isDescendant(of: $0)
            },
            visibleBounds: visibleBounds
        )
        return bestCandidate(from: frame, direction: direction, candidates: candidates)
    }

    /// 纯几何打分。容器兜底候选使用 `focusEntryFrame`，其余用自身 window frame。
    static func bestCandidate(from originFrame: CGRect, direction: FocusDirection, candidates: [UIView]) -> UIView? {
        var best: UIView?
        var bestScore: Score?

        for candidate in candidates {
            let targetFrame = scoringFrame(for: candidate, direction: direction)
            guard let score = score(from: originFrame, to: targetFrame, direction: direction) else { continue }
            if bestScore == nil || score < bestScore! {
                best = candidate
                bestScore = score
            }
        }
        return best
    }

    /// 参与打分的矩形：容器兜底候选取进入落点，其余取 window frame
    private static func scoringFrame(for candidate: UIView, direction: FocusDirection) -> CGRect {
        if let container = candidate as? (UIView & FocusContainer),
           container.isFocusable,
           let entryFrame = container.focusEntryFrame(from: direction) {
            return entryFrame
        }
        return frameInWindow(of: candidate)
    }

    /// 仅保留屏内可见面积超过 1/3 的候选（≤1/3 可见视为屏外）
    private static func onScreenCandidates(from candidates: [UIView], visibleBounds: CGRect?) -> [UIView] {
        guard let bounds = visibleBounds else { return candidates }
        return candidates.filter { isSufficientlyVisibleInWindow(frameInWindow(of: $0), visibleBounds: bounds) }
    }

    /// 视图在 window 中的可见面积占比是否超过 (1 - offScreenAreaThreshold)，即少于 2/3 在屏外
    static func isSufficientlyVisibleInWindow(_ frame: CGRect, visibleBounds: CGRect) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }
        let intersection = frame.intersection(visibleBounds)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return false }
        let visibleRatio = (intersection.width * intersection.height) / (frame.width * frame.height)
        return visibleRatio > (1 - offScreenAreaThreshold)
    }

    // MARK: - 打分

    /// 排序键（越小越优）：
    /// 1. 横向/纵向投影是否与 origin 重叠（正右方胜过斜右方更近）
    /// 2. 主轴边到边距离
    /// 3. 横轴中心偏移
    /// 4. tie-break
    private struct Score: Comparable {
        let overlapGroup: Int      // 0 = 投影重叠, 1 = 不重叠
        let mainDistance: CGFloat
        let transverseDistance: CGFloat
        let tieBreak: CGFloat

        static func < (lhs: Score, rhs: Score) -> Bool {
            if lhs.overlapGroup != rhs.overlapGroup { return lhs.overlapGroup < rhs.overlapGroup }
            if abs(lhs.mainDistance - rhs.mainDistance) > 0.5 { return lhs.mainDistance < rhs.mainDistance }
            if abs(lhs.transverseDistance - rhs.transverseDistance) > 0.5 { return lhs.transverseDistance < rhs.transverseDistance }
            return lhs.tieBreak < rhs.tieBreak
        }
    }

    /// 目标整体位于 origin 的 direction 方向外侧（允许少量重叠容差），且中心在同侧
    private static func isBeyond(_ target: CGRect, of origin: CGRect, direction: FocusDirection) -> Bool {
        switch direction {
        case .up: return target.maxY <= origin.minY + overlapTolerance && target.midY < origin.midY
        case .down: return target.minY >= origin.maxY - overlapTolerance && target.midY > origin.midY
        case .left: return target.maxX <= origin.minX + overlapTolerance && target.midX < origin.midX
        case .right: return target.minX >= origin.maxX - overlapTolerance && target.midX > origin.midX
        }
    }

    private static func score(from origin: CGRect, to target: CGRect, direction: FocusDirection) -> Score? {
        guard isBeyond(target, of: origin, direction: direction) else { return nil }

        let mainDistance: CGFloat
        switch direction {
        case .up: mainDistance = max(0, origin.minY - target.maxY)
        case .down: mainDistance = max(0, target.minY - origin.maxY)
        case .left: mainDistance = max(0, origin.minX - target.maxX)
        case .right: mainDistance = max(0, target.minX - origin.maxX)
        }

        let overlaps: Bool
        let transverseDistance: CGFloat
        let tieBreak: CGFloat
        if direction.isHorizontal {
            overlaps = target.maxY > origin.minY && target.minY < origin.maxY
            transverseDistance = abs(target.midY - origin.midY)
            tieBreak = target.minY * 10000 + target.minX
        } else {
            overlaps = target.maxX > origin.minX && target.minX < origin.maxX
            transverseDistance = abs(target.midX - origin.midX)
            tieBreak = target.minY * 10000 + target.minX
        }

        return Score(
            overlapGroup: overlaps ? 0 : 1,
            mainDistance: mainDistance,
            transverseDistance: transverseDistance,
            tieBreak: tieBreak
        )
    }

    // MARK: - 工具

    /// 视图 frame 换算到 window 坐标系
    static func frameInWindow(of view: UIView) -> CGRect {
        guard let window = view.window else { return view.frame }
        return view.convert(view.bounds, to: window)
    }

    /// 目标在滚动容器中不完全可见时，滚动使其可见。
    /// UICollectionView 容器自行处理滚动，这里只处理普通 UIScrollView 祖先。
    static func ensureVisible(_ view: UIView) {
        var current = view.superview
        while let candidate = current {
            if let collectionView = candidate as? UICollectionView {
                current = collectionView.superview
                continue
            }
            if let scrollView = candidate as? UIScrollView {
                let frame = view.convert(view.bounds, to: scrollView)
                let visible = scrollView.bounds.inset(by: scrollView.adjustedContentInset)
                if !visible.contains(frame) {
                    scrollView.scrollRectToVisible(frame.insetBy(dx: -8, dy: -8), animated: true)
                }
            }
            current = candidate.superview
        }
    }
}
