//
//  ActivityView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/9/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI
import YYImage
import Photos
import MobileCoreServices

class SaveToRollActivity: UIActivity {
    
    var urls = [URL]()
    
    override var activityTitle: String? { return "Add to Photos" }
    
    
    override var activityImage: UIImage? { return UIImage(systemName: "square.and.arrow.down") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems as? [URL] != nil
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        self.urls = activityItems as! [URL]
    }
    
    override func perform() {
        
        for url in self.urls {
            
            if let data = try? Data(contentsOf: url), let image = YYImage(data: data) {
                
                
                image.yy_saveToAlbum { (url, error) in
                    print(error)
                    
                    self.activityDidFinish(true)
                }
 
                    
              
            }
            
            
        }
        
    }
}




struct ActivityView : UIViewControllerRepresentable {
    
    let gifs: [GIF]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        var urls = [URL]()
        for gif in gifs {
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
        } catch {}
        
            urls.append(localGIFURL)
            
        }
        
        
        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        
        vc.completionWithItemsHandler = { _, _, _, _ in
            
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {
        
    }
    
    typealias UIViewControllerType = UIActivityViewController
    
    
    
    
}
