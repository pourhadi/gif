//
//  Uploader.swift
//  gif
//
//  Created by Daniel Pourhadi on 2/29/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import Combine
import Alamofire

class Uploader {
    static let debug = false
    static var cancellables = Set<AnyCancellable>()
    
    static let publicURL = URL(string: "https://files.giffed.app")!
    static var apiURL: URL { !API.debug ? URL(string: "https://app.giffed.app/app/uploads")! : URL(string:"http://192.168.1.12:8080/app/uploads")! }
    static func checkExists(user: String, fileId: String) -> AnyPublisher<URL?, Never> {
        var request = URLRequest(url: apiURL.appendingPathComponent(user).appendingPathComponent(fileId))
        request.authorize()
        request.httpMethod = "GET"
        return
            API.reath(request).flatMap { request in
                
                API.session.dataTaskPublisher(for: request)
                    .map { data, _ in
                        if let str = String(data: data, encoding: .utf8), str.count > 0, let _ = URL(string: str) {
                            return publicURL.appendingPathComponent(user).appendingPathComponent(fileId).appendingPathExtension("gif")
                        }
                        return nil
                }
                .replaceError(with: nil)
            }
            .eraseToAnyPublisher()
    }
    
    static func upload(gif: GIF, user: String) -> AnyPublisher<URL?, Never> {
        var request = URLRequest(url: apiURL.appendingPathComponent(user).appendingPathComponent(gif.id))
        request.httpMethod = "POST"
        request.authorize()
        
        return
            API.reath(request).flatMap { request in
                
                Future<URL?, Never> { (promise) in
                    gif.getData { (data, _, _) in
                        if let data = data {
                            
                            AF.upload(multipartFormData: { (form) in
                                form.append(data, withName: "file", fileName: "\(gif.id).gif", mimeType: "image/gif")
                            }, with: request)
                                .uploadProgress { (progres) in
                                    print("uploaded: \(progres)")
                            }
                            .redirect(using: API.instance)
                            .responseString { response in
                                
                                if let str = response.value, str.count > 0, let url = URL(string: str) {
                                    promise(.success(url))
                                } else {
                                    promise(.success(nil))
                                }
                            }
                            
                        } else {
                            promise(.success(nil))
                        }
                    }
                }
            }
            .eraseToAnyPublisher()
        
    }
    
    static func delete(gif: GIF, user: String) -> AnyPublisher<Bool, Never> {
        var request = URLRequest(url: apiURL.appendingPathComponent(user).appendingPathComponent(gif.id))
        request.httpMethod = "DELETE"
        request.authorize()
        return API.session.dataTaskPublisher(for: request).map { _, _ in
            return true
        }
        .replaceError(with: false)
        .eraseToAnyPublisher()
    }
    
}
