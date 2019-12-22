//
//  GIFView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct GIFView: View {
    let gif: GIF?
    
    @Binding var fullscreen: Bool
    @State var animating = true
    
    let toolbarBuilder: (_ metrics: GeometryProxy, _ background: AnyView) -> AnyView
    
    var body: some View {
        Group {
            GeometryReader { metrics in
                
                GIFImageView(isAnimating: self.animating, gif: self.gif)
                    .onTapGesture {
                        withAnimation {
                            self.fullscreen.toggle()
                        }
                }.edgesIgnoringSafeArea([.top, .bottom]).frame(height: metrics.size.height + (metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom)).offset(y: self.fullscreen ? -metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom : -metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom)
                
                if !self.fullscreen {
                    self.toolbarBuilder(metrics, VisualEffectView(effect: .init(style: .dark)).asAny).transition(.opacity)
                        //.offset(y: metrics.safeAreaInsets.bottom)
                }
            }
        }.edgesIgnoringSafeArea([.top, .bottom])
        
    }
    
}


