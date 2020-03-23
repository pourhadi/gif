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

//@propertyWrapper
//struct Transformed<From, To> {
//    var set: (From?) -> To?
//    var get: (To?) -> From?
//
//    var wrappedValue: To? {
//        get {
//            return get(val)
//        }
//        set {
//            val = set(newValue)
//        }
//    }
//}

extension View {
    @ViewBuilder
    func modify<ModifiedContent>(if condition: Bool = true,
                                    @ViewBuilder _ modifier: (Self) -> ModifiedContent) -> some View where ModifiedContent : View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }
}

@propertyWrapper
struct BoundDefaults<Value, EncodedValue> {
    
    var encode: ((Value) -> EncodedValue)
    var decode: ((EncodedValue) -> Value)
    
    var key: String
    
    var wrappedValue: Binding<EncodedValue> {
        get {
                Binding<EncodedValue>(get: {
                    self.encode(UserDefaults.standard.object(forKey: self.key) as! Value)

                }, set: { val in
                    UserDefaults.standard.set(self.decode(val), forKey: self.key)
                })
        }
        set {  }
    }
    
    init(encode: @escaping (Value) -> EncodedValue, decode: @escaping (EncodedValue) -> Value, key: String, defaultValue: EncodedValue) {
        self.encode = encode
        self.decode = decode
        self.key = key
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(decode(defaultValue), forKey: key)
        }
    }
}

extension BoundDefaults where EncodedValue == Value {
    
    init(key: String, defaultValue: EncodedValue) {
        self.key = key
        self.encode = { $0 }
        self.decode = { $0 }
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(decode(defaultValue), forKey: key)
        }
    }
    
}


@propertyWrapper
struct Defaults<Value, EncodedValue> {
    
    var encode: ((Value) -> EncodedValue)
    var decode: ((EncodedValue) -> Value)
    
    var key: String
    var wrappedValue: EncodedValue {
        get {
                return encode(UserDefaults.standard.object(forKey: key) as! Value)
        }
        set { UserDefaults.standard.set(decode(newValue), forKey: key) }
    }
    
    init(wrappedValue: EncodedValue, encode: @escaping (Value) -> EncodedValue, decode: @escaping (EncodedValue) -> Value, key: String) {
        self.encode = encode
        self.decode = decode
        self.key = key
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(decode(wrappedValue), forKey: key)
        }
    }
}

extension Defaults where EncodedValue == Value {
    
    init(wrappedValue: EncodedValue, key: String) {
        self.key = key
        self.encode = { $0 }
        self.decode = { $0 }
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(decode(wrappedValue), forKey: key)
        }
    }
    
}

extension UIImage {
    
    func resized(_ fitting: CGSize) -> UIImage {
        let r = CGRect(origin: CGPoint.zero, size: self.size.scaledToFit(fitting))
        UIGraphicsBeginImageContextWithOptions(r.size, true, 0.0)
        self.draw(in: r)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? self
    }
    
}

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

extension Int {
    func clamp(_ min: Self = 0, _ max: Self = 2) -> Self {
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
    func clamp(_ min: Self = 0, _ max: Self = 2) -> Self {
        if self > max {
            return max
        }
        
        if self < min {
            return min
        }
        
        return self
    }
}

extension Numeric where Self : Strideable {
    func clamp(_ min: Self = 0, _ max: Self = 1) -> Self {
        if self > max {
            return max
        }
        
        if self < min {
            return min
        }
        
        return self
    }
}

@propertyWrapper
public struct Clamped<N> where N : Numeric, N : Strideable {
    
    let min: N
    let max: N
    
    public init(wrappedValue: N, min: N = 0, max: N = 1) {
        self.min = min
        self.max = max
        self.number = wrappedValue
    }
    
    var number: N = 0
    public var wrappedValue: N {
        get { return number }
        set { number = newValue.clamp(min, max) }
    }
}

extension Double {
    func secondsToFormattedTimestamp() -> String {
        var formatted = String(format: "%.2f", self)

        if (self / 60 > 1) {
            let leftover = self - Double(Int(self / 60.0) * 60)
            let minutes = Int(self / 60.0)
            
            formatted = String(format: "%d:%.2f", minutes, leftover)
        }
        
        return formatted
    }
}

extension CGFloat {
    var percentDisplayString: String {
        return "\(Int(self * 100))"
    }
}

final class DeviceDetails: ObservableObject {
    enum Orientation {
        case portrait
        case landscape
    }
      
    var compact: Bool = false
    
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
        getEditor()
//        EditorView<VideoPlayerView, VideoGifGenerator>().environment(\.colorScheme, .dark).environmentObject(Video.preview.editingContext).background(Color.background).accentColor(Color.text)

    }
    
    
        func getEditor() -> some View {
            return NavigationView {
                EditorView<VideoPlayerView, VideoGifGenerator>()
                    .navigationBarTitle("Create GIF", displayMode: .inline)

            }
                //        .edgesIgnoringSafeArea(self.globalState.visualState.compact ? [.leading, .trailing, .top] : [.top, .bottom])
    //            .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
                .environmentObject(Video.preview.editingContext_blocking)
                .background(Color.background)
                .navigationViewStyle(StackNavigationViewStyle())
        }
}
#endif

public func ExtrapolateValue<V: BinaryFloatingPoint>(from:V, to:V, percent:V) -> V {
    let value = from + ((to - from) * percent)
    return value
}

public func CalculatePercentComplete<V: BinaryFloatingPoint>(start:V, end:V, current:V) -> V {
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
    
    func noAnimations() -> some View {
        return self.transaction { (tx: inout Transaction) in
            tx.disablesAnimations = true
            tx.animation = nil
        }.animation(nil)
    }
    
    
   
    
    func fadedEdges(_ startFadeDistance: CGFloat = 0.1, endFadeDistance: CGFloat = 0.1, startPoint: UnitPoint = .leading, endPoint: UnitPoint = .trailing) -> some View {
        
        var _fadedEdgeGradient: Gradient {
               return Gradient(stops: [Gradient.Stop(color: Color.clear, location: 0),
                                       Gradient.Stop.init(color: Color.black, location: startFadeDistance),
                                       Gradient.Stop.init(color: Color.black, location: 1 - endFadeDistance),
                                       Gradient.Stop.init(color: Color.clear, location: 1)])
           }
        
        return self.mask(LinearGradient(gradient: _fadedEdgeGradient, startPoint: startPoint, endPoint: endPoint))
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
        get{
        return CGPoint(x: self.midX, y: self.midY)

        }
        
        set {
            self.origin = CGPoint(x: newValue.x - (self.size.width / 2), y: newValue.y - (self.size.height / 2))
        }
    }
    
}


