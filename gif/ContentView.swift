//
//  ContentView.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Combine
import SwiftUI

enum ActiveView: Hashable {
    case pickVideo
    case editor
}

struct DisplayedEditor {
    enum EditorType {
        case editor
        case crop
        case text
    }
    
    let type: EditorType
    let gif: GIF
    
    func reset() {
        gif.reset()
    }
    
    static func editor(_ gif: GIF) -> DisplayedEditor {
        .init(type: .editor, gif: gif)
    }
    
    static func crop(_ gif: GIF) -> DisplayedEditor {
        .init(type: .crop, gif: gif)
    }
    
    static func text(_ gif: GIF) -> DisplayedEditor {
        .init(type: .text, gif: gif)
    }
}

enum DisplayedEditor1 {
    case editor(GIF)
    case crop(GIF)
    case text(GIF)
    
    func reset() {
        switch self {
        case .editor(let gif): gif.reset()
        case .crop(let gif): gif.reset()
        case .text(let gif): gif.reset()
        }
    }
}

enum ActivePopover: Identifiable, Equatable {
    var id: String {
        return "\(self)"
    }
    
    case videoPicker
    case gifSettings
    case preview
    case docBrowser
    case gifCreated(GIF)
    case gifToShare([GIF])
    case urlDownload
}

struct TopControlView<Generator: GifGenerator>: View {
    @Binding var activePopover: ActivePopover?
    @Binding var activeView: ActiveView
    @Binding var ready: Bool
    
    @EnvironmentObject var globalState: GlobalState
    
    let editingContext: EditingContext<Generator>
    var body: some View {
        VStack {
            Spacer(minLength: 40)
            HStack {
                Button(action: {
                    withAnimation {
                        self.activeView = .pickVideo
                    }
                }, label: { Text("Cancel") })
                Spacer()
                Button(action: {
                    self.globalState.generateGIF(editingContext: self.editingContext)
                }, label: { Text("Create GIF") })
            }.padding(.bottom, 10)
        }.padding([.leading, .trailing], 20)
    }
}

struct VisualState: Equatable {
    var compact = false
    
    init(_ compact: Bool = false) {
        self.compact = compact
    }
}




struct ConditionalCornerRadius: ViewModifier {
    let condition: Bool
    
    func body(content: _ViewModifier_Content<ConditionalCornerRadius>) -> some View {
        if self.condition {
            return content.cornerRadius(10).any
        } else {
            return content.any
        }
    }
}

extension Collection where Element == GIF {
    var gifCollection: GIFCollection { return GIFCollection(gifs: self as! [GIF]) }
}

struct GIFCollection: Identifiable {
    let gifs: [GIF]
    
    var id: String {
        return self.gifs.reduce("") { prev, next in
            prev + next.id
        }
    }
}

struct ContentView: View {
    
    var accent: Binding<UIColor> = _accentColorBinding
    
    @State var displayedEditor: DisplayedEditor? = nil
    
    @State var activeView: ActiveView = .pickVideo
    @EnvironmentObject var globalState: GlobalState
    
    @State var gifToShare: GIFCollection? = nil
    
    @State var showHUD = false
    @State var showHUDLoading = false
    @State var showHUDMessage = false
    
    @State var showCreatedGIF = false
    
    @State var addingText: GIF? = nil
    
    //    @State var editingGIF: GIF? = nil
    
    @State var createdGIF: GIF? = nil
    
    @ObservedObject var privacySettings = PrivacySettings.shared
    
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?

    @State var rerendering = false
    
    //    @State var hudMessage: HUDAlertMessage = HUDAlertMessage.empty
    var body: some View {
//        GeometryReader { metrics in
            
            //            ZStack {
            self.getMain()
//                .frame(width: metrics.size.width, height: metrics.size.height).zIndex(0)
//                .overlay(Color.background                .opacity(self.displayedEditor == nil ? 0 : 1).animation(Animation.linear(duration: 0.1).delay(0.5)).edgesIgnoringSafeArea(.all))
            
            
            
            //            }
//        }
//        .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
        .sheet(item: self.$globalState.activePopover, content: { _ in
            self.getPopover()
        })
            .onReceive(self.globalState.video.unwrappedGifConfig.$visible) { s in
                self.globalState.activePopover = s ? .gifSettings : nil
        }.onReceive(self.globalState.video.updated.receive(on: DispatchQueue.main)) { v in
            if self.globalState.activePopover == .videoPicker {
                if v.isValid ?? false {
                    self.globalState.activePopover = nil
                }
            }
        }.onReceive(GlobalPublishers.default.created) { gif in
            
            
            Delayed(0.1) {
                self.$displayedEditor.animation(Animation.default).wrappedValue = .editor(gif)
                self.globalState.video.reset()
                
                self.activeView = .pickVideo
            }
            
            //            self.$createdGIF.animation(Animation.spring(dampingFraction: 0.7)).wrappedValue = gif
        }.onReceive(self.globalState.video.readyToEdit, perform: { valid in
            guard let valid = valid else {
                
                DispatchQueue.main.async {
                self.globalState.hudAlertState.showLoadingIndicator = false
                }
                return
                
            }
            if valid {
                DispatchQueue.main.async {
                    self.globalState.hudAlertState.showLoadingIndicator = false
                    
                    withAnimation(Animation.default.delay(0.4)) {
                        self.activeView = .editor
                    }
                }
                
            } else {
                Delayed(0.2) {
                    withAnimation(Animation.default.delay(0.1)) {
                        
                        self.globalState.hudAlertState.show(.error("something went wrong"))
                    }
                }
            }
        })
            .onReceive(GlobalPublishers.default.addText, perform: { gif in
                self.displayedEditor = .text(gif)
            })
            .onReceive(GlobalPublishers.default.crop, perform: { gif in
                self.displayedEditor = .crop(gif)
            })
            .onReceive(GlobalPublishers.default.edit, perform: { gif in
                self.$displayedEditor.animation(Animation.easeIn(duration: 0.3)).wrappedValue = .editor(gif)
            })
            
            .onReceive(GlobalPublishers.default.showShare) { gif in
                self.globalState.activePopover = .gifToShare(gif)
        }
            
            
            //            .overlay(ZStack {
            //                EmptyView().zIndex(0)
            //
            //                if self.createdGIF != nil {
            //
            //                    self.gifCreatedView()
            //                }
            //            })
            
            .onReceive(GlobalPublishers.default.dismissEditor) { (_) in
                self.dismissEditor()
        }
        .overlay(ZStack {
            
            if self.activeView == .editor {
                self.getEditor()
                    .transition(.slide)
                    .zIndex(1)
            }
            
            if self.displayedEditor != nil {
                
                self.getDisplayedEditor()
                    .background(Color.background.edgesIgnoringSafeArea(.all))
                    .transition(AnyTransition.opacity.animation(Animation.easeIn(duration: 0.3).delay(0.2)))
                    .zIndex(2)
            }
            
            if self.privacySettings.passcodeEnabled && !self.privacySettings.authorized  {
                VisualEffectView.blur(.regular).edgesIgnoringSafeArea(.all)
                    .transition(AnyTransition.opacity.animation(Animation.default)).zIndex(1000)
                
                Group {
                    if self.privacySettings.passcode == nil {
                        PasscodeLockView(state: .setPasscode)
                    } else if self.privacySettings.needsPasscodeUnlock {
                        PasscodeLockView(state: .enterPasscode)
                    }
                }
                .scaleEffect(self.verticalSizeClass == .compact ? 0.7 : 1)
            .zIndex(1001)
                .transition(AnyTransition.scale(scale: 1.1).combined(with: .opacity).animation(Animation.default))
            }
            
        })
                .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
                    .opacity(self.rerendering ? 0 : 1)
                    .onReceive(AccentPublisher.shared.$publisher) { (val) in
                        self.rerendering = true
                        
                        Async {
                            self.rerendering = false
                        }
                }
            .accentColor(Color(self.accent.wrappedValue))
    }
    
    func dismissEditor() {
        self.displayedEditor?.reset()
        self.$displayedEditor.animation().wrappedValue = nil
        
        self.globalState.video.reset()
        
        self.activeView = .pickVideo
    }
    
    func cropEditor(gif: GIF) -> some View {
        
        gif.cropState = CropState(aspectRatio: gif.aspectRatio ?? 1)
        
        return NavigationView {
            GIFCroppingView(croppingGIF: gif).zIndex(2)
                
                
                .navigationBarTitle(Text("Crop GIF"), displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    self.dismissEditor()
                    }, trailing: Button("Save") {
                        GlobalPublishers.default.readyToCrop.send(gif)
                        
                        Async {
                            self.dismissEditor()
                        }
                })
            
        }.navigationViewStyle(StackNavigationViewStyle())
            .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.3).delay(0.1)))
        
    }
    
    func gifCreatedView() -> some View {
        Group {
            Rectangle().fill(
                LinearGradient(gradient:
                    .init(stops: [.init(color: .black, location: 0),
                                  .init(color: Color.black.opacity(0.8), location: 0.2),
                                  .init(color: Color.black.opacity(0.8), location: 0.8),
                                  .init(color: .black, location: 1)]), startPoint: .leading,
                                                                       endPoint: .trailing))
                //                    .fill(Color.black.opacity(0.8))
                .blendMode(.destinationOver)
                .zIndex(3)
                .edgesIgnoringSafeArea([.top, .bottom])
                .transition(AnyTransition.opacity.animation(.default))
                .compositingGroup()
            
            if self.createdGIF != nil {
                GifCreatedView(gif: self.createdGIF!, dismissBlock: {
                    self.$createdGIF.animation().wrappedValue = nil
                })
                    .onDisappear(perform: {
                        self.createdGIF = nil
                    })
//                    .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
                    .accentColor(Color.accent)
                    .zIndex(5)
                    .transition(AnyTransition.move(edge: .bottom).animation(Animation.spring(dampingFraction: 0.7)))
            }
        }
    }
    
    func gifEditor(gif: GIF) -> some View {
        return
            //NavigationView {
            
            EditContainerView(gif: gif, dismissBlock: {
                self.dismissEditor()
            })
//                .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
                
                .navigationBarItems(leading: Button(action: {
                    self.displayedEditor = .none
                }, label: { Text("Cancel") }))
        
        // }.navigationViewStyle(StackNavigationViewStyle())
        
        
        
        //         return NavigationView {
        //                   EditorView<FramePlayerView, ExistingFrameGenerator>(
        //                    visualState: self.$globalState.visualState)
        //                    .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
        //                       .navigationBarTitle("Edit GIF", displayMode: .inline)
        //                       .navigationBarItems(leading: Button("Cancel") {
        //
        //                        self.dismissEditor()
        //                           }, trailing: Button("Create GIF") {
        //                               GlobalState.instance.generateGIF(editingContext: gif.editingContext)
        //                       })
        //
        //
        //               }            .navigationViewStyle(StackNavigationViewStyle())
        //
        //                   .environmentObject(gif.editingContext)
        //                   .background(Color.background)
    }
    
    func getDisplayedEditor() -> some View {
        
        Group {
            
            if self.displayedEditor?.type == .editor {
                self.gifEditor(gif: self.displayedEditor!.gif)
            } else if self.displayedEditor?.type == .crop {
                self.cropEditor(gif: self.displayedEditor!.gif)
            } else if self.displayedEditor?.type == .text {
                self.getTextEditor(gif: self.displayedEditor!.gif)
            }
            
        }
        
    }
    
    func getPopover() -> AnyView {
        switch self.globalState.activePopover {
        case .videoPicker:
            return ImagePickerController(video: self.globalState.video).onDisappear {
                self.globalState.activePopover = nil
                if self.globalState.video.isValid ?? false {
                    withAnimation(Animation.default.delay(0.4)) {
                        self.activeView = .editor
                    }
                }
            }.any
            
        case .gifSettings:
            return GifSettingsView().environmentObject(self.globalState.video.gifConfig).onDisappear {
                self.globalState.activePopover = nil
                self.globalState.video.gifConfig.visible = false
            }.any
        case .preview:
            return EmptyView().any
        //            return PreviewModal<VideoGifGenerator>(activePopover: self.$globalState.activePopover).environmentObject(self.globalState.gifGenerator).any
        case .docBrowser:
            //            return DocumentBrowserView(activePopover: self.$globalState.activePopover).any
            return DocumentPickerUIView(video: self.globalState.video, cancelBlock: {
                self.globalState.activePopover = nil
                
            }).onDisappear {
                self.globalState.activePopover = nil
                
            }.any
        case .gifCreated(let gif):
            
            return EmptyView().any
        //            return GifCreatedView(gif: gif).modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState)).accentColor(Color.accent).environmentObject(self.globalState).any
        case .gifToShare(let gif):
            return ActivityView(gifs: gif).any
            
        case .urlDownload:
            return EnterURLView(url: self.$globalState.urlEntry, dismissBlock: {
                self.globalState.activePopover = nil
            }, goBlock: {
                if let url = self.globalState.urlEntry {
                    self.globalState.urlEntry = nil
                    self.globalState.activePopover = nil
                    Async {
                        self.globalState.hudAlertState.showLoadingIndicator = true
                        Async {
                            self.globalState.hudAlertState.loadingMessage = ("processing video", {
                                Downloader.instance.cancellables.forEach { $0.cancel() }
                            })
                        }
                    }
                    Downloader.instance.getVideo(url: url)
                        .receive(on: DispatchQueue.main)
                        .handleEvents(receiveCancel: {
                            Delayed(0.2) {
                                withAnimation(Animation.default) {
                                    if Downloader.instance.failed {
                                        self.globalState.hudAlertState.show(.error("something went wrong"))

                                    } else {
                                    self.globalState.hudAlertState.show(.error("cancelled"))
                                    }
                                }
                            }
                        })
                        .sink { video in
                            if let video = video {
                                Async {
                                    //                                    self.globalState.hudAlertState.showLoadingIndicator = false
                                    
                                    //                                    Delayed(0.3) {
                                    
                                    self.globalState.video.reset(video)
                                    
                                    //                                    }
                                    
                                }
                            } else {
                                Delayed(0.2) {
                                    withAnimation(Animation.default) {
                                        
                                        self.globalState.hudAlertState.show(.error("something went wrong"))
                                    }
                                }
                                print("no video")
                            }
                    }.store(in: &Downloader.instance.cancellables)
                } else {
                    Async {
                        self.globalState.hudAlertState.show(.error("Bad URL"))
                    }
                    print("bad url")
                }
            }).accentColor(Color.accent).any
        case .none:
            return EmptyView().any
        }
    }
    
    func getTextEditor(gif: GIF) -> some View {
        return NavigationView {
            EditorView<TextPlayerView, TextFrameGenerator>()
                .navigationBarTitle("Add Text", displayMode: .inline)
                .navigationBarItems(leading: Button(action: {
                    self.dismissEditor()
                }, label: { Text("Cancel") }), trailing: Button(action: {
                    self.globalState.generateGIF(editingContext: gif.textEditingContext)
                }, label: { Text("Create GIF") }))
        }
            //        .edgesIgnoringSafeArea(self.globalState.visualState.compact ? [.leading, .trailing, .top] : [.top, .bottom])
//            .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
            .environmentObject(gif.textEditingContext)
            .background(Color.background)
            .navigationViewStyle(StackNavigationViewStyle())
            .transition(.slide)
            .zIndex(3)
    }
    
    func getEditor() -> some View {
        return NavigationView {
            EditorView<VideoPlayerView, VideoGifGenerator>()
                .navigationBarTitle("Create GIF", displayMode: .inline)
                .navigationBarItems(leading: Button(action: {
                    withAnimation {
                        self.activeView = .pickVideo
                    }
                }, label: { Text("Done") }), trailing: Button(action: {
                    self.globalState.generateGIF(editingContext: self.globalState.video.editingContext)
                }, label: { Text("Create GIF") }))
        }
            //        .edgesIgnoringSafeArea(self.globalState.visualState.compact ? [.leading, .trailing, .top] : [.top, .bottom])
//            .modifier(WithHUDModifier(hudAlertState: self.globalState.hudAlertState))
            .environmentObject(self.globalState.video.editingContext)
            .background(Color.background)
            .navigationViewStyle(StackNavigationViewStyle())
    }
    
    let transitionAnimationContext = TransitionAnimationContext()
    func getMain() -> some View {
        return GalleryContainer(activePopover: self.$globalState.activePopover, transitionAnimation: self.transitionAnimationContext)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(Video.preview)
    }
}
