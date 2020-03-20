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
                .background(VisualEffectView.barBlur()
                    .edgesIgnoringSafeArea(.all))
                
                .offset(x: 0, y: !self.navBarVisible ? -(40 + metrics.safeAreaInsets.top) : 0)
                .zIndex(1)
                Divider().edgesIgnoringSafeArea([.leading, .trailing])
                    .offset(x: 0, y: !self.navBarVisible ? -(40 + metrics.safeAreaInsets.top) : 0)
                
                self.content().frame(height: metrics.size.height - 40).zIndex(0)
            }
        }
    }
}

class _NoTouchView : UIView {
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }
}

struct NoTouchView : UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<NoTouchView>) -> _NoTouchView {
        let v = _NoTouchView()
        v.backgroundColor = UIColor.black
        return v
    }
    
    func updateUIView(_ uiView: _NoTouchView, context: UIViewRepresentableContext<NoTouchView>) {
        
    }
    
    
    typealias UIViewType = _NoTouchView
    
    
    
    
}

struct FadeNavView<Content, Leading, Trailing>: View where Content: View, Leading: View, Trailing: View {
    func navBarVisible(_ visible: Bool) -> some View {
        FadeNavView(title: self.title, leadingItem: self.leadingItem, trailingItem: self.trailingItem, navBarVisible: visible, content: self.content)
    }
    
    let leadingItem: Leading?
    let trailingItem: Trailing?
    let content: () -> Content
    let title: String
    let navBarVisible: Bool
    
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    
    init(title: String, leadingItem: Leading?, trailingItem: Trailing?, navBarVisible: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.leadingItem = leadingItem
        self.trailingItem = trailingItem
        self.content = content
        self.navBarVisible = navBarVisible
    }
    
    var body: some View {
        ZStack {
            VStack {
                ZStack {

                    HStack(spacing: 12) {
                        Spacer()
                        self.leadingItem?
                            .allowsHitTesting(true)
                            
                            .background({
                                GeometryReader { metrics in
                                    VisualEffectView.blur(.regular)
                                        .brightness(0.1)
                                        .cornerRadius(metrics.size.height / 2)
                                }
                                
                            }())
                        self.trailingItem?
                            .allowsHitTesting(true)
                            .background({
                                GeometryReader { metrics in
                                    VisualEffectView.blur(.regular)
                                        .brightness(0.1)
                                        
                                        .cornerRadius(metrics.size.height / 2)
                                }
                                
                            }())
                    }
                    .offset(y: self.verticalSizeClass != .compact ? -5 : 10)
                .zIndex(1)
                }
                
                .frame(height: self.verticalSizeClass == .compact ? 40 : 100)
                .padding([.leading, .trailing], 20)
                
                Spacer()
            }
            
            .zIndex(2)
            
            self.content()
                
                .zIndex(0)
        }
    }
    
    var background: some View {
        NoTouchView()
            //                        LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0)]), startPoint: .top, endPoint: .bottom)
            
//            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .edgesIgnoringSafeArea(.all)
    }
}
