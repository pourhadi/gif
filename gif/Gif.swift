//
//  Gif.swift
//  gif
//
//  Created by dan on 12/7/19.
//  Copyright © 2019 dan. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices
import SwiftUI
import Combine
import AVFoundation

struct GifConfigDiff {
    let selectionChanged: Bool
    let settingsChanged: Bool
    
    let framesChanged: Bool
}

struct GifDefinition {
    let frames: [UIImage]
    let duration: TimeInterval
    
    static var empty: GifDefinition {
        return GifDefinition(frames: [], duration: 0)
    }
    
    var uiImage: UIImage? {
        return UIImage.animatedImage(with: self.frames, duration: self.duration)
    }
}

class GifConfig: ObservableObject, Equatable {
    struct Selection: Equatable {
        var startTime: CGFloat = 0
        var endTime: CGFloat = 0

    }
    
    enum AnimationQuality: CaseIterable, Hashable, Identifiable {
        var id: Self { return self }
        
        case high
        case medium
        case low
        
        var name: String {
            return "\(self)".capitalized
        }
        
        static var all: [Self] {
            return Self.allCases
        }
        
        var frameMultiplier: Int {
            switch self {
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
        
        var jpegQuality: CGFloat {
            switch self {
            case .high: return 1
            case .medium: return 0.7
            case .low: return 0.4
            }
        }
    }

    @Published var animationQuality: AnimationQuality = .medium
    @Published var speed: CGFloat = 1.0
    @Published var sizeScale: CGFloat = 1.0
        
    @Published var selection = Selection()
    
    @Published var visible = false
    
    struct Values {
        let animationQuality: AnimationQuality
        let speed: CGFloat
        let sizeScale: CGFloat
        let selection: Selection
        
        static var empty: Self {
            return Values(animationQuality: .high, speed: 0, sizeScale: 0, selection: Selection())
        }
        
        func diff(_ other: Self) -> GifConfigDiff {
            let selectionChanged = selection != other.selection
            let settingsChanged = animationQuality != other.animationQuality || speed != other.speed || sizeScale != other.sizeScale
            
            let framesChanged = animationQuality != other.animationQuality || sizeScale != other.sizeScale || selectionChanged
            
            return GifConfigDiff(selectionChanged: selectionChanged, settingsChanged: settingsChanged, framesChanged: framesChanged)
        }
    }
    
    var values: AnyPublisher<GifConfig.Values, Never> {
        return $animationQuality.combineLatest($speed, $sizeScale, $selection).map { animationQuality, speed, sizeScale, selection in
            
            return Values(animationQuality: animationQuality, speed: speed, sizeScale: sizeScale, selection: selection) }.eraseToAnyPublisher()
    }
    
    var adjustedFps: Int {
        return Int(self.assetInfo.fps) / self.animationQuality.frameMultiplier
    }

    let assetInfo: AssetInfo
    init(assetInfo: AssetInfo) {
        self.assetInfo = assetInfo
    }
    
    
    static func == (lhs: GifConfig, rhs: GifConfig) -> Bool {
        return lhs.animationQuality == rhs.animationQuality && lhs.speed == rhs.speed && lhs.sizeScale == rhs.sizeScale && lhs.selection == rhs.selection
    }
}


class GifGenerator: ObservableObject {
    @Published var gifDefinition = GifDefinition.empty
    @Published var reloading = false
    
    let video: Video
    var currentPlayState: PlayState
    let gifQueue = DispatchQueue(label: "createGif.queue")
    var cancellables = Set<AnyCancellable>()
    let frameGenerator: AVAssetImageGenerator
    
    let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("frames")
    
    init(video: Video) {
        self.video = video
        self.currentPlayState = video.playState
        
        self.frameGenerator = AVAssetImageGenerator(asset: video.asset)
        self.frameGenerator.appliesPreferredTrackTransform = true
        self.frameGenerator.requestedTimeToleranceAfter = CMTime.zero
        self.frameGenerator.requestedTimeToleranceBefore = CMTime.zero
        video.gifConfig.values
            .receive(on: DispatchQueue.main)
            .assign(to: \.config, on: self)
            .store(in: &cancellables)
        
        
        
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    var config: GifConfig.Values = GifConfig.Values.empty {
        didSet {
            let diff = config.diff(oldValue)
            
            if diff.framesChanged {
                self.frameGenerator.cancelAllCGImageGeneration()
                
                self.getFrames()
                    .receive(on: DispatchQueue.main)
                    .flatMap { self.getDefinition(for: $0) }
                    .assign(to: \.gifDefinition, on: self)
                    .store(in: &cancellables)
            } else if diff.settingsChanged {
                self.getDefinition(for: self.gifDefinition.frames)
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.gifDefinition, on: self)
                    .store(in: &cancellables)
            }
        }
    }
    
    func getDefinition(for frames: [UIImage]) -> AnyPublisher<GifDefinition, Never> {
        let duration = TimeInterval(Double(frames.count) / Double(self.video.gifConfig.adjustedFps) / Double(self.config.speed))
        
        return Just(GifDefinition(frames: frames, duration: duration)).eraseToAnyPublisher()
    }
    
    func getFrames(preview: Bool = true) -> AnyPublisher<[UIImage], Never> {
        return Future<[UIImage], Never> { promise in
            DispatchQueue.main.async {
                self.reloading = true
            }
            
            try? FileManager.default.removeItem(at: self.temporaryDirectoryURL)
            try? FileManager.default.createDirectory(at: self.temporaryDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            
            self.frameGenerator.maximumSize = preview ? CGSize(width: 500, height: 500) : self.video.assetInfo.size.applying(.init(scaleX: self.config.sizeScale, y: self.config.sizeScale))
            
            var times = [NSValue]()
            let frameMultiplier = self.config.animationQuality.frameMultiplier
            
            let totalFrames = Double(self.video.assetInfo.fps) * self.video.assetInfo.duration
            let startFrame = Int(self.config.selection.startTime * CGFloat(totalFrames)) - frameMultiplier
            let endFrame = Int(self.config.selection.endTime * CGFloat(totalFrames)) + frameMultiplier
            
            for x in stride(from: startFrame, to: endFrame, by: frameMultiplier) {
                let time = CMTime(value: CMTimeValue(x), timescale: CMTimeScale(self.video.assetInfo.fps))
                if time < self.video.asset.duration {
                    times.append(NSValue(time:time))
                }
            }
            
            var results = [UIImage]()
            self.frameGenerator.generateCGImagesAsynchronously(forTimes: times as [NSValue]) { (requested, cgImage, actual, result, error) in
                autoreleasepool {
                    if let _ = error {
                        promise(.success(results))
                        return
                    }
                    
                    guard let cgImage = cgImage else {
                        return
                    }
                    
                    let image = UIImage(cgImage: cgImage)
                    if let data = image.jpegData(compressionQuality: preview ? 0.5 : self.config.animationQuality.jpegQuality) {
                        if let image = UIImage(data: data) {
                            results.append(image)
                        }
                        
                        /*let fileURL = self.temporaryDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                        
                        do {
                            try data.write(to: fileURL)
                            if let image = UIImage(contentsOfFile: fileURL.absoluteString) {
                                results.append(image)
                            }
                        } catch {
                            print(error)
                        }*/
                        
                    }
                    
                    
                    if results.count == times.count {
                        
                        DispatchQueue.main.async {
                            self.reloading = false
                        }
                        promise(.success(results))
                    }
                    
                }
                
            }
            
        }.eraseToAnyPublisher()
    }
    
    func generateGif(photos: [UIImage], filename: String, frameDelay: Double) -> AnyPublisher<URL?, Never> {
        
        return Future<URL?, Never> { (promise) in
            let documentsDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let path = documentsDirectoryPath.appending(filename)
            let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
            let gifProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay]]
            let cfURL = URL(fileURLWithPath: path) as CFURL
            if let destination = CGImageDestinationCreateWithURL(cfURL, kUTTypeGIF, photos.count, nil) {
                CGImageDestinationSetProperties(destination, fileProperties as CFDictionary?)
                for photo in photos {
                    CGImageDestinationAddImage(destination, photo.cgImage!, gifProperties as CFDictionary?)
                }
                if (CGImageDestinationFinalize(destination)) {
                    promise(.success(cfURL as URL))
                    return
                }
            }
            promise(.success(nil))
        }.eraseToAnyPublisher()
        
    }
    
}
