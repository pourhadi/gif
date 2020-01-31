//
//  Gallery.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Combine
import Drawsana
import Foundation
import iCloudSync
import Photos
import SwiftDate
import SwiftUI
import UIKit
import YYImage

let DEMO = false

class CloudGIF: GIFFile {
    override func getData(done: @escaping (Data?, GIF, Bool) -> Void) -> Bool {
        if let data = self.data {
            done(data, self, true)
            return true
        }
        
        if !iCloud.shared.fileExistInCloud("\(self.id).gif") {
            done(nil, self, true)
            return true
        }
        
        iCloud.shared.retrieveCloudDocument("\(self.id).gif") { _, data, _ in
            DispatchQueue.main.async {
                self.data = data
                done(data, self, false)
            }
        }
        
        return false
    }
    
    init(name: String, thumbnail: UIImage? = nil, data: Data? = nil, creationDate: Date? = nil) {
        super.init(id: name.replacingOccurrences(of: ".gif", with: ""), url: iCloud.shared.cloudDocumentsURL!.appendingPathComponent(name))
        
        self.thumbnail = thumbnail
        self.data = data
        self.creationDate = creationDate
        
        if data != nil {
            self.preferredSource = .data
        }
    }
}

extension GIF {
    var unwrappedGifConfig: GifConfig {
        set {
            self.gifConfig = newValue
        }
        
        get {
            return self.gifConfig
        }
    }
    
    var frameIncrement: CGFloat { return 1 }
    
    var size: CGSize {
        if let size = _size { return size }
        
        if let thumb = self.thumbnail {
            return thumb.size
        } else if let data = self.data, let img = UIImage(data: data) {
            return img.size
        }
        
        return CGSize.zero
    }
}

class GIF: Identifiable, Equatable, Editable {
    var isDeletable = true
    
    @Published var cropState: CropState?
    
    enum PreferredSource {
        case url
        case data
    }
    
    var preferredSource = PreferredSource.url
    
    var animationSubscribers = [UUID: (CGImage) -> Void]()
    
    var animating: Bool {
        return self.subscribers > 0
    }
    
    var subscribers = 0
    
    var speed: Double = 1 {
        didSet {
            guard speed != oldValue else { return }
            
            self.killAnimation = true
            print("set speed: \(speed)")
            
            if self.subscribers >= 1 {
                DispatchQueue.global().async {
                    while self.killAnimation {
                        // wait
                    }
                    self.startAnimation()
                }
            }
        }
    }
    
    var frameDelay: Double?
    
    var reAnimate = false
    var isAnimating = false {
        didSet {
            if !self.isAnimating, self.reAnimate {
                self.reAnimate = false
                print("re-animating")
                self.subscribers += 1
                
                self.startAnimation()
            }
        }
    }
    
    var killAnimation = false
    
    lazy var nextAnimationPublisher: AnyPublisher<UIImage, Never> = {
        self.nextAnimationImageSubject.handleEvents(receiveSubscription: { [unowned self] _ in
            self.subscribers += 1
            
            print(self.id + " + 1, total: \(self.subscribers)")
            
            if self.subscribers == 1 {
                DispatchQueue.global().async {
                    while self.killAnimation {
                        // wait
                    }
                    self.startAnimation()
                }
            }
        }, receiveCancel: { [unowned self] in
            self.subscribers -= 1
            if self.subscribers == 0 {
                self.killAnimation = true
            }
            print(self.id + " - 1, total: \(self.subscribers)")
            
        }).eraseToAnyPublisher()
    }()
    
    lazy var nextAnimationImageSubject = PassthroughSubject<UIImage, Never>()
    
    var currentFrame: Int = -1
    func startAnimation() {
        guard !self.isAnimating else { return }
        self.isAnimating = true
        
        DispatchQueue.global().async {
            _ = self.getData { data, _, _ in
                
                if let data = data {
                    var dict: [CFString: CFNumber]?
                    
                    if self.speed != 1 {
                        if self.frameDelay == nil {
                            if let decoder = YYImageDecoder(data: data, scale: 1) {
                                self.frameDelay = decoder.frameDuration(at: 0)
                            }
                        }
                        
                        if let frameDelay = self.frameDelay {
                            dict = [kCGImageAnimationDelayTime: (frameDelay / self.speed) as CFNumber]
                        }
                    }
                    
                    print("start animating")
                    CGAnimateImageDataWithBlock(data as CFData, dict as CFDictionary?) { [weak self] x, img, getNext in
                        //                        print(x)
                        guard let weakSelf = self,
                            weakSelf.subscribers > 0,
                            !weakSelf.killAnimation,
                            (x == weakSelf.currentFrame + 1) || weakSelf.currentFrame == -1 || x == 0 else {
                            //                                self?.speed = 1
                            self?.currentFrame = -1
                            self?.isAnimating = false
                            print("stop animating")
                            getNext.pointee = true
                            
                            Async {
                                self?.killAnimation = false
                            }
                            return
                        }
                        
                        weakSelf.currentFrame = x
                        weakSelf.nextAnimationImageSubject.send(UIImage(cgImage: img))
                    }
                }
            }
        }
    }
    
    func reset() {
        self._animatedImage = nil
        self._data = nil
        GIF.frameData = nil
        ContextStore.context = nil
        self.cropState = nil
    }
    
    var _size: CGSize?
    
    var playState: PlayState = PlayState()
    
    var createdGIF: GIF?
    
    class FrameData {
        let gifId: String
        let animatedImage: UIImage
        
        init(gifId: String, animatedImage: UIImage) {
            self.gifId = gifId
            self.animatedImage = animatedImage
        }
    }
    
    static var frameData: FrameData?
    var _animatedImage: UIImage?
    var animatedImage: UIImage? {
        if let animatedImage = GIF.frameData?.animatedImage, GIF.frameData?.gifId == self.id {
            return animatedImage
        }
        
        if self.preferredSource == .url {
            if let img = GIFDecoder.decode(from: self.url) {
                GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
                return img
            }
        } else if self.preferredSource == .data {
            if let data = self.getDataSync(), let img = GIFDecoder.decode(from: data) {
                GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
                return img
            }
        }
        
        if let img = GIFDecoder.decode(from: self.url) {
            GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
            return img
        }
        
        if let data = self.getDataSync(), let img = GIFDecoder.decode(from: data) {
            GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
            return img
        }
        
        return nil
    }
    
    unowned var cacheManager: PHCachingImageManager?
    
    static var cache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 150 * 1000
        return cache
    }()
    
    var cancellables = Set<AnyCancellable>()
    //    var _textEditingContext: EditingContext<TextFrameGenerator>? = nil
    var textEditingContext: EditingContext<TextFrameGenerator> {
        if let context = ContextStore.context as? EditingContext<TextFrameGenerator> {
            return context
        }
        
        let drawsana = DrawsanaView()
        
        let context = EditingContext<TextFrameGenerator>(item: self, gifConfig: self.gifConfig, playState: self.playState, frameIncrement: 1, size: self.size, generator: TextFrameGenerator(gif: self, drawsana: drawsana), thumbGenerator: ThumbGenerator(item: self))
        context.mode = .text
        context.gifConfig.hideAnimationQuality = true
        context.gifConfig.assetInfo.size = self.size
        context.gifConfig.assetInfo.duration = self.animatedImage?.duration ?? 0
        
        let fiveSeconds = 5 / context.gifConfig.assetInfo.duration
        context.gifConfig.selection.fiveSecondValue = CGFloat(fiveSeconds)
        context.gifConfig.selection.endTime = 0.1
        ContextStore.context = context
        
        context.textFormat.objectWillChange.sink {
            Async {
                print(context.textFormat.color)
                
                context.generator.drawsana.userSettings.fillColor = context.textFormat.color
                context.generator.drawsana.userSettings.strokeColor = context.textFormat.color
                context.generator.drawsana.userSettings.fontName = context.textFormat.fontName
                
                let shadow = NSShadow()
                if context.textFormat.shadow {
                    shadow.shadowColor = context.textFormat.shadowColor
                    shadow.shadowOffset = CGSize(width: 0, height: context.textFormat.shadowMeasure)
                    shadow.shadowBlurRadius = 0
                } else {
                    shadow.shadowColor = UIColor.clear
                    shadow.shadowOffset = CGSize(width: 0, height: 0)
                    shadow.shadowBlurRadius = 0
                }
                
                context.generator.drawsana.userSettings.shadow = shadow.copy() as! NSShadow
                
                context.generator.drawsana.userSettings.fontName = context.generator.drawsana.userSettings.fontName.replacingOccurrences(of: "-Bold", with: "")
                
                if context.textFormat.bold {
                    context.generator.drawsana.userSettings.fontName = context.generator.drawsana.userSettings.fontName + "-Bold"
                }
                
                (context.generator.drawsana.tool as? TextTool)?.updateShapeFrame()
            }
            
        }.store(in: &self.cancellables)
        
        return context
    }
    
    //    var _editingContext: EditingContext<ExistingFrameGenerator>? = nil
    var editingContext: EditingContext<ExistingFrameGenerator> {
        if let context = ContextStore.context as? EditingContext<ExistingFrameGenerator> {
            return context
        }
        
        let context = EditingContext<ExistingFrameGenerator>(item: self, gifConfig: self.gifConfig, playState: self.playState, frameIncrement: 1, size: self.size, generator: ExistingFrameGenerator(gif: self), thumbGenerator: ThumbGenerator(item: self))
        context.gifConfig.selection.endTime = 1
        context.gifConfig.hideAnimationQuality = true
        context.gifConfig.assetInfo.size = self.size
        context.gifConfig.assetInfo.duration = self.animatedImage?.duration ?? 0
        
        let fiveSeconds = 5 / context.gifConfig.assetInfo.duration
        context.gifConfig.selection.fiveSecondValue = CGFloat(fiveSeconds)
        ContextStore.context = context
        return context
    }
    
    var id: String
    var creationDate: Date?
    
    let url: URL
    var image: UIImage?
    
    var _thumbnail: UIImage?
    var thumbnail: UIImage?
    var _data: Data?
    var data: Data?
    
    var asset: PHAsset?
    
    @Published var editing = false
    
    @Published var gifConfig: GifConfig = GifConfig(assetInfo: AssetInfo.empty)
    
    var aspectRatio: CGFloat? {
        if let thumb = self.thumbnail {
            let size = thumb.size
            return size.width / size.height
        } else if let data = self.data, let img = UIImage(data: data) {
            let size = img.size
            return size.width / size.height
        }
        return nil
    }
    
    var _duration: Double = 0
    var duration: Double {
        if self._duration != 0 { return self._duration }
        
        if let data = self.getDataSync(), let decoder = YYImageDecoder(data: data, scale: 1) {
            var dur: Double = 0
            
            for x in 0..<decoder.frameCount {
                dur += decoder.frameDuration(at: x)
            }
            
            self._duration = dur
            return dur
        }
        
        return 0
    }
    
    func getDataSync() -> Data? {
        if let data = self.data {
            return data
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var foundData: Data?
        let isSync = self.getData { data, _, sync in
            
            foundData = data
            if !sync {
                semaphore.signal()
            }
        }
        
        if !isSync {
            semaphore.wait()
        }
        
        return foundData
    }
    
    func getData(done: @escaping (_ data: Data?, _ context: GIF, _ synchronous: Bool) -> Void) -> Bool {
        return false
    }
    
    init(id: String, url: URL) {
        self.id = id
        self.creationDate = nil
        self.url = url
        self.image = nil
        self._thumbnail = nil
        self.thumbnail = nil
        self.asset = nil
        
        self.preferredSource = .url
    }
    
    init?(url: URL, thumbnail: UIImage? = nil, image: UIImage? = nil, asset: PHAsset? = nil, id: String) {
        guard url != nil || thumbnail != nil || image != nil || asset != nil else {
            return nil
        }
        self.url = url
        self._thumbnail = thumbnail
        self.image = image
        self.id = id
        self.asset = asset
        
        if asset != nil {
            self.preferredSource = .data
        }
        
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let date = attr[FileAttributeKey.creationDate] as? Date {
            self.creationDate = date
        }
    }
    
    static func == (lhs: GIF, rhs: GIF) -> Bool {
        return lhs.id == rhs.id
    }
}

extension GIF {}

class GIFFile: GIF {
    override func getData(done: @escaping (_ data: Data?, _ context: GIF, _ synchronous: Bool) -> Void) -> Bool {
        if let data = self.data {
            done(data, self, true)
            return true
        }
        
        if let asset = self.asset {
            let opt = PHImageRequestOptions()
            opt.isNetworkAccessAllowed = true
            opt.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opt) { data, _, _, _ in
                self.data = data
                DispatchQueue.main.async {
                    done(data, self, false)
                }
            }
        } else {
            done(nil, self, true)
        }
        
        return false
    }
    
    override var thumbnail: UIImage? {
        get {
            if _thumbnail != nil { return _thumbnail }
            
            if let asset = asset, let cacheManager = cacheManager {
                let opts = PHImageRequestOptions()
                opts.isSynchronous = true
                opts.deliveryMode = .fastFormat
                opts.isNetworkAccessAllowed = true
                
                var image: UIImage?
                cacheManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: opts) { imageResult, _ in
                    image = imageResult
                }
                
                return image
            } else if let data = self.data, let thumb = UIImage(data: data) {
                _thumbnail = thumb
                return thumb
            } else if let data = self.getDataSync(), let thumb = UIImage(data: data) {
                _thumbnail = thumb
                return _thumbnail
            }
            
            return UIImage()
        }
        set {
            _thumbnail = newValue
        }
    }
    
    override var data: Data? {
        get {
            if let data = self._data {
                return data
            }
            
            if let data = GIF.cache.object(forKey: id as NSString) {
                return data as Data
            } else {
                if let data = try? Data(contentsOf: url) {
                    self.data = data
                    return data
                }
            }
            
            return nil
        }
        
        set {
            if let data = newValue {
                let size = Int(data.count / 1000)
                GIF.cache.setObject(data as NSData, forKey: id as NSString, cost: size)
            }
        }
    }
}

class GalleryStore: ObservableObject {
    @Published var galleries: [Gallery] = []
    
    var fileGallery: Gallery = {
        FileGallery()
    }()
    
    init() {
        self.galleries.append(self.fileGallery)
        self.galleries.append(LibraryGallery(galleryStore: self))
    }
    
    func addToMyGIFs(data: Data, completion: ((String?, Error?) -> Void)?) {
        self.fileGallery.add(data: data, completion)
    }
    
    //    init() {
    //
    //    }
    //
    //    init(local: F = FileGallery() as! F, photoLibrary: L = LibraryGallery() as! L) {
    //        self.local = local
    //        self.photoLibrary = photoLibrary
    //    }
}

class PreviewGalleryStore: GalleryStore {
    override init() {
        super.init()
        self.galleries = [PreviewGallery()]
    }
}

struct ViewConfig<ToolbarContent: View, NavBarItem: View> {
    let toolbarContent: (Gallery, Binding<[GIF]>, Binding<GIFViewState>) -> ToolbarContent
    let trailingNavBarItem: (Gallery, Binding<[GIF]>) -> NavBarItem
    
    init(_ gallery: Gallery, @ViewBuilder toolbarContent: @escaping (Gallery, Binding<[GIF]>, Binding<GIFViewState>) -> ToolbarContent, @ViewBuilder trailingNavBarItem: @escaping (Gallery, Binding<[GIF]>) -> NavBarItem) {
        self.toolbarContent = toolbarContent
        self.trailingNavBarItem = trailingNavBarItem
    }
}

class Gallery: ObservableObject, Identifiable, Equatable {
    //    var gifs: Published<[G]> { get set }
    
    var unableToLoad: AnyView?
    
    @Published var croppingGIF: GIF?
    
    @Published var editingGIF: GIF?
    
    var gifsState = State<[GIF]>(initialValue: [])
    
    @Published var gifs = [GIF]()
    
    var gifsUpdatedPublisher = PassthroughSubject<[GIF], Never>()
    
    var cancellables = Set<AnyCancellable>()
    
    init() {
        $gifs
            .removeDuplicates()
            .subscribe(self.gifsUpdatedPublisher)
            //            .sink { gifs in
            //            self.gifsUpdatedPublisher.send(gifs)
            .store(in: &self.cancellables)
    }
    
    func add(data: Data, _ completion: ((String?, Error?) -> Void)? = nil) {}
    
    func add(data: Data) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            self.add(data: data) { id, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(id ?? ""))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func remove(_ gifs: [GIF]) {}
    
    var title: String { return "" }
    
    var tabItem: AnyView { EmptyView().any }
    
    var tabImage: Image { fatalError() }
    
    lazy var viewConfig = ViewConfig(self, toolbarContent: { _, _, _ in EmptyView().any }, trailingNavBarItem: { _, _ in EmptyView().any })
}

extension Gallery {
    static func == (lhs: Gallery, rhs: Gallery) -> Bool {
        return lhs.id == rhs.id
    }
}

// class Gallery_: ObservableObject, Identifiable, Hashable {
//    let id = UUID().uuidString
//
//    static func == (lhs: Gallery, rhs: Gallery) -> Bool {
//        return lhs.id == rhs.id
//    }
//
//
//
//    @Published var gifs: [G] = []
//    @Published var viewState = ViewState()
//
//    func add(data: Data) -> Bool { return false }
//    func remove(_ gifs: [G]) { }
//
//
// }

internal final class PreviewGallery: Gallery {
    override init() {
        super.init()
        for x in 1..<6 {
            if let url = Bundle.main.url(forResource: "\(x)", withExtension: "gif") {
                if let data = try? Data(contentsOf: url), let gif = GIFFile(url: url, thumbnail: UIImage(data: data), image: nil, id: "\(x)") {
                    self.gifs.append(gif)
                }
            }
        }
        
        self.viewConfig = ViewConfig(self, toolbarContent: { _, _, _ in
            Group {
                Button(action: {}, label: { Image.symbol("square.and.arrow.up") })
                    .padding(12)
                Spacer()
                Button(action: {}, label: { Image.symbol("trash") })
                    .padding(12)
            }.any
        }, trailingNavBarItem: { _, _ in
            EmptyView().any
        })
    }
    
    override var title: String { return "Preview" }
}

final class LibraryGallery: Gallery {
    override var title: String { return "Photo Library" }
    
    override var tabItem: AnyView {
        TupleView((Image.symbol("photo.on.rectangle.fill"), Text("Photo Library"))).any
    }
    
    override var tabImage: Image { Image.symbol("photo.on.rectangle.fill")! }
    
    let changeObserver = ChangeObserver()
    class ChangeObserver: NSObject, PHPhotoLibraryChangeObserver {
        func photoLibraryDidChange(_ changeInstance: PHChange) {}
    }
    
    let cachingManager = PHCachingImageManager()
    unowned var galleryStore: GalleryStore
    init(galleryStore: GalleryStore) {
        self.galleryStore = galleryStore
        super.init()
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                self.unableToLoad = AnyView(VStack {
                    Spacer()
                    Image.symbol("exclamationmark.circle")
                    Spacer()
                    Text("To view your photo library, allow access in Settings.")
                    Spacer()
                })
                
                return
            }
            
            //            PHPhotoLibrary.shared().register(self.changeObserver)
            let opts = PHImageRequestOptions()
            opts.isSynchronous = true
            opts.deliveryMode = .fastFormat
            opts.isNetworkAccessAllowed = true
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAnimated, options: nil)
            if let result = smartAlbums.firstObject {
                let allPhotosOptions = PHFetchOptions()
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                let assets = PHAsset.fetchAssets(in: result, options: allPhotosOptions)
                var assetArray = [PHAsset]()
                var gifs = [GIF]()
                assets.enumerateObjects { asset, x, _ in
                    assetArray.append(asset)
                    
                    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: opts) { image, _ in
                        if let gif = GIFFile(url: URL(fileURLWithPath: asset.localIdentifier), thumbnail: image, asset: asset, id: "\(x)") {
                            //                            gif.cacheManager = self.cachingManager
                            
                            gif.isDeletable = false
                            gifs.append(gif)
                            
                            if gifs.count == assets.count {
                                DispatchQueue.main.async {
                                    self.gifs = gifs
                                }
                            }
                        }
                    }
                }
                
                //                self.cachingManager.startCachingImages(for: assetArray, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: opts)
            }
        }
        
        self.viewConfig = ViewConfig(self, toolbarContent: { _, _, _ in
            Group {
                Button(action: {}, label: { Image.symbol("square.and.arrow.up") })
                    .padding(12)
                Spacer()
                Spacer()
            }.any
        }, trailingNavBarItem: { _, selectedGIFs in
            Button(action: {
                let hud = HUDAlertState.global
                hud.showLoadingIndicator = true
                guard let gif = selectedGIFs.wrappedValue.first, let data = gif.data else {
                    hud.showLoadingIndicator = false
                    return
                }
                
                Delayed(0.2) {
                    self.galleryStore.addToMyGIFs(data: data) { _, error in
                        if let _ = error {
                            let message = HUDAlertMessage(text: "Error adding GIF", symbolName: "xmark.octagon.fill")
                            hud.hudAlertMessage = [message]
                        } else {
                            let message = HUDAlertMessage(text: "Added to My GIFs", symbolName: "checkmark")
                            hud.hudAlertMessage = [message]
                        }
                    }
                }
                
            }, label: { Image.symbol("arrow.down.to.line.alt") })
                .padding(12).any
        })
    }
}

extension FileGallery: iCloudDelegate {}

final class FileGallery: Gallery, FileGalleryUtils {
    var updating = false {
        didSet {
            guard self.updating != oldValue else { return }
            
            if !self.updating {
                iCloud.shared.updateFiles()
            }
        }
    }
    
    class iCloudObserver: NSObject, iCloudDelegate {
        let parent: FileGallery
        
        func iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) {
            print("conflict, local: \(localFile), cloud: \(cloudFile)")
        }

        var iCloudUpdating = false
        func iCloudFileUpdateDidBegin() {
            iCloudUpdating = true
            print("icloud begin update")
        }
        
//        func iCloudFileUpdateDidEnd() {
//            iCloudUpdating = false
//            print("icloud end update")
//        }
        
        func iCloudFilesDidChange(_ files: [NSMetadataItem], with filenames: [String]) {
            print("icloud list changed")
            if self.parent.updating { return }
            if !self.iCloudUpdating { return }
            print("number of icloud files: \(files.count)")
            DispatchQueue.global().async {
                var gifs = [GIF]()
                for file in files {
                    let filename = file.value(forAttribute: NSMetadataItemFSNameKey) as! String
                    let creationDate = file.value(forAttribute: NSMetadataItemFSCreationDateKey) as! Date
                    
                    let gif: GIF
                    
                    if !FileManager.default.fileExists(atPath: self.parent.gifURL.appendingPathComponent(filename).path) {
                        print("need to copy: \(filename)")
                        do {
                            let url = file.value(forAttribute: NSMetadataItemURLKey) as! URL
                            try FileManager.default.copyItem(at: url, to: self.parent.gifURL.appendingPathComponent(filename))
                            
                            gif = GIFFile(id: filename.replacingOccurrences(of: ".gif", with: ""), url: self.parent.gifURL.appendingPathComponent(filename))
                            gif.creationDate = creationDate
                        } catch {
                            print("error copying gif")
                            gif = CloudGIF(name: filename, data: nil, creationDate: creationDate)
                        }
                    } else {
                        
                        gif = GIFFile(id: filename.replacingOccurrences(of: ".gif", with: ""), url: self.parent.gifURL.appendingPathComponent(filename))
                        gif.creationDate = creationDate
                    }
                    
                    do {
                        let thumbData = try Data(contentsOf: self.parent.thumbURL.appendingPathComponent(filename.replacingOccurrences(of: ".gif", with: ".jpg")))
                        let thumbImage = UIImage(data: thumbData)!
                        gif.thumbnail = thumbImage
                        
                    } catch {
                        let semaphore = DispatchSemaphore(value: 0)
                        _ = gif.getData { data, _, _ in
                            if let data = data, let thumb = try? self.parent.createThumb(data: data, id: gif.id) {
                                gif.thumbnail = thumb
                            } else {
                                gif.thumbnail = UIImage(systemName: "questionmark.circle.fill")
                            }
                            semaphore.signal()
                        }
                        
                        semaphore.wait()
                    }
                    
                    gifs.append(gif)
                }
                
                gifs.sort { (lhs, rhs) -> Bool in
                    lhs.creationDate ?? Date() > rhs.creationDate ?? Date()
                }

                do {
                    let local = try FileManager.default.contentsOfDirectory(atPath: self.parent.gifURL.path)

                    for file in local {
                        if !filenames.contains(file) {
                            print("deleting local document")
                            try FileManager.default.removeItem(at: self.parent.gifURL.appendingPathComponent(file))
                        }
                    }

                } catch {}
            }
            
            self.parent.load()
            self.iCloudUpdating = false
        }
        
        init(_ parent: FileGallery) {
            self.parent = parent
        }
    }
    
    lazy var icloudObserver = iCloudObserver(self)
    
    override var title: String { return "Your GIFs" }
    
    override var tabItem: AnyView {
        TupleView((Image.symbol("person.2.square.stack.fill"),
                   Text("Your GIFs"))).any
    }
    
    override var tabImage: Image { Image.symbol("person.2.square.stack.fill")! }
    
    var cloudAvailable: Bool {
        return !DEMO && iCloud.shared.cloudAvailable && Settings.shared.icloudEnabled
    }
    
    override init() {
        super.init()
        do {
            try FileManager.default.createDirectory(at: thumbURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        
//        do {
//            try FileManager.default.createDirectory(at: gifURL, withIntermediateDirectories: true, attributes: nil)
//        } catch {
//            print(error)
//        }
        
        self.viewConfig = ViewConfig(self, toolbarContent: { gallery, selectedGIFs, _ in
            Group {
                Button(action: {
                    GlobalPublishers.default.showShare.send([selectedGIFs.wrappedValue[0]])
                    
                }, label: { Image.symbol("square.and.arrow.up") })
                    .padding(12)
                
                Spacer()
                Button(action: {
                    withAnimation {
                        gallery.remove(selectedGIFs.wrappedValue)
                        selectedGIFs.animation().wrappedValue = []
                        //                        gallery.remove(gallery.viewState.selectedGIFs)
                        //                        gallery.viewState.selectedGIFs = []
                    }
                }, label: { Image.symbol("trash") })
                    .padding(12)
            }.any
        }, trailingNavBarItem: { _, selectedGIFs in
            Button(action: {
                GlobalPublishers.default.edit.send(selectedGIFs.wrappedValue[0])
                
            }, label: { Text("Edit") })
                .padding(12).any
        })
        
        iCloud.shared.setupiCloud(nil)
        
        if self.cloudAvailable {
            iCloud.shared.updateFiles()
            iCloud.shared.delegate = self.icloudObserver

        }
        
        self.load()
    }
    
    func add(url: URL) {}
    
    override func remove(_ gifs: [GIF]) {
        var finished = 0 {
            didSet {
                if finished == gifs.count {
                    self.updating = false
                    Async {
                    self.load()
                    }
                }
            }
        }
        //        DispatchQueue.global().async {
        self.updating = true
        
        for gif in gifs {
            do {
                try FileManager.default.removeItem(at: self.thumbURL.appendingPathComponent("\(gif.id)").appendingPathExtension("jpg"))
            } catch {
                print(error)
            }
            
            do {
                try FileManager.default
                    .removeItem(at: self.gifURL.appendingPathComponent("\(gif.id)")
                        .appendingPathExtension("gif"))
            } catch {}
            if self.cloudAvailable {
                if let localUrl = iCloud.shared.localDocumentsURL?.appendingPathComponent("\(gif.id).gif") {
                    do {
                        try FileManager.default.removeItem(at: localUrl)
                    } catch {
                        print(error)
                    }
                }
                //                    let semaphore = DispatchSemaphore(value: 0)
                iCloud.shared.deleteDocument("\(gif.id).gif") { _ in
                    //                        semaphore.signal()
                    
                    finished += 1
                }
                
                //                    semaphore.wait()
                
            } else {
                self.updating = false
                
                DispatchQueue.main.async {
                    self.gifs.removeAll { $0 == gif }
                }
            }
        }
        
        //        }
    }
    
    enum GIFAddError: Error {
        case badData
        case failedToSaveThumbnail(Error)
        case failedToSaveGIF(Error)
        case cloudError(Error)
        case exception(Error)
    }
    
    func createThumb(data: Data, id: String) throws -> UIImage? {
        if let thumb = UIImage(data: data) {
            let thumbData = thumb.jpegData(compressionQuality: 1.0)
            try thumbData?.write(to: self.thumbURL.appendingPathComponent(id).appendingPathExtension("jpg"))
            return thumb
        }
        
        return nil
    }
    
    override func add(data: Data, _ completion: ((String?, Error?) -> Void)? = nil) {
        self.updating = true

        _galleryAdd(data: data) { (id, error) in
            self.updating = false
            Async {
                completion?(id, error)
                Async {
                    self.load()
                }
            }
        }
        
//        let date = Date().toFormat("yyyy-MM-dd-HH-mm-ss")
//        let id = "\(date)"
//
//        do {
//            _ = try self.createThumb(data: data, id: id)
//        } catch {
//            completion?(nil, GIFAddError.failedToSaveThumbnail(error))
//            self.updating = false
//            return
//        }
//
//        if self.cloudAvailable {
//            iCloud.shared.saveAndCloseDocument("\(id).gif", with: data) { _, _, error in
//                guard error == nil else {
//                    completion?(nil, error)
//                    return
//                }
//
//                completion?(id, nil)
//                self.updating = false
//                iCloud.shared.updateFiles()
//            }
//
//        } else {
//            do {
//                try data.write(to: self.gifURL.appendingPathComponent(id).appendingPathExtension("gif"))
//
//            } catch {
//                try? FileManager.default.removeItem(at: self.thumbURL.appendingPathComponent(id).appendingPathExtension("jpg"))
//
//                completion?(nil, GIFAddError.failedToSaveGIF(error))
//                self.updating = false
//                return
//            }
//
//            completion?(id, nil)
//            self.updating = false
//            DispatchQueue.main.async {
//                self.load()
//            }
//        }
    }
    
    func load() {
        Async {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: self.gifURL.path)
                print("number of local files: \(files.count)")
                self.gifs = files.compactMap { file in
                    do {
                        let thumbData = try Data(contentsOf: self.thumbURL.appendingPathComponent(file.replacingOccurrences(of: ".gif", with: ".jpg")))
                        let thumbImage = UIImage(data: thumbData)!
                        
                        return GIFFile(url: self.gifURL.appendingPathComponent(file), thumbnail: thumbImage, id: file.replacingOccurrences(of: ".gif", with: ""))
                    } catch {
                        return nil
                    }
                }.sorted(by: { (lhs, rhs) -> Bool in
                    lhs.creationDate ?? Date() > rhs.creationDate ?? Date()
                })
            } catch {
                print(error)
            }
        }
    }
}
