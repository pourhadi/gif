//
//  Common.swift
//  gif
//
//  Created by Daniel Pourhadi on 6/2/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

let serialQueue = DispatchQueue(label: "com.pourhadi.gif.global", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)

class ContextStore {
    
    static var context: AnyObject?
    
}


struct PlayState {
    
    @Clamped
    var currentPlayhead: CGFloat = 0.0
    
    var playing: Bool = false
    
    var previewing = false
}


struct UnitSpaceEdgeInsets {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0
    var top: CGFloat = 0
    var bottom: CGFloat = 0
    
    init() {}
    
    init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
    
    public static func * (lhs: UnitSpaceEdgeInsets, rhs: CGSize) -> EdgeInsets {
        return EdgeInsets(top: lhs.top * rhs.height, leading: lhs.leading * rhs.width, bottom: lhs.bottom * rhs.height, trailing: lhs.trailing * rhs.width)
    }
    
    public static func + (lhs: UnitSpaceEdgeInsets, rhs: UnitSpaceEdgeInsets) -> UnitSpaceEdgeInsets {
        return UnitSpaceEdgeInsets(top: lhs.top + rhs.top, leading: lhs.leading + rhs.leading, bottom: lhs.bottom + rhs.bottom, trailing: lhs.trailing + rhs.trailing)
    }
}

class CropState: ObservableObject, Identifiable {
    var id = UUID()
    
    @Published var visible = false
    
    
    @Published var cropUnitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    @Published var inset = EdgeInsets.zero
    
    
    var tmpInset = EdgeInsets.zero
    
    var tmpFrame = CGRect.zero
    
    var aspectRatio: CGFloat = 1
    
    init() {}
    init(aspectRatio: CGFloat) {
        self.aspectRatio = aspectRatio
    }
}

protocol Editable {
    var url: URL { get }
    
}

public extension EdgeInsets {
    static var zero: EdgeInsets {
        return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }
    
    static func + (lhs: EdgeInsets, rhs: EdgeInsets) -> EdgeInsets {
        return EdgeInsets(top: lhs.top + rhs.top, leading: lhs.leading + rhs.leading, bottom: lhs.bottom + rhs.bottom, trailing: lhs.trailing + rhs.trailing)
    }
    
    func uiEdgeInsets() -> UIEdgeInsets {
        UIEdgeInsets(top: self.top, left: self.leading, bottom: self.bottom, right: self.trailing)
    }
    
    mutating func clamp() {
        if self.top < 0 {
            self.top = 1
        }
        
        if self.bottom < 0 {
            self.bottom = 1
        }
        
        if self.leading < 0 {
            self.leading = 1
        }
        
        if self.trailing < 0 {
            self.trailing = 1
        }
    }
    
    func unitSpaceInsets(actualSize: CGSize) -> EdgeInsets {
        var new = self
        new.top /= actualSize.height
        new.leading /= actualSize.width
        new.bottom /= actualSize.height
        new.trailing /= actualSize.width
        return new
    }
}
