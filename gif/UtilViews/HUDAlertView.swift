//
//  HUDAlertView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/29/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import Combine

struct FallModifier: ViewModifier {
    
    let active: Bool
    
    func body(content: _ViewModifier_Content<FallModifier>) -> AnyView {
        GeometryReader { metrics in
            content.drawingGroup().rotationEffect(.degrees(self.active ? 90 : 0), anchor: .bottomTrailing).offset(y: self.active ? metrics.size.height : 0)
            }.zIndex(10).any
    }
    
    
}


class HUDAlertState: ObservableObject {
    
    @Published var determinate = false
    
    @Published var percentComplete: Double = 0
//        {
//        didSet {
//            guard percentComplete != oldValue else { return }
//            if self.percentComplete != 0 {
//                self.determinate = true
//            } else {
//                self.determinate = false
//            }
//        }
//    }
    
    @Published var hudAlertMessage: [HUDAlertMessage] = []

    @Published var showLoadingIndicator: Bool = false
//        {
//           didSet {
//               if self.showLoadingIndicator != oldValue {
//                self.loadingMessage = (nil, nil)
//                self.percentComplete = 0
//               }
//           }
//       }
    
    @Published var loadingMessage: (String?, (()->Void)?) = (nil, nil)

    var loadingIndicatorStartTime: Date = Date()
    
    static let global = HUDAlertState()
    
    @Published var hudVisible = false
    
    func show(_ message: HUDAlertMessage) {
        self.hudAlertMessage = [message]
    }
    
    var cancellables = Set<AnyCancellable>()
    
    init() {
        self.$showLoadingIndicator.removeDuplicates().sink { [unowned self] showing in
            if !showing {
                self.loadingMessage = (nil, nil)
                self.percentComplete = 0
            }
        }.store(in: &self.cancellables)
        
        self.$percentComplete.removeDuplicates().sink { [unowned self] percent in
            if percent != 0 {
                self.determinate = true
            } else {
                self.determinate = false
            }
        }.store(in: &self.cancellables)
    }
}

struct HUDTransitions {
    
    static var insertion: AnyTransition {
        AnyTransition.scale(scale: 0.5)
        .combined(with: .opacity)
    }
    
    static var removal: AnyTransition {
        AnyTransition.scale(scale: 1.2)
        .combined(with: .opacity)
    }
    
    static var fallModifier: AnyTransition {
        AnyTransition.modifier(active: FallModifier(active: true), identity: FallModifier(active: false))
    }
    
    static var bounceInFallOut: AnyTransition {
        AnyTransition.asymmetric(insertion: insertion, removal: fallModifier)
        .animation(Animation.spring(dampingFraction: 0.5))
    }
    
    static var inAndOut: AnyTransition {
        AnyTransition.asymmetric(insertion: insertion, removal: removal)
            .animation(Animation.spring(dampingFraction: 0.5))
    }
    
    static var inOnly: AnyTransition {
        AnyTransition.asymmetric(insertion: insertion, removal: AnyTransition.identity)
        .animation(Animation.spring(dampingFraction: 0.5))
    }
    
    
}

struct HUDAlertMessage {
    init(text: String, symbolName: String, cancelAction: (() -> Void)? = nil) {
        self.text = text
        self.symbolName = symbolName
        self.cancelAction = cancelAction
    }
    
    let text: String
    let symbolName: String
    
    let cancelAction: (() -> Void)?
    
    static let empty = HUDAlertMessage(text: "", symbolName: "questionmark")
    
    static func error(_ message: String) -> HUDAlertMessage {
        return HUDAlertMessage(text: message, symbolName: "xmark")
    }
        
    static func thumbdown(_ message: String) -> HUDAlertMessage {
        return HUDAlertMessage(text: message, symbolName: "hand.thumbsdown.fill")
    }
    
    static func thumbup(_ message: String) -> HUDAlertMessage {
        return HUDAlertMessage(text: message, symbolName: "hand.thumbsup.fill")
    }
}

struct HUDContainer<Content>: View where Content : View {
    
    let content: Content
        
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        
        GeometryReader { metrics in
            self.content
                .padding(30)
                .background(VisualEffectView.blur(.prominent))
                .cornerRadius(10)
                .frame(width: metrics.size.width, height: metrics.size.height, alignment: .center)
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 1)
        }.compositingGroup()
    }

}


struct HUDMessageView: View {
    
    var message: HUDAlertMessage
    
    var body: some View {
        VStack(spacing:20) {
            Image.symbol(self.message.symbolName, .init(pointSize: 40))?
                .renderingMode(.template)
                .foregroundColor(Color.accent)
            
            Text(self.message.text)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .font(.title)
                .padding([.leading, .trailing], 20)
                .lineLimit(2)
                .foregroundColor(Color.secondary)
            
            if message.cancelAction != nil {
                Button(action: {
                    self.message.cancelAction?()
                }, label: {
                    Text("Cancel").padding(20)
                })
            }
        }
    }
}

struct HUDLoadingView: View {
    
    @ObservedObject var hudAlertState = HUDAlertState.global
    
    var body: some View {
        VStack {
            LoadingCircleView(progress: self.hudAlertState.determinate ? self.hudAlertState.percentComplete : nil).frame(width: 60, height: 60)
//        ActivityIndicatorView()
            .scaleEffect(1.3)
            .padding(30)
        
            if self.hudAlertState.loadingMessage.0 != nil {
                Text(self.hudAlertState.loadingMessage.0!).foregroundColor(Color.secondary)
            }
            
            if self.hudAlertState.loadingMessage.1 != nil {
                Button(action: {
                    self.hudAlertState.loadingMessage.1?()
                }, label: { Text("Cancel").padding(20) })
            }
        }
        .animation(Animation.default)
        .accentColor(Color.accent)
        .foregroundColor(Color.accent)

    }
}

//struct HUDTestView: View {
//    let message = HUDAlertMessage(text: "GIF Added!", symbolName: "checkmark")
//    @State var showHUD: Bool = false
//
//    var body: some View {
//        GeometryReader { metrics in
//            Group {
//                if self.showHUD {
//                    HUDAlertView(alertMessage: self.message)
//
//                        .onAppear {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                self.showHUD.toggle()
//                            }
//                    }
//                }
//
//
//            Button(action: {
//                self.showHUD.toggle()
//            }, label: { Text("Toggle") } )
//                .frame(width: metrics.size.width, height: metrics.size.height, alignment: .bottom)
//            }
//        }
//    }
//}
//
//
//struct HUDAlertView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        HUDTestView()
//    }
//}


struct WithHUDModifier: ViewModifier {
    let hudAlertState: HUDAlertState
    
    @State var showHUD = false
    @State var showHUDLoading = false
    @State var showHUDMessage = false
    
    func body(content: _ViewModifier_Content<WithHUDModifier>) -> some View {
        ZStack {
            content
                .overlay(Color.background.opacity(self.showHUD ? 0.3 : 0).animation(Animation.default).edgesIgnoringSafeArea(.all))
                .zIndex(4)
            
            if self.showHUD {
                HUDContainer {
                    ZStack {
                        HUDMessageView(message: self.hudAlertState.hudAlertMessage.first ?? HUDAlertMessage.empty)
                            .opacity(self.showHUDMessage ? 1 : 0.00)
                            .scaleEffect(self.showHUDMessage ? 1 : 0.5)
                            .frame(width: self.showHUDMessage ? nil : 120, height: self.showHUDMessage ? nil : 120)
                        .animation(Animation.spring(dampingFraction: 0.5))
                            .zIndex(100)
                        .transition(AnyTransition.opacity.animation(Animation.default))

                        HUDLoadingView()
                            .opacity(self.showHUDLoading ? 1 : 0)
                            .scaleEffect(self.showHUDLoading ? 1 : 0.5)
                            .animation(Animation.spring(dampingFraction: 0.5))
                            .zIndex(101)
                            .transition(AnyTransition.opacity.animation(Animation.default))
                    }
                }
                    .animation(Animation.spring(dampingFraction: 0.5))

                .onAppear(perform: {
                    self.hudAlertState.hudVisible = true
                })
                
                .onDisappear(perform: {
                    DispatchQueue.main.async {
                        self.hudAlertState.hudAlertMessage = []
                        self.hudAlertState.showLoadingIndicator = false
                        self.hudAlertState.hudVisible = false
                    }
                }).transition(HUDTransitions.inAndOut)
                    .zIndex(5)
            }
        }.onReceive(self.hudAlertState.$hudAlertMessage
            .combineLatest(self.hudAlertState.$showLoadingIndicator).delay(for: 0.1, scheduler: DispatchQueue.main)) { out in
            
            let loadingViewDelay: Double = 2.0
            //            self.hudMessage = out.0.first ?? HUDAlertMessage.empty
            
            if !self.showHUD, out.0.count == 0, !out.1 {
                self.showHUDLoading = false
                self.showHUDMessage = false
                return
            }
            
            if out.0.count > 0 {
                self.showHUD = true
                
                if self.showHUDLoading {
                    let timeDiff = abs(self.hudAlertState.loadingIndicatorStartTime.timeIntervalSinceNow)
                    if timeDiff < loadingViewDelay {
                        Delayed((loadingViewDelay - timeDiff) + 0.1) {
                            self.$showHUDLoading.animation().wrappedValue = false
                            self.hudAlertState.showLoadingIndicator = false
                            
                            Delayed(0.7) {
                                self.$showHUDMessage.animation(.spring(dampingFraction: 0.6)).wrappedValue = true
                                Delayed(2) {
                                    self.showHUD = false
                                }
                            }
                        }
                    } else {
                        self.showHUDLoading = false
                        self.$showHUDLoading.animation(Animation.default).wrappedValue = false
                        self.hudAlertState.showLoadingIndicator = false
                        
                        Delayed(0.7) {
                            self.showHUDMessage = true
                            self.$showHUDMessage.animation(.spring(dampingFraction: 0.6)).wrappedValue = true
                            Delayed(2) {
                                self.showHUD = false
                            }
                        }
                    }
                }
                
            } else {
                if out.1 {
                    if !self.showHUDLoading {
                        self.hudAlertState.loadingIndicatorStartTime = Date()
                    }
                    
                    self.showHUDLoading = true
                    self.showHUD = true
                } else {
                    if self.showHUDLoading, !self.showHUDMessage {
                        let timeDiff = abs(self.hudAlertState.loadingIndicatorStartTime.timeIntervalSinceNow)
                        if timeDiff < loadingViewDelay {
                            Delayed((loadingViewDelay - timeDiff) + 0.1) {
                                self.showHUD = false
                            }
                        } else {
                            Delayed(0.1) {
                                self.showHUD = false
                            }
                        }
                    } else if !self.showHUDMessage {
                        Delayed(0.1) {
                            self.showHUD = false
                        }
                    }
                }
            }
        }
        
        

    }
}
