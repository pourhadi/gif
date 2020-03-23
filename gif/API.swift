//
//  API.swift
//  gif
//
//  Created by Daniel Pourhadi on 3/2/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import Alamofire
import Combine
import Firebase


class API: NSObject, URLSessionTaskDelegate, RedirectHandler {
    
    static func reath(_ req: URLRequest) -> AnyPublisher<URLRequest, Never> {
        return Future<URLRequest, Never> { promise in
            Auth.auth().signInAnonymously() { (authResult, error) in
                if let authResult = authResult {
                    authResult.user.getIDTokenForcingRefresh(true, completion: { (result, error) in
                        API.token = result
                        var req = req
                        req.authorize()
                        promise(.success(req))
                    })
                } else {
                    promise(.success(req))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    static let instance = API()
    
    static var session: URLSession {
        return self.instance.session
    }
    
    lazy var session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    
    static var debug = false
    
    static var token : String? = nil
    
    static func authenticateRequest(request: inout URLRequest) {
        guard let token = self.token else {
            print("no token!!!!!!!!!!!")
            fatalError()
            
        }
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        
        var request = request
        request.authorize()
        completionHandler(request)
        
    }
    
    func task(_ task: URLSessionTask,
    willBeRedirectedTo request: URLRequest,
    for response: HTTPURLResponse,
    completion: @escaping (URLRequest?) -> Void) {
        var request = request
        request.authorize()
        completion(request)
    }
    
}


extension URLRequest {
    
    mutating func authorize() {
        API.authenticateRequest(request: &self)
    }
    
}
