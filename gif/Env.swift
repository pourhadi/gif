//
//  Env.swift
//  gif
//
//  Created by dan on 12/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import CoreHaptics
import Combine

//public protocol EnvironmentKey {
//
//    associatedtype Value
//
//    static var defaultValue: Self.Value { get }
//}



extension ViewAlignment: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine("\(self)")
    }
}

protocol AnchoredFrameKey : PreferenceKey where Value == AnchoredFrame {}

extension AnchoredFrameKey {
    static var defaultValue: AnchoredFrame { return AnchoredFrame() }
    
    static func reduce(value: inout AnchoredFrame, nextValue: () -> AnchoredFrame) {
        let n = nextValue()
        
        if let bounds = n.bounds {
            value.bounds = bounds
        }
        
        if let center = n.center {
            value.center = center
        }
        
        
    }
    
    

}

struct AnchoredFrame {
    var bounds: Anchor<CGRect>?
    var center: Anchor<CGPoint>?
    
}

struct SelectedItemFrameKey: AnchoredFrameKey {}

extension View {
    
    func saveAnchorFrame<K>(to key: K.Type = K.self, condition: Bool = true) -> some View where K : AnchoredFrameKey {
        
        return self
 
            .anchorPreference(key: K.self, value: .bounds, transform: { anchor  in
                var val = AnchoredFrame()
                if condition {
                    val.bounds = anchor
                } else {
                    val.bounds = nil
                }
                return val
            })
        
        
    }
}

struct EditorPreferences {
    var settingsButtonRect : Anchor<CGRect>? = nil
    
    var editorBounds : Anchor<CGRect>? = nil
    
    var mainPlayerBounds : Anchor<CGRect>? = nil
    var mainPlayerCenter : Anchor<CGPoint>? = nil
    
    var startPlayerBounds : Anchor<CGRect>? = nil
    var startPlayerCenter : Anchor<CGPoint>? = nil
    
    var endPlayerBounds : Anchor<CGRect>? = nil
    var endPlayerCenter : Anchor<CGPoint>? = nil
    
    static var boundsPaths: [WritableKeyPath<EditorPreferences, Anchor<CGRect>?>] = [\EditorPreferences.settingsButtonRect,
                                                                                     \EditorPreferences.editorBounds,
                                                                                     \EditorPreferences.mainPlayerBounds,
                                                                                     \EditorPreferences.startPlayerBounds,
                                                                                     \EditorPreferences.endPlayerBounds]
    
    static var pointsPaths: [WritableKeyPath<EditorPreferences, Anchor<CGPoint>?>] = [\EditorPreferences.mainPlayerCenter,
                                                                                      \EditorPreferences.startPlayerCenter,
                                                                                      \EditorPreferences.endPlayerCenter]
    
}


struct EditorPreferencesKey : PreferenceKey {
    static var defaultValue: EditorPreferences = EditorPreferences()
    
    static func reduce(value: inout EditorPreferences, nextValue: () -> EditorPreferences) {
        let next = nextValue()
        
        for path in EditorPreferences.boundsPaths {
            if let val = next[keyPath: path] {
                value[keyPath: path] = val
            }
        }
        
        for path in EditorPreferences.pointsPaths {
            if let val = next[keyPath: path] {
                value[keyPath: path] = val
            }
        }
    }
    
    typealias Value = EditorPreferences
    
    
}

struct CropPreferenceData {
    var bounds: [UnitPoint : Anchor<CGRect>] = [:]
    
    var leadingTopBounds : Anchor<CGRect>? = nil
    var leadingBottomBounds : Anchor<CGRect>? = nil
    var trailingTopBounds: Anchor<CGRect>? = nil
    var trailingBottomBounds: Anchor<CGRect>? = nil
    
    var selectionViewBounds: Anchor<CGRect>? = nil
    
    var contentBounds : Anchor<CGRect>? = nil
    
    var contentTop : Anchor<CGPoint>? = nil
    
    var contentTopLeading : Anchor<CGPoint>? = nil
    var contentBottomTrailing : Anchor<CGPoint>? = nil
}

struct CropPreferenceKey : PreferenceKey {
    static var defaultValue: CropPreferenceData = CropPreferenceData()
    
    static func reduce(value: inout CropPreferenceData, nextValue: () -> CropPreferenceData) {
        let next = nextValue()
        
        value.bounds.merge(next.bounds) { (lhs, rhs) -> Anchor<CGRect> in
            rhs
        }
        
        if let selectionB = next.selectionViewBounds {
            value.selectionViewBounds = selectionB
        }
        
        if let cB = next.contentBounds {
            value.contentBounds = cB
        }
        
        if let contentTop = next.contentTop {
            value.contentTop = contentTop
        }
        
        if let ctl = next.contentTopLeading {
            value.contentTopLeading = ctl
        }
        
        if let cbt = next.contentBottomTrailing {
            value.contentBottomTrailing = cbt
        }
        
    }
    
    typealias Value = CropPreferenceData
    
    
}

class KeyboardManager: ObservableObject {
    @Published var keyboardVisible = false
    
    @Published var keyboardHeight: CGFloat = 0
    
    var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil) { (_) in
            self.keyboardVisible = true
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil) { (_) in
            self.keyboardVisible = false
        }
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification).sink { note in
            
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                Async {
                    self.keyboardHeight = frame.size.height
                }
            }
            
        }.store(in: &self.cancellables)
    }
}

struct KeyboardManagerKey: EnvironmentKey {
    static var defaultValue: KeyboardManager = KeyboardManager()
    
    typealias Value = KeyboardManager
    
    
}


extension EnvironmentValues {
    var keyboardManager: KeyboardManager {
        get {
            return self[KeyboardManagerKey.self]
        }
        set {
            self[KeyboardManagerKey.self] = newValue
        }
    }
}


struct DeviceDetailsKey: EnvironmentKey {
    static let defaultValue: DeviceDetails = DeviceDetails()
}

extension EnvironmentValues {
    var deviceDetails: DeviceDetails {
        get {
            return self[DeviceDetailsKey.self]
        }
        set {
            self[DeviceDetailsKey.self] = newValue
        }
    }
}

class TimelineState: ObservableObject {
    
    @Published var isDragging = false
    
}

struct TimelineStateKey: EnvironmentKey {
    static let defaultValue: TimelineState = TimelineState()
}

extension EnvironmentValues {
    var timelineState: TimelineState {
        get {
            return self[TimelineStateKey.self]
        }
        set {
            self[TimelineStateKey.self] = newValue
        }
    }
}




struct HUDAlertStateKey: EnvironmentKey {
    static let defaultValue: HUDAlertState = HUDAlertState.global
}

extension EnvironmentValues {
    var hudAlertState: HUDAlertState {
        get {
            return self[HUDAlertStateKey.self]
        }
        set {
            self[HUDAlertStateKey.self] = newValue
        }
    }
}


struct HapticControllerKey: EnvironmentKey {
    static let defaultValue: HapticController = HapticController()
}

extension EnvironmentValues {
    var hapticController: HapticController {
        get {
            return self[HapticControllerKey.self]
        }
        set {
            self[HapticControllerKey.self] = newValue
        }
    }
}


class HapticController {
        
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    init() {
        feedbackGenerator.prepare()
    }
    
    func longPressHaptic() {
        
        feedbackGenerator.impactOccurred(intensity: 1.0)

    }
    
}


struct AuthorizedPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
    
    typealias Value = Bool
    
    
}
