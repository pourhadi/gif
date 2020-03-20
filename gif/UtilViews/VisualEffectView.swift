//
//  VisualEffectView.swift
//  gif
//
//  Created by dan on 12/5/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct VisualEffectView: UIViewRepresentable {
    
    let effect: UIBlurEffect
        
    func makeUIView(context: UIViewRepresentableContext<VisualEffectView>) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<VisualEffectView>) {
        uiView.effect = self.effect
    }
    
    typealias UIViewType = UIVisualEffectView
    
    static func blur(_ style: UIBlurEffect.Style) -> VisualEffectView {
        return VisualEffectView(effect: .init(style: style))
    }
    
    static func barBlur() -> some View {
        BarVisualEffectView()
    }
    
}

 
struct BarVisualEffectView : View {
    
    @Environment(\.colorScheme) var colorScheme
    
    var body : some View {
        VisualEffectView.blur(.prominent)
//            .modify(if: colorScheme == .dark, { (content)  in
//                content.overlay(Color.black.opacity(0.2))
//            })
    }
}
 

//struct TestBlurView : View {
//    
//    var body : some View {
//        
//        Rectangle().fill(Color.black.opacity(0.8)).blur(radius: 10, opaque: false)
//    }
//}
//
//struct VisualEffectView_Previews: PreviewProvider {
//    @State static var effect = UIBlurEffect.init(style: .regular)
//    static var previews: some View {
////        VisualEffectView(effect: effect)
//        ZStack {
//            GlobalPreviewView().zIndex(0)
//            TestBlurView().zIndex(1)
//        }
//    }
//}
