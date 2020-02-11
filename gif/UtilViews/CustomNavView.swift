//
//  CustomNavView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/28/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI

struct CustomNavView<Content>: View where Content: View {
    
    func navBarVisible(_ visible: Bool) -> some View {
        CustomNavView(title: self.title, leadingItem: self.leadingItem, trailingItem: self.trailingItem, navBarVisible: visible, content: self.content)
    }
    
    let leadingItem: AnyView
    let trailingItem: AnyView
    let content: () -> Content
    let title: String
    let navBarVisible: Bool
    
    init(title: String, leadingItem: AnyView, trailingItem: AnyView, navBarVisible: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.leadingItem = leadingItem
        self.trailingItem = trailingItem
        self.content = content
        self.navBarVisible = navBarVisible
    }
    
    var body: some View {
        GeometryReader { metrics in
            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        Spacer()
                        Text(self.title).font(.headline)
                        Spacer()
                    }
                    HStack {
                        self.leadingItem
                        Spacer()
                        self.trailingItem
                    }
                }
                .frame(height: 40)
                .padding([.leading, .trailing], 20)
                .background(VisualEffectView.blur(.systemChromeMaterial)
                .edgesIgnoringSafeArea(.all))
                    
                .offset(x: 0, y: !self.navBarVisible ? -(40 + metrics.safeAreaInsets.top) : 0)
                .zIndex(1)
                Divider().edgesIgnoringSafeArea([.leading, .trailing])
                    .offset(x: 0, y: !self.navBarVisible ? -(40 + metrics.safeAreaInsets.top) : 0)
                
                self.content().frame(height: metrics.size.height - (40)).zIndex(0)
            }
            
        }
    }
}

