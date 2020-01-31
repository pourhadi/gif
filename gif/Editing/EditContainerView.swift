//
//  EditContainerView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/18/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Combine
import SwiftUI

struct SlideUpModifier : ViewModifier {

    @Binding var visible: Bool
    let delay: Double

    func body(content: Self.Content) -> some View {
        content
        .opacity(self.visible ? 1 : 0)
        .scaleEffect(self.visible ? 1 : 0.2)
        .offset(y: self.visible ? 0 : 50)
            .animation(Animation.bouncy2.delay(self.delay))
    }
}

struct EditNavView<Content>: View where Content: View {
    let leadingItem: AnyView
    let trailingItem: AnyView
    let content: () -> Content
    let title: String
    
    init(title: String, leadingItem: AnyView, trailingItem: AnyView, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.leadingItem = leadingItem
        self.trailingItem = trailingItem
        self.content = content
    }
    
    var body: some View {
        GeometryReader { metrics in
            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        Spacer()
                        Text(self.title).font(.headline)
                        Spacer()
                    }
                    HStack {
                        self.leadingItem
                        Spacer()
                        self.trailingItem
                    }
                }
                .frame(height: 40)
                .padding([.leading, .trailing], 20)
                .background(Color.black)
                
                self.content().frame(height: metrics.size.height - (40))
            }
        }
    }
}

struct EditContainerView: View {
    
    
    init(gif: GIF, dismissBlock: @escaping () -> Void) {
        self._gif = State<GIF>(initialValue: gif)
        self.dismissBlock = dismissBlock
    }
    
    @State var visible = false
    
    class Store {
        var cancellables = Set<AnyCancellable>()
    }
    
    let store = Store()
    
    enum ActiveEditor: Identifiable {
        var id: ActiveEditor { return self }
        case trim
        case text
        case crop
        case image
    }
    
    let editor = GifEditor()
    
    @State var activeEditor: ActiveEditor?
    
    @State var gif: GIF
    
    @State var animated = true
    
    let dismissBlock: () -> Void
    
    var body: some View {
        let trailing = Button("Save") {
            GlobalState.instance.saveGeneratedGIF(gif: self.gif) { (success) in
                if success {
                    Async {
                        self.dismissBlock()
                    }
                }
            }
        }
        
        
        return GeometryReader { metrics in
            VStack(spacing: 0) {
 
                EditNavView(title: "Edit", leadingItem: Button(action: {
                    self.dismissBlock()
                }, label: { Text("Cancel") }).any, trailingItem: trailing.any) {
                    
                    AnimatedGIFView(gif: self.$gif, animated: self.$animated)
                        .opacity(self.activeEditor == nil ? 1 : 0)
                }
                
                self.getToolbar(with: metrics).offset(y: self.activeEditor == nil ? 0 : 80)
                
            }
        }
        .overlay(Group {
            self.getActiveEditor()
        })
            .background(Color.black.edgesIgnoringSafeArea([.top, .bottom]))
            .onAppear {
                Delayed(0.2) {
                    self.$visible.animation(Animation.bouncy1).wrappedValue = true
                }
        }
        /*
         .background(ZStack {
         AnimatedGIFView(gif: self.$gif, animated: self.$animated, contentMode: .fill).zIndex(0)
         VisualEffectView.blur(.systemThickMaterialDark).brightness(-0.1).zIndex(1)
         
         }        .edgesIgnoringSafeArea([.top, .bottom])
         )
         */
    }
    
    func getActiveEditor() -> some View {
        Group {
            if self.activeEditor == .crop {
                self.cropEditor()
            }
            
            if self.activeEditor == .text {
                self.getTextEditor()
            }
            
            if self.activeEditor == .image {
                self.getImageEditor()
            }
            
            if self.activeEditor == .trim {
                self.getFrameEditor()
            }
        }
    }
    
    func getToolbar(with metrics: GeometryProxy, background: AnyView = Color.clear.any) -> some View {
        return ToolbarView(metrics: metrics, bottomAdjustment:nil, background: background, hideDivider: true) {
            self.toolbarItems
            
        }.frame(height: 40)
    }
    
    var toolbarItems: some View {
        Group {
            Button(action: {
                self.$activeEditor.animation().wrappedValue = ActiveEditor.trim

                
            }, label: { Image.symbol("slider.horizontal.below.rectangle") }).padding(12)
                .modifier(SlideUpModifier(visible: self.$visible, delay: 0.2))
            
            Spacer()
            
            Button(action: {
                self.$activeEditor.animation().wrappedValue = ActiveEditor.crop
            }, label: { Image.symbol("crop") }).padding(12)

            .modifier(SlideUpModifier(visible: self.$visible, delay: 0.3))

            
            Spacer()
            
            Button(action: {
                self.$activeEditor.animation().wrappedValue = ActiveEditor.text
            }, label: { Image.symbol("textbox") }).padding(12)
                                .modifier(SlideUpModifier(visible: self.$visible, delay: 0.4))

            
            Spacer()
            
            Button(action: {
                self.$activeEditor.animation().wrappedValue = ActiveEditor.image
                
            }, label: { Image.symbol("dial.fill") }).padding(12)
                                .modifier(SlideUpModifier(visible: self.$visible, delay: 0.5))

        }
    }
    
    
    func getImageEditor() -> some View {
        
        let imageEditor = ImageEditor(gif: self.gif)

        
        let leading = Button("Cancel") {
            self.$activeEditor.animation().wrappedValue = nil

        }.any
        
        let trailing = Button("Apply") {
            
            Async {
                HUDAlertState.global.showLoadingIndicator = true
            }
            
            
            imageEditor.createRenderedGif(for: self.gif)
                .subscribe(on: DispatchQueue.global())
                .receive(on: DispatchQueue.main)
                .sink { newGif in
                    
                    if let newGif = newGif {
                        HUDAlertState.global.showLoadingIndicator = false
                        
                        Async {
                            self.gif.reset()
                            self.$gif.animation().wrappedValue = newGif
                            self.$activeEditor.animation().wrappedValue = nil
                        }
                    } else {
                        HUDAlertState.global.show(.error("Error editing GIF"))

                    }
                    
            }.store(in: &self.store.cancellables)
            
//            generateGif(photos: imageEditor.images, filename: "edited.gif", frameDelay: imageEditor.duration / Double(imageEditor.images.count))
//                .subscribe(on: DispatchQueue.global())
//                .receive(on: DispatchQueue.main)
//                .sink { url in
//                    if let url = url {
//                        let gif = GIFFile(id: UUID().uuidString, url: url)
//
//                        HUDAlertState.global.showLoadingIndicator = false
//
//                        Async {
//                            self.$gif.animation().wrappedValue = gif
//                            self.$activeEditor.animation().wrappedValue = nil
//                        }
//                    } else {
//                        HUDAlertState.global.show(.error("Error editing GIF"))
//                    }
//
//            }.store(in: &self.store.cancellables)
        }.any
        
        
        
        return GeometryReader { metrics in
            VStack(spacing: 0) {
                EditNavView(title: "Adjust", leadingItem: leading, trailingItem: trailing) {
                    ImageAdjustmentView(gif: self.gif, editor: imageEditor)
                }
                
//                Color.clear.frame(height: 40)

            }
            
        }.transition(AnyTransition.scale(scale: 1.2).combined(with: .opacity).animation(Animation.default))
            .animation(.default)
    }
    
    
    func getFrameEditor() -> some View {
        return NavigationView {
            EditorView<FramePlayerView, ExistingFrameGenerator>()
                .navigationBarTitle("Edit GIF", displayMode: .inline)
                .navigationBarItems(leading: Button(action: {
                    
                    self.$activeEditor.animation().wrappedValue = nil
                    
                }, label: { Text("Cancel") }), trailing: Button(action: {
                    HUDAlertState.global.showLoadingIndicator = true
                    
                    self.editor.generate(from: self.gif.editingContext)
                        .receive(on: DispatchQueue.main)
                        .sink { gif in
                            if let gif = gif {
                                HUDAlertState.global.showLoadingIndicator = false
                                
                                Async {
                                    self.$gif.animation().wrappedValue = gif
                                    self.$activeEditor.animation().wrappedValue = nil
                                }
                            } else {
                                HUDAlertState.global.show(.error("Error editing GIF"))
                            }
                    }.store(in: &self.store.cancellables)
                    
                }, label: { Text("Apply") }))
        }
            //        .edgesIgnoringSafeArea(self.globalState.visualState.compact ? [.leading, .trailing, .top] : [.top, .bottom])
            .modifier(WithHUDModifier(hudAlertState: HUDAlertState.global))
            .environmentObject(self.gif.editingContext)
            .background(Color.background)
            .navigationViewStyle(StackNavigationViewStyle())
            .transition(.slide)
            .zIndex(3)
    }
    
    func getTextEditor() -> some View {
        return NavigationView {
            EditorView<TextPlayerView, TextFrameGenerator>()
                .navigationBarTitle("Add Text", displayMode: .inline)
                .navigationBarItems(leading: Button(action: {
                    
                    self.$activeEditor.animation().wrappedValue = nil
                    
                }, label: { Text("Cancel") }), trailing: Button(action: {
                    HUDAlertState.global.showLoadingIndicator = true
                    
                    self.editor.generate(from: self.gif.textEditingContext)
                        .receive(on: DispatchQueue.main)
                        .sink { gif in
                            if let gif = gif {
                                HUDAlertState.global.showLoadingIndicator = false
                                
                                Async {
                                    self.$gif.animation().wrappedValue = gif
                                    self.$activeEditor.animation().wrappedValue = nil
                                }
                            } else {
                                HUDAlertState.global.show(.error("Error editing GIF"))
                            }
                    }.store(in: &self.store.cancellables)
                    
                }, label: { Text("Apply") }))
        }
            //        .edgesIgnoringSafeArea(self.globalState.visualState.compact ? [.leading, .trailing, .top] : [.top, .bottom])
            .modifier(WithHUDModifier(hudAlertState: HUDAlertState.global))
            .environmentObject(self.gif.textEditingContext)
            .background(Color.background)
            .navigationViewStyle(StackNavigationViewStyle())
            .transition(.slide)
            .zIndex(3)
    }
    
    func cropEditor() -> some View {
        self.gif.cropState = CropState(aspectRatio: self.gif.aspectRatio ?? 1)
        
        let leading = Button("Cancel") {
            self.$activeEditor.animation().wrappedValue = .none
            
        }.any
        
        let trailing = Button("Apply") {
            HUDAlertState.global.showLoadingIndicator = true
            
            self.editor.crop(self.gif)
                .receive(on: DispatchQueue.main)
                .sink { gif in
                    if let gif = gif {
                        HUDAlertState.global.showLoadingIndicator = false
                        
                        Async {
                            self.$activeEditor.animation().wrappedValue = nil
                            
                            Async {
                                self.gif.reset()
                                self.gif = gif
                            }
                        }
                    } else {
                        HUDAlertState.global.show(.error("Error cropping GIF"))
                    }
            }.store(in: &self.store.cancellables)
            
        }.any
        
        return GeometryReader { _ in
            VStack(spacing: 0) {
                EditNavView(title: "Crop GIF", leadingItem: leading, trailingItem: trailing) {
                    GIFCroppingView(croppingGIF: self.gif)
                }
                Color.clear.frame(height: 40)
                
            }
            //        .background(Color.black)
        }.transition(.opacity).animation(.default)
    }
}

struct EditContainerView_Previews: PreviewProvider {
    static let data = try! Data(contentsOf: Bundle.main.url(forResource: "1", withExtension: "gif")!)
    static var previews: some View {
        EditContainerView(gif: GIFFile(url: Bundle.main.url(forResource: "6", withExtension: "gif")!, thumbnail: nil, image: nil, asset: nil, id: "1")!, dismissBlock: {}).colorScheme(.dark)
    }
}
