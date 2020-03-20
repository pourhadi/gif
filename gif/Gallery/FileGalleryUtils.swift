//
//  FileGalleryUtils.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/21/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import iCloudSync
import Combine
import SwiftUI
import SwiftDate

var DEMO = false


protocol FileGalleryUtils {
    
    var thumbURL: URL { get }
    var gifURL : URL { get }
    
    var cloudAvailable: Bool { get }
}

enum GIFAddError: Error {
       case badData
       case failedToSaveThumbnail(Error)
       case failedToSaveGIF(Error)
       case cloudError(Error)
       case exception(Error)
   }
   
extension FileGalleryUtils {
    
    var thumbURL: URL {
        
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pourhadi.gif")!.appendingPathComponent("thumbs")
        
        
    }
     var gifURL: URL {
        if DEMO {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentsDirectory = paths[0]
            try? FileManager.default.createDirectory(at: documentsDirectory.appendingPathComponent("demo"), withIntermediateDirectories: true, attributes: nil)
            return documentsDirectory.appendingPathComponent("demo")
        }
        
         if self.cloudAvailable {
             return iCloud.shared.localDocumentsURL!
         }
         let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
         var documentsDirectory = paths[0]

         return documentsDirectory
     }
    
    var cloudAvailable: Bool {
        return iCloud.shared.cloudAvailable && !DEMO && (UserDefaults(suiteName: "group.com.pourhadi.gif")?.bool(forKey: "iCloudEnabled") ?? false)
    }
    

       func _galleryCreateThumb(data: Data, id: String) throws -> UIImage? {
        if let thumb = UIImage(data: data) {
            let thumbData = thumb.jpegData(compressionQuality: 1.0)
            try thumbData?.write(to: self.thumbURL.appendingPathComponent(id).appendingPathExtension("jpg"))
            return thumb
        }
        
        return nil
    }
    
    func _galleryAdd(data: Data, _ completion: ((String?, Error?) -> Void)? = nil) {
        
        let date = Date().toFormat("yyyy-MM-dd-HH-mm-ss")
        let id = "\(date)"
        
        do {
            let _ = try _galleryCreateThumb(data: data, id: id)
        } catch {
            completion?(nil, GIFAddError.failedToSaveThumbnail(error))
            return
        }
        

            
            do {
                try data.write(to: self.gifURL.appendingPathComponent(id).appendingPathExtension("gif"))
                
                
            } catch {
                try? FileManager.default.removeItem(at: self.thumbURL.appendingPathComponent(id).appendingPathExtension("jpg"))
                
                
                completion?(nil, GIFAddError.failedToSaveGIF(error))
                return
            }
        
        if self.cloudAvailable {
            
            iCloud.shared.saveAndCloseDocument("\(id).gif", with: data) { (_, _, error) in
                guard error == nil else {
                    completion?(nil, error)
                    return
                }
                
                completion?(id, nil)
                iCloud.shared.updateFiles()
            }
            
            
        } else {
            
            completion?(id, nil)
        }
        
        
    }
}

class FileGalleryDummy: FileGalleryUtils {
    
    static let shared = FileGalleryDummy()
    
}
