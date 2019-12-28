//
//  EditorView.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct EditorView: View {
    
    @EnvironmentObject var video: Video
    
    @Binding var gifGenerator: GifGenerator
    
    @State var selectedMode: VideoMode = .playhead
    
    @Binding var visualState: VisualState
    
    @State var playersHeight: CGFloat? = nil
    
    var body: some View {
        GeometryReader { metrics in
            VStack(spacing:0) {
                PlayerContainerView(gifGenerator: self.$gifGenerator,
                                    selectedMode: self.$selectedMode,
                                    visualState: self.$visualState,
                                    playersHeight: self.$playersHeight)
                    .environmentObject(self.video).frame(height: self.playersHeight)
//                    .zIndex(2)
                TimelineView(selection: self.$video.gifConfig.selection,
                             playState: self.$video.playState,
                             videoMode: self.$selectedMode,
                             visualState: self.$visualState)
                    .frame(minHeight: metrics.size.height / 3)
                    .background(Color.background)
                
                ControlsView(selection: self.$video.gifConfig.selection,
                             playState: self.$video.playState)
                    .background(Color.background)
            }
        }
    }
}

struct EditorView_Previews: PreviewProvider {
    
    static var previews: some View {
        GlobalPreviewView()
    }
}
