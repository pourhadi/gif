//
//  ControlsView.swift
//  gif
//
//  Created by dan on 11/28/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct ControlsView<Generator>: View where Generator : GifGenerator {
    @Binding var selection: GifConfig.Selection
    @Binding var playState: PlayState
    var context: EditingContext<Generator>
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        GeometryReader { metrics in
            HStack(spacing: 4) {
                Button(action: {
                    self.selection.startTime = self.playState.currentPlayhead
                    
                }, label: {
                    HStack {
                        Spacer()
                        Text(self.context.mode == .text ? "Set Text Start" : "Set Start").bold()
//                            .shadow(radius: 1)
                            .padding(8)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .padding(.bottom, metrics.safeAreaInsets.bottom)
                        
                    .background(RoundedRectangle(cornerRadius: 0).fill(Color(white: self.colorScheme == .dark ? 0.7 : 1.0).opacity(0.2)).edgesIgnoringSafeArea(.bottom))
                }).foregroundColor(Color.green.opacity(1))
                Button(action: {
                    self.selection.endTime = self.playState.currentPlayhead
                    
                }, label: {
                    
                    HStack {
                        Spacer()
                        Text(self.context.mode == .text ? "Set Text End" : "Set End").bold()
//                        .shadow(radius: 1)
                            .padding(8)
                        .padding(.top, 8)

                        Spacer()
                    }
                    .padding(.bottom, metrics.safeAreaInsets.bottom)
                    .background(RoundedRectangle(cornerRadius: 0).fill(Color(white: self.colorScheme == .dark ?  0.7 : 1.0).opacity(0.2)).edgesIgnoringSafeArea(.bottom))

                }).foregroundColor(Color.red.opacity(1))
            }
//            .padding(.top, metrics.safeAreaInsets.bottom)

//            .frame(height: metrics.size.height + metrics.safeAreaInsets.bottom)
        }
    }
}
//
//struct ControlsView_Previews: PreviewProvider {
//    @State static var playState = PlayState()
//    @State static var selection = GifConfig.Selection()
//    static var previews: some View {
//        VStack {
//            Spacer()
//            ControlsView(selection: $selection, playState: $playState)
//        }.edgesIgnoringSafeArea(.bottom)
//    }
//}
