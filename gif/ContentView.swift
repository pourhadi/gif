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

enum ActivePopover {
    case videoPicker
    case gifSettings
    case preview
    case docBrowser
}

struct TopControlView: View {
    
    @Binding var presentedPopover: Bool
    @Binding var activePopover: ActivePopover
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
    @State var presentedPopover = false
    
    var videoSubject = CurrentValueSubject<Video?, Never>(nil)
    @State var activePopover: ActivePopover = .videoPicker
    
    var body: some View {
        ZStack {
            self.getMainMenu()
            
            if self.activeView == .editor {
                self.getEditor().transition(.slide)
            }
            
        }.popover(isPresented: $presentedPopover) {
            self.getPopover()
        }.onReceive(self.globalState.video.gifConfig.$visible) { (s) in
            self.activePopover = .gifSettings
            self.presentedPopover = s
        }
    }
    
    func getPopover() -> some View {
        switch self.activePopover {
        case .videoPicker:
            return ImagePickerController(presentedVideoPicker: self.$presentedPopover,
                                         video: self.$globalState.video).onDisappear {
                if self.globalState.video.isValid {
                    withAnimation(Animation.default.delay(0.4)) {
                        self.activeView = .editor
                    }
                }
            }.asAny
        case .gifSettings:
            return GifSettingsView().environmentObject(self.globalState.video.gifConfig).onDisappear {
                self.globalState.video.gifConfig.visible = false
            }.asAny
        case .preview:
            return PreviewModal(presentedPopover: self.$presentedPopover).environmentObject(self.globalState.gifGenerator).asAny
            case .docBrowser:
                return DocumentBrowserView().asAny
        }
        
    }
    
    func getEditor() -> some View {
        return GeometryReader { metrics in
            VStack(spacing:4) {
                if !(self.globalState.visualState.compact) {
                    TopControlView(presentedPopover: self.$presentedPopover,
                                   activePopover: self.$activePopover,
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
    
    
    func getMainMenu() -> some View {
        return VStack {
            Spacer()
            Button(action: {
                self.activePopover = .videoPicker
                if !self.presentedPopover {
                    self.presentedPopover = true
                }
            }, label: { return Text("Get Video") } )
            Spacer()
            Button(action: {
                self.activePopover = .docBrowser
                if !self.presentedPopover {
                    self.presentedPopover = true
                }
            }, label: { return Text("Import Video") } )
            Spacer()
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(Video.preview)
    }
}
