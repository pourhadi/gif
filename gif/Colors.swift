//
//  Colors.swift
//  gif
//
//  Created by dan on 12/8/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Foundation
import SwiftUI
let _accent = UIColor(red: 0.94, green: 0.70, blue: 0.18, alpha: 1.00)
//let _accent = UIColor(hue: 0.80, saturation: 0.72, brightness: 0.75, alpha: 1.00)
extension Color {
    
    static var accent = Color(_accent)
    static var text = Color.primary
    static var background = Color(UIColor.systemBackground) //.brightness(-0.1)
//    static var background = Color(UIColor(red: 0.00, green: 0.09, blue: 0.16, alpha: 1.00))
//    static var background = Color(white: 0.1)
   // static var text = Color.white
}
