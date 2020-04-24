//
//  PreviewView.swift
//  gif
//
//  Created by dan on 12/11/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import SnapKit
import UIKit
import AVFoundation

class _PreviewVideoView : CustomPlayerView {
    
}

struct PreviewVideoView : UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    
    let url: URL
    @Binding var config: GifConfig.Values
    
    func makeUIView(context: Context) -> _PreviewVideoView {
        let v = _PreviewVideoView()
        v.isOpaque = false
        if let player = EditorStore.players[.preview] {
            v.player = player
        } else {
            let player = AVPlayer(url: self.url)
            EditorStore.players[.preview] = player
            v.player = player
        }
        v.clipsToBounds = true
        (v.layer as! AVPlayerLayer).videoGravity = .resizeAspect
        
        return v
    }
    
    func updateUIView(_ uiView: _PreviewVideoView, context: Context) {
        if let player = uiView.player,
            let duration = player.currentItem?.duration {
            
            player.isMuted = true
            
            if let observer = context.coordinator.observer {
                player.removeTimeObserver(observer)
            }
            
            if let startObserver = context.coordinator.startObserver {
                player.removeTimeObserver(startObserver)
            }
            
            let startTime = CMTime(seconds: duration.seconds * Double(self.config.selection.startTime), preferredTimescale: 1000)
            let endTime = CMTime(seconds: duration.seconds * Double(self.config.selection.endTime), preferredTimescale: 1000)
            
            context.coordinator.observer = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: nil, using: { [weak player] in
                player?.pause()
                
                switch self.config.animationType {
                case .palindrome:
                    player?.playImmediately(atRate: -1)
                case .regular:
                    player?.seek(to: startTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                    player?.playImmediately(atRate: 1)
                case .reverse:
                    player?.playImmediately(atRate: -1)
                }
            })
            
            if self.config.animationType == .palindrome || self.config.animationType == .reverse {
                context.coordinator.startObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: startTime)], queue: nil, using: { [weak player] in
                    player?.pause()
                    
                    switch self.config.animationType {
                    case .palindrome:
                        player?.playImmediately(atRate: 1)
                    case .regular:
                        break
                    case .reverse:
                        player?.seek(to: endTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                        player?.playImmediately(atRate: -1)
                    }
                })
            }
            
            
            if self.config.animationType == .reverse {
                player.seek(to: endTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                player.playImmediately(atRate: -1)
            } else {
                player.seek(to: startTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                player.playImmediately(atRate: 1)
            }
        }
    }
    
    static func dismantleUIView(_ uiView: _PreviewVideoView, coordinator: Coordinator) {
        if let player = uiView.player {
            player.pause()
            
            if let observer = coordinator.observer {
                player.removeTimeObserver(observer)
            }
            
            if let startObserver = coordinator.startObserver {
                player.removeTimeObserver(startObserver)
            }
        }
        
        
    }
    
    typealias UIViewType = _PreviewVideoView
    
    class Coordinator {
        let parent: PreviewVideoView
        
        
        var observer: Any?
        var startObserver: Any?
        
        init(_ parent: PreviewVideoView) {
            self.parent = parent
            
            
        }
    }
    
    
}

struct PreviewModal<Generator>: View where Generator : GifGenerator {
    @Binding var activePopover: ActivePopover?
    
    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                PreviewView<Generator>().frame(width: metrics.size.width - 20, height: metrics.size.height - 20).scaledToFit().clipped().centered()
            }
        }.navigationBarTitle("Preview GIF")
            .navigationViewStyle(StackNavigationViewStyle())

            .navigationBarItems(trailing: Button(action: {
                self.activePopover = nil
            }, label: { Text("Done") } ))
    }
}

struct PreviewView<Generator>: View where Generator : GifGenerator {
    
    @EnvironmentObject var generator: Generator

    var body: some View {
        GeometryReader { metrics in
            AnimatedImage(gifDefinition: self.$generator.gifDefinition)
            if self.generator.reloading {
                LoadingView().frame(width: metrics.size.width, height: metrics.size.height)
            }
        }
    }
}

struct VideoPreviewView: View {
    
    @EnvironmentObject var generator: VideoGifGenerator

    var body: some View {
        PreviewVideoView(url: self.generator.url, config: self.$generator.config)
    }
}


//extension PreviewView where Generator: GifG {
//    var body: some View {
//        GeometryReader { metrics in
//            PreviewVideoView(url: self.generator.url, config: self.$generator.config)
//        }
//    }
//}
//
//
//extension PreviewView where Generator == VideoGifGenerator {
//    var body: some View {
//        GeometryReader { metrics in
//        }
//    }
//}

class AnimatedImageContainer: UIView {
    let imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct AnimatedImage: UIViewRepresentable {
    @Binding var gifDefinition: GifDefinition

    func makeUIView(context: UIViewRepresentableContext<AnimatedImage>) -> AnimatedImageContainer {
        let imgView = AnimatedImageContainer(frame: CGRect.zero)
        imgView.imageView.startAnimating()
        imgView.imageView.contentMode = .scaleAspectFit
        imgView.imageView.clipsToBounds = true
        return imgView
    }
    
    func updateUIView(_ uiView: AnimatedImageContainer, context: UIViewRepresentableContext<AnimatedImage>) {
        uiView.imageView.image = gifDefinition.uiImage
        uiView.imageView.animationDuration = gifDefinition.duration
        uiView.imageView.startAnimating()
    }
    
    typealias UIViewType = AnimatedImageContainer
    
    
}
