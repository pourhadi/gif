//
//  TransitionTest.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/25/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct TransitionTest: View {
    
    @State var showBlock = false
    
    var body: some View {
        GeometryReader { metrics in
        Group {
            
            Button(action: {
                self.$showBlock.animation().wrappedValue.toggle()
            }, label: { Text("Show block") })
            
            if self.showBlock {
                Text("Test")
//                    .frame(width: metrics.size.width, height: metrics.size.height)
                    .onTapGesture {
                    self.showBlock.toggle()
                }.transition(.move(edge: .leading))
            }
        }
        }
    }
}

struct TransitionTest_Previews: PreviewProvider {
    static var previews: some View {
        TransitionTest()
    }
}
