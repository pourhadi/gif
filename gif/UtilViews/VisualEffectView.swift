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
    
}

struct VisualEffectView_Previews: PreviewProvider {
    @State static var effect = UIBlurEffect.init(style: .dark)
    static var previews: some View {
        VisualEffectView(effect: effect)
    }
}
