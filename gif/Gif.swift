//
//  Gif.swift
//  gif
//
//  Created by dan on 12/7/19.
//  Copyright © 2019 dan. All rights reserved.
//

import UIKit
import ImageIO.CGImageAnimation
import ImageIO.CGImageSource
import MobileCoreServices
import SwiftUI
import Combine
import AVFoundation
import YYImage
import Drawsana

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


extension Collection where Element == GifConfig.Selection {
    func selectionDuration(for duration: Double) ->  Double {
        return self.reduce(Double(0)) { (last, selection) -> Double in
            return last + selection.seconds(for: duration)
        }
    }
}

@propertyWrapper
struct Clamped {
    private var number: CGFloat = 0
    var wrappedValue: CGFloat {
        get { return number }
        set { number = newValue.clamp() }
    }
}

class GifConfig: ObservableObject, Equatable {
    enum AnimationType: CaseIterable, Hashable, Identifiable {
        var id: Self { return self }
        
        case regular
        case reverse
        case palindrome
        
        var name: String {
            return "\(self)".capitalized
        }
        
        static var all: [Self] {
            return Self.allCases
        }
        
    }
    
    @Published var regenerateFlag: UUID = UUID()
    
    @Published var animationType = AnimationType.regular
    
    struct Selection: Equatable {
        static func == (lhs: GifConfig.Selection, rhs: GifConfig.Selection) -> Bool {
            return lhs.startTime == rhs.startTime && lhs.endTime == rhs.endTime
        }
        
        init(startTime: CGFloat = 0, endTime: CGFloat = 0, fiveSecondValue: CGFloat = 0) {
            self.fiveSecondValue = fiveSecondValue
            
            self.startTime = startTime
            self.endTime = endTime
        }
        
        
        @Clamped var startTime: CGFloat {
            didSet {
                if endTime < startTime {
                    endTime = startTime + fiveSecondValue
                }
            }
        }
        
        @Clamped var endTime: CGFloat {
            didSet {
                if endTime.isInfinite {
                    self.endTime = 1
                }
                
                if endTime < startTime {
                    startTime = endTime - fiveSecondValue
                }
            }
        }
        
        
        var fiveSecondValue: CGFloat
        
        func seconds(for assetDuration: Double) -> Double {
            let diff = self.endTime - self.startTime
            return assetDuration * Double(diff)
        }
        
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
        
        var fps: Double {
            switch self {
            case .high: return 30
            case .medium: return 15
            case .low: return 8
            }
        }
    }
    
    var hideAnimationQuality = false
    
    
    
    @Published var animationQuality: AnimationQuality = .medium
    @Published var speed: CGFloat = 1.0
    @Published var sizeScale: CGFloat = 1.0
    
    @Published var selections = [Selection()]
    
    
    @Published var selection = Selection()
    
    @Published var visible = false
    
    @Published var selectedSelection = 0
    
    struct Values {
        let animationQuality: AnimationQuality
        let speed: CGFloat
        let sizeScale: CGFloat
        let selection: Selection
        let animationType: AnimationType
        let regenerate: UUID
        static var empty: Self {
            return Values(animationQuality: .high, speed: 0, sizeScale: 0, selection: Selection(), animationType: .regular, regenerate: UUID())
        }
        
        func diff(_ other: Self) -> GifConfigDiff {
            var selectionChanged = selection != other.selection
            
            var settingsChanged = animationQuality != other.animationQuality || speed != other.speed || sizeScale != other.sizeScale
            
            var framesChanged = animationQuality != other.animationQuality || sizeScale != other.sizeScale || selectionChanged || animationType != other.animationType
            
            if self.regenerate != other.regenerate {
                selectionChanged = true
                settingsChanged = true
                framesChanged = true
            }
            
            return GifConfigDiff(selectionChanged: selectionChanged, settingsChanged: settingsChanged, framesChanged: framesChanged)
        }
    }
    
    var values: AnyPublisher<GifConfig.Values, Never> {
        return $animationQuality.combineLatest($speed, $sizeScale, $selection).combineLatest($animationType).combineLatest($regenerateFlag)
            .map { (arg0, arg1) in
                let animationQuality = arg0.0.0
                let speed = arg0.0.1
                let sizeScale = arg0.0.2
                let selection = arg0.0.3
                let regenerate = arg1
                
                return Values(animationQuality: animationQuality, speed: speed, sizeScale: sizeScale, selection: selection, animationType: arg0.1, regenerate: regenerate) }.eraseToAnyPublisher()
    }
    
    var assetInfo: AssetInfo
    init(assetInfo: AssetInfo) {
        self.assetInfo = assetInfo
        
        let fiveSeconds = 5 / assetInfo.duration
        self.selection.fiveSecondValue = CGFloat(fiveSeconds)
        self.selection.startTime = 0
        self.selection.endTime = CGFloat(fiveSeconds)
    }
    
    
    static func == (lhs: GifConfig, rhs: GifConfig) -> Bool {
        return lhs.animationQuality == rhs.animationQuality && lhs.speed == rhs.speed && lhs.sizeScale == rhs.sizeScale && lhs.selection == rhs.selection
    }
    
    var selectionDuration : Double {
        //        return self.selection.reduce(Double(0)) { (last, selection) -> Double in
        //            return last + selection.seconds(for: self.assetInfo.duration)
        //        }
        
        return self.selection.seconds(for: self.assetInfo.duration)
    }
}



protocol GifGenerator : ObservableObject {
    
    var gifDefinition: GifDefinition { get set }
    var reloading: Bool { get set}
    
    func getFrames(preview: Bool) -> AnyPublisher<[UIImage], Never>
}

func generateGif(photos: [UIImage], filename: String, frameDelay: Double) -> AnyPublisher<URL?, Never> {
    
    return Future<URL?, Never> { (promise) in
        let path = NSTemporaryDirectory().appending("/\(filename)")
        
        try? FileManager.default.removeItem(atPath: path)
        
        if let encoder = YYImageEncoder(type: .GIF) {
            
            for image in photos {
                encoder.add(image, duration: frameDelay)
            }
            
            if encoder.encode(toFile: path) {
                promise(.success(URL(fileURLWithPath: path)))
                return
            }
            
        }
        
        promise(.success(nil))
    }.eraseToAnyPublisher()
    
}

extension GifGenerator {
    
    func generate(with images: [UIImage], filename: String) -> AnyPublisher<URL?, Never> {
        return self.generateGif(photos: images, filename: filename, frameDelay: self.gifDefinition.duration / Double(self.gifDefinition.frames.count))
    }
    

    func generateGif(photos: [UIImage], filename: String, frameDelay: Double) -> AnyPublisher<URL?, Never> {
        
        return Future<URL?, Never> { (promise) in
            let path = NSTemporaryDirectory().appending("/\(filename)")
            
            if let encoder = YYImageEncoder(type: .GIF) {
                
                for image in photos {
                    encoder.add(image, duration: frameDelay)
                }
                
                if encoder.encode(toFile: path) {
                    promise(.success(URL(fileURLWithPath: path)))
                    return
                }
                
            }
            
            //            let path = NSTemporaryDirectory().appending("/\(filename)")
            //            let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
            //            let gifProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay]]
            //            let cfURL = URL(fileURLWithPath: path) as CFURL
            //            if let destination = CGImageDestinationCreateWithURL(cfURL, kUTTypeGIF, photos.count, nil) {
            //                CGImageDestinationSetProperties(destination, fileProperties as CFDictionary?)
            //                for photo in photos {
            //                    CGImageDestinationAddImage(destination, photo.cgImage!, gifProperties as CFDictionary?)
            //                }
            //                if (CGImageDestinationFinalize(destination)) {
            //                    promise(.success(cfURL as URL))
            //                    return
            //                }
            //            }
            promise(.success(nil))
        }.eraseToAnyPublisher()
        
    }
}

extension GifGenerator {
    func getFrames() -> AnyPublisher<[UIImage], Never> {
        return self.getFrames(preview: false)
    }
}


class TextFrameGenerator: ExistingFrameGenerator {
    
    //    func generate(with filename: String) -> AnyPublisher<URL?, Never> {
    //        return self.generateGif(photos: self.gifDefinition.frames, filename: filename, frameDelay: self.gifDefinition.duration / Double(self.gifDefinition.frames.count))
    //    }
    
    let drawsana: DrawsanaView
    
    init(gif: GIF, drawsana: DrawsanaView) {
        self.drawsana = drawsana
        super.init(gif: gif)
    }
    
    override func getFrames(preview: Bool = true) -> AnyPublisher<[UIImage], Never> {
        return Future<[UIImage], Never> { (promise) in
            autoreleasepool {
                var images = self.image.images ?? []
                
                let startFrame = Int(Double(self.config.selection.startTime) * Double(images.count))
                let endFrame = Int(Double(self.config.selection.endTime) * Double(images.count))
                
                guard images.count > 0 else {
                    promise(.success([]))
                    return
                }
                
                let image = images[0]
                
                
                self.drawsana.selectionIndicatorView.alpha = 0
                UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
                self.drawsana.drawHierarchy(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height), afterScreenUpdates: true)
                let overlay = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                
                //                let o = self.drawsana.snapshotView(afterScreenUpdates: true)
                Async {
                    self.drawsana.selectionIndicatorView.alpha = 1
                }
                
                DispatchQueue.global().async {
                    autoreleasepool {
                        for x in startFrame..<endFrame {
                            let image = images[x]
                            var newImage = image
                            
                            //                if let text = self.drawsana.drawHierarchy(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height), afterScreenUpdates: false) {
                            UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
                            image.draw(at: .zero)
                            //                    text.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
                            
                            //                            o?.layer.draw(in: )
                            //                            o?.layer.render(in: UIGraphicsGetCurrentContext()!)
                            overlay?.draw(at: .zero)
                            newImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                            UIGraphicsEndImageContext()
                            //                }
                            
                            images[x] = newImage
                        }
                        
                        promise(.success(images))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    
    override func getDefinition(for frames: [UIImage]) -> AnyPublisher<GifDefinition, Never> {
        return Just(GifDefinition(frames: frames, duration: self.originalDuration)).eraseToAnyPublisher()
        
    }
}

class ExistingFrameGenerator: GifGenerator {
    typealias Item = GIF
    @Published var gifDefinition = GifDefinition.empty
    @Published var reloading = false
    
    let gif: GIF
    let image: UIImage
    
    let originalDuration: Double
    
    var cancellables = Set<AnyCancellable>()
    
    
    init(gif: GIF) {
        self.gif = gif
        if let image = self.gif.animatedImage {
            self.image = image
            let dur: Double = image.duration
            //            for x in 0..<animatedImages.count {
            //                dur = dur + image.animatedImageDuration(at: x)
            //            }
            
            self.originalDuration = dur
            
        } else {
            self.image = UIImage()
            self.originalDuration = 0
        }
        
        self.gif.unwrappedGifConfig.values
            .receive(on: DispatchQueue.main)
            
            
            .assign(to: \.config, on: self)
            .store(in: &cancellables)
    }
    
    var config: GifConfig.Values = GifConfig.Values.empty {
        didSet {
            let diff = config.diff(oldValue)
            
            if diff.framesChanged {
                
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
    
    func getFrames(preview: Bool = true) -> AnyPublisher<[UIImage], Never> {
        return Future<[UIImage], Never> { (promise) in
            DispatchQueue.global().async {
                if let images = self.image.images {
                    let startFrame = Int(CGFloat(images.count) * self.config.selection.startTime)
                    let endFrame = Int(CGFloat(images.count) * self.config.selection.endTime)
                    
                    var frames = [UIImage]()
                    guard startFrame < endFrame else {
                        promise(.success([]))
                        return
                    }
                    
                    for x in startFrame..<endFrame {
                        frames.append(images[x])
                    }
                    
                    var framesCopy = frames
                    if self.config.animationType == .palindrome && frames.count > 0 {
                        var f2 = framesCopy
                        f2.removeLast()
                        framesCopy = framesCopy + f2.reversed()
                        framesCopy.removeLast()
                    } else if self.config.animationType == .reverse {
                        framesCopy = framesCopy.reversed()
                    }
                    promise(.success(framesCopy))
                    
                    
                } else {
                    promise(.success([]))
                }
                
            }
        }.eraseToAnyPublisher()
    }
    
    func getDefinition(for frames: [UIImage]) -> AnyPublisher<GifDefinition, Never> {
        var duration = TimeInterval(self.config.selection.seconds(for: self.originalDuration) / Double(self.config.speed))
        
        if self.config.animationType == .palindrome && frames.count > 0 {
            duration *= 2
        }
        
        return Just(GifDefinition(frames: frames, duration: duration)).eraseToAnyPublisher()
    }
    
}

class VideoGifGenerator: GifGenerator {
    
    @Published var gifDefinition = GifDefinition.empty
    @Published var reloading = false
    
    let gifConfig: GifConfig
    var currentPlayState: PlayState
    let gifQueue = DispatchQueue(label: "createGif.queue")
    var cancellables = Set<AnyCancellable>()
    let frameGenerator: AVAssetImageGenerator
    
    let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("frames")
    
    init(gifConfig: GifConfig, playState: PlayState, asset: AVAsset) {
        self.gifConfig = gifConfig
        self.currentPlayState = playState
        
        self.frameGenerator = AVAssetImageGenerator(asset: asset)
        self.frameGenerator.appliesPreferredTrackTransform = true
        self.frameGenerator.requestedTimeToleranceAfter = CMTime.zero
        self.frameGenerator.requestedTimeToleranceBefore = CMTime.zero
        self.gifConfig.values
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
        var duration = TimeInterval(self.config.selection.seconds(for: self.gifConfig.assetInfo.duration) / Double(self.config.speed))
        
        if self.config.animationType == .palindrome && frames.count > 0 {
            duration *= 2
        }
        
        return Just(GifDefinition(frames: frames, duration: duration)).eraseToAnyPublisher()
    }
    
    func getFrames(preview: Bool = true) -> AnyPublisher<[UIImage], Never> {
        return Future<[UIImage], Never> { promise in
            let dur = self.config.selection.seconds(for: self.gifConfig.assetInfo.duration)
            
            guard dur > 0 else {
                promise(.success([]))
                return
            }
            
            DispatchQueue.main.async {
                self.reloading = true
            }
            
            try? FileManager.default.removeItem(at: self.temporaryDirectoryURL)
            try? FileManager.default.createDirectory(at: self.temporaryDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            
//            self.frameGenerator.maximumSize = preview ? CGSize(width: 500, height: 500) : self.gifConfig.assetInfo.size.applying(.init(scaleX: self.config.sizeScale, y: self.config.sizeScale))
  
            self.frameGenerator.maximumSize = preview ? CGSize(width: 400, height: 400) : CGSize(width: 800, height: 800)

            
            var times = [NSValue]()
            
            
            
            let frameMultiplier = self.config.animationQuality.frameMultiplier
            
            //            let totalFrames = Double(self.video.assetInfo.fps) * self.video.assetInfo.duration
            //            let startFrame = Int(self.config.selection.startTime * CGFloat(totalFrames))
            //            let endFrame = Int(self.config.selection.endTime * CGFloat(totalFrames)) + frameMultiplier
            //
            //            for x in stride(from: startFrame, to: endFrame, by: frameMultiplier) {
            //                let time = CMTime(value: CMTimeValue(x * 100), timescale: CMTimeScale(self.video.assetInfo.fps * 100))
            //                if time < self.video.asset.duration {
            //                    times.append(NSValue(time:time))
            //                }
            //            }
            //
            
            
            let fps = Double(self.gifConfig.assetInfo.fps) / Double(frameMultiplier)
            //            let totalFrames = fps * dur
            
            
            let inc = dur / (fps * dur)
            
            let start = self.gifConfig.assetInfo.duration * Double(self.config.selection.startTime)
            let end = self.gifConfig.assetInfo.duration * Double(self.config.selection.endTime)
            
            for x in stride(from: start, to: (end - inc), by: inc) {
                let time = CMTime(seconds: x, preferredTimescale: 1000)
                if time.seconds < self.gifConfig.assetInfo.duration {
                    times.append(NSValue(time:time))
                }
            }
            
            var results = [UIImage]()
            self.frameGenerator.generateCGImagesAsynchronously(forTimes: times as [NSValue]) { (requested, cgImage, actual, result, error) in
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
                    }
               
                
                //                if let data = image.jpegData(compressionQuality: preview ? 0.5 : self.config.animationQuality.jpegQuality) {
                //                    if let image = UIImage(data: data) {
                //                        results.append(image)
                //                    }
                //
                //                    /*let fileURL = self.temporaryDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                //
                //                     do {
                //                     try data.write(to: fileURL)
                //                     if let image = UIImage(contentsOfFile: fileURL.absoluteString) {
                //                     results.append(image)
                //                     }
                //                     } catch {
                //                     print(error)
                //                     }*/
                //
                //                }
                
                
                if results.count == times.count {
                    
                    DispatchQueue.main.async {
                        self.reloading = false
                    }
                    
                    var framesCopy = results
                    if self.config.animationType == .palindrome && results.count > 0 {
                        var f2 = framesCopy
                        f2.removeLast()
                        framesCopy = framesCopy + f2.reversed()
                        framesCopy.removeLast()
                    } else if self.config.animationType == .reverse {
                        framesCopy = framesCopy.reversed()
                    }
                    promise(.success(framesCopy))
                }
                
                
            }
            
        }.eraseToAnyPublisher()
    }
    
    
    
}


class GIFDecoder {
    
    static func decode(from url: URL) -> (UIImage)? {
        
        if let data = try? Data(contentsOf: url) {
            return construct(with: data)
        }
        return nil
        
        //        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        //        return construct(with: source)
    }
    
    static func decode(from data: Data) -> (UIImage)? {
        return construct(with: data)
        //        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        //
        //        return construct(with: source)
    }
    
    static func construct(with data: Data) -> (UIImage)? {
        autoreleasepool {
            
            guard let decoder = YYImageDecoder(data: data, scale: UIScreen.main.scale) else { return nil }
            
            var images = [UIImage]()
            var duration : Double = 0
            for x in 0..<decoder.frameCount {
                if let frame = decoder.frame(at: x, decodeForDisplay: false), let image = frame.image {
                    images.append(image)
                    duration += frame.duration
                }
            }
            
            
            return UIImage.animatedImage(with: images, duration: duration)
        }
        
        
        //        let count = CGImageSourceGetCount(source)
        //
        //        var images = [UIImage]()
        //        var duration : Double = 0
        //
        //
        //        for x in 0..<count {
        //
        //            if let properties = CGImageSourceCopyPropertiesAtIndex(source, x, nil) as? [String: AnyObject]  {
        //                if let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Double] {
        //                    if let unclamped = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] {
        //                        duration += unclamped
        //                    } else if let clamped = gifProps[kCGImagePropertyGIFDelayTime as String] {
        //                        duration += clamped
        //                    }
        //                }
        //            }
        //
        //            if let cgImage = CGImageSourceCreateImageAtIndex(source, x, nil) {
        //                images.append(UIImage(cgImage: cgImage))
        //            }
        //        }
        //
        //        if let image = UIImage.animatedImage(with: images, duration: duration) {
        //            return (image)
        //        }
        //
        //        return nil
    }
    
}


protocol AnimationSubscriber {
    var subscriberId: UUID { get }
}

extension GIF {
    
    
    func animate(id: UUID, block: @escaping (_ ready: Bool) -> ((CGImage) -> Void)) -> Bool {
        
        
        if self.animating {
            self.animationSubscribers[id] = block(true)
            return true
        }
        
        if self.preferredSource == .url {
            if CGAnimateImageAtURLWithBlock(self.url as CFURL, nil, { [weak self] (x, img, done) in
                guard let weakSelf = self else {
                    done.pointee = true
                    return
                }
                
                if !weakSelf.animating {
                    done.pointee = true
                    return
                }
                
                self?.animationSubscribers.forEach({ (key, block) in
                    block(img)
                })
                
            }) == 0 {
                self.animationSubscribers[id] = block(true)
                return true
            } else {
                let _ = block(false)
                return true
            }
        } else {
            
            return self.getData { (data, _, sync) in
                if let data = data, CGAnimateImageDataWithBlock(data as CFData, nil, { [weak self] (x, img, done) in
                    guard let weakSelf = self else {
                        done.pointee = true
                        return
                    }
                    
                    if !weakSelf.animating {
                        done.pointee = true
                        return
                    }
                    
                    self?.animationSubscribers.forEach({ (key, block) in
                        block(img)
                    })
                }) == 0 {
                    self.animationSubscribers[id] = block(true)
                    
                } else {
                    let _ = block(false)
                }
            }
            
            
        }
    }
    
    //    func animate(_ block: @escaping (CGImage) -> Void) {
    //        guard !self.animating else { return  }
    //
    //        self.animating = true
    //
    //
    //        if self.preferredSource == .url {
    //            if CGAnimateImageAtURLWithBlock(self.url as CFURL, nil, { [unowned self] (x, img, done) in
    //
    //                if !self.animating {
    //                    done.pointee = true
    //                    return
    //                }
    //
    //                block(img)
    //
    //            }) != 0 {
    //                self.animating = false
    //            }
    //        } else {
    //
    //
    //
    //        }
    //    }
    
    func stopAnimating(id: UUID) {
        self.animationSubscribers.removeValue(forKey: id)
    }
    
}


struct AnimatedGIFView : View {
    class Store {
        
        var cancellable: AnyCancellable?
        
    }
    
    let store = Store()
    
    @Binding var gif: GIF
    
    @State var image: UIImage?
    @Binding var animated: Bool
    
    @State var loaded = false
    
    let contentMode: ContentMode
    
    init(gif: GIF, animated: Binding<Bool>, contentMode: ContentMode = .fit) {
        self._gif = Binding<GIF>(get: {
            return gif
        }, set: { (_) in
            
        })
        self._animated = animated
        self.contentMode = contentMode
        self.image = self.gif.thumbnail
        
    }
    
    init(gif: Binding<GIF>, animated: Binding<Bool>, contentMode: ContentMode = .fit){
        self._gif = gif
        self._animated = animated
        self.contentMode = contentMode
        self.image = self.gif.thumbnail

    }
    
    var body : some View {
        Group {
            
            if self.animated {
                Group {
                    if self.image != nil {
                        Image(uiImage: self.image!).resizable()
                    }
                }
                .onReceive(self.gif.nextAnimationPublisher) { (img) in
                    self.image = img
                }
            } else {
                
                if self.gif.thumbnail != nil {
                    Image(uiImage: self.gif.thumbnail!).resizable()
                }
            }
            
        }.aspectRatio(self.gif.aspectRatio, contentMode: self.contentMode)
 
//            .onAppear {
//                self.store.cancellable?.cancel()
//
//                self.store.cancellable = self.gif.nextAnimationPublisher
//                    .receive(on: DispatchQueue.main)
//                    .sink { image in
//                        self.image = image
//                }
//        }
//        .onDisappear {
//            self.store.cancellable?.cancel()
//        }
    }
}

class ImageIOAnimationView : UIImageView, AnimationSubscriber {
    
    init() {
        super.init(frame: CGRect.zero)
        
        self.layer.drawsAsynchronously = true
        self.mask = UIView()
        self.mask?.backgroundColor = UIColor.black
        self.mask?.frame = self.bounds
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.mask?.frame = self.bounds
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil {
            self.stopAnimating()
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var subscriberId: UUID = UUID()
    
    
    var running = true
    
    lazy var loading: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        self.addSubview(v)
        v.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        v.stopAnimating()
        return v
    }()
    
    var gif: GIF?
    
    deinit {
        self.cancellable?.cancel()
    }
    
    var speed: Double = 1 {
        didSet {
            guard speed != oldValue else { return }
            print("set speed imageview: \(speed)")
            self.gif?.speed = speed
            if self.cancellable != nil {
                self.stopAnimating()
                Async {
                    self.startAnimating()
                }
            }
        }
    }
    
//    override var isAnimating: Bool {
//        return self.cancellable != nil
//    }
    
    var cancellable: AnyCancellable?
    var connectedToAnimation = false
    override func startAnimating() {
        guard let gif = self.gif else { return }
        self.connectedToAnimation = true
        self.cancellable = gif.nextAnimationPublisher
//            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                
                self?.image = image
                
//                if !(self?.cancelAnimation ?? false) {
//                    self?.image = image
//                } else {
//                    self?.cancelAnimation = false
//                }
        }
    }
    
    var cancelAnimation = false
    override func stopAnimating() {
        self.cancellable?.cancel()
        self.cancellable = nil
        
        cancelAnimation = true
        self.connectedToAnimation = false
    }
    
    func set(gif: GIF?, animating: Bool) {
        guard gif != self.gif else {
            if animating != self.connectedToAnimation {
                if animating {
                    self.startAnimating()
                } else {
                    self.stopAnimating()
                }
            }
            
            return
        }
        
        self.stopAnimating()
        
        self.image = nil
        
        self.gif = gif
        
        self.image = self.gif?.thumbnail
        //        self.layer.contents = self.gif?.thumbnail?.cgImage
        
        if animating {
            self.startAnimating()
        }
        
        //        Async {
        //
        //            if animating {
        //                self.startAnimating()
        //            }
        //        }
    }
}
