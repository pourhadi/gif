//
//  Stack.swift
//  gif
//
//  Created by dan on 12/6/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI


struct Stack<Content> : View where Content : View {
    var body: AnyView
    
    @inlinable public init(_ stackType: Axis, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        switch stackType {
        case .horizontal:
            self.body = AnyView(HStack(spacing: spacing, content: content))
        case .vertical:
            self.body = AnyView(VStack(spacing: spacing, content: content))
            
        }
    }
}
