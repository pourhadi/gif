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
    
    let hideDivider: Bool
    
    init(metrics: GeometryProxy, bottomAdjustment: CGFloat? = nil, background: AnyView, hideDivider: Bool = false, @ViewBuilder content: () -> Content) {
        self.items = content()
        self.metrics = metrics
        self.background = background
        self.hideDivider = hideDivider
        self.bottomAdjustment = bottomAdjustment
    }
    
    var body: some View {
        Group {
            VStack {
                if !self.hideDivider {
                Divider()
                }
                HStack {
                    self.items
                }.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                Spacer()
                Spacer(minLength: self.bottomAdjustment)
            }
            .background(self.background)
            .frame(height: 40 + (self.bottomAdjustment ?? 0))
        }
//            .offset(y: self.bottomAdjustment != nil ? -(self.bottomAdjustment!) : 0)
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
