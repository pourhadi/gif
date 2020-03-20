
//
//  PlayerView.swift
//  gif
//
//  Created by dan on 11/21/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Combine
import SwiftUI

class ControlsState: ObservableObject {
    var timer: Timer?
    
    func resetTimer() {
        self.timer?.invalidate()
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { _ in
            
            self.controlsVisible = false
        })
    }
    
    @Published var controlsVisible = false
    
    var cancellable: AnyCancellable?
    init() {
        self.cancellable = $controlsVisible.sink { _ in
            self.objectWillChange.send()
        }
    }
}

struct MainPlayerView<Player, Generator>: View where Player: PlayerView, Generator: GifGenerator {
    @EnvironmentObject var context: EditingContext<Generator>
    
    var showText: Bool {
        
        
        return false
    }
    
    var body: some View {
        Group {
            if self.context.playState.previewing {
                PreviewView<Generator>().zIndex(0).environmentObject(self.context.generator)
            } else {
                Player(item: self.context.item,
                       timestamp: self.$context.playState.currentPlayhead,
                       playing: self.$context.playState.playing,
                       playerType: .playhead)
                    
                    /*.background(BlurredPlayerView(playerView:
                     Player(item: self.context.item,
                     timestamp: self.$context.playState.currentPlayhead,
                     playing: self.$context.playState.playing, contentMode: .fill),
                     effect: .init(style: .systemThinMaterial)))*/
                    .overlay(
                        ZStack {
                            
                            if !(self.context.mode == .text) {
                                Button(action: {
                                    self.context.playState.playing.toggle()
                                }, label: { Rectangle().foregroundColor(Color.clear) }).padding(.bottom, 70).zIndex(2)
                            }
                            
                            self.getTimestampLabel().zIndex(1)
                        }
                )
                
                
                
            }
        }
    }
    
    func getTimestampLabel() -> some View{
        let duration = self.context.gifConfig.assetInfo.duration
        let seconds = duration * Double(self.context.playState.currentPlayhead)
        
        let formatted = seconds.secondsToFormattedTimestamp()
        
        return TimestampLabel(text: formatted)
    }
}

struct TimestampLabel : View {
    
    var text: String
    
    var body : some View {
        VStack {
            Spacer()
            Text(text)
                .fontWeight(.medium)
                //                .shadow(color: Color.black, radius: 2, x: 0, y: 0)
                .scaledToFill()
                .padding(6)
                .background(Color.black.opacity(0.5).cornerRadius(4))
                .frame(alignment: .bottom)
        }
    }
    
}

struct PercentCompleteLine: View {
    
    @Binding var percent: CGFloat
    
    var body : some View{
        Rectangle().fill(Color.accent).frame(height: 2).scaleEffect(x: self.percent, y: 1, anchor: .leading)
    }
    
}

struct PlayerContainerView<Player, Generator>: View where Player: PlayerView, Generator: GifGenerator {
    @ObservedObject var controlsState: ControlsState
    
    @EnvironmentObject var context: EditingContext<Generator>
    
    @Binding var previewing: Bool
    
    @State var dummyPlayable = false
    
    
    @Binding var playersHeight: CGFloat?
    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    @Environment(\.verticalSizeClass) var verticalSize: UserInterfaceSizeClass?
    
    var editorHeight: CGFloat
    
    var body: some View {
        let spacing: CGFloat = 6
        
        if self.verticalSize == .compact {
            return HStack {
                self.getStartFrameView().shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                self.getMainView().shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                self.getEndFrameView().shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
            }.any
        }
        
        var outer = Axis.horizontal
        var inner = Axis.vertical
        
        let videoSize = context.size
        if videoSize.width > videoSize.height {
            outer = .vertical
            inner = .horizontal
        }
        
        return GeometryReader { metrics in
            
            Run(true) {
                let size = metrics.size
                Async {
                    if videoSize.width > videoSize.height {
                        let height = self.size(for: size,
                                               videoSize: videoSize).height + (self.heightForSecondary(for: (size.width / 2) - spacing, videoSize: videoSize) ?? 0)
                        if height != self.playersHeight {
                            
                            self.$playersHeight.animation(Animation.linear(duration: 0.2).delay(0.1)).wrappedValue = height
                        }
                    }
                }
            }
            
            ZStack {
                
                PercentCompleteLine(percent: self.$context.playState.currentPlayhead)
                    .frame(width: metrics.size.width, height: metrics.size.height, alignment: .top).zIndex(2)
                Stack(outer, spacing: spacing) {
                    self.getMainView()
                        .frame(width: self.size(for: metrics.size,
                                                videoSize: videoSize).width,
                               height: self.size(for: metrics.size,
                                                 videoSize: videoSize).height)
                        .transformAnchorPreference(key: EditorPreferencesKey.self, value: .center) { (val, anchor) in
                            val.mainPlayerCenter = anchor
                    }
                    .transformAnchorPreference(key: EditorPreferencesKey.self, value: .bounds) { (val, anchor) in
                        val.mainPlayerBounds = anchor
                    }
                    //.shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                    
                    Stack(inner, spacing: spacing) {
                        self.getStartFrameView().transformAnchorPreference(key: EditorPreferencesKey.self, value: .center) { (val, anchor) in
                            val.startPlayerCenter = anchor
                        }
                        .transformAnchorPreference(key: EditorPreferencesKey.self, value: .bounds) { (val, anchor) in
                            val.startPlayerBounds = anchor
                        } // .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                        
                        
                        self.getEndFrameView().transformAnchorPreference(key: EditorPreferencesKey.self, value: .center) { (val, anchor) in
                            val.endPlayerCenter = anchor
                        }
                        .transformAnchorPreference(key: EditorPreferencesKey.self, value: .bounds) { (val, anchor) in
                            val.endPlayerBounds = anchor
                        } // .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }.frame(height: self.heightForSecondary(for: (metrics.size.width / 2) - spacing, videoSize: videoSize))
                    
                }.frame(height: inner == .horizontal ? self.size(for: metrics.size,
                                                                 videoSize: videoSize).height + (self.heightForSecondary(for: (metrics.size.width / 2) - spacing, videoSize: videoSize) ?? 0) : nil)
                    .backgroundPreferenceValue(EditorPreferencesKey.self, { (val: EditorPreferences) in
                        GeometryReader { metrics in
                            self.getShadowBackground(metrics: metrics, values: val)
                            
                        }
                    })
                    .zIndex(1)
                
            }
        }.onAppear(perform: {
            self.controlsState.resetTimer()
            
        }).any
    }
    
    func getShadowBackground(metrics: GeometryProxy, values: EditorPreferences) -> some View {
        let mainPlayerCenter = metrics[values.mainPlayerCenter!]
        let mainPlayerBounds = metrics[values.mainPlayerBounds!]
        let startPlayerCenter = metrics[values.startPlayerCenter!]
        let startPlayerBounds = metrics[values.startPlayerBounds!]
        let endPlayerCenter = metrics[values.endPlayerCenter!]
        let endPlayerBounds = metrics[values.endPlayerBounds!]
        
        return Group {
            
            Rectangle()
                .foregroundColor(Color.black.opacity(0.4))
                .frame(width: mainPlayerBounds.width, height: mainPlayerBounds.height)
                .position(mainPlayerCenter)
            
            Rectangle()
                .foregroundColor(Color.black.opacity(0.4))
                
                .frame(width: startPlayerBounds.width, height: startPlayerBounds.height)
                .position(startPlayerCenter)
            
            Rectangle()
                .foregroundColor(Color.black.opacity(0.4))
                
                .frame(width: endPlayerBounds.width, height: endPlayerBounds.height)
                .position(endPlayerCenter)
        }
            //        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
            .shadow(color: Color.black, radius: 8, x: 0, y: 0)
    }
    
    func getEndFrameView() -> some View {
        return self.playerView(self.$context.gifConfig.selection.endTime, forMode: .end)
    }
    
    func getStartFrameView() -> some View {
        return self.playerView(self.$context.gifConfig.selection.startTime, forMode: .start)
    }
    
    func getMainView() -> some View {
        return MainPlayerView<Player, Generator>().environmentObject(self.context)
    }
    
    func heightForSecondary(for width: CGFloat, videoSize: CGSize) -> CGFloat? {
        if videoSize.height > videoSize.width { return nil }
        
        return videoSize.fittingWidth(width).height
    }
    
    func size(for metricsSize: CGSize, videoSize: CGSize) -> CGSize {
        let width: CGFloat
        let height: CGFloat
        if videoSize.width > videoSize.height {
            height = videoSize.scaledToFit(metricsSize).height.clamp(0, self.editorHeight / 3)
            width = metricsSize.width
        } else {
            height = metricsSize.height
            width = videoSize.fittingHeight(metricsSize.height).width.clamp(0, metricsSize.width * 0.6)
        }
        
        return CGSize(width: width, height: height)
    }
    
    func playerView(_ time: Binding<CGFloat>, forMode: VideoMode) -> some View {
        let startGrad = LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
        let endGrad = LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.8), Color.red.opacity(0.2)]), startPoint: .top, endPoint: .bottom)
        
        let duration = self.context.gifConfig.assetInfo.duration
        
        return PlayerLabelView(playerView: Player(item: self.context.item,
                                                  timestamp: time,
                                                  playing: $dummyPlayable,
                                                  playerType: forMode == .start ? .start : .end),
                               label: forMode == .start ? "Start" : "End",
                               frameIncrement: self.context.frameIncrement,
                               controlsState: self.controlsState,
                               adjustedTime: { time in
                                self.context.playState.currentPlayhead = time
        }, duration: duration, timestamp: time)
            .onTapGesture {
                if !self.controlsState.controlsVisible {
                    self.controlsState.controlsVisible = true
                }
        }
        //        .background(Color(white: 0.1))
        //    .background((forMode == .start ? startGrad : endGrad))
        //        .clipShape(RoundedRectangle(cornerRadius: 20))
        //        .background(RoundedRectangle(cornerRadius: 20)
        //            .fill(forMode == .start ? startGrad : endGrad))
    }
}

struct PlayerContainerView_Previews: PreviewProvider {
    //    @State static var generator = GifGenerator.init(video: context.preview)
    
    //    @State static var selectedMode = VideoMode.playhead
    static var previews: some View {
        //        EditorView(gifGenerator: $generator).environmentObject(context.preview).environment(\.colorScheme, .dark).background(Color.black).accentColor(Color.white)
        
        GlobalPreviewView()
    }
}
