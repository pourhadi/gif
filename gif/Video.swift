//
//  VideoController.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Photos
import PhotosUI
import Combine
import UIKit
import SwiftUI
import AVFoundation
import mobileffmpeg
import YYImage
import Drawsana

public enum VideoMode {
    case playhead
    case start
    case end
}


struct PlayState {
    
    @Clamped
    var currentPlayhead: CGFloat = 0
    
    var playing: Bool = false
    
    var previewing = false
}


//class PlayState: ObservableObject, Equatable {
//    static func == (lhs: PlayState, rhs: PlayState) -> Bool {
//        return lhs.currentPlayhead == rhs.currentPlayhead
//    }
//
//    var startTime: CGFloat = 0
//    var endTime: CGFloat = 0
//
//    @Published var currentPlayhead: CGFloat = 0
//
//    @Published var playing: Bool = false
//
//    @Published var previewing = false
//
//    func gifSelectionEqual(_ other: PlayState?) -> Bool {
//        return self.startTime == other?.startTime && self.endTime == other?.endTime
//    }
//
//    var cancellable: AnyCancellable? = nil
//    init() {
//
//        self.cancellable = $currentPlayhead
//            .combineLatest($playing)
//            .combineLatest($previewing).sink { _ in
//                self.objectWillChange.send()
//        }
//    }
//}

struct AssetInfo {
    var fps: Float
    var duration: Double
    var size: CGSize
    
    var unitFrameIncrement: CGFloat {
        let totalFrames = fps * Float(duration)
        return CGFloat(1 / totalFrames)
    }
    
    static var empty: Self {
        return Self(fps: 0, duration: 0, size: CGSize.zero)
    }
}

class TextContext : ObservableObject {
    
    @Published var selection: GifConfig.Selection = GifConfig.Selection()
    
    var drawsanaView: DrawsanaView = DrawsanaView()
    
}


class ContextStore {
    
    static var context: AnyObject?
    
}

class EditingContext<Generator>: ObservableObject where Generator : GifGenerator {

    @Published var textFormat = TextFormat()
    
    var drawsanaView: DrawsanaView? = nil

    @Published var editingText = false
    
    var avPlayer: AVPlayer? = nil
    
    enum Mode {
        case trim
        case text
    }
    
//    var unwrappedActiveSelection : GifConfig.Selection {
//        get {
//            return self.activeSelection
//        }
//        set {
//            switch self.mode {
//            case .text: self.textContext.selection = newValue
//            case .trim: self.gifConfig.selection = newValue
//            }
//        }
//    }
        
    lazy var cropState: CropState = {
       let state = CropState()
        state.aspectRatio = self.size.width / self.size.height
        return state
    }()
    
//    @Published var activeSelection: GifConfig.Selection = GifConfig.Selection()
    
    
    @Published var mode: Mode = .trim
    
    @Published var generator: Generator
    
    var thumbGenerator: ThumbGenerator
    
    @Published var playState: PlayState
    
    var timelineItems: [TimelineItem] = []

    @Published var gifConfig: GifConfig
    
    @Published var createdGIF: GIF? = nil
    
    var item: Editable
    
    var unwrappedGifConfig: GifConfig {
        get {
            self.gifConfig
        }
        set {
            self.gifConfig = newValue
        }
    }
    
    var frameIncrement: CGFloat
    
    let size: CGSize
    
    var cancellables = Set<AnyCancellable>()
    
    var activeSelectionCancellable: AnyCancellable?
    init(item: Editable,
         gifConfig: GifConfig,
         playState: PlayState,
         frameIncrement: CGFloat,
         size: CGSize,
         generator: Generator,
         thumbGenerator: ThumbGenerator) {
        self.item = item
        self.gifConfig = gifConfig
        self.playState = playState
        self.frameIncrement = frameIncrement
        self.size = size
        self.generator = generator
        self.thumbGenerator = thumbGenerator
        
//        self.$mode.map {
//            switch $0 {
//            case .trim: return self.gifConfig.selection
//            case .text: return self.textContext.selection
//            }
//        }.assign(to: \.activeSelection, on: self)
//            .store(in: &self.cancellables)
//
//        self.gifConfig.$selection
//            .combineLatest(self.textContext.$selection)
//            .map { (trimSelection, textSelection) in
//                if self.mode == .trim {
//                    return trimSelection
//                }
//
//                return textSelection
//        }
//        .assign(to: \.activeSelection, on: self)
//        .store(in: &self.cancellables)
        
    }
}

protocol Editable {
    var url: URL { get }
    
}

extension Optional where Wrapped == URL {
    var isEmpty: Bool {
        return true
    }
}

extension URL {
    
    var nilOrNotEmpty: URL? {
        return self.absoluteString == "/" ? nil : self
    }
    
}

extension Video {
    var unwrappedGifConfig: GifConfig {
        set {
            self.gifConfig = newValue
        }
        
        get {
            return self.gifConfig
        }
    }
    
    var frameIncrement: CGFloat {
        return self.assetInfo.unitFrameIncrement
    }
    
    var size: CGSize {
        return (self.videoTrack?.naturalSize ?? CGSize.zero).applying(self.videoTrack?.preferredTransform ?? CGAffineTransform.identity)
    }
}

class Video: ObservableObject, Identifiable, Editable {

    var editingContext_blocking : EditingContext<VideoGifGenerator> {
        let sem = DispatchSemaphore(value: 0)
        
        var c: EditingContext<VideoGifGenerator>?
        serialQueue.async {
            while self.videoTrack == nil {
                continue
            }
            
            c = self.editingContext
            sem.signal()
        }
        
        sem.wait()
        return c!
    }
    
    var editingContext: EditingContext<VideoGifGenerator> {
        if let context = ContextStore.context as? EditingContext<VideoGifGenerator> {
            return context
        }
        
        let config = self.gifConfig
        let playState = PlayState()
        let context = EditingContext(item: self, gifConfig: config, playState: playState, frameIncrement: self.frameIncrement, size: self.size, generator: VideoGifGenerator(gifConfig: gifConfig, playState: playState, asset: self.asset), thumbGenerator: ThumbGenerator(item: self))
        
        ContextStore.context = context
        return context
    }
    
    var id = UUID()
    
    var data: Data?
    
    @Published var isValid:Bool? = nil
    
    var readyToEdit = PassthroughSubject<Bool?, Never>()
    
    var updated = PassthroughSubject<Video, Never>()

    
    @Published var url: URL = URL.init(string: "/")!
    
    var playState = PlayState()
    var timelineItems = [TimelineItem]()
    
    var ready = false
    
    var asset: AVURLAsset!
    
    var assetInfo: AssetInfo = AssetInfo.empty
    
    @Published var createdGIF: GIF? = nil
    
    @Published var gifConfig: GifConfig = GifConfig(assetInfo: AssetInfo.empty)
    
    func reset(_ url: URL? = nil) {
        
        EditorStore.reset()
        ContextStore.context = nil
        if let nonEmpty = url?.nilOrNotEmpty {
            GlobalState.instance.previousURL = nonEmpty
        }
        
        self.timelineItems = []

        self.assetInfo = AssetInfo.empty
        self.gifConfig = GifConfig(assetInfo: self.assetInfo)
        self.isValid = nil

        if let url = url {
            self.url = url
            
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            self.asset = asset
            
            self.asset.loadValuesAsynchronously(forKeys: ["readable", "duration"]) {
                if let track = asset.tracks(withMediaType: .video).last {
                    self.assetInfo = AssetInfo(fps: track.nominalFrameRate, duration: asset.duration.seconds, size: track.naturalSize.applying(track.preferredTransform).absolute())
                } else {
                    self.assetInfo = AssetInfo.empty
                    
                    self.gifConfig = GifConfig(assetInfo: self.assetInfo)
                    
                    self.isValid = false
                    self.updated.send(self)

                    Delayed(0.2) {
                        self.readyToEdit.send(false)
                    }
                    return
                }

            self.gifConfig = GifConfig(assetInfo: self.assetInfo)
            
            Delayed(0.2) {
                if asset.isReadable {
                        self.isValid = true
                        self.readyToEdit.send(true)
                        GlobalPublishers.default.videoReady.send(self)
                    } else {
                        self.isValid = false
                        self.readyToEdit.send(false)
                    }
                }
                
                self.updated.send(self)
                
            }
        } else {
            self.url = URL.init(string: "/")!
            self.readyToEdit.send(nil)

            self.updated.send(self)
        }
    }
    
    init(data: Data?, url: URL) {
        self.data = data
        
//        self.reset(url)
        
        
        
    }
    
    static func createFromGIF(url: URL, completion: (Video?) -> Void) {
        let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("tmpVideo.mp4")
        
        let localGIFURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            
            if FileManager.default.fileExists(atPath: tmpDirURL.path) {
                try FileManager.default.removeItem(at: tmpDirURL)
            }
            
            if FileManager.default.fileExists(atPath: localGIFURL.path) {
                try FileManager.default.removeItem(at: localGIFURL)
            }
            
        } catch { }
        
        do {
            
            try FileManager.default.copyItem(at: url, to: localGIFURL)
            
            if MobileFFmpeg.execute("-i \(localGIFURL.path) -pix_fmt yuv420p -vf \"crop=trunc(iw/2)*2:trunc(ih/2)*2\" \(tmpDirURL.path)") == 0 {
                
                let video = Video(data: nil, url: tmpDirURL)
                let selection = GifConfig.Selection(startTime: 0, endTime: 1)
                video.gifConfig.selection = selection
                video.gifConfig.animationQuality = .high
                completion(video)
            } else {
                completion(nil)
            }
            
        } catch {
            
            completion(nil)
        }
        
    }
    
    static func empty() -> Video {
        return Video(data: nil, url: URL.init(string: "/")!)
    }
    
    static var preview: Video {
        let v = Video(data: nil, url: Bundle.main.url(forResource: "test_movie", withExtension: "mov")!)
        v.reset(Bundle.main.url(forResource: "test_movie", withExtension: "mov")!)
        
        Thread.sleep(forTimeInterval: 2)
        return v
    }
    
    var videoTrack: AVAssetTrack? {
        return self.asset.tracks(withMediaType: .video).last
    }
}

struct TimelineThumb {
    let image: UIImage
    let time: CMTime
}

class ThumbGenerator {
    
    let generator: AVAssetImageGenerator?
    let asset: AVAsset?
    
    var gif: GIF? = nil
    
    init(item: Editable) {
        
        if item is GIF {
            self.generator = nil
            self.asset = nil
            self.gif = item as? GIF
        } else {


            let url = (item as! Video).url
            
            self.asset = AVAsset(url: url)
            self.generator = AVAssetImageGenerator(asset: self.asset!)
            self.generator?.appliesPreferredTrackTransform = true
            self.generator?.maximumSize = CGSize(width: 100, height: 100)
        }
    }
    
    init(url: URL) {
        self.asset = AVAsset(url: url)
        self.generator = AVAssetImageGenerator(asset: self.asset!)
        self.generator?.appliesPreferredTrackTransform = true
        self.generator?.maximumSize = CGSize(width: 100, height: 100)
    }
    
    func getThumbs(for item: Editable, multiplier: CGFloat = 1) ->
        AnyPublisher<[TimelineThumb], Never> {
            
//            guar/d self.asset != nil else { return Just([]).eraseToAnyPublisher() }
        self.generator?.cancelAllCGImageGeneration()
        
        return Future { (doneBlock) in
            if let gif = self.gif, let animatedImages = gif.animatedImage?.images {
                serialQueue.async {
                    
                    var results = [TimelineThumb]()

                    results = animatedImages.map { img in
                        
                        
                        return TimelineThumb(image: img, time: CMTime.zero)
                    }
                    
                    doneBlock(.success(results))
                }
                
                return
    
            }
            
            
            
            var times = [NSValue]()
            
            for x in stride(from: 0, through: self.asset!.duration.seconds, by: Double(1 / multiplier)) {
                times.append(NSValue(time: CMTime(seconds: ((x)), preferredTimescale: CMTimeScale(1))))
                
            }
            
            var results = [TimelineThumb]()
            
            self.generator!.generateCGImagesAsynchronously(forTimes: times as [NSValue]) { (requested, cgImage, actual, result, error) in
                
                if let _ = error {
                    doneBlock(.success(results))
                    return
                }
                
                guard let image = cgImage else {
                    return
                }
                
                results.append(TimelineThumb(image: UIImage(cgImage: image), time: actual))
                
                if results.count == times.count {
                    doneBlock(.success(results))
                }
                
            }
        }.eraseToAnyPublisher()
        
    }
    
}

struct ImagePickerController: UIViewControllerRepresentable {
    
    //     var selectedVideo: CurrentValueSubject<Video?, Never>
    var video: Video
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePickerController>) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    
    typealias UIViewControllerType = UIImagePickerController
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.delegate = context.coordinator
        vc.mediaTypes = ["public.movie"]
        vc.videoQuality = .type640x480
        return vc
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePickerController
        
        init(_ imagePickerController: ImagePickerController) {
            self.parent = imagePickerController
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                self.parent.video.reset(url)
                picker.dismiss(animated: true, completion: nil)

            }
            
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: nil)
        }
    }
}

class Converter {
    
    static var exportSession: AVAssetExportSession?
    
    static func convert(url: URL, done: @escaping (URL?) -> Void) {
        serialQueue.async {
            let anAsset = AVURLAsset(url: url)
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("tmpvid.mp4")
            
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch {
                
            }
            
            // These settings will encode using H.264.
            let preset = AVAssetExportPreset1280x720
            let outFileType = AVFileType.mp4
            
            AVAssetExportSession.determineCompatibility(ofExportPreset: preset, with: anAsset, outputFileType: outFileType, completionHandler: { (isCompatible) in
                if !isCompatible {
                    return
                }})
            
            exportSession = AVAssetExportSession(asset: anAsset, presetName: preset)
            
            guard let export = exportSession else {
                return
            }
            
            export.outputFileType = outFileType
            export.outputURL = outputURL
            export.exportAsynchronously { [unowned export] () -> Void in
                
                if export.status == .cancelled || export.status == .failed {
                    done(nil)
                } else if export.status == .completed {
                    done(outputURL)
                }
                
            }
        }
    }
    
}
