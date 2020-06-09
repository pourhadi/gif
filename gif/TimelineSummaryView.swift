//
//  TimelineSummaryView.swift
//  giffed
//
//  Created by Daniel Pourhadi on 4/22/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI

protocol SelectionFrameKey : AnchoredFrameKey {}

struct TimelineSummaryView: View { // <Generator>: View where Generator : GifGenerator {
    //    @EnvironmentObject var context: EditingContext<Generator>
    
    @Binding var selection: GifConfig.Selection
    @Binding var playState: PlayState
    
    var body: some View {
        
        let selectionX = self.selection.startTime
        let selectionWidth = self.selection.endTime - self.selection.startTime
        
        return ZStack {
            
            GeometryReader { metrics in
                Group {
                    self.timelineBackground
                        

                            .overlay(
                                Capsule()
//                                RoundedRectangle(cornerRadius: metrics.size.height / 4)
                                    .size(width: metrics.size.width * selectionWidth, height: metrics.size.height / 2)
                                    .stroke(Color.accent.opacity(0.5), lineWidth: 2)
                                    .padding([.top, .bottom], metrics.size.height / 4)

                                    .offset(x: metrics.size.width * selectionX)
                                    .scaleEffect(x: 1, y: 1.5)
                                
                                    .contentShape(Rectangle()
                                        .size(width: max(40.0, metrics.size.width * selectionWidth), height: 40)
                                        .offset(x: metrics.size.width * selectionX))
                                    .onTapGesture {
                                        self.playState.currentPlayhead = self.selection.startTime
                                        
                                }
                        )
                        
                        .zIndex(0)
                    
                    Rectangle()
                        .fill(Color.accent)
                        .frame(width: 4, height: metrics.size.height)
                        .offset(x: metrics.size.width * self.playState.currentPlayhead)
                        .zIndex(2)
                    .contentShape(Rectangle().size(metrics.size))
                    .gesture(DragGesture().onChanged({ (v) in
                        let touchWidth: CGFloat = 60
                        let touchAreaStart = (metrics.size.width * self.playState.currentPlayhead) - (touchWidth / 2)
                        
                        if v.location.x >= touchAreaStart || v.location.x <= touchAreaStart + touchWidth {
                            let p = v.location.x / metrics.size.width
                            self.playState.currentPlayhead = p
                        }
                        
                    }))
                }

            }
            .padding([.leading, .trailing], 20)
            
        }
    }
    
    
    var timelineBackground: some View {
        
        
        
        return VStack {
            Spacer()
            VisualEffectView.blur(.prominent).brightness(0.2)
                .frame(height: 4)

            Spacer()
        }
    }
    
}

struct TimelineContentTest : View {
    @State  var selection = GifConfig.Selection.init(startTime: 0.5, endTime: 0.6, fiveSecondValue: 0)
    @State  var playState = PlayState.init()
    
    var body: some View {
        TimelineSummaryView(selection: self.$selection, playState: self.$playState)
        .background(Color(white: 0.1))
    }
}

struct TimelineSummaryView_Previews: PreviewProvider {

    static var previews: some View {
        TimelineContentTest()
    }
}
