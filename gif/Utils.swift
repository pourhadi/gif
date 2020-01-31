//
//  Utils.swift
//  gif
//
//  Created by dan on 11/27/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

public func Delayed(_ seconds: Double, _ block: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        block()
    }
}

public func Async(_ block: @escaping () -> Void) {
    DispatchQueue.main.async(execute: block)
}

extension CGSize {
    
    func scaledToFit(_ other: CGSize) -> CGSize {
        let widthRatio = other.width / self.width,
        heightRatio = other.height / self.height
        let bestRatio = min(widthRatio, heightRatio)

        // output
        let newWidth = self.width * bestRatio,
        newHeight = self.height * bestRatio
    
        return CGSize(width: newWidth, height: newHeight)
    }
    
    func fittingHeight(_ fitTo: CGFloat) -> CGSize {
        let heightRatio = fitTo / abs(self.height)
        let newWidth = abs(self.width) * heightRatio,
            newHeight = abs(self.height) * heightRatio
        
            return CGSize(width: newWidth, height: newHeight)
    }
    
    func fittingWidth(_ fitTo: CGFloat) -> CGSize {
        let widthRatio = fitTo / abs(self.width)
        let newWidth = abs(self.width) * widthRatio,
            newHeight = abs(self.height) * widthRatio
        
            return CGSize(width: newWidth, height: newHeight)
    }
    
    func absolute() -> CGSize {
        return CGSize(width: abs(self.width), height: abs(self.height))
    }
    
    var displayString: String {
        return "\(Int(self.width)) x \(Int(self.height))"
    }
}

extension FloatingPoint {
    func clamp(min: Self = 0, max: Self = 1) -> Self {
        if self > max {
            return max
        }
        
        if self < min {
            return min
        }
        
        return self
    }
}

extension CGFloat {
    var percentDisplayString: String {
        return "\(Int(self * 100))"
    }
}

final class DeviceDetails {
    enum Orientation {
        case portrait
        case landscape
    }
      
    var compact: Bool {
        return self.uiIdiom == .phone && self.orientation == .landscape
    }
    
    @Published var orientation: Orientation
    
    public var uiIdiom: UIUserInterfaceIdiom {
        return UIDevice.current.userInterfaceIdiom
    }
    
    private var _observer: NSObjectProtocol?
      
    init() {
        // fairly arbitrary starting value for 'flat' orientations
        if UIDevice.current.orientation.isLandscape {
            self.orientation = .landscape
        }
        else {
            self.orientation = .portrait
        }
          
        // unowned self because we unregister before self becomes invalid
        _observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil) { [weak self] note in
            guard let device = note.object as? UIDevice else {
                return
            }
            if device.orientation.isPortrait {
                self?.orientation = .portrait
            }
            else if device.orientation.isLandscape {
                self?.orientation = .landscape
            }
        }
    }
      
    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}  

extension Alignment {
    
    var unitPoint: UnitPoint {
        var point = UnitPoint()
        
        switch self.horizontal {
        case .center: point.x = 0.5
        case .leading: point.x = 0
        case .trailing: point.x = 1
        default:
            break
        }
        
        switch self.vertical {
        case .center: point.y = 0.5
        case .top: point.y = 0
        case .bottom: point.y = 1
        default:
            break
        }
        
        return point
    }
    
}
//struct GlobalPreviewView: View {
//
//    @State var ready = true
//    @State var activeView = ActiveView.editor
//    @State var activePopover = ActivePopover.gifSettings
//    @State var presentedPopover = false
//    @State var visualState = VisualState()
//    var video = Video.preview
//    @State var generator = GifGenerator.init(video: Video.preview)
//
//    var body: some View {
//        NavigationView {
//            VStack(spacing:8) {
//                TopControlView(presentedPopover: $presentedPopover, activePopover: $activePopover, activeView: $activeView, ready: $ready)
//                EditorView(gifGenerator: $generator, visualState: visualState)
//            }.background(Color.primary.opacity(0.1))
//        }.background(Color.black).environmentObject(video).environment(\.colorScheme, .dark).accentColor(Color.white).navigationBarHidden(true).edgesIgnoringSafeArea(.top)
//    }
//}

extension URL {
    
    static var empty: URL {
        return URL(fileURLWithPath: "")
    }
}

#if MAIN_TARGET
struct GlobalPreviewView: View {
    @State var visualState = VisualState()
    var body: some View {
        EditorView<VideoPlayerView, VideoGifGenerator>().environment(\.colorScheme, .dark).environmentObject(Video.preview.editingContext).background(Color.background).accentColor(Color.text)

    }
    
}
#endif

public func ExtrapolateValue(from:CGFloat, to:CGFloat, percent:CGFloat) -> CGFloat {
    let value = from + ((to - from) * percent)
    return value
}

public func CalculatePercentComplete(start:CGFloat, end:CGFloat, current:CGFloat) -> CGFloat {
    let x = end - start
    return (current - start) / x
}

enum Scaled {
    case toFit
    case toFill
}


extension View {
    
    func scaled(_ how: Scaled) -> some View {
        switch how {
        case .toFill:
            return self.scaledToFill().any
        case .toFit:
            return self.scaledToFit().any
        }
    }
    
}

extension CGRect {
    
    static func *= ( lhs: inout CGRect, rhs: CGSize) {
        lhs.origin.x *= rhs.width
        lhs.origin.y *= rhs.height
        lhs.size.width *= rhs.width
        lhs.size.height *= rhs.height
    }
    
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
    
}
