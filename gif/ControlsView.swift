//
//  ControlsView.swift
//  gif
//
//  Created by dan on 11/28/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct ControlsView: View {
    @Binding var selection: GifConfig.Selection
    @Binding var playState: PlayState
    
    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            Button(action: {
                self.selection.startTime = self.playState.currentPlayhead
                if self.selection.endTime < self.selection.startTime {
                    self.selection.endTime = self.selection.startTime + 0.1
                }
            }, label: { Text("Set Start").padding(8) }).foregroundColor(Color.green.opacity(1)).cornerRadius(4)
            Spacer()
            Button(action: {
                self.selection.endTime = self.playState.currentPlayhead
                if self.selection.endTime < self.selection.startTime {
                    self.selection.startTime = self.selection.endTime - 0.1
                }
                }, label: { Text("Set End").padding(8) }).foregroundColor(Color.red.opacity(1)).cornerRadius(4)
            Spacer()
        }
    }
}

struct ControlsView_Previews: PreviewProvider {
    @State static var playState = PlayState()
    @State static var selection = GifConfig.Selection()
    static var previews: some View {
        ControlsView(selection: $selection, playState: $playState)
    }
}
