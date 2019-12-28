//
//  PlayerView.swift
//  gif
//
//  Created by dan on 11/21/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

class CustomPlayerView: UIView {
    var player: AVPlayer? {
        get {
            return (self.layer as! AVPlayerLayer).player
        }
        set {
            (self.layer as! AVPlayerLayer).player = newValue
        }
    }
    
    override class var layerClass: AnyClass { return  AVPlayerLayer.self }
}

struct UIPlayerView: UIViewRepresentable {
    
    @Binding var timestamp: CGFloat
    @Binding var playing: Bool
    let url: URL
    let videoGravity: AVLayerVideoGravity
    
    
    func makeUIView(context: UIViewRepresentableContext<UIPlayerView>) -> CustomPlayerView {
        let v = CustomPlayerView()
        v.isOpaque = false
        let player = AVPlayer(url: url)
        v.player = player
        v.clipsToBounds = true
        (v.layer as! AVPlayerLayer).videoGravity = videoGravity
        context.coordinator.player = player
        return v
    }
    
    func updateUIView(_ uiView: CustomPlayerView, context: UIViewRepresentableContext<UIPlayerView>) {
        
        if let player = uiView.player {
            if player.rate < 1 {
                if playing {
                    player.rate = 1
                }
            } else {
                if !playing {
                    player.rate = 0
                }
            }
        }
        
        if let duration = uiView.player?.currentItem?.duration, !duration.isIndefinite, context.coordinator.prevTimestamp != $timestamp.wrappedValue, !playing {
            
            context.coordinator.prevTimestamp = $timestamp.wrappedValue
            let scaled = CMTimeValue(CGFloat(duration.seconds) * $timestamp.wrappedValue * 30)
            
            DispatchQueue.main.async {
                uiView.player?.seek(to: CMTime(value: scaled, timescale: 30), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { _ in })
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    typealias UIViewType = CustomPlayerView
    
    class Coordinator: NSObject {
        let url: URL? = nil
        var parent: UIPlayerView
        var prevTimestamp: CGFloat = -1
        
        unowned var player: AVPlayer? = nil {
            didSet {
                if let oldValue = oldValue, let oldObserver = observer {
                    oldValue.removeTimeObserver(oldObserver)
                }
                
                if let player = player {
                    observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: DispatchQueue.init(label: "playerTimeObserver.queue"), using: { [weak self] (time) in
                        if let weakSelf = self, let duration = weakSelf.player?.currentItem?.duration {
                            if weakSelf.parent.playing {
                                
                                DispatchQueue.main.async {
                                    weakSelf.parent.timestamp = CGFloat(time.seconds / duration.seconds)
                                }
                            }
                        }
                    })
                }
            }
        }
        var observer: Any?
        
        init(_ parent: UIPlayerView) {
            self.parent = parent
        }
        
        deinit {
            if let player = player, let observer = observer {
                player.removeTimeObserver(observer)
            }
        }
    }
    
    
}

struct PlayerView: View {
    
    let url: URL
    @Binding var timestamp: CGFloat
    @Binding var playing: Bool
    
    let stepForward = Empty<Any, Never>(completeImmediately: false)
    
    var body: some View {
        UIPlayerView(timestamp: $timestamp,
                     playing: $playing,
                     url: url,
                     videoGravity: .resizeAspect)
        //        .background(BlurredPlayerView(playerView: UIPlayerView(timestamp: $timestamp,
        //                                                               playing: $playing,
        //                                                               url: url,
        //                                                               videoGravity: .resizeAspectFill)
        //))
    }
    
    
}

struct StepperView: View {
    
    let stepForward: () -> Void
    let stepBackward: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                self.stepBackward()
            }, label: { self.backView })
            Spacer()
            Button(action: {
                self.stepForward()
            }, label: { self.forwardView })
        }.padding(20)
    }
    
    var backView: some View {
        return VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight)).mask(Image(systemName: "backward.fill").frame(alignment: .center)).shadow(radius: 2)
    }
    
    var forwardView: some View {
        return VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight)).mask(Image(systemName: "forward.fill").frame(alignment: .center)).shadow(radius: 2)
    }
}

struct BlurredPlayerView: View {
    let playerView: UIPlayerView
    
    let effect: UIBlurEffect
    var body: some View {
        ZStack {
            playerView
            VisualEffectView(effect: effect)
            
        }
    }
    
}

struct PlayerLabelView: View {
    let borderColor = Color.gray
    
    let playerView: PlayerView
    let label: String
    let assetInfo: AssetInfo
    
    var body: some View {
        Group {
            GeometryReader { metrics in
                
//                    .frame(width: metrics.size.width, height: metrics.size.height)
                
                self.playerView.background(BlurredPlayerView(playerView:
                UIPlayerView(timestamp: self.playerView.$timestamp,
                             playing: self.playerView.$playing,
                             url: self.playerView.url,
                             videoGravity: .resizeAspectFill),
                              effect: .init(style: .systemThinMaterial)))
                
                self.text
                    .frame(width: metrics.size.width, height: metrics.size.height)
                    .shadow(color: Color.black, radius: 2, x: 0, y: 1)
                
                self.playerView
                    .mask(self.text
                        .frame(width: metrics.size.width, height: metrics.size.height)
                        .compositingGroup())
                    .brightness(0.3)
 
            }
        }
    }
    
    var text: Text {
        Text(self.label.uppercased())
            .font(.system(size: 20))
        .fontWeight(.bold)
        .foregroundColor(Color.text)
    }
    
    func stepForward() {
        self.playerView.timestamp = self.playerView.timestamp + assetInfo.unitFrameIncrement
        
    }
    
    func stepBackward() {
        self.playerView.timestamp = self.playerView.timestamp - assetInfo.unitFrameIncrement
        
    }
}

struct PlayerView_Previews: PreviewProvider {
    @State static var generator = GifGenerator.init(video: Video.preview)
    
    static var previews: some View {
        //        VStack {
        
        GlobalPreviewView()
        //        EditorView(gifGenerator: $generator).environmentObject(Video.preview).environment(\.colorScheme, .dark).background(Color.background).accentColor(Color.white)
        
        //        }
    }
}


/*
 
 GeometryReader { innerMetrics in
 Text(self.label)
 .shadow(radius: 2)
 .frame(width: metrics.size.height)
 
 .offset(x: -innerMetrics.size.height)
 
 .rotationEffect(.init(degrees: 90), anchor: .bottomLeading)
 
 .align(.vertical, .trailingBottom)
 */


/*
 
 //                    Text(self.label.uppercased())
 //                        .font(.caption)
 //                    .padding(12)
 //                        .background(Color.background)
 //                        .cornerRadius(6, corners: .topRight)
 //                        .frame(width:metrics.size.width, height: metrics.size.height, alignment:.bottomLeading)
 //                    StepperView(stepForward: self.stepForward, stepBackward: self.stepBackward).accentColor(Color.white)*/
