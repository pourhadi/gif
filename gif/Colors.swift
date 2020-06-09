//
//  Colors.swift
//  gif
//
//  Created by dan on 12/8/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
//UIColor(hue: 0.97, saturation: 0.80, brightness: 0.98, alpha: 1.00)

var _accentHue: Binding<CGFloat> = Binding<CGFloat>(get: { () -> CGFloat in
            CGFloat(UserDefaults.standard.float(forKey: "_accentHue"))

}) { (newValue) in
    UserDefaults.standard.set(newValue, forKey: "_accentHue")
    
    _accentColorBinding.wrappedValue = UIColor(hue: newValue, saturation: _accentSaturation.wrappedValue, brightness: _accentBrightness.wrappedValue, alpha: 1.00)
    
    AccentPublisher.shared.publisher = Color.accent
}

var _accentSaturation: Binding<CGFloat> = Binding<CGFloat>(get: { () -> CGFloat in
            CGFloat(UserDefaults.standard.float(forKey: "_accentSat"))

}) { (newValue) in
    UserDefaults.standard.set(newValue, forKey: "_accentSat")
    
    _accentColorBinding.wrappedValue = UIColor(hue: _accentHue.wrappedValue, saturation: newValue, brightness: _accentBrightness.wrappedValue, alpha: 1.00)
    
    AccentPublisher.shared.publisher = Color.accent
}

var _accentBrightness: Binding<CGFloat> = Binding<CGFloat>(get: { () -> CGFloat in
            CGFloat(UserDefaults.standard.float(forKey: "_accentBrightness"))

}) { (newValue) in
    UserDefaults.standard.set(newValue, forKey: "_accentBrightness")
    
    _accentColorBinding.wrappedValue = UIColor(hue: _accentHue.wrappedValue, saturation: _accentSaturation.wrappedValue, brightness: newValue, alpha: 1.00)
    
    AccentPublisher.shared.publisher = Color.accent
}

var _accentColorBinding: Binding<UIColor> = Binding<UIColor>(get: { () -> UIColor in
    return _accent
}) { (color) in
//    _accent = color
}

class AccentPublisher {
    static let shared = AccentPublisher()
    
    @Published var publisher: Color = Color.accent
}

//var _accent: UIColor = UIColor(hue: _accentHue.wrappedValue, saturation: _accentSaturation.wrappedValue, brightness: 1.0, alpha: 1.00)

var _accent: UIColor {
    UIColor.init { (trait) -> UIColor in
        trait.userInterfaceStyle == .dark ? .white : .black
    }
}

//let _accent = UIColor(red: 0.94, green: 0.70, blue: 0.18, alpha: 1.00)
//let _accent = UIColor(hue: 0.80, saturation: 0.72, brightness: 0.75, alpha: 1.00)
extension Color {
    
    static var accent: Color {  Color.primary }
    static var text = Color.primary
    static var background: Color { Color(UIColor.systemBackground) } //.brightness(-0.1)
//    static var background = Color(UIColor(red: 0.00, green: 0.09, blue: 0.16, alpha: 1.00))
//    static var background = Color(white: 0.1)
   // static var text = Color.white
}


extension Color : Identifiable {
    public var id: Int { self.hashValue }
    
    
}
struct Colors_Previews: PreviewProvider {
    
    static var colors: [Color] = {
        var hue: CGFloat = 0
        var arr = [Color]()
        while hue < 1 {
            arr.append(Color(UIColor(hue: hue, saturation: 0.8, brightness: 0.99, alpha: 1.00)))
            
            hue += 0.05
        }
        
        return arr
    }()
    
    static var previews: some View {
        VStack {
            ForEach(colors) { color in
                Text("Test").foregroundColor(color)
                    .padding(10)
            }
            }.background(Color.black).scaledToFill()
    }
}
