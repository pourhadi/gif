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

class Downloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    
    static let instance = Downloader()
    
    @Published var downloadProgress: Double = 0
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        print("download progress: \(self.downloadProgress)")
    }
    
    
    lazy var session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
     let apiURL = URL(string: "http://34.66.43.42:5000/")!
    
     var cancellables = Set<AnyCancellable>()
    
    var failed = false
    
     func getVideo(url: URL) -> AnyPublisher<URL?, Never> {
        self.downloadProgress = 0
        var cancel = false
        func handleInitialResponse(data: Data) -> AnyPublisher<URL?, Never> {
                print("handle initial response")
            return self.checkAndGet(data: data)
                .map { url -> URL? in
                    
                    if let url = url {
                        if url.absoluteString.contains("mkv") {
                            Async {
                                HUDAlertState.global.loadingMessage = ("converting video", {
                                    cancel = true
                                })
                            }
                            let localTmpUrl = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.mp4")
                            
                            try? FileManager.default.removeItem(at: localTmpUrl)
                            MobileFFmpeg.execute("-i \(url.path) -strict -2 -c copy \(localTmpUrl.path)")
                            if cancel { return nil }
                            return localTmpUrl

                        } else {
                            return url
                        }
                    } else {
                        return nil
                    }
            }.eraseToAnyPublisher()
        }
        
        var req = URLRequest(url: apiURL.appendingPathComponent("app"))
        req.httpMethod = "POST"
        req.httpBody = "url=\(url.absoluteString)".data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return self.session.dataTaskPublisher(for: req)
            .map { val -> URLSession.DataTaskPublisher.Output? in Optional(val) }
            .catch { _ in Just<URLSession.DataTaskPublisher.Output?>(nil) }
            .flatMap { response -> AnyPublisher<URL?, Never> in
                if let response = response {
                    
                    return handleInitialResponse(data: response.data)
                } else {
                    return Just<URL?>(nil).eraseToAnyPublisher()
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

            var retries = 0
            print("id: \(id)")
            return self.session.dataTaskPublisher(for: req)
                .delay(for: 1, scheduler: DispatchQueue.main)
                .tryMap { response -> String? in
                    print("try")
                    print("retries: \(retries)")

                    retries += 1
                    if let val = String(data: response.data, encoding: .utf8), val.count > 0 {
                        if val == "FAIL" {
                            if retries > 3 {
                                Downloader.instance.failed = true
                                Downloader.instance.cancellables.forEach { $0.cancel() }
                            }
                            throw DownloadError.error
                        }
                        print("got from check: \(val)")
                        return val
                    } else {
                        throw DownloadError.error
                    }
                }
            .retry(120)
            .replaceError(with: nil)
            .flatMap { id -> AnyPublisher<URL?, Never> in
                if let id = id, id.count > 0 {
                    print("id for get: \(id)")
                    return self.get(id: id)
                } else {
                    return Just<URL?>(nil).eraseToAnyPublisher()
                }
            }.eraseToAnyPublisher()
            
        }
        
        return Just(nil).eraseToAnyPublisher()
    }
    
    
    fileprivate func get(id: String) -> AnyPublisher<URL?, Never> {
        let req = URLRequest(url: apiURL.appendingPathComponent("files").appendingPathComponent(id))
//        req.httpMethod = "POST"
//        req.httpBody = "file=\(id)".data(using: .utf8)
//        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var task: URLSessionDownloadTask? = nil
        Async {
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
