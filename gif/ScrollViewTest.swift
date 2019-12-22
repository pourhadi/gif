//
//  ScrollViewTest.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/20/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import Combine


struct Run: View {
    let block: () -> Void

    var body: some View {
        DispatchQueue.main.async(execute: block)
        return AnyView(EmptyView())
    }
}

enum ScrollAction {
    case none
    case set(CGFloat)
}

struct ScrollViewTest: View {

    @State var offset: CGFloat = 700
    @State var setOffset: CGFloat? = nil
    @State var disableUpdate = false
    
    var body: some View {
        
        let scrollView = ScrollView(.horizontal) {
            self.scrollViewContent
        }//.content.offset(y: self.$offset.wrappedValue)
        
//        var scrollViewAsView = scrollView.asAny
//        if let setOffset = self.setOffset {
//            scrollViewAsView = scrollView.content.offset(y: setOffset).asAny
//            DispatchQueue.main.async {
//                self.setOffset = nil
//            }
//        } else {
////            scrollViewAsView = scrollView.content.offset().asAny
//        }
        
        
        return GeometryReader { metrics in
            VStack {
                
                Text("\(self.offset)")
                
                scrollView
                Button(action: {
                    //                    withAnimation {
                    self.disableUpdate = true
                    self.offset = 500
                    self.disableUpdate = false
                    //                    }
                }, label: { Text("Set Offset") } )
            }
        }
    }
    
    var scrollViewContent: some View {
        HStack {
            
            Rectangle().foregroundColor(Color.red).frame(width: 300)
            Rectangle().foregroundColor(Color.blue).frame(width: 300)
            Rectangle().foregroundColor(Color.green).frame(width: 300)
            
            GeometryReader { scrollMetrics in
                
                Run {
                    if !self.disableUpdate {
                        self.$offset.wrappedValue = scrollMetrics.frame(in: .global).origin.x
                    }
                }
                
            }.frame(width: 0, height: 0)
            
        }
        .frame(height: 100)
        
    }
    
}

struct ScrollViewTest_Previews: PreviewProvider {
    @State static var offset: CGFloat = 0
    static var previews: some View {
        ScrollViewTest()
    }
}
