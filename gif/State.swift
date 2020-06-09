//
//  State.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/7/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import mobileffmpeg
import MobileCoreServices



enum GenerateGIFError: Error {
      case unknownFailure
  }
  
class GlobalPublishers {
    
    static let `default` = GlobalPublishers()
    
    var readyToCrop = PassthroughSubject<GIF, Never>()
    
    var showShare: PassthroughSubject<[GIF], Never> { return share }
    
    var addText = PassthroughSubject<GIF, Never>()
    
    var created = PassthroughSubject<GIF, Never>()
    
    var share = PassthroughSubject<[GIF], Never>()
    
    var crop = PassthroughSubject<GIF, Never>()
    
    var edit = PassthroughSubject<GIF, Never>()
    
    var prepVideo = PassthroughSubject<URL, Never>()
    
    var dismissEditor = PassthroughSubject<Void, Never>()
    
    var videoReady = PassthroughSubject<Video, Never>()
}


class GIFItemProvider : NSObject, UIActivityItemSource {
    
    let gif: GIF
    
    init(_ gif: GIF) {
        self.gif = gif
        
        if gif.data == nil {
            let _ = gif.getDataSync()
        }
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return gif.data ?? Data()
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return gif.data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return kUTTypeGIF as String
    }
    
}

class GlobalState: ObservableObject {
    
    static let instance = GlobalState()
    
    var disableRotation = false
    
    var previousURL: URL? {
        set {
            UserDefaults.standard.set(newValue, forKey: "_previousURL")
        }
        get {
            return UserDefaults.standard.url(forKey: "_previousURL")
        }
    }
        
    let video: Video = Video.empty()
    var visualState = VisualState()
    @Published var activePopover: ActivePopover? = nil
    
    @Published var createdGIF: GIF? = nil
    
    var timelineState = TimelineState()
    
    var hudAlertState = HUDAlertState.global
    
    
    var cancellables = Set<AnyCancellable>()
    
    let deviceDetails = DeviceDetails()
    
    @Published var urlEntry: URL? = nil
    
    init() {
        self.deviceDetails.$orientation.map {
            VisualState($0 == .landscape && self.deviceDetails.uiIdiom == .phone)
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.visualState, on: self)
        .store(in: &self.cancellables)
        
        GlobalPublishers.default.readyToCrop.sink { gif in
            
            self.crop(gif)
            
        }.store(in: &self.cancellables)
        
        GlobalPublishers.default.prepVideo.sink { url in
            
            Delayed(0.2) {
                self.hudAlertState.showLoadingIndicator = true
                            }
                    
                    
                    
                    Converter.convert(url: url) { (newUrl) in
                        if let newUrl = newUrl {
                            
                            Async {
                                
                                self.video.reset(newUrl)
                            }
                            
                        } else {
                            Async {
                                self.hudAlertState.show(.error("Error loading video"))
                            }
                        }
                        
                    }
            
        }.store(in: &self.cancellables)
    }
    
    func crop(_ gif: GIF) {
        guard let cropState = gif.cropState else { return }
        
        Async {
            self.hudAlertState.showLoadingIndicator = true
        }
        
        serialQueue.async {
            let url = gif.url
            let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.gif")
            
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
                
                var rect = cropState.cropUnitRect
                
                rect *= gif.size
                
                let cropString = "crop=\(Int(rect.size.width)):\(Int(rect.size.height)):\(Int(rect.origin.x)):\(Int(rect.origin.y))"
                
                if MobileFFmpeg.execute("-i \(localGIFURL.path) -filter:v \"\(cropString)\" \(tmpDirURL.path)") == 0 {
                    
                    let data = try Data(contentsOf: tmpDirURL)
                    FileGallery.shared.add(data: data) { (_, error) in
                        if let _ = error {
                            Async {
                                self.hudAlertState.hudAlertMessage = [.thumbdown("Error cropping")]
                            }
                        } else {
                            
                            Async {
                                self.hudAlertState.hudAlertMessage = [.init(text: "Cropped and Saved", symbolName: "checkmark")]
                                
                            }
                            
                        }
                    }
                    
                    
                } else {
                    self.hudAlertState.hudAlertMessage = [.thumbdown("Error cropping")]
                }
                
            } catch {
                
                
                Async {
                    self.hudAlertState.hudAlertMessage = [.thumbdown("Error cropping")]
                }
            }
            
        }
    }
    
    enum GenerationError : Error {
        case error
    }
  
    func saveGeneratedGIF(gif: GIF, done: ((Bool) -> Void)?) {
        guard let data = gif.data else { return }
        
        DispatchQueue.main.async {
            self.hudAlertState.showLoadingIndicator = true
        }
        
        
        
        FileGallery.shared
            .add(data: data)
            
            .replaceError(with: "")
            .flatMap { id in
                FileGallery.shared
                    .$gifs

                    .debounce(for: 0.5, scheduler: DispatchQueue.main)
                    .tryMap({ (array) -> Bool in
                        print("retry")
                        let good = array.contains { (gif) -> Bool in
                            return gif.id == id
                        }
                        
                        if good { return true }
                        throw GenerationError.error
                    })
                .retry(5)
                .replaceError(with: false)
                .first()
//                    .map { (array) -> Bool in
//                        array.contains { (gif) -> Bool in
//                            return gif.id == id
//                        }
//                }
                
        }
        .sink(receiveValue: { success in
            Delayed(0.1) {
                
                if success {
                    self.hudAlertState.hudAlertMessage = [HUDAlertMessage(text: "Saved to My GIFs!", symbolName: "checkmark")]
                    done?(true)
                }
                else {
                    self.hudAlertState.hudAlertMessage = [HUDAlertMessage(text: "Error creating GIF", symbolName: "exclamationmark.circle.fill")]
                    done?(false)
                }
            }
        })
            
            .store(in: &self.cancellables)
    }
    
    func generateGIF<Generator: GifGenerator>(editingContext: EditingContext<Generator>) {
        DispatchQueue.main.async {
            self.hudAlertState.showLoadingIndicator = true
        }
        
        /*
         
         60 frames, 30fps = 2 seconds, frame delay 1/30
         
         */
        
//        let dur = editingContext.gifConfig.selectionDuration / Double(editingContext.gifConfig.speed)
        
        editingContext.generator
            .getFrames(preview: false)
            .flatMap { images in
                editingContext.generator.generate(with: images, filename: "tmp")
        }.tryMap { (url) -> Data in
            if let url = url, let data = try? Data(contentsOf: url) {
                return data
            }
            
            throw GenerateGIFError.unknownFailure
        }
        .replaceError(with: Data.init())
        .receive(on: DispatchQueue.main)
        .map { data -> GIF? in
            guard data.count > 0 else {
                Delayed(0.5) {
                    self.hudAlertState.hudAlertMessage = [HUDAlertMessage(text: "Error creating GIF", symbolName: "exclamationmark.circle.fill")]
                }
                return nil
            }
            
            
            self.hudAlertState.showLoadingIndicator = false
            
            let gif = GIFFile(id: "tmp", url: URL.empty)
            gif.thumbnail = UIImage(data: data)
            gif._data = data
            return gif
        }
        .sink { gif in
            guard let gif = gif else { return }
            Delayed(0.2) {
                GlobalPublishers.default.created.send(gif)
            }
            
        }
            
        .store(in: &self.cancellables)
    }
}
