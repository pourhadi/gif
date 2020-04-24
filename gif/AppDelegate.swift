//
//  AppDelegate.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import UIKit
import Firebase
import StoreKit
import Purchases

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        
        
        FirebaseApp.configure()
        
        Auth.auth().signInAnonymously() { (authResult, error) in
            print("signed in")
            authResult?.user.getIDTokenForcingRefresh(true, completion: { (token, _) in
                print("token: \(token ?? "")")
                API.token = token
            })
        }
        
 
        Purchases.debugLogsEnabled = true
        Purchases.configure(withAPIKey: "vKmmTEQfrYvYzHuzvwNXziYnxoDmQylx")
        
//        SKPaymentQueue.default().add(IAP.shared)
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        let videoExtensions = ["mp4", "mkv", "mov"]
        
        if videoExtensions.contains(url.pathExtension.lowercased()) {
            Async {
                HUDAlertState.global.showLoadingIndicator = true
                HUDAlertState.global.loadingMessage = ("processing", nil)
            }
            
            serialQueue.async {
//                let localTmpUrl = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.mp4")
//
//                try? FileManager.default.removeItem(at: localTmpUrl)
//                try? FileManager.default.copyItem(at: url, to: localTmpUrl)
//
                GlobalPublishers.default.prepVideo.send(url)
                
            }
        } else if url.pathExtension.lowercased() == "gif" {
            Async {
                HUDAlertState.global.showLoadingIndicator = true
            }
            
            serialQueue.async {
                
                func tryUrl(_ tryUrl: URL) -> Bool {
                    if let data = try? Data(contentsOf: url) {
                        FileGallery.shared.add(data: data) { (id, error) in
                            if error != nil || id == nil {
                                Delayed(0.2) {
                                    HUDAlertState.global.show(.error("something went wrong"))
                                }
                            } else {
                                Delayed(0.2) {
                                    HUDAlertState.global.show(HUDAlertMessage(text: "GIF Added", symbolName: "hand.thumbsup.fill"))
                                }
                            }
                        }
                        
                        return true
                    } else {
                        return false
                    }
                }
                
                if !tryUrl(url) {
                    
                    let localTmpUrl = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.gif")
                    try? FileManager.default.removeItem(at: localTmpUrl)
                    try? FileManager.default.copyItem(at: url, to: localTmpUrl)
                    
                    if !tryUrl(localTmpUrl) {
                        Delayed(0.2) {
                            HUDAlertState.global.show(.error("something went wrong"))
                        }
                    }
                }
            }
        }
        return true
        
    }
    
    
}

