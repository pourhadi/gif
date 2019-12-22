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

class GIF: Identifiable, ObservableObject, Equatable {
    let id: Int
    
    static func == (lhs: GIF, rhs: GIF) -> Bool {
        return lhs.id == rhs.id
    }
    
    @Published var image: UIImage? = nil
    
    let url: URL?
    let thumbnail: UIImage?
    
    init?(url: URL? = nil, thumbnail: UIImage? = nil, image: UIImage? = nil, id: Int) {
        guard url != nil || thumbnail != nil || image != nil else {
            return nil
        }
        self.url = url
        self.thumbnail = thumbnail
        self.image = image
        self.id = id
    }
}

final class Gallery: ObservableObject {
 
    @Published var gifs: [GIF] = []
    
    let thumbURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pourhadi.gif")!.appendingPathComponent("thumbs")
    let gifURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pourhadi.gif")!.appendingPathComponent("gifs")

    init() {
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
    
    func remove(_ gifs: [GIF]) {
        for gif in gifs {
            do {
                try FileManager.default.removeItem(at: self.gifURL.appendingPathComponent("\(gif.id)").appendingPathExtension("gif"))
                try FileManager.default.removeItem(at: self.thumbURL.appendingPathComponent("\(gif.id)").appendingPathExtension("jpg"))

                self.gifs.removeAll { $0 == gif }
            } catch {
                
            }
        }
    }
    
    func add(data: Data) {
        
        let id = "\(self.gifs.count + 1)"

        do {
            try data.write(to: self.gifURL.appendingPathComponent(id).appendingPathExtension("gif"))
            
            var thumbImage: UIImage? = nil
            if let thumb = UIImage(data: data) {
                let thumbData = thumb.jpegData(compressionQuality: 1.0)
                try thumbData?.write(to: self.thumbURL.appendingPathComponent(id).appendingPathExtension("jpg"))
                thumbImage = thumb
            }
            
            if let gif = GIF(url: self.gifURL.appendingPathComponent(id).appendingPathExtension("gif"), thumbnail: thumbImage, id: Int(id) ?? 0) {
                self.gifs.append(gif)
            }
        } catch {
            print(error)
        }
    }
    
    func load() {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: gifURL.path)
            
            self.gifs = files.compactMap { file in
                do {
                    let thumbData = try Data(contentsOf: thumbURL.appendingPathComponent(file.replacingOccurrences(of: ".gif", with: ".jpg")))
                    let thumbImage = UIImage(data: thumbData)!
                    
                    return GIF(url: gifURL.appendingPathComponent(file), thumbnail: thumbImage, id: Int(file.replacingOccurrences(of: ".gif", with: "")) ?? 0)
                } catch {
                    return nil
                }
            }.sorted(by: { (lhs, rhs) -> Bool in
                return lhs.id > rhs.id
            })
        } catch {
            print(error)
        }
    }
    
}
