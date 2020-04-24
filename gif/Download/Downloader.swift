//
//  Downloader.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/30/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import mobileffmpeg

enum DownloadError: Error {
    case error
}

class Downloader: NSObject, ObservableObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    
    static let instance = Downloader()
    
    @Published var downloadProgress: Double = 0
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        
        var request = request
        request.authorize()
        completionHandler(request)
        
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        print("download progress: \(self.downloadProgress)")
    }
    
    
    lazy var session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
    var apiURL: URL { API.apiURL }
    var cancellables = Set<AnyCancellable>()
    
    var failed = false
    
    func handleDownload(url: URL?) -> AnyPublisher<URL?, Never> {
        return Future<URL?, Never> { promise in
            if let url = url {
                if url.absoluteString.contains("mkv") || url.absoluteString.contains("webm") {
                    var cancel = false
                    
                    Async {
                        HUDAlertState.global.percentComplete = 0
                        HUDAlertState.global.loadingMessage = ("converting video", {
                            cancel = true
                        })
                    }
                    
                    serialQueue.async {
                        let localTmpUrl = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.mp4")
                        
                        try? FileManager.default.removeItem(at: localTmpUrl)
                        //                            MobileFFmpeg.execute("-i \(url.path) -strict -2 -codec copy \(localTmpUrl.path)")
                        MobileFFmpeg.execute("-i \(url.path) -strict -2 -crf 17 -vcodec libx264 \(localTmpUrl.path)")
                        
                        if cancel { promise(.success(nil)) }
                        promise(.success(localTmpUrl))
                    }
                    
                } else {
                    return promise(.success(url))
                }
            } else {
                promise(.success(nil))
            }
            
        }.eraseToAnyPublisher()
    }
    
    func getVideo(url: URL) -> AnyPublisher<URL?, Never> {
        self.downloadProgress = 0

        
        if url.pathExtension == "mp4" || url.pathExtension == "mov" {
            
            return self.get(URLRequest(url: url))
                .flatMap { url in
                    return self.handleDownload(url: url)
            }.eraseToAnyPublisher()
            
        }
                
        var req = URLRequest(url: apiURL.appendingPathComponent("app"))
        req.authorize()
        
        req.httpMethod = "POST"
        let quality = Settings.shared.videoDownloadQuality.rawValue
        req.httpBody = "url=\(url.absoluteString)&quality=\(quality)".data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return API.reath(req)
            .flatMap { req in
                self.session.dataTaskPublisher(for: req)
                    .map { val -> URLSession.DataTaskPublisher.Output? in Optional(val) }
                    .catch { _ in Just<URLSession.DataTaskPublisher.Output?>(nil) }
                    .flatMap { response -> AnyPublisher<URL?, Never> in
                        if let response = response {
                            let data = response.data
                            return self.checkAndGet(data: data)
                                .flatMap { url in
                                    return self.handleDownload(url: url)
                                    
                            }.eraseToAnyPublisher()
                        } else {
                            return Just<URL?>(nil).eraseToAnyPublisher()
                        }
                }
                
        }
            
            
            
        .eraseToAnyPublisher()
    }
    
    
    
    fileprivate  func checkAndGet(data: Data) -> AnyPublisher<URL?, Never> {
        if let id = String(data: data, encoding: .utf8), id.count > 0 {
            var req = URLRequest(url: apiURL.appendingPathComponent("app").appendingPathComponent("check"))
            req.httpMethod = "POST"
            req.httpBody = "file=\(id)".data(using: .utf8)
            req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.authorize()
            var retries = 0
            var timesToRetry = 120
            print("id: \(id)")
            return self.session.dataTaskPublisher(for: req)
                .delay(for: 0.5, scheduler: DispatchQueue.main)
                .tryMap { response -> String? in
                    print("try")
                    print("retries: \(retries)")
                    
                    retries += 1
                    if let val = String(data: response.data, encoding: .utf8), val.count > 0 {
                        print("got from check: \(val)")
                        
                        if val == "FAIL" || val == "error" {
                            if retries > 3 {
                                Downloader.instance.failed = true
                                Downloader.instance.cancellables.forEach { $0.cancel() }
                            }
                            throw DownloadError.error
                        } else if let x = Int(val) {
                            Async {
                                HUDAlertState.global.percentComplete = Double(x) / 100.0
                            }
                            
                            timesToRetry += 1
                            throw DownloadError.error
                        }
                        print("got from check: \(val)")
                        return val
                    } else {
                        throw DownloadError.error
                    }
            }
                //            .filter({ $0 == nil || ($0?.count ?? 0) > 2 })
                .retry(timesToRetry)
                .replaceError(with: nil)
                .flatMap { id -> AnyPublisher<URL?, Never> in
                    if let id = id, id.count > 0, id != "error" {
                        print("id for get: \(id)")
                        var req = URLRequest(url: self.apiURL.appendingPathComponent("files").appendingPathComponent(id))
                        req.authorize()
                        return self.get(req)
                    } else {
                        return Just<URL?>(nil).eraseToAnyPublisher()
                    }
            }.eraseToAnyPublisher()
            
        }
        
        return Just(nil).eraseToAnyPublisher()
    }
    
    
    fileprivate func get(_ req: URLRequest) -> AnyPublisher<URL?, Never> {
        
        //        req.httpMethod = "POST"
        //        req.httpBody = "file=\(id)".data(using: .utf8)
        //        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var task: URLSessionDownloadTask? = nil
        Async {
            HUDAlertState.global.percentComplete = 0
            HUDAlertState.global.loadingMessage = ("downloading video", {
                task?.cancel()
            })
        }
        
        let future = Future<URL?, Never> { (promise) in
            task = self.session.downloadTask(with: req) { (url, response, error) in
                print("download complete")
                if let url = url, let filename = response?.suggestedFilename {
                    
                    var filename = filename
                    
                    if filename.contains(".html") {
                        filename = filename.replacingOccurrences(of: ".html", with: ".mp4")
                    }
                    
                    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                    
                    try? FileManager.default.removeItem(at: tmp)
                    do {
                        
                        try FileManager.default.copyItem(at: url, to: tmp)
                        promise(.success(tmp))
                        
                    } catch {
                        print(error)
                        promise(.success(nil))
                        
                    }
                } else {
                    promise(.success(nil))
                }
            }
            
            task?.resume()
        }
        
        
        return future.eraseToAnyPublisher()
        
    }
    
}
