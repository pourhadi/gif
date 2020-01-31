//
//  GifEditor.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/18/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import mobileffmpeg
import Combine
import UIKit

class GifEditor {
    
    var hudAlertState : HUDAlertState = HUDAlertState.global
    
    
    
    func crop(_ gif: GIF) -> AnyPublisher<GIF?, Never> {
        return Future<GIF?, Never> { (promise) in
            
            guard let cropState = gif.cropState else {
                promise(.success(nil))
                return
            }

            DispatchQueue.global().async {
                let url = gif.url
                
                let filename = UUID().uuidString
                let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename + "_cropped").appendingPathExtension("gif")
                    
                let localGIFURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename).appendingPathExtension("gif")
                
//                do {
                    
                    if FileManager.default.fileExists(atPath: tmpDirURL.path) {
                        try? FileManager.default.removeItem(at: tmpDirURL)
                    }
                    
                    if FileManager.default.fileExists(atPath: localGIFURL.path) {
                        try? FileManager.default.removeItem(at: localGIFURL)
                    }
                    
//                } catch { }
                
                do {
                    
                    try FileManager.default.copyItem(at: url, to: localGIFURL)
                    
                    var rect = cropState.cropUnitRect
                    
                    rect *= gif.size
                    
                    let cropString = "crop=\(Int(rect.size.width)):\(Int(rect.size.height)):\(Int(rect.origin.x)):\(Int(rect.origin.y))"
                    
                    if MobileFFmpeg.execute("-i \(localGIFURL.path) -filter:v \"\(cropString)\" \(tmpDirURL.path)") == 0 {
                        
                        let data = try Data(contentsOf: tmpDirURL)
                        
                        let gif = GIFFile(id: filename, url: tmpDirURL)
                        gif.data = data
                        
                        
                        try? FileManager.default.removeItem(at: localGIFURL)
                        promise(.success(gif))
                        
                        
                    } else {
                        
                        promise(.success(nil))
                    }
                    
                } catch {
                    
                    
                    Async {
                        promise(.success(nil))
                    }
                }
                
            }
        }.eraseToAnyPublisher()
    }
    
//    func generate(
    
    func generate<Generator>(from editingContext: EditingContext<Generator>) -> AnyPublisher<GIF?, Never> where Generator : GifGenerator {
        
        return editingContext.generator
            .getFrames(preview: false)
            .flatMap { images in
                editingContext.generator.generate(with: images, filename: "tmp.gif")
        }.tryMap { (url) -> (Data, URL) in
            if let url = url, let data = try? Data(contentsOf: url) {
                return (data, url)
            }
            
            throw GenerateGIFError.unknownFailure
        }
        .replaceError(with: (Data.init(), URL.empty))
        .receive(on: DispatchQueue.main)
        .map { (data, url) -> GIF? in
            guard data.count > 0 else {
                return nil
            }

            let gif = GIFFile(id: "tmp", url: url)
            gif.thumbnail = UIImage(data: data)
            gif._data = data
            return gif
        }.eraseToAnyPublisher()
        
    }
}
