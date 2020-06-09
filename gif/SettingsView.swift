//
//  SettingsView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/28/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import SmileLock
import BiometricAuthentication

enum EnterPasscodeMode {
    case create((String) -> Void)
    case confirm((String) -> Bool)
    case validate((String) -> Bool)
}

struct EnterPasscodeView: View {
    
    let mode: EnterPasscodeMode

    var body: some View {
        PasscodeView(mode: self.mode)
            .background(VisualEffectView.blur(.regular).edgesIgnoringSafeArea(.all))
        
    }
    
}

struct PasscodeView : UIViewRepresentable {
    
    let mode: EnterPasscodeMode
    
    @State var wrongCode = false
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PasswordContainerView {
        let v = PasswordContainerView.create(withDigit: 4)
        v.delegate = context.coordinator
        v.tintColor = UIColor.white
        v.highlightedColor = _accent
        return v
    }
    
    func updateUIView(_ uiView: PasswordContainerView, context: Context) {
        if self.wrongCode {
            uiView.wrongPassword()
            uiView.clearInput()
            
            Async {
                self.wrongCode = false
            }
        }
    }
    
   
    typealias UIViewType = PasswordContainerView
    
    
    class Coordinator : PasswordInputCompleteProtocol {
        func passwordInputComplete(_ passwordContainerView: PasswordContainerView, input: String) {
            switch self.parent.mode {
            case .create(let block): block(input)
            case .confirm(let block):
                if !block(input) { self.parent.wrongCode = true }
            case .validate(let block):
                if !block(input) { self.parent.wrongCode = true }
            }
        }
        
        func touchAuthenticationComplete(_ passwordContainerView: PasswordContainerView, success: Bool, error: Error?) {
            
        }
        
        let parent: PasscodeView
        
        init(_ parent: PasscodeView) {
            self.parent = parent
        }
    }
    
}

//
//struct PrivacySettingsView : View {
//    
//    @ObservedObject var privacySettings = PrivacySettings.shared
//    
//    var body: some View {
//        
//        Form {
//            
//        }
//        .navigationBarTitle("Privacy")
//        
//    }
//    
//}

struct SettingsView: View {
    
    init(showSubscriptionView : Binding<Bool>) {
        _hue = _accentHue
        _sat = _accentSaturation
        _hueColor = _accentColorBinding
        _showSubscriptionView = showSubscriptionView
        _brightness = _accentBrightness
    }
    
    @Binding var showSubscriptionView: Bool
    
    @Binding var hueColor: UIColor
    @Binding var hue : CGFloat
    @State var hueState: CGFloat = _accentHue.wrappedValue
    
    @Binding var sat: CGFloat
    @Binding var brightness: CGFloat
    
    @State var satState: CGFloat = _accentSaturation.wrappedValue
    
    @EnvironmentObject var settings: Settings
    @ObservedObject var privacySettings = PrivacySettings.shared
    
        @Environment(\.subscriptionState) var subscriptionState: SubscriptionState

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(isOn: _DEMO, label: { Text("Demo Mode")})
                }
                
                Section {
                    Button(action: {
                        self.subscriptionState.showUI = true
                    }, label: {
                        HStack {
                            Spacer()
                            Text("Subscription")
                            Spacer()
                        }
                    })
                }
                
                Section(header: Text("iCloud")) {
                    Toggle(isOn: self.$settings.icloudEnabled, label: { Text("Sync GIFs to iCloud Drive") } )
                }
                
                Section(header: Text("Privacy")) {
                    //                    NavigationLink(destination: PrivacySettingsView().environmentObject(PrivacySettings()), label: { Text("Passcode") })
                    
                    
                    Toggle("Require Passcode", isOn: self.$privacySettings.passcodeEnabled.animation(Animation.default))
                    
                    
                    if self.privacySettings.passcodeEnabled && self.privacySettings.passcode != nil {
                        if BioMetricAuthenticator.shared.faceIDAvailable() {
                            Toggle("Use FaceID", isOn: self.$privacySettings.bioEnabled)
                            
                        } else if BioMetricAuthenticator.shared.touchIDAvailable() {
                            Toggle("Use TouchID", isOn: self.$privacySettings.bioEnabled)
                            
                        }
                    }
                    
                }
                
//                Section(header: Text("Video Downloads")) {
//                    HStack {
//                        Text("Preferred Quality")
//                        Spacer()
//                    Picker("Preferred Quality", selection: self.$settings.videoDownloadQuality, content: {
//                        Text(VideoDownloadQuality.fourEighty.qualityString).tag(VideoDownloadQuality.fourEighty)
//                        Text(VideoDownloadQuality.sevenTwenty.qualityString).tag(VideoDownloadQuality.sevenTwenty)
//
//                        }).pickerStyle(SegmentedPickerStyle())
//                    }
//                }
                
                Section(header: Text("Style")) {
                    VStack {
                        HStack {
                            Text("Hue")
                            Spacer()
                            Text("\(Int(self.hue * 100.0))")
                        }
                        Slider(value: $hue.animation(Animation.default), in: 0...1, step: 0.01, onEditingChanged: { _ in
//                            self.hueState = _accentHue.wrappedValue
//                            self.hueColor = _accentColorBinding.wrappedValue
                        }) {
                            EmptyView()
                        }.labelsHidden()
                    }
                    
                    VStack {
                        HStack {
                            Text("Saturation")
                            Spacer()
                            Text("\(Int(self.sat * 100.0))")
                        }
                        Slider(value: $sat.animation(Animation.default), in: 0...1, step: 0.01, onEditingChanged: { _ in
//                            self.satState = _accentSaturation.wrappedValue
//                            self.hueColor = _accentColorBinding.wrappedValue
                        }) {
                            EmptyView()
                        }.labelsHidden()
                    }
                    
                    VStack {
                                            HStack {
                                                Text("Brightness")
                                                Spacer()
                                                Text("\(Int(self.brightness * 100.0))")
                                            }
                                            Slider(value: $brightness.animation(Animation.default), in: 0...1, step: 0.01, onEditingChanged: { _ in
                    //                            self.satState = _accentSaturation.wrappedValue
                    //                            self.hueColor = _accentColorBinding.wrappedValue
                                            }) {
                                                EmptyView()
                                            }.labelsHidden()
                                        }

                }
                
            }.navigationBarTitle("Settings")
            
        }
        .navigationViewStyle(StackNavigationViewStyle()).accentColor(Color(self.hueColor))

    }
}

struct SettingsView_Previews: PreviewProvider {
    
    @State static var showSubView = false
    static var previews: some View {
        SettingsView(showSubscriptionView: $showSubView).environmentObject(Settings())
    }
}
