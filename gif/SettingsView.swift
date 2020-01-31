//
//  SettingsView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/28/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("iCloud")) {
                    Toggle(isOn: self.$settings.icloudEnabled, label: { Text("Sync GIFs to iCloud Drive") } )
                }
            }.navigationBarTitle("Settings")

        }
        .navigationViewStyle(StackNavigationViewStyle())

    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
