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

enum Alignment {
    case leadingTop
    case trailingBottom
}

extension View {

    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
    
    var asAny: AnyView {
        return AnyView(self)
    }
    
    func centered(_ axis: Axis = .horizontal) -> some View {
        Stack(axis) {
            Spacer()
            self
            Spacer()
        }
    }
    
    func align(_ axis: Axis, _ alignment: Alignment) -> some View {
        if alignment == .leadingTop {
            return Stack(axis) {
                self
                Spacer()
                Spacer()
            }.asAny
        } else {
            return Stack(axis) {
                Spacer()
                Spacer()
                self
            }.asAny
        }
    }
}

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Image {
    
    static func symbol(_ named: String, useDefault: Bool = false) -> Self {
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        let img = UIImage(systemName: named, withConfiguration: useDefault ? .unspecified : config)
        
        return Image(uiImage: img ?? UIImage())
    }
}

struct WrappedUIView<V: UIView>: UIViewRepresentable {
    
    let initBlock: ()->V
    let updateBlock: ((_ uiView: V, _ context: UIViewRepresentableContext<WrappedUIView<V>>) -> Void)?
    
    init(initBlock: @escaping ()->V, _ updateBlock:((_ uiView: V, _ context: UIViewRepresentableContext<WrappedUIView<V>>) -> Void)?) {
        self.initBlock = initBlock
        self.updateBlock = updateBlock
    }
    
    func makeUIView(context: UIViewRepresentableContext<WrappedUIView<V>>) -> V {
        return initBlock()
    }
    
    func updateUIView(_ uiView: V, context: UIViewRepresentableContext<WrappedUIView<V>>) {
        self.updateBlock?(uiView, context)
    }
    
    typealias UIViewType = V

}


final class DeviceDetails: ObservableObject {
    enum Orientation {
        case portrait
        case landscape
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
        _observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            guard let device = note.object as? UIDevice else {
                return
            }
            if device.orientation.isPortrait {
                self.orientation = .portrait
            }
            else if device.orientation.isLandscape {
                self.orientation = .landscape
            }
        }
    }
      
    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
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


struct GlobalPreviewView: View {
    @State var generator = GifGenerator.init(video: Video.preview)
    @State var visualState = VisualState()
    var body: some View {
        EditorView(gifGenerator: $generator, visualState: $visualState).environmentObject(Video.preview).environment(\.colorScheme, .dark).background(Color.background).accentColor(Color.white)

    }
    
}
