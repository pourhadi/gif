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
    
    var body: some View {
        GeometryReader { metrics in
            VStack(spacing:0) {
                PlayerContainerView(gifGenerator: self.$gifGenerator,
                                    selectedMode: self.$selectedMode,
                                    visualState: self.$visualState)
                    .environmentObject(self.video).background(Color.red)
                    .zIndex(2)
                    TimelineView(selection: self.$video.gifConfig.selection,
                             playState: self.$video.playState,
                             videoMode: self.$selectedMode,
                             visualState: self.$visualState)
                    .background(Color.background)
//                    .frame(height: metrics.size.height / 3)
                
                ControlsView(selection: self.$video.gifConfig.selection,
                             playState: self.$video.playState)
                    .background(Color.black)
            }
        }
    }
}

struct EditorView_Previews: PreviewProvider {

    static var previews: some View {
        GlobalPreviewView()
    }
}
