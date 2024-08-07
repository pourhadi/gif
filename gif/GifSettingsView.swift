//
//  GifSettingsView.swift
//  gif
//
//  Created by dan on 12/8/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct GifSettingsView: View {
    
    @EnvironmentObject var settings: GifConfig
    
    var body: some View {
        NavigationView {
            Form {
                
                if !settings.hideAnimationQuality {
                    Section(header: Text("Animation Quality")) {
                        Picker(selection: self.$settings.animationQuality, label: Text("Animation Quality") ) {
                            ForEach(GifConfig.AnimationQuality.all.reversed()) { q in
                                Text((q as GifConfig.AnimationQuality).name).tag(q)
                            }
                        }.pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Image Quality")) {
                        Text("\(Int(self.settings.imageQuality * 100))%").centered()
                        Slider(value: self.$settings.imageQuality)
                    }
                }
                Section(header: Text("Speed")) {
                    Text("\(Int(self.settings.speed * 100))%").centered()
                    Slider(value: self.$settings.speed, in: ClosedRange(uncheckedBounds: (0.25, 2)))
                }
                
                

//                Section(header: Text("Size")) {
//                    Text(self.settings.assetInfo.size.applying(.init(scaleX: self.settings.sizeScale, y: self.settings.sizeScale)).displayString).centered()
//                    Slider(value: self.$settings.sizeScale, in: 0.10...1.0)
//                }
                Section(header: Text("Animation Type")) {
                    Picker(selection: self.$settings.animationType, label: Text("Animation Type") ) {
                        ForEach(GifConfig.AnimationType.all) { q in
                            Text((q as GifConfig.AnimationType).name).tag(q)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }
            }.navigationBarTitle("GIF Settings")

                .navigationBarItems(trailing: Button(action: {
                self.settings.visible = false
            }, label: { Text("Done") } ))
        }.accentColor(Color.accent)
        .navigationViewStyle(StackNavigationViewStyle())

    }
}

struct GifSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GifSettingsView().environmentObject(Video.preview.gifConfig)
    }
}
