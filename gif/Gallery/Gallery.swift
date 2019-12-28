//
//  Gallery.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Foundation
import UIKit
import SwiftyGif
import SwiftDate
import Photos
import SwiftUI

class GIF: Identifiable, Equatable {
    
    var id: String
    var creationDate: Date?
    
    var url: URL?
    var image: UIImage?
    
    var _thumbnail: UIImage?
    var thumbnail: UIImage?
    var data: Data? { return nil }
    
    var asset: PHAsset?

    func getData(done: @escaping (_ data: Data?) -> Void) {
        
    }
    
    
    init?(url: URL? = nil, thumbnail: UIImage? = nil, image: UIImage? = nil, asset: PHAsset? = nil, id: String) {
        guard url != nil || thumbnail != nil || image != nil || asset != nil else {
            return nil
        }
        self.url = url
        self._thumbnail = thumbnail
        self.image = image
        self.id = id
        self.asset = asset
        
        if let url = url, let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let date = attr[FileAttributeKey.creationDate] as? Date {
            self.creationDate = date
        }
    }
    
    static func == (lhs: GIF, rhs: GIF) -> Bool {
        return lhs.id == rhs.id
    }
    
}

extension GIF {
    
}


class GIFFile: GIF {
    
    
    unowned var cacheManager: PHCachingImageManager? = nil
    
    static var cache: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 50
        return cache
    }()
    
    
    
    override func getData(done: @escaping (_ data: Data?) -> Void) {
        if let asset = self.asset {
            
            let opt = PHImageRequestOptions()
            opt.isNetworkAccessAllowed = true
        
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opt) { (data, s, orientation, misc) in
                DispatchQueue.main.async {
                    done(data)
                }
            }
        } else {
            done(nil)
        }
    }
    
   
    override var thumbnail: UIImage? {
        get {
            if _thumbnail != nil { return _thumbnail }
            
            if let asset = asset, let cacheManager = cacheManager {
                let opts = PHImageRequestOptions()
                opts.isSynchronous = true
                opts.deliveryMode = .fastFormat
                opts.isNetworkAccessAllowed = true
                
                var image: UIImage? = nil
                cacheManager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFit, options: opts) { (imageResult, _) in
                    image = imageResult
                }
                
                return image
            }
            
            return nil
        }
        set {
            _thumbnail = newValue
        }
    }

    override var data: Data? {
        if let url = url {
            if let data = GIFFile.cache.object(forKey: url as NSURL) {
                return data as Data
            } else {
                if let data = try? Data(contentsOf: url) {
                    let size = Int((data.count / 1000) / 1000)
                    GIFFile.cache.setObject(data as NSData, forKey: url as NSURL, cost: size)
                    
                    return data
                }
            }
        }
        
        return nil
    }
}

class GalleryStore: ObservableObject {
    
    
    @Published var galleries = [FileGallery(), LibraryGallery()]

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

class ViewState: ObservableObject {
    @Published var selectedGIFs: [GIF] = []
    @Published var selectionMode = false
}

class Gallery: ObservableObject, Identifiable, Hashable {
//    var gifs: Published<[G]> { get set }
    
    @Published var gifs = [GIF]()
    
    func add(data: Data) -> Bool { return false }
    func remove(_ gifs: [GIF]) {}
    
    var title: String { return "" }
    
    var tabItem: AnyView { EmptyView().any }
    
    @Published var viewState = ViewState()
}

extension Gallery {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func == (lhs: Gallery, rhs: Gallery) -> Bool {
        return lhs.id == rhs.id
    }
}




//class Gallery_: ObservableObject, Identifiable, Hashable {
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
//}

final internal class PreviewGallery: Gallery {
 
    
    override init() {
        super.init()
        for x in 1..<6 {
            if let url = Bundle.main.url(forResource: "\(x)", withExtension: "gif") {
                if let data = try? Data(contentsOf: url), let gif = GIFFile(url: url, thumbnail: UIImage(data: data), image: nil, id: "\(x)") {
                    self.gifs.append(gif)
                }
            }
        }
    }
    
    override var title: String { return "Preview" }
        
    
}


final class LibraryGallery: Gallery {
    
    override var title: String { return "Photo Library" }
        
    override var tabItem: AnyView {
        TupleView((Image.symbol("photo.on.rectangle.fill"), Text("Photo Library"))).any
    }
    
    let changeObserver = ChangeObserver()
    class ChangeObserver: NSObject, PHPhotoLibraryChangeObserver {
        func photoLibraryDidChange(_ changeInstance: PHChange) {
            
        }
        
        
    }
    
   
    let cachingManager = PHCachingImageManager()

    override init() {
        super.init()
        PHPhotoLibrary.requestAuthorization { (status) in
            guard status == .authorized else {
                return
            }
            
            PHPhotoLibrary.shared().register(self.changeObserver)
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
                assets.enumerateObjects { (asset, x, done) in
                    assetArray.append(asset)
                    
                    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: opts) { (image, misc) in
                        if let gif = GIFFile(thumbnail: image, asset: asset, id: "\(x)") {
                            gif.cacheManager = self.cachingManager
                            DispatchQueue.main.async {
                                self.gifs.append(gif)
                            }
                        }
                    }
                    
                }
                
                
                
                
                self.cachingManager.startCachingImages(for: assetArray, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: opts)
            }
        }
    }


}

final class FileGallery: Gallery {
    override var title: String { return "Your GIFs" }
    
    override var tabItem: AnyView {
        TupleView((Image.symbol("person.2.square.stack.fill"),
            Text("Your GIFs"))).any
    }
    
    let thumbURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pourhadi.gif")!.appendingPathComponent("thumbs")
    let gifURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pourhadi.gif")!.appendingPathComponent("gifs")
    
    override init() {
        super.init()
        do {
            try FileManager.default.createDirectory(at: thumbURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        
        do {
            try FileManager.default.createDirectory(at: gifURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
        }
        
        load()
    }
    
    func add(url: URL) {
        
    }
    
    func remove(_ gifs: [GIFFile]) {
        for gif in gifs {
            do {
                try FileManager.default.removeItem(at: self.gifURL.appendingPathComponent("\(gif.id)").appendingPathExtension("gif"))
                try FileManager.default.removeItem(at: self.thumbURL.appendingPathComponent("\(gif.id)").appendingPathExtension("jpg"))
                
                self.gifs.removeAll { $0 == gif }
            } catch {
                
            }
        }
    }
    
    override func add(data: Data) -> Bool {
        guard let _ = try? UIImage(gifData: data) else { return false }
        
        let date = Date().toISO()
        let id = "\(date)"
        
        do {
            try data.write(to: self.gifURL.appendingPathComponent(id).appendingPathExtension("gif"))
            
            var thumbImage: UIImage? = nil
            if let thumb = UIImage(data: data) {
                let thumbData = thumb.jpegData(compressionQuality: 1.0)
                try thumbData?.write(to: self.thumbURL.appendingPathComponent(id).appendingPathExtension("jpg"))
                thumbImage = thumb
            }
            
            if let gif = GIFFile(url: self.gifURL.appendingPathComponent(id).appendingPathExtension("gif"), thumbnail: thumbImage, id: id) {
                self.gifs.append(gif)
                return true
            }
            
        } catch {
            print(error)
        }
        
        return false
    }
    
    func load() {
        do {
            
            let files = try FileManager.default.contentsOfDirectory(atPath: gifURL.path)
            
            self.gifs = files.compactMap { file in
                do {
                    let thumbData = try Data(contentsOf: thumbURL.appendingPathComponent(file.replacingOccurrences(of: ".gif", with: ".jpg")))
                    let thumbImage = UIImage(data: thumbData)!
                    
                    return GIFFile(url: gifURL.appendingPathComponent(file), thumbnail: thumbImage, id: (file.replacingOccurrences(of: ".gif", with: "")))
                } catch {
                    return nil
                }
            }.sorted(by: { (lhs, rhs) -> Bool in
                return lhs.creationDate ?? Date() > rhs.creationDate ?? Date()
            })
        } catch {
            print(error)
        }
    }

}
