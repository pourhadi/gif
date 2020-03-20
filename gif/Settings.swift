//
//  Settings.swift
//  gif
//
//  Created by Daniel Pourhadi on 2/13/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import Combine
import BiometricAuthentication
import SwiftUI



struct PasscodeLockView : UIViewControllerRepresentable {
    
    let state: PasscodeLockViewController.LockState
    
    func makeUIViewController(context: Context) -> PasscodeLockViewController {
        let vc = PasscodeLockViewController(state: self.state, configuration: PrivacySettings.shared)
        
        vc.successCallback = { _ in
            PrivacySettings.shared.authorized = true
            PrivacySettings.shared.needsPasscodeUnlock = false
        }
        
        if state == .setPasscode {
            vc.dismissCompletionCallback = {
                if PrivacySettings.shared.passcode == nil {
                    PrivacySettings.shared.passcodeEnabled = false
                }
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: PasscodeLockViewController, context: Context) {
        
    }
    
    typealias UIViewControllerType = PasscodeLockViewController
    
    

}


struct PrivacySettingsKey : EnvironmentKey {
    static var defaultValue: PrivacySettings = PrivacySettings.shared
    
    typealias Value = PrivacySettings
}

extension EnvironmentValues {
    var privacySettings: PrivacySettings {
        get {
            return self[PrivacySettingsKey.self]
        }
        set {
            self[PrivacySettingsKey.self] = newValue
        }
    }
}

class PrivacySettings : ObservableObject {
    static let shared = PrivacySettings()
    
    enum DefaultsKeys: String {
        case passcodeEnabled
        case passcode
        case bioEnabled
    }
    
    @Published var authorized = false
    
    @Published var needsPasscodeUnlock = false
    
    @Published var passcodeEnabled: Bool {
        willSet {
            guard newValue != passcodeEnabled else { return }
            if !newValue {
                self.deletePasscode()
                self.bioEnabled = false
            } else {
                self.authorized = false
            }
        }
        
        didSet {
            UserDefaults.standard.set(passcodeEnabled, forKey: DefaultsKeys.passcodeEnabled.rawValue)
            
        }
    }
    
    @Published var passcode: [String]? {
        didSet {
            UserDefaults.standard.set(passcode, forKey: DefaultsKeys.passcode.rawValue)

        }
    }
    
    @Published var bioEnabled: Bool {
        didSet {
            UserDefaults.standard.set(bioEnabled, forKey: DefaultsKeys.bioEnabled.rawValue)

        }
    }
    
    init() {
        self.passcodeEnabled = UserDefaults.standard.bool(forKey: DefaultsKeys.passcodeEnabled.rawValue)
        self.passcode = UserDefaults.standard.array(forKey: DefaultsKeys.passcode.rawValue) as? [String]
        self.bioEnabled = UserDefaults.standard.bool(forKey: DefaultsKeys.bioEnabled.rawValue)
        
        self.authorized = !self.passcodeEnabled
    }

    lazy var isTouchIDAllowed: Bool = false
}

extension PrivacySettings: PasscodeLockConfigurationType, PasscodeRepositoryType {
    var hasPasscode: Bool {
        return self.passcodeEnabled && self.passcode != nil && !self.bioEnabled
    }
    
    func savePasscode(_ passcode: [String]) {
        self.passcode = passcode
    }
    
    func deletePasscode() {
        self.passcode = nil
    }
    
    var repository: PasscodeRepositoryType {
        return self
    }
    
    
    
    var shouldRequestTouchIDImmediately: Bool {
        return false
    }
    
    var touchIdReason: String? {
        get {
            return nil
        }
        set {
            
        }
    }
    
    
}

enum VideoDownloadQuality: Int, CaseIterable, Identifiable {
    var id: Int { self.rawValue }
    case fourEighty = 480
    case sevenTwenty = 720
    
    var qualityString: String {
        return "\(self.rawValue)p"
    }
}

class Settings: ObservableObject {
    @Defaults(encode: { (x: Int) -> VideoDownloadQuality in
        VideoDownloadQuality(rawValue: x)!
    }, decode: { (x: VideoDownloadQuality) -> Int in
        x.rawValue
    }, key: "videoDownloadQuality")
    var videoDownloadQuality: VideoDownloadQuality = .fourEighty
    
    @Published var icloudEnabled = false
    
    var cancellables = Set<AnyCancellable>()
    
    static let shared = Settings()
    
    let defaults = UserDefaults(suiteName: "group.com.pourhadi.gif")!
    
    init() {
        self.icloudEnabled = defaults.bool(forKey: "iCloudEnabled")
        
        $icloudEnabled.sink { val in
            self.defaults.set(val, forKey: "iCloudEnabled")
        }.store(in: &self.cancellables)
    }
}

var _DEMO = Binding<Bool>(get: { () -> Bool in
    return DEMO
}) { (newVal) in
    if newVal != DEMO {
        DEMO = newVal
        FileGallery.shared.load()
    }
}
