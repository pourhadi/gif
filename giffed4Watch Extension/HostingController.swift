//
//  HostingController.swift
//  giffed4Watch Extension
//
//  Created by Daniel Pourhadi on 6/2/20.
//  Copyright © 2020 dan. All rights reserved.
//

import WatchKit
import Foundation
import SwiftUI

class HostingController: WKHostingController<ContentView> {
    override var body: ContentView {
        return ContentView(playGIFBlock: { gif in
            self.presentMediaPlayerController(with: gif, options: [WKMediaPlayerControllerOptionsLoopsKey: true]) { (a, b, c) in
                if let c = c {
                    self.presentAlert(withTitle: "", message: c.localizedDescription, preferredStyle: .alert, actions: [WKAlertAction.init(title: "OK", style: .default, handler: {
                        
                    })])
                }
            }
        }, showErrorBlock: { message in
            self.presentAlert(withTitle: nil, message: message, preferredStyle: .alert, actions: [WKAlertAction(title: "OK", style: .default, handler: {
                
            })])
        })
    }

    
//    override func didAppear() {
//        super.didAppear()
//
//        WatchController.shared.updateGIFList()
//    }
}

