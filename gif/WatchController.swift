//
//  WatchController.swift
//  gif
//
//  Created by Daniel Pourhadi on 6/3/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import WatchConnectivity
import UIKit
import Combine
import SwiftUI
import CloudKit

struct WatchGIF: Identifiable {
    internal init(data: URL, name: String, thumb: URL?, index: Int = 0) {
        self.data = data
        self.name = name
        self.thumb = thumb
        self.index = index
    }
    
    internal init(data: URL? = nil, name: String, thumb: URL?, index: Int = 0) {
        self.data = data
        self.name = name
        self.thumb = thumb
        self.index = index
    }
    
    var data: URL?
    let name: String
    let thumb: URL?
    
    var id: String {
        return name
    }
    
    var index = 0
    
    var aspectRatio: CGFloat? {
        if let thumb = self.thumb, let data = try? Data(contentsOf: thumb), let image = UIImage(data: data) {
            
            return image.size.width / image.size.height
        }
        
        return nil
    }
    
    
    func getDataURL(complete: @escaping (URL?) -> Void) {
        Cloud.getDataURL(for: self.name) { (url) in
            complete(url)
        }
    }
}

class Cloud {
    


    
//    static var createdCustomZone = false
//    static func config() {
//        let createZoneGroup = DispatchGroup()
//
//            createZoneGroup.enter()
//
//            let customZone = CKRecordZone(zoneID: CKRecordZone.ID(zoneName: watchRecordZone, ownerName: CKCurrentUserDefaultName))
//
//            let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [] )
//
//            createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
//                if (error == nil) { self.createdCustomZone = true }
//                // else custom error handling
//                createZoneGroup.leave()
//            }
//            createZoneOperation.qualityOfService = .userInitiated
//
//            self.db.add(createZoneOperation)
//
//
//
//    }
//

    
    static let watchRecordZone = "watchZone"
    static let gifRecordType = "gif"
    
    static let container = CKContainer(identifier: "iCloud.com.pourhadi.gif")
    static let db = Cloud.container.privateCloudDatabase
    
    static func removeFromCloud(name: String) {
        let id = CKRecord.ID(recordName: name)
        self.db.delete(withRecordID: id) { (_, _) in
            
        }
    }
    
    static func addToCloud(data: URL, thumb: UIImage?, name: String, _ complete: ((Bool) -> Void)?) {
        let id = CKRecord.ID(recordName: name)
        let record = CKRecord(recordType: gifRecordType, recordID: id)
        record["name"] = name
        record["data"] = CKAsset(fileURL: data)
        
        if let thumb = thumb {
            let thumbData = thumb.jpegData(compressionQuality: 0.5)
            let thumbURL = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("watch").appendingPathExtension("thumb").appendingPathExtension("jpg")
            try? thumbData?.write(to: thumbURL)
            record["thumb"] = CKAsset(fileURL: thumbURL)

        }
        
        
        db.save(record) { (_, error) in
            if let _ = error {
                complete?(false)
            } else {
                complete?(true)
            }
        }
    }
    
    static func getUploaded(complete: @escaping ([WatchGIF]) -> Void) {
        
        let query = CKQueryOperation(query: CKQuery(recordType: gifRecordType, predicate: NSPredicate.init(value: true)))
        query.desiredKeys = ["name", "thumb"]
        
        var newList = [WatchGIF]()
        query.recordFetchedBlock = { record in
            if let name = record["name"] as? String {
                newList.append(WatchGIF(name: name, thumb: (record["thumb"] as? CKAsset)?.fileURL))
            }
        }
        
        query.queryCompletionBlock = { _, _ in
            complete(newList)
        }
        
        self.db.add(query)
    }
    
    static func getDataURL(for name: String, complete: @escaping (URL?) -> Void) {
        self.db.perform(CKQuery(recordType: gifRecordType, predicate: NSPredicate(format: "name == %@", argumentArray: [name])), inZoneWith: nil, completionHandler: { (records, _) in
            complete((records?.first?["data"] as? CKAsset)?.fileURL)
        })
    }
}

struct WatchMessage {
    
    static let gifOnWatch = "gifOnWatch"
    static let removeFromWatch = "removeFromWatch"
    static let gifName = "gifName"
    static let gifList = "gifList"
}

class WatchController: NSObject {
    
    @Published var loading = false
    
    override init() {
        super.init()
        self.session.delegate = self
        self.session.activate()
        
        #if os(watchOS)
        if let files = try? FileManager.default.contentsOfDirectory(at: FileGalleryDummy.shared.gifURL, includingPropertiesForKeys: nil, options: []) {
            self.gifsOnWatch = files.map { $0.lastPathComponent.replacingOccurrences(of: ".gif", with: "") }
            self.message = "found files"
        } else {
            self.message = "couldnt find files"
        }
        #endif
    }
    
    static let shared = WatchController()
    
    let session = WCSession.default
    
    @Published var watchAvailable: Bool = false
    
    @Published var gifsOnWatch: [String] = []
    
    @Published var uploadedGIFs = [WatchGIF]()
    
    @Published var message = ""
    
    func updateWatchAvailable() {
        if (session.activationState != .activated) {
            session.activate()
            self.watchAvailable = false
        } else {
            
            #if os(iOS)
            self.watchAvailable = session.isPaired && session.isWatchAppInstalled && session.activationState == .activated
            
            self.updateGIFList()
            #endif
        }
    }
    
    func updateGIFList(_ done: (() -> Void)? = nil) {
//        guard self.watchAvailable else { return }
        
        self.loading = true
        
        Cloud.getUploaded { (gifs) in
            DispatchQueue.main.async {
                self.uploadedGIFs = gifs
                done?()
                self.loading = false
            }
        }
        
        
//        self.session.sendMessage([WatchMessage.gifList: ""], replyHandler: { (reply) in
//
//            self.gifsOnWatch = reply[WatchMessage.gifList] as? [String] ?? []
//
//        }, errorHandler: nil)
    }
    
    var cancellables = [AnyCancellable]()
    
    func checkIfOnWatch(_ name: String) -> AnyPublisher<Bool, Never> {
        guard self.watchAvailable else { return Just(false).eraseToAnyPublisher() }
        
        return Future<Bool, Never> { [unowned self] promise in
            self.session.sendMessage([WatchMessage.gifOnWatch: name], replyHandler: { (reply) in
                if let answer = reply[WatchMessage.gifOnWatch] as? Bool {
                    promise(.success(answer))
                } else {
                    promise(.success(false))
                }
            }, errorHandler: { _ in
                promise(.success(false))
            })
            
        }.eraseToAnyPublisher()
    }
    
    func removeFromWatch(_ name: String) {
//        guard self.watchAvailable else { return }
        
        Cloud.removeFromCloud(name: name)
        self.session.sendMessage([WatchMessage.removeFromWatch: name], replyHandler: nil, errorHandler: nil)
        
    }
    
    func watchHandleMessage(_ message: [String: Any], reply: (([String: Any]) -> Void)?) {
        if let gifToCheck = message[WatchMessage.gifOnWatch] as? String {
//            self.message = "got check message"

            if let files = try? FileManager.default.contentsOfDirectory(at: FileGalleryDummy.shared.gifURL, includingPropertiesForKeys: nil, options: .producesRelativePathURLs), files.contains(where: { $0.absoluteString.contains(gifToCheck) } ) {
                reply?([WatchMessage.gifOnWatch: true])
            } else {
                reply?([WatchMessage.gifOnWatch: false])

            }
        } else if let gifToDelete = message[WatchMessage.removeFromWatch] as? String {
//            self.message = "got remove message"
//            self.removeFromWatch(gifToDelete)
            self.uploadedGIFs.removeAll { (gif) -> Bool in
                gif.name == gifToDelete
            }
        } else if let _ = message[WatchMessage.gifList] {
//            self.message = "got list message"
//            if let files = try? FileManager.default.contentsOfDirectory(at: FileGalleryDummy.shared.gifURL, includingPropertiesForKeys: nil, options: .producesRelativePathURLs) {
//                reply?([WatchMessage.gifList: files.map { $0.lastPathComponent.replacingOccurrences(of: ".gif", with: "") }])
//            }
        }
    }
    
    var transfers: [String: PassthroughSubject<Bool, Never>] = [:]
    
    let watchQueue = DispatchQueue(label: "com.pourhadi.watchqueue")
    func sendToWatch(data: Data, name: String, thumb: UIImage? = nil){
        #if os(iOS)
        showHUDLoading()
        
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("watch").appendingPathExtension("gif")
        try? FileManager.default.removeItem(at: tmpURL)
        
        try? data.write(to: tmpURL)
        
        
 
        watchQueue.async {
            Video.createFromGIF(url: tmpURL, false) { (video) in
                if let video = video {
                    Cloud.addToCloud(data: video, thumb: thumb, name: name) { (success) in
                        print(success)
                        
                        
                        self.uploadedGIFs.append(WatchGIF(data: video, name: name, thumb: nil))
                        
                            hideHUDLoading()
                        
                    }
                    
                } else {
                    self.updateGIFList({
                        hideHUDLoading()
                    })
                }
            }
        }
        
        #endif
        
        
        
//        self.session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        
//        let _ = self.session.transferFile(tmpURL, metadata: [WatchMessage.gifName: name])
        
    }
}


extension WatchController: WCSessionDelegate {
    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        self.updateWatchAvailable()
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        self.updateWatchAvailable()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        self.updateWatchAvailable()
    }
    #endif
    func sessionReachabilityDidChange(_ session: WCSession) {
        self.updateWatchAvailable()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.updateWatchAvailable()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        #if os(watchOS)
        self.watchHandleMessage(message, reply: replyHandler)
        #endif
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        #if os(watchOS)
        self.watchHandleMessage(message, reply: nil)
        #endif
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        self.message = "received message data"
        
//        try? messageData.write(to: FileGalleryDummy.shared.gifURL.appendingPathComponent(name).appendingPathExtension(".gif"))
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        self.message = "received file"

        if let name = file.metadata?[WatchMessage.gifName] as? String {
            do {
                let name = name.replacingOccurrences(of: ".gif", with: "")
                try FileManager.default.moveItem(at: file.fileURL, to: FileGalleryDummy.shared.gifURL.appendingPathComponent(name).appendingPathExtension(".gif"))
                self.gifsOnWatch.append(name)
            } catch {
                self.message = "error copying file"
            }
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print(error)
        }
        
        if let name = fileTransfer.file.metadata?[WatchMessage.gifName] as? String,
        let future = self.transfers[name] {
            
            if let _ = error {
                future.send(false)
            } else {
                future.send(true)
            }
        }
        
        self.updateGIFList()
    }
}
