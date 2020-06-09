//
//  PlayerView.swift
//  gif
//
//  Created by dan on 11/21/19.
//  Copyright © 2019 dan. All rights reserved.
//

import AVFoundation
import Combine
import SnapKit
import SwiftUI
import UIKit
import YYImage

class CustomPlayerView: UIView {
    var player: AVPlayer? {
        get {
            return (self.layer as! AVPlayerLayer).player
        }
        set {
            (self.layer as! AVPlayerLayer).player = newValue
        }
    }
    
    override class var layerClass: AnyClass { return AVPlayerLayer.self }
}

struct UIPlayerView: UIViewRepresentable {
    
    let playerType: PlayerType
    
    @Environment(\.timelineState) var timelineState: TimelineState

    
    @Binding var timestamp: CGFloat
    @Binding var playing: Bool
    let url: URL
    let videoGravity: AVLayerVideoGravity
    
    func makeUIView(context: UIViewRepresentableContext<UIPlayerView>) -> CustomPlayerView {
        let v = CustomPlayerView()
        v.isOpaque = false
        if let player = EditorStore.players[self.playerType] {
            v.player = player
        } else {
            let player = AVPlayer(url: self.url)
            EditorStore.players[self.playerType] = player
            v.player = player
        }
        v.clipsToBounds = true
        (v.layer as! AVPlayerLayer).videoGravity = self.videoGravity
        context.coordinator.player = v.player
        
        Delayed(0.1) {
            if let duration = v.player?.currentItem?.duration, !duration.isIndefinite, context.coordinator.prevTimestamp != self.$timestamp.wrappedValue, !self.playing {
                context.coordinator.prevTimestamp = self.$timestamp.wrappedValue
//                let scaled = CMTimeValue(CGFloat(duration.seconds) * self.$timestamp.wrappedValue * 30)
                
                let time = duration.seconds * Double(self.timestamp)
                let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
                
                v.player?.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { _ in })
            }
        }
        
        return v
    }
    
    func updateUIView(_ uiView: CustomPlayerView, context: UIViewRepresentableContext<UIPlayerView>) {
        if let player = uiView.player {
            if player.rate < 1 {
                if self.playing {
                    player.rate = 1
                }
            } else {
                if !self.playing {
                    player.rate = 0
                }
            }
        }
        
        if let duration = uiView.player?.currentItem?.duration, !duration.isIndefinite, context.coordinator.prevTimestamp != $timestamp.wrappedValue, !playing {
            context.coordinator.prevTimestamp = $timestamp.wrappedValue
            let time = duration.seconds * Double(self.timestamp)
            let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
            
            DispatchQueue.main.async {
                if self.timelineState.isDragging {
                    uiView.player?.seek(to: cmTime, toleranceBefore: CMTime(value: 5, timescale: 30), toleranceAfter: CMTime(value: 5, timescale: 30), completionHandler: { _ in })
                } else {
                    uiView.player?.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { _ in })
                }
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
        
        var player: AVPlayer? {
            didSet {
                if let player = player, EditorStore.playerObservers[self.parent.playerType] == nil {
                    EditorStore.playerObservers[self.parent.playerType] = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: DispatchQueue(label: "playerTimeObserver.queue"), using: { [weak self] time in
                        if let weakSelf = self, let duration = EditorStore.players[weakSelf.parent.playerType]?.currentItem?.duration {
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
        

    }
}

enum PlayerType: Hashable {
    case playhead
    case start
    case end
    case preview
}

protocol PlayerView: View {
    
    var playerType: PlayerType { get }
    
    var timestamp: CGFloat { get nonmutating set }
    
    var playing: Bool { get nonmutating set }
    
    var contentMode: ContentMode { get }
    
    init(item: Editable, timestamp: Binding<CGFloat>, playing: Binding<Bool>, contentMode: ContentMode, playerType: PlayerType)
}

struct FrameImageView: UIViewRepresentable {
    func makeCoordinator() -> FrameImageView.Coordinator {
        return Coordinator(self)
    }
    
    let gif: GIF
    
    let contentMode: ContentMode
    
    @Binding var timestamp: CGFloat
    
    @Binding var playing: Bool
    
    func makeUIView(context: UIViewRepresentableContext<FrameImageView>) -> FrameImageUIView {
        let v = FrameImageUIView()
        if let img = self.gif.animatedImage {
            context.coordinator.numberOfFrames = (img.images?.count ?? 1) - 1
            
            Delayed(0.2) {
                if !self.timestamp.isInfinite {
                    let currentFrame = Int(CGFloat(context.coordinator.numberOfFrames) * self.timestamp)
                    v.imageView.image = self.gif.animatedImage?.images?[currentFrame]
                }
            }
        }
        return v
    }
    
    func updateUIView(_ uiView: FrameImageUIView, context: UIViewRepresentableContext<FrameImageView>) {
        uiView.imageView.contentMode = self.contentMode == .fit ? UIView.ContentMode.scaleAspectFit : .scaleAspectFill
        
        if self.playing {
            if !uiView.imageView.isAnimating {
                uiView.imageView.animationImages = self.gif.animatedImage?.images
                uiView.imageView.animationDuration = self.gif.animatedImage?.duration ?? 0
                uiView.imageView.startAnimating()
            }
        } else {
            uiView.imageView.stopAnimating()
            if !self.timestamp.isInfinite {
                let currentFrame = Int(CGFloat(context.coordinator.numberOfFrames) * self.timestamp)
                uiView.imageView.image = self.gif.animatedImage?.images?[currentFrame]
            }
        }
    }
    
    typealias UIViewType = FrameImageUIView
    
    class Coordinator {
        var numberOfFrames: Int = 0
        let parent: FrameImageView
        
        init(_ parent: FrameImageView) {
            self.parent = parent
        }
    }
}

class FrameImageUIView: UIView {
    let imageView = UIImageView()
    
    init() {
        super.init(frame: CGRect.zero)
        
        addSubview(self.imageView)
        self.imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.clipsToBounds = true
        self.imageView.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PlayerView {
    init(item: Editable, timestamp: Binding<CGFloat>, playing: Binding<Bool>, playerType: PlayerType) {
        self.init(item: item, timestamp: timestamp, playing: playing, contentMode: .fit, playerType: playerType)
    }
}

public struct TextPlayerView : PlayerView {
    
    var contentMode: ContentMode
    let playerType: PlayerType
    let gif: GIF
    @Binding internal var timestamp: CGFloat
    @Binding public var playing: Bool
    
    init(item: Editable, timestamp: Binding<CGFloat>, playing: Binding<Bool>, contentMode: ContentMode, playerType: PlayerType) {
        self.gif = item as! GIF
        self._timestamp = timestamp
        self._playing = playing
        self.contentMode = contentMode
        self.playerType = playerType
    }
    
    var showText: Bool {
        if self.playerType == .playhead && self.timestamp >= gif.textEditingContext.gifConfig.selection.startTime && self.timestamp <= gif.textEditingContext.gifConfig.selection.endTime {
            return true
        }
        
        return false
    }
    
    var textAdded : Bool {
        return self.gif.textEditingContext.generator.drawsana.drawing.shapes.count > 0
    }
    
    public var body: some View {
        FrameImageView(gif: self.gif, contentMode: self.contentMode, timestamp: self.$timestamp, playing: self.$playing)
                .zIndex(0)
                .overlay(GeometryReader { metrics in
                    
                    self.getOverlay(metrics: metrics)
                })
        
            
    }
    
    
    func getOverlay(metrics: GeometryProxy) -> some View {
//        let size = self.gif.size
//        let frameSize = metrics.size
//        
//        let scaleW = frameSize.width / size.width
//        let scaleH = frameSize.height / size.height
        
        return Group {
            if self.showText {
                DrawsanaContainerView(drawsanaView: self.gif.textEditingContext.generator.drawsana).environmentObject(self.gif.textEditingContext)
                    .aspectRatio(self.gif.aspectRatio, contentMode: .fit)
                    .frame(width: metrics.size.width, height: metrics.size.height, alignment: .center)
//                    .scaleEffect(CGSize(width: scaleW, height: scaleH))
                
            }
            
            if !self.textAdded && self.showText {
                Text("Tap to add text").font(.title).foregroundColor(Color.white)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.2)))
                    .frame(width: metrics.size.width, height: metrics.size.height, alignment: .center)
                .allowsHitTesting(false)
                

            }
        }.onTapGesture {
            if !self.gif.textEditingContext.editingText {
                self.gif.textEditingContext.editingText = true
                self.gif.textEditingContext.generator.drawsana.tool?.handleTap(context: self.gif.textEditingContext.generator.drawsana.toolOperationContext, point: CGPoint(x: 10, y: 10))
            }
        }
        
    }
}

public struct FramePlayerView: PlayerView {
    var contentMode: ContentMode
    let playerType: PlayerType
    let gif: GIF
    @Binding internal var timestamp: CGFloat
    @Binding public var playing: Bool
    
    init(item: Editable, timestamp: Binding<CGFloat>, playing: Binding<Bool>, contentMode: ContentMode, playerType: PlayerType) {
        self.gif = item as! GIF
        self._timestamp = timestamp
        self._playing = playing
        self.contentMode = contentMode
        self.playerType = playerType
    }
    
    public var body: some View {
        FrameImageView(gif: self.gif, contentMode: self.contentMode, timestamp: self.$timestamp, playing: self.$playing)
    }
}

public struct VideoPlayerView: PlayerView {
    
    let playerType: PlayerType
    
    init(item: Editable, timestamp: Binding<CGFloat>, playing: Binding<Bool>, contentMode: ContentMode, playerType: PlayerType) {
        self.url = item.url
        self._timestamp = timestamp
        self._playing = playing
        self.contentMode = contentMode
        self.playerType = playerType
    }

    
    var contentMode: ContentMode
    
    public let url: URL
    @Binding internal var timestamp: CGFloat
    @Binding public var playing: Bool
    
    let stepForward = Empty<Any, Never>(completeImmediately: false)
    
    public var body: some View {
        UIPlayerView(playerType: self.playerType,
            timestamp: $timestamp,
                     playing: $playing,
                     url: url,
                     videoGravity: contentMode == .fit ? .resizeAspect : .resizeAspectFill)
        //        .background(BlurredPlayerView(playerView: UIPlayerView(timestamp: $timestamp,
        //                                                               playing: $playing,
        //                                                               url: url,
        //                                                               videoGravity: .resizeAspectFill)
        // ))
    }
}

struct StepperView<TimestampLabel>: View where TimestampLabel : View {
    let stepForward: () -> Void
    let stepBackward: () -> Void
    let timestampLabel: TimestampLabel
    var body: some View {

        GeometryReader { metrics in
            HStack(alignment: .bottom, spacing: 2) {
                Group {
                
                Button(action: {
                    self.stepBackward()
                }, label: { self.backView.padding(7) })
                    .layoutPriority(1)
//                Spacer()
                self.timestampLabel
                    .noAnimations()
                    .minimumScaleFactor(0.7)
                .allowsTightening(true)
                    .layoutPriority(2)
                Button(action: {
                    self.stepForward()
                }, label: { self.forwardView.padding(7) })
                .layoutPriority(1)
                    
                }
                .background(Color.black.opacity(0.5).cornerRadius(4, corners: [.topLeft, .topRight]))


            }

            .frame(height: metrics.size.height, alignment: .bottom)
        }
    }
    
    var backView: some View {
        return Image.symbol("backward.fill", .init(pointSize: 15))!.foregroundColor(Color.white)
            //.shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 0)
    }
    
    var forwardView: some View {
        return Image.symbol("forward.fill", .init(pointSize: 15))!.foregroundColor(Color.white)
            //.shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 0)

    }
}


struct OpacityModifier: ViewModifier {
    @Binding var controlsVisible: Bool
    
    func body(content: Content) -> some View {
        content.opacity(self.controlsVisible ? 1 : 0)
    }
}

struct PlayerLabelView<Player>: View where Player: PlayerView {
    let borderColor = Color.gray
    
    let playerView: Player
    let label: String
    let frameIncrement: CGFloat
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails

    @ObservedObject var controlsState: ControlsState
    
    let adjustedTime: (CGFloat) -> Void
    
    let duration: Double
    
    @Binding var timestamp: CGFloat
    
    var body: some View {
        Group {
            GeometryReader { metrics in
                ZStack {
                    self.playerView
                        .zIndex(1)
                    
                    Group {
//                        self.text
//                            .frame(width: metrics.size.width, height: metrics.size.height)
//                            .shadow(color: Color.black, radius: 2, x: 0, y: 1)
//                        
//                        self.playerView
//                            .mask(self.text
//                                .frame(width: metrics.size.width,
//                                       height: metrics.size.height)
//                            )
//                            .brightness(0.3)
                        
                        StepperView(stepForward: self.stepForward,
                                    stepBackward: self.stepBackward,
                                    timestampLabel: self.getTimestampLabel())
                    }
//                    .opacity(self.controlsState.controlsVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3))
                    .zIndex(2)
                }
            }
        }
//        .overlay(self.getTimestampLabel())
    }
    
    var text: Text {
        Text(self.label.uppercased())
            .font(.system(size: 20))
            .fontWeight(.bold)
            .foregroundColor(Color.text)
    }
    
    func stepForward() {
        self.controlsState.resetTimer()
        self.playerView.timestamp = self.playerView.timestamp + self.frameIncrement
        self.adjustedTime(self.playerView.timestamp)
    }
    
    func stepBackward() {
        self.controlsState.resetTimer()
        self.playerView.timestamp = self.playerView.timestamp - self.frameIncrement
        self.adjustedTime(self.playerView.timestamp)
    }
    
    func getTimestampLabel() -> some View{
        let duration = self.duration
        let seconds = duration * Double(self.timestamp)
        let formatted = seconds.secondsToFormattedTimestamp()

        
        return TimestampLabel(text: formatted)
    }
}

struct PlayerView_Previews: PreviewProvider {
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
