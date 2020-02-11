//
//  ShareViewController.swift
//  share
//
//  Created by Daniel Pourhadi on 1/21/20.
//  Copyright © 2020 dan. All rights reserved.
//

import UIKit
import Social
import SwiftUI
import CoreGraphics
import MobileCoreServices
import SnapKit
import Combine

class ShareViewController: UIViewController {

    
    var toLog: String = ""
    
    
    override func beginRequest(with context: NSExtensionContext) {
        super.beginRequest(with: context)
        
        if let item = context.inputItems.first as? NSExtensionItem, let itemProvider = item.attachments?.first {
            
            if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                itemProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (url, error) in
                    if let url = url as? URL {
                        
                        self.url = url
                        
                    }
                }
            }
            
            if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeGIF as String) {
                itemProvider.loadItem(forTypeIdentifier: kUTTypeGIF as String, options: nil) { (data, error) in
                    if let data = data as? Data {
                        self.data = data
                    }
                }
            }
            self.toLog = "\(itemProvider.registeredTypeIdentifiers)"
        }
    }

    var data: Data? = nil {
        didSet {
            reset()
        }
    }
    var url: URL? = nil {
        didSet {
            reset()
        }
    }
    
    var context: ShareContext = ShareContext()
    
    func sendSomething(_ x: Int) {
        
        if x == 0 {
            self.context.image.send(UIImage.add)
        } else if x == 1 {
            self.context.image.send(UIImage.actions)
        } else {
            self.context.image.send(UIImage.checkmark)
        }
        
    }
    
    func reset () {
        if let data = data {
            if CGAnimateImageDataWithBlock(data as CFData, nil, { (x, cgImage, done) in
                self.context.image.send(UIImage(cgImage: cgImage))
            }) != 0 {
                self.sendSomething(0)
            }
        } else if let url = url {
            if CGAnimateImageAtURLWithBlock(url as CFURL, nil, { (x, cgImage, done) in
                                self.context.image.send(UIImage(cgImage: cgImage))

            }) != 0 {
                self.sendSomething(1)
            }
        } else {
            self.sendSomething(2)
        }
        
        DispatchQueue.main.async {
            self.context.text = "\(self.hostingVC.sizeThatFits(in: self.view.bounds.size))"

        }
    }
    let fileGallery = FileGalleryDummy()

    var xables = Set<AnyCancellable>()
    
    func addHit() {
        
        var useData: Data!
        if let data = self.data {
            useData = data
        } else if let url = self.url {
            useData = try? Data(contentsOf: url)
        } else {
            fatalError()
        }
        
        
        HUDAlertState.global.showLoadingIndicator = true

        Async {
            self.fileGallery._galleryAdd(data: useData) { (id, error) in
                guard error == nil else {
                    HUDAlertState.global.show(.error("Error saving GIF"))
                    
                    self.extensionContext?.cancelRequest(withError: error!)
                    return
                }
                
                Async {
                    HUDAlertState.global.show(.thumbup("GIF saved"))
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        }
    }
    
    func cancelHit() {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    lazy var hostingVC: UIHostingController<ShareView> = UIHostingController(rootView: ShareView(context: self.context, addHit: self.addHit, cancelHit: self.cancelHit))
    override func viewDidLoad() {
        super.viewDidLoad()

        self.context.text = "view did load"
        let vc = self.hostingVC
        
//        vc.willMove(toParent: self)
//        self.addChild(vc)
        self.view.addSubview(vc.view)
//        vc.didMove(toParent: self)
        
        vc.view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        vc.view.backgroundColor = UIColor.clear
        vc.view.isOpaque = false
        
        DispatchQueue.main.async {
            self.context.text = "\(vc.sizeThatFits(in: self.view.bounds.size))"

        }
        
        self.context.height.receive(on: DispatchQueue.main).sink { height in
            self.preferredContentSize = CGSize(width: -1, height: height)
            vc.view.snp.remakeConstraints { (make) in
                make.edges.equalToSuperview()
                make.height.equalTo(height)
            }
            vc.view.setNeedsUpdateConstraints()
            vc.view.setNeedsLayout()
            self.view.setNeedsUpdateConstraints()
            self.view.setNeedsLayout()
        }.store(in: &self.xables)
        
        
    }

}


struct HeightPreferenceKey : PreferenceKey {
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
    
    
    typealias Value = Anchor<CGRect>?
    
    
}

class ShareContext: ObservableObject {
    var image = PassthroughSubject<UIImage?, Never>()

    var height = PassthroughSubject<CGFloat, Never>()
    
    @Published var text: String?
}

struct Run : View {
    
    let block: () -> Void
    
    var body: some View {
        DispatchQueue.main.async {
            self.block()
        }
        
        return EmptyView()
    }
}

struct ShareView: View {
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @ObservedObject var hudAlertState = HUDAlertState.global
    @ObservedObject var context: ShareContext
    
    @State var image: UIImage? = nil
    
    @State var readCount = 0
    
    let addHit: () -> Void
    let cancelHit: () -> Void
    
    var body: some View {
        GeometryReader { outerMetrics in
            
            VStack {
                Spacer()
                if self.image != nil {
                    
                    VStack(spacing: 12) {
                        Image(uiImage: self.image!)
                            .resizable()
                            .aspectRatio(self.image!.size, contentMode: .fit)
                        
                        Group {
                            self.saveButton().padding(.top, 20)
                            self.cancelButton()
                                .padding(.bottom, 40 + outerMetrics.safeAreaInsets.bottom)
                        }
                        
                    }
                    .padding(.top, 20)
                    .anchorPreference(key: HeightPreferenceKey.self, value: .bounds) { anchor in
                        return anchor
                    }
                    .backgroundPreferenceValue(HeightPreferenceKey.self) { pref in
                        GeometryReader { metrics in
                            self.getBackground(metrics: metrics, pref: pref).edgesIgnoringSafeArea(.bottom)
                        }
                        
                    }
                    .cornerRadius(10)
                    .shadow(radius: 20)
                }
            }.modifier(WithHUDModifier(hudAlertState: HUDAlertState.global))
            
        }
            
            
        .onReceive(self.context.image) { (image) in
            self.image = image
            self.readCount += 1
        }

    }
    func saveButton() -> some View {
        Button(action: {
            self.addHit()
        }, label: {
            Text("Save to My GIFs")
                .font(.system(size: 20))
                .fontWeight(.medium)
                .accentColor(Color.accent)
                .centered(.horizontal)
                .frame(height: 60)
            
            
        })
            .background(Color.white .opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal, 20)
    }
    
    func cancelButton() -> some View {
        Button(action: {
            self.cancelHit()
        }, label: {
            Text("Cancel")
                .accentColor(Color.accent)
                .font(.system(size: 20))
                .centered(.horizontal)
                .frame(height: 60)

            
        })
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 20)
    }
    
    func getBackground(metrics: GeometryProxy, pref: HeightPreferenceKey.Value) -> some View {
        let bounds = pref != nil ? metrics[pref!] : CGRect.zero
        self.context.height.send(bounds.size.height + metrics.safeAreaInsets.bottom)

        return ZStack {
            if self.image != nil {
                Image(uiImage: self.image!)
                    .resizable()
                    .aspectRatio(self.image!.size, contentMode: .fill).zIndex(0)
                
                VisualEffectView.blur(.prominent)
            }
            
        }.frame(height:bounds.size.height + metrics.safeAreaInsets.bottom, alignment: .bottom)

        
        
    }
}


struct TmpView : View {
    
    let text: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(text)
            Spacer()
        }
    }
    
}
