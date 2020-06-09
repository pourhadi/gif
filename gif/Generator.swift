//
//  Generator.swift
//  giffed
//
//  Created by Daniel Pourhadi on 6/2/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import YYImage
import Combine
import Drawsana
import AVFoundation

protocol GifGenerator : ObservableObject {
    
    var gifDefinition: GifDefinition { get set }
    var reloading: Bool { get set}
    
    func getFrames(preview: Bool) -> AnyPublisher<[UIImage], Never>
}

func generateGif(urls: [URL], filename: String, frameDelay: Double) -> AnyPublisher<URL?, Never> {
    
    return Future<URL?, Never> { (promise) in
        let path = NSTemporaryDirectory().appending("/\(filename)")
        
        try? FileManager.default.removeItem(atPath: path)
        
        if let encoder = YYImageEncoder(type: .GIF) {
            
            for image in urls {
                encoder.addImage(withFile: image.absoluteString, duration: frameDelay)
            }
            
            if encoder.encode(toFile: path) {
                promise(.success(URL(fileURLWithPath: path)))
                return
            }
            
        }
        
        promise(.success(nil))
    }.eraseToAnyPublisher()
    
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
                
                serialQueue.async {
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
            serialQueue.async {
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
    let url: URL
    init(gifConfig: GifConfig, playState: PlayState, asset: AVAsset) {
        self.gifConfig = gifConfig
        self.currentPlayState = playState
        
        self.url = (asset as! AVURLAsset).url
            
        
        
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
//                let time = CMTime(seconds: x, preferredTimescale: 1000)
                let time = CMTime(value: CMTimeValue((x * 1000)), timescale: 1000)
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
                
                if let data = image.jpegData(compressionQuality: preview ? 0.5 : CGFloat(self.config.imageQuality)) {
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

