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
    
    let bottomAdjustment: CGFloat?
    
    init(metrics: GeometryProxy, bottomAdjustment: CGFloat? = nil, background: AnyView, @ViewBuilder content: () -> Content) {
        self.items = content()
        self.metrics = metrics
        self.background = background
        self.bottomAdjustment = bottomAdjustment
    }
    
    var body: some View {
        Group {
            VStack {
                HStack {
                    self.items
                }
                Spacer(minLength: self.bottomAdjustment)
            }
            .background(self.background)
            .frame(height: 40 + (self.bottomAdjustment ?? 0))
        }.frame(height: metrics.size.height, alignment: .bottom)
            .offset(y: self.bottomAdjustment ?? 0)
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
