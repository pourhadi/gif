//
//  SceneDelegate.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import UIKit
import SwiftUI
import BiometricAuthentication
import Security


enum Orientation {
    case landscape
    case portrait
}

struct OrientationKey : EnvironmentKey {
    static var defaultValue: Orientation = .portrait
    typealias Value = Orientation
}

extension EnvironmentValues {
    var orientation: Orientation {
        get {
            return self[OrientationKey.self]
        }
        set {
            self[OrientationKey.self] = newValue
        }
    }
}

class HostingController<InnerContent> : UIHostingController<OrientatedView<InnerContent>> where InnerContent: View {
    
    init(rootView: InnerContent) {
        super.init(rootView: OrientatedView(orientation: .portrait, content: rootView))
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.rootView = OrientatedView(orientation: size.width > size.height ? .landscape : .portrait, content: self.rootView.content)
    }
    
}

struct OrientatedView<Content> : View where Content : View {
    
    let orientation: Orientation
    let content: Content
    
    var body: some View {
        content.environment(\.orientation, self.orientation)
    }
    
}


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        // Create the SwiftUI view that provides the window contents.
        let state = GlobalState.instance
//        let injected = AppState.Injection(appState: .init(AppState()))
        let contentView = ContentView()
//            .environment(\.hudAlertState, state.hudAlertState)
            .environment(\.timelineState, state.timelineState)
//            .environment(\.injected, injected)
//            .colorScheme(.dark)
        
            .environmentObject(state)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = HostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        authorizeIfNecessary()
    }
    
    var authenticating = false
    func authorizeIfNecessary() {
        guard !PrivacySettings.shared.needsPasscodeUnlock && !authenticating && !PrivacySettings.shared.authorized else { return }
        
        func passcodeAuth() {
            PrivacySettings.shared.needsPasscodeUnlock = true
        }
        
        if PrivacySettings.shared.passcodeEnabled {
            if PrivacySettings.shared.bioEnabled {
                authenticating = true
                BioMetricAuthenticator.authenticateWithBioMetrics(reason: "") { [weak self] (result) in
                    self?.authenticating = false
                    switch result {
                    case .success(_):
                        PrivacySettings.shared.authorized = true
                    case .failure(_):
                        passcodeAuth()

                    }
                }
            } else {
                passcodeAuth()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        authorizeIfNecessary()

        IAP.shared.checkActive { (active) in
            SubscriptionState.shared.active = active
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        
        if PrivacySettings.shared.passcodeEnabled {
            PrivacySettings.shared.authorized = false
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
//        authorizeIfNecessary()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

