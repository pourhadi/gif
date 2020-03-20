//
//  ShareViewController.swift
//  share
//
//  Created by Daniel Pourhadi on 3/9/20.
//  Copyright © 2020 dan. All rights reserved.
//

import UIKit
import Social
import SwiftUI
import iCloudSync

class ShareViewController: UIHostingController<AnyView> {

    let queue = DispatchQueue(label: "com.pourhadi.giffed.share")
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(rootView: AnyView(EmptyView()))
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        iCloud.shared.setupiCloud(nil)

        
        print("view did appear")
        
        self.view.backgroundColor = UIColor.black
    }
    
    
    override func beginRequest(with context: NSExtensionContext) {
        super.beginRequest(with: context)
        
        queue.async {
            for item in context.inputItems {
                if let item = item as? NSExtensionItem, let attachments = item.attachments {
                    for att in attachments {
                        att.loadDataRepresentation(forTypeIdentifier: "com.compuserve.gif") { [unowned self] (data, _) in
                            if let data = data {
                                
                                DispatchQueue.main.async {
                                    
                                    self.rootView = AnyView(ShareView(data: data, addHandler: {
                                        
                                        self.queue.async {
                                            FileGalleryDummy.shared._galleryAdd(data: data) { (_, _) in
                                                DispatchQueue.main.async {
                                                    context.completeRequest(returningItems: nil, completionHandler: nil)
                                                }
                                            }
                                        }
                                        
                                    }, cancelHandler: {
                                        context.completeRequest(returningItems: nil, completionHandler: nil)
                                    }))
                                }
                            }
                        }
                    }
                }
                
            }
        }
    }
}


struct ShareView : View {
    
    let data: Data
    
    let addHandler: () -> Void
    let cancelHandler: () -> Void
    
    @State var showLoading = false
    
    var body : some View {
        GeometryReader { metrics in
            VStack {
                Spacer()
                AnimatedImage(self.data)
                .cornerRadius(10)
                    .padding(10)
                    .shadow(radius: 10)
                Spacer(minLength: 40)
                VStack(spacing: 10) {
                    Button(action: {
                        self.$showLoading.animation(Animation.linear(duration: 0.3)).wrappedValue = true
                        
                        DispatchQueue.main.async {
                            self.addHandler()

                        }
                    }, label: {
                        Text("Add to My GIFs")
                            .font(.title)
                            .shadow(radius: 1)
                            .padding(20)
                            .frame(width: metrics.size.width - 40)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.2)))
                        
                        
                    })
                    Button(action: {
                        self.cancelHandler()
                    }, label: {
                        Text("Cancel")
                            .font(.title)
                            .shadow(radius: 1)
                            .padding(20)
                            .frame(width: metrics.size.width - 40)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.2)))
                        
                    } )
                }
                Spacer()
            }
                .padding(.bottom, metrics.safeAreaInsets.bottom)
            .background(AnimatedImage(self.data, contentMode: .fill)
            .frame(width: metrics.size.width, height: metrics.size.height)
            .blur(radius: 45, opaque: true)
            .brightness(-0.3))
        }.blur(radius: self.showLoading ? 40 : 0)
            .overlay(self.getOverlay())
            .accentColor(Color.accent)
            .edgesIgnoringSafeArea(.all)
    }
    
    func getOverlay() -> some View {
        LoadingCircleView()
            .frame(width: 80, height: 80)
            .scaleEffect(self.showLoading ? 2 : 1.8)
            .opacity(self.showLoading ? 1 : 0)
    }
    
}
