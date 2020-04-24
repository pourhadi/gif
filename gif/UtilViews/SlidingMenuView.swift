//
//  SlidingMenuView.swift
//  giffed
//
//  Created by Daniel Pourhadi on 4/11/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI

struct SlidingMenuWrapperView<Content>: View, Identifiable where Content: View {
    var id = UUID()
    
    let content: Content
    
    
    var body: some View {
        content

    }
}

struct _SlidingMenuContent<Content>: View, Equatable where Content: View {
    static func == (lhs: _SlidingMenuContent<Content>, rhs: _SlidingMenuContent<Content>) -> Bool {
        lhs.items.count == rhs.items.count &&
            lhs.itemWidth == rhs.itemWidth &&
            lhs.selectedIndex == rhs.selectedIndex
    }
    
    let items: [Content]
    let itemWidth: CGFloat
    let selectedIndex: Int
    var body: some View {
        HStack(spacing: 0) {
            ForEach(self.items.map { SlidingMenuWrapperView(content: $0) }) { item in
                item
                    .frame(width: self.itemWidth)
//                    .overlay(Color.init(red: Double.random(in: 0..<1), green: Double.random(in: 0..<1), blue: Double.random(in: 0..<1)))
            }
        }
    }
}

struct SlidingMenuView<Content>: View where Content: View {
    let items: [Content]
    
    let itemWidth: CGFloat
    
    @Binding var selectedIndex: Int
    
    @Binding var touchDown: Bool
    
    let selectionChanged: (Int) -> Void
    
    init(items: [Content], itemWidth: CGFloat, selectedIndex: Binding<Int>, touchDown: Binding<Bool>, selectionChanged: @escaping (Int) -> Void) {
        self.items = items
        self.itemWidth = itemWidth
        self._selectedIndex = selectedIndex
        self._touchDown = touchDown
        self.selectionChanged = selectionChanged
    }
    
    class Store {
        var tmpOffset: CGFloat = 0
    }
    
    @State var store = Store()
    
    @State var offset: CGFloat = 0
    
    @State var gestureState = GestureState<CGFloat>(initialValue: 0)
    
    var body: some View {
        GeometryReader { metrics in
            _SlidingMenuContent(items: self.items, itemWidth: self.itemWidth, selectedIndex: self.selectedIndex)
                                .equatable()
                
                .offset(x: self.offset + (metrics.size.width / 2) - (self.itemWidth / 2))
                .frame(width: metrics.size.width, alignment: .leading)
        }
        .overlay(GeometryReader { _ in
            Rectangle()
                .fill(Color.clear)
            //                .frame(width: metrics.size.width, height: metrics.size.height)
        }
        .contentShape(Rectangle())
        .gesture(self.dragGesture)
        )
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            
            .onChanged { v in
                
                if !self.touchDown {
                    Async {
//                        self.$touchDown.animation(Animation.linear(duration: 0.1)).wrappedValue = true
                        self.touchDown = true
                    }
                }

                let offset = v.translation.width + self.store.tmpOffset
                Async {
                    self.offset = offset
                }
                var index = Int(-((offset - (self.itemWidth / 2)) / (self.itemWidth)))
                if index < 0 {
                    index = 0
                } else if index > self.items.count - 1 {
                    index = self.items.count - 1
                }
                
                if index != self.selectedIndex {
                        self.selectedIndex = index
                        self.selectionChanged(self.selectedIndex)
                }
            }
            .onEnded { v in
                
                if self.touchDown {
                    Delayed(0.2) {
                        self.$touchDown.animation(Animation.default).wrappedValue = false
                    }
                }
                
                var index = Int(-((v.translation.width + self.store.tmpOffset - (self.itemWidth / 2)) / (self.itemWidth)))
//                let diff = (v.predictedEndTranslation.width - v.translation.width)
//                if diff <= (self.itemWidth / 2) {
//                    index += 1
//                } else if diff >= (self.itemWidth / 2) {
//                    index -= 1
//                }
                
                if index < 0 {
                    index = 0
                } else if index > self.items.count - 1 {
                    index = self.items.count - 1
                }
                
                let off = CGFloat(index) * -self.itemWidth
                
                Async {
                    withAnimation(Animation.spring(response: 0.2)) {
                        self.offset = CGFloat(off)
                    }
                }
                self.store.tmpOffset = CGFloat(off)
                
                
                if index != self.selectedIndex {
                        self.selectedIndex = index
                        self.selectionChanged(self.selectedIndex)
                }
            }
    }
}
