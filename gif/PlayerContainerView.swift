
//
//  PlayerView.swift
//  gif
//
//  Created by dan on 11/21/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import SwiftUI_Utils

struct PlayerContainerView: View {
    
    @EnvironmentObject var video: Video
    
    @Binding var gifGenerator: GifGenerator
    @Binding var selectedMode: VideoMode
    
    @State var dummyPlayable = false
    
    @State var showingPreview = false
    
    @Binding var visualState: VisualState
    
    @Binding var playersHeight: CGFloat?
    
    var body: some View {
        let spacing: CGFloat = 6

        if self.visualState.compact {
            return HStack {
                self.getStartFrameView()
                self.getMainView()
                self.getEndFrameView()
            }.any
        }
        
        var outer = Axis.horizontal
        var inner = Axis.vertical
        
        let videoSize = (video.videoTrack?.naturalSize ?? CGSize(width: 0, height: 1)).applying(video.videoTrack?.preferredTransform ?? CGAffineTransform.identity)
        if videoSize.width > videoSize.height {
            outer = .vertical
            inner = .horizontal
            
            
        }
        
        
        return GeometryReader { metrics in
            Run {
                if videoSize.width > videoSize.height {
                    self.playersHeight = self.size(for: metrics.size,
                                                   videoSize: videoSize).height + (self.heightForSecondary(for: (metrics.size.width / 2) - spacing, videoSize: videoSize) ?? 0)
                }
            }
            
            Stack(outer, spacing: spacing) {
                
                self.getMainView()
                    .frame(width: self.size(for: metrics.size,
                                            videoSize: videoSize).width,
                           height: self.size(for: metrics.size,
                                             videoSize: videoSize).height)
                
                Stack(inner, spacing: spacing) {
                    self.getStartFrameView()
                    self.getEndFrameView()
                }.frame(height: self.heightForSecondary(for: (metrics.size.width / 2) - spacing, videoSize: videoSize))
                
            }.frame(height: inner == .horizontal ? self.size(for: metrics.size,
                                                             videoSize: videoSize).height + (self.heightForSecondary(for: (metrics.size.width / 2) - spacing, videoSize: videoSize) ?? 0) : nil)
        }.any
    }
    
    func getEndFrameView() -> some View {
        return self.playerView(self.$video.gifConfig.selection.endTime, forMode: .end)
    }
    
    func getStartFrameView() -> some View {
        return self.playerView(self.$video.gifConfig.selection.startTime, forMode: .start)
    }

    func getMainView() -> some View {
        if self.video.playState.previewing {
            return PreviewView().environmentObject(self.gifGenerator).any
        } else {
            return PlayerView(url: self.video.url,
                              timestamp: self.$video.playState.currentPlayhead,
                              playing: self.$video.playState.playing)
            .background( BlurredPlayerView(playerView:
                UIPlayerView(timestamp: self.$video.playState.currentPlayhead,
                                            playing: self.$video.playState.playing,
                                            url: self.video.url,
                                            videoGravity: .resizeAspectFill),
                                             effect: .init(style: .systemThinMaterial)))
                .overlay(Button(action: {
                    self.selectedMode = .playhead
                    self.$video.playState.playing.wrappedValue.toggle()
                }, label: { Rectangle().foregroundColor(Color.clear) }).padding(.bottom, 70)).any
        }
    }
    
    func heightForSecondary(for width: CGFloat, videoSize: CGSize) -> CGFloat? {
        if videoSize.height > videoSize.width { return nil }
        
        return videoSize.fittingWidth(width).height
    }
    
    func size(for metricsSize: CGSize, videoSize: CGSize) -> CGSize {
        
        let width: CGFloat
        let height: CGFloat
        if videoSize.width > videoSize.height {
            height = videoSize.scaledToFit(metricsSize).height
            width = metricsSize.width
        } else {
            height = metricsSize.height
            width = videoSize.fittingHeight(metricsSize.height).width
        }
        
        return CGSize(width: width, height: height)
    }
    
    func playerView(_ time: Binding<CGFloat>, forMode: VideoMode) -> some View {
        
        
        let startGrad = LinearGradient(gradient:Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
        let endGrad = LinearGradient(gradient:Gradient(colors: [Color.red.opacity(0.8), Color.red.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
        
        return PlayerLabelView(playerView: PlayerView(url: self.video.url, timestamp: time, playing: $dummyPlayable), label: forMode == .start ? "Start" : "End", assetInfo: self.video.assetInfo).onTapGesture {
            self.selectedMode = forMode
        }
        //        .background(Color(white: 0.1))
        //    .background((forMode == .start ? startGrad : endGrad))
        //        .clipShape(RoundedRectangle(cornerRadius: 20))
        //        .background(RoundedRectangle(cornerRadius: 20)
        //            .fill(forMode == .start ? startGrad : endGrad))
        
    }
}

struct PlayerContainerView_Previews: PreviewProvider {
//    @State static var generator = GifGenerator.init(video: Video.preview)
    
    //    @State static var selectedMode = VideoMode.playhead
    static var previews: some View {
//        EditorView(gifGenerator: $generator).environmentObject(Video.preview).environment(\.colorScheme, .dark).background(Color.black).accentColor(Color.white)
        
        GlobalPreviewView()
    }
}
