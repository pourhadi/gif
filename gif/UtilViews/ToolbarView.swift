//
//  ToolbarView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct ToolbarView<Content>: View where Content: View {
    
    let items: Content
    let metrics: GeometryProxy
    
    let background: AnyView
    init(metrics: GeometryProxy, background: AnyView, @ViewBuilder content: () -> Content) {
        self.items = content()
        self.metrics = metrics
        self.background = background
    }
    
    var body: some View {
        VStack {
            HStack {
                self.items
            }
            Spacer(minLength: metrics.safeAreaInsets.bottom)
        }
        //.opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
            .background(self.background)
            .frame(height: 60 + metrics.safeAreaInsets.bottom)
            .position(x: metrics.size.width / 2, y: metrics.size.height - metrics.safeAreaInsets.bottom)
    }
}

struct ToolbarActiveModifier: ViewModifier {
    typealias Body = Never
    
    
    
    
}
//
//struct ToolbarView_Previews: PreviewProvider {
//    static var previews: some View {
//        ToolbarView()
//    }
//}
