//
//  EditorView.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import Combine
import AVFoundation

class EditorStore {
    static var players = [PlayerType: AVPlayer]()
    
    static var playerObservers = [PlayerType : Any]()
    
    static func reset() {
        for (key, val) in self.players {
            if let observer = self.playerObservers[key] {
                val.removeTimeObserver(observer)
            }
        }
        
        self.players.removeAll()
        self.playerObservers.removeAll()
    }
}

struct EditorStoreKey: EnvironmentKey {
    static let defaultValue: EditorStore = EditorStore()
}

extension EnvironmentValues {
    var editorStore: EditorStore {
        get {
            return self[EditorStoreKey.self]
        }
        set {
            self[EditorStoreKey.self] = newValue
        }
    }
}


enum EditorSheet: Identifiable {
    var id: EditorSheet { return self }
    case settings
    case crop
    
}

struct EditorView<Player, Generator>: View where Player : PlayerView, Generator : GifGenerator {
    
    @Environment(\.keyboardManager) var keyboardManager: KeyboardManager
    @Environment(\.editorStore) var editorStore: EditorStore
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    let controlsState = ControlsState()
    
    @EnvironmentObject var context: EditingContext<Generator>
                
    @State var playersHeight: CGFloat? = nil
    
    @State var dummyPlayable = false
    
    @State var showingCrop = false
    
    @State var activeSheet: EditorSheet? = nil
    
    @State var activePopover: EditorSheet? = nil
    
    @State var keyboardVisible = false
        
    var body: some View {
        GeometryReader { metrics in
                VStack(spacing:0) {
                    PlayerContainerView<Player, Generator>(controlsState: self.controlsState,
                                        previewing: self.$context.playState.previewing,
                                        playersHeight: self.$playersHeight,
                                        editorHeight: metrics.size.height)
                        .environmentObject(self.context).frame(height: self.deviceDetails.compact ? nil : self.playersHeight)

                    
                    TimelineView<Generator>(selection: self.$context.gifConfig.selection,
                                            playState: self.$context.playState)
                    .frame(minHeight: metrics.size.height / 3)
                    
                    ControlsView(selection: self.$context.gifConfig.selection,
                                 playState: self.$context.playState,
                                 context: self.context)
                    
                }
                .modifier(BlurredPlayerBackgroundModifier<Player>(item: self.context.item, playState: self.$context.playState))
                .zIndex(1)
                .overlayPreferenceValue(EditorPreferencesKey.self) { (val: EditorPreferences) in
                    GeometryReader { metrics in
                        self.getTextEditingOverlay(metrics: metrics, values: val)
                    }
            }
            
        }
        .onDisappear(perform: {
            ContextStore.context = nil
            EditorStore.reset()
        })
        .popover(item: self.$activePopover, content: { sheet  in
            GifSettingsView().environmentObject(self.context.gifConfig)

        })
        .sheet(item: self.$activeSheet) { sheet in
            Group {
                if sheet == .settings {
                    GifSettingsView().environmentObject(self.context.gifConfig)
                }
                
                if sheet == .crop {
                    PreviewCroppingView<Generator>().environmentObject(self.context).onDisappear {
                        self.context.cropState.visible = false
                    }
                }
            }
        }.onReceive(GlobalPublishers.default.readyToCrop) { cropContext in
            self.activeSheet = .crop
        }.onReceive(self.context.gifConfig.$visible) { (visible) in
                if visible {
                    self.activeSheet = .settings
                } else {
                    self.activeSheet = nil
                }
        }.onReceive(self.keyboardManager.$keyboardVisible) { (visible) in
            self.keyboardVisible = visible
        }
        
    }
    
    func getTextEditingOverlay(metrics: GeometryProxy, values: EditorPreferences) -> some View {
        let mainBounds = values.mainPlayerBounds != nil ? metrics[values.mainPlayerBounds!] : CGRect.zero
        
        return Group {
            if self.context.mode == .text && self.keyboardVisible {
                VStack {
                    Spacer(minLength: mainBounds.size.height)
                    ZStack {
                        Rectangle().fill(Color.background.opacity(0.95)).zIndex(0)
                        VStack { TextFormatView().environmentObject(self.context.textFormat).zIndex(1).frame(height: 50)
                            Spacer()
                        }
                    }.frame(alignment: .top)
                }.transition(AnyTransition.opacity.animation(Animation.default))
            }
        }
    }

}


struct BlurredPlayerBackgroundModifier<Player>: ViewModifier where Player : PlayerView {
    
    let item: Editable
    @Binding var playState: PlayState
    @State var playing = false
    
    func body(content: _ViewModifier_Content<BlurredPlayerBackgroundModifier>) -> some View {
        return content.background(BlurredPlayerView(playerView:
            
            Player(item: self.item, timestamp: self.$playState.currentPlayhead, playing: self.$playing, contentMode: .fill, playerType: .playhead)
            
            
            , effect: .init(style: .systemThickMaterial))
            .brightness(-0.05)
//            .saturation(1.5)
            .edgesIgnoringSafeArea(.all))
    }
}

struct EditorView_Previews: PreviewProvider {
    
    static var previews: some View {
        GlobalPreviewView()
    }
}
