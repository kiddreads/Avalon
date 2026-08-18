//
//  FocusContainer.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// 容器内部消化方向键的结果
enum FocusContainerResult {
    /// 容器内部已处理，焦点落到返回的视图上
    /// （若目标 cell 尚未布局完成，容器可先返回自身，待布局后再应用视觉）
    case handled(UIView)
    /// 已到达容器边缘，交还给外层空间寻径引擎
    case exit
}

/// 具有"进入层级"能力的容器视图。
///
/// 对外层引擎而言，页面级寻径会展开容器内部已实例化的可聚焦后代参与打分；
/// 命中后调用 `enterFocus(from:preferred:)` 进入容器；容器内导航仍由容器自行管理。
protocol FocusContainer: UIView {
    /// 容器当前是否可以被进入（例如 UICollectionView 无任何 item 时应返回 false）
    var canEnterFocus: Bool { get }

    /// 焦点从 direction 方向进入容器（nil 表示初始聚焦，无方向）。
    /// `preferred` 为页面级空间寻径命中的内部视图时，容器应优先落到该位置。
    /// 返回 nil 表示拒绝进入。
    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView?

    /// 容器内部消化方向键
    func navigateFocus(_ direction: FocusDirection, current: UIView?) -> FocusContainerResult

    /// 容器内当前聚焦的后代视图（可能因滚动复用暂时为 nil）
    var currentFocusedDescendant: UIView? { get }

    /// 焦点记忆：焦点离开后再次进入时优先恢复的后代
    var lastFocusedDescendant: UIView? { get }

    /// 焦点离开容器（焦点记忆保留，视觉清除）
    func resignFocus()

    /// 确定键落在容器内部焦点上时的默认行为（如触发 didSelectItemAt），返回是否消费
    func performPrimaryActionOnFocused() -> Bool

    /// 焦点位于容器内部时生效的额外命令
    func containerFocusCommands() -> [FocusCommand]

    /// 供外层空间寻径打分的"进入落点"参考矩形（window 坐标系）。
    /// 全屏容器与页面上其他可聚焦视图（如悬浮工具条）frame 重叠时，
    /// 容器整体 frame 会被半平面过滤排除导致无法进入；
    /// 返回进入后实际会落焦的位置可让打分准确。返回 nil 表示使用容器整体 frame。
    func focusEntryFrame(from direction: FocusDirection) -> CGRect?
}

extension FocusContainer {
    var canEnterFocus: Bool { true }
    func containerFocusCommands() -> [FocusCommand] { [] }
    func focusEntryFrame(from direction: FocusDirection) -> CGRect? { nil }

    func enterFocus(from direction: FocusDirection?) -> UIView? {
        enterFocus(from: direction, preferred: nil)
    }

    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView? {
        _ = preferred
        return nil
    }
}
