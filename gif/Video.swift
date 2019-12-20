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

public enum VideoMode {
    case playhead
    case start
    case end
}


struct PlayState: Equatable {
    var startTime: CGFloat = 0
    var endTime: CGFloat = 0
    var currentPlayhead: CGFloat = 0
    
    var playing: Bool = false
    
    var previewing = false
    
    func gifSelectionEqual(_ other: Self?) -> Bool {
        return self.startTime == other?.startTime && self.endTime == other?.endTime
    }
}

struct AssetInfo {
    let fps: Float
    let duration: Double
    let size: CGSize
    
    var unitFrameIncrement: CGFloat {
        let totalFrames = fps * Float(duration)
        return CGFloat(1 / totalFrames)
    }
    
    static var empty: Self {
        return Self(fps: 0, duration: 0, size: CGSize.zero)
    }
}



class Video: ObservableObject {
    var data: Data?
    
    var isValid: Bool {
        return asset.isReadable
    }
    
    let url: URL
    
    @Published var playState = PlayState()
    @Published var timelineItems = [TimelineItem]()
    
    @Published var ready = false
        
    let asset: AVURLAsset
    
    let assetInfo: AssetInfo
    
    @Published var gifConfig: GifConfig

    init(data: Data?, url: URL) {
        self.data = data
        self.url = url
        
        let asset = AVURLAsset(url: url)
        
        if let track = asset.tracks(withMediaType: .video).last {
            self.assetInfo = AssetInfo(fps: track.nominalFrameRate, duration: asset.duration.seconds, size: track.naturalSize.applying(track.preferredTransform).absolute())
        } else {
            self.assetInfo = AssetInfo.empty
        }
        
        self.asset = asset
        self.gifConfig = GifConfig(assetInfo: self.assetInfo)
    }
    
    static func empty() -> Video {
        return Video(data: nil, url: URL.init(string: "/")!)
    }
    
    static var preview: Video {
        return Video(data: nil, url: Bundle.main.url(forResource: "test_movie", withExtension: "mov")!)
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
    
    let generator: AVAssetImageGenerator
    let asset: AVAsset
    init(url: URL) {
        self.asset = AVAsset(url: url)
        self.generator = AVAssetImageGenerator(asset: self.asset)
        self.generator.appliesPreferredTrackTransform = true
        self.generator.maximumSize = CGSize(width: 100, height: 100)
    }
    
    func getThumbs(for video: URL, multiplier: CGFloat = 1) -> Future<[TimelineThumb], Never> {
        
        self.generator.cancelAllCGImageGeneration()
        
        return Future { (doneBlock) in
            var times = [NSValue]()
            
            for x in stride(from: 0, through: self.asset.duration.seconds, by: Double(1 / multiplier)) {
                times.append(NSValue(time: CMTime(seconds: ((x)), preferredTimescale: CMTimeScale(1))))

            }

            var results = [TimelineThumb]()
            
            self.generator.generateCGImagesAsynchronously(forTimes: times as [NSValue]) { (requested, cgImage, actual, result, error) in
                
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
        }
        
    }
    
}

struct ImagePickerController: UIViewControllerRepresentable {
    
//     var selectedVideo: CurrentValueSubject<Video?, Never>
    @Binding var presentedVideoPicker: Bool
    @Binding var video: Video
    
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
        return vc
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePickerController
        
        init(_ imagePickerController: ImagePickerController) {
            self.parent = imagePickerController
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                self.parent.video = Video(data: nil, url: url)
            }
            
            self.parent.presentedVideoPicker = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.parent.presentedVideoPicker = false
            picker.dismiss(animated: true, completion: nil)
        }
    }
}
