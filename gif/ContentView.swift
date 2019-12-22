//
//  ContentView.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import Combine

enum ActiveView: Hashable {
    case pickVideo
    case editor
}

enum ActivePopover: Identifiable {
    var id: ActivePopover {
        return self
    }
    
    case videoPicker
    case gifSettings
    case preview
    case docBrowser
}

struct TopControlView: View {
    
    @Binding var activePopover: ActivePopover?
    @Binding var activeView: ActiveView
    @Binding var ready: Bool
    
    var body: some View {
        VStack {
            Spacer(minLength: 40)
            HStack {
                Button(action: {
                    withAnimation {
                        self.activeView = .pickVideo
                    }
                }, label: { Text("Cancel") } )
                Spacer()
                Button(action: {
                    
                }, label: { Text("Create GIF") } ).disabled(!self.ready)
            }.padding(.bottom, 10)
        }.padding([.leading, .trailing], 20)
        
    }
}

struct VisualState {
    
    var compact = false
    
    init(_ compact: Bool = false) {
        self.compact = compact
    }
}

class GlobalState: ObservableObject {
    
    @Published var video: Video = Video.empty()
    @Published var visualState = VisualState()
    @Published var gallery = Gallery()
    var gifGenerator: GifGenerator = GifGenerator(video: Video.empty())

    var cancellables = Set<AnyCancellable>()
    
    let deviceDetails = DeviceDetails()
    
    init() {
        $video.map {
            GifGenerator(video: $0)
        }
        .assign(to: \.gifGenerator, on: self)
        .store(in: &self.cancellables)
        
        deviceDetails.$orientation.map {
            VisualState($0 == .landscape && self.deviceDetails.uiIdiom == .phone)
        }
        .assign(to: \.visualState, on: self)
        .store(in: &self.cancellables)
    }
}


struct ContentView: View {
    @State var activeView: ActiveView = .pickVideo
    @EnvironmentObject var globalState: GlobalState
    
    var videoSubject = CurrentValueSubject<Video?, Never>(nil)
    @State var activePopover: ActivePopover? = nil
    
    var body: some View {
        ZStack {
            self.getMain()
            
            if self.activeView == .editor {
                self.getEditor().transition(.slide)
            }
            
        }.popover(isPresented: Binding<Bool>(get: { () -> Bool in
            return self.activePopover != nil
        }, set: { (active) in
            if !active {
                self.activePopover = nil
            }
        }), content: {
            self.getPopover()
        }).onReceive(self.globalState.video.gifConfig.$visible) { (s) in
            self.activePopover = s ? .gifSettings : nil
        }.onReceive(self.globalState.$video) { (v) in
            if self.activePopover == .videoPicker {
                if v.isValid {
                    self.activePopover = nil
                }
            }
        }
    }
    
    func getPopover() -> AnyView {
        switch self.activePopover {
        case .videoPicker:
            return ImagePickerController(video: self.$globalState.video).onDisappear {
                self.activePopover = nil
                if self.globalState.video.isValid {
                    withAnimation(Animation.default.delay(0.4)) {
                        self.activeView = .editor
                    }
                }
            }.asAny
        case .gifSettings:
            return GifSettingsView().environmentObject(self.globalState.video.gifConfig).onDisappear {
                self.activePopover = nil
                self.globalState.video.gifConfig.visible = false
            }.asAny
        case .preview:
            return PreviewModal(activePopover: self.$activePopover).environmentObject(self.globalState.gifGenerator).asAny
            case .docBrowser:
                return DocumentBrowserView().asAny
        case .none:
            return EmptyView().asAny
        }
        
    }
    
    func getEditor() -> some View {
        return GeometryReader { metrics in
            VStack(spacing:4) {
                if !(self.globalState.visualState.compact) {
                    TopControlView(activePopover: self.$activePopover,
                                   activeView: self.$activeView,
                                   ready: self.$globalState.video.ready)
                        .background(Color.background)
                        .frame(height:80)
                }
                EditorView(gifGenerator: self.$globalState.gifGenerator,
                           visualState: self.$globalState.visualState)
                
                
            }.edgesIgnoringSafeArea(self.globalState.visualState.compact ? [.leading, .trailing, .top] : [.top])
                .environmentObject(self.globalState.video)
                .background(Color.background)
        }
    }
    
    
    func getMain() -> some View {
        return GalleryContainer(activePopover: self.$activePopover).environmentObject(self.globalState.gallery)
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(Video.preview)
    }
}
