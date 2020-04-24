//
//  SubscriptionView.swift
//  giffed
//
//  Created by Daniel Pourhadi on 3/13/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI


struct SubscriptionStateKey : EnvironmentKey {
    static var defaultValue: SubscriptionState = SubscriptionState.shared
    typealias Value = SubscriptionState
}

extension EnvironmentValues {
    var subscriptionState: SubscriptionState {
        get {
            return self[SubscriptionStateKey.self]
        }
        set {
            self[SubscriptionStateKey.self] = newValue
        }
    }
}

class SubscriptionState : ObservableObject {
    static let shared = SubscriptionState()
    
    @Published var active: Bool = false
    
    @Published var limited: Bool = false
    
    @Published var showUI = false
}


struct SlideOutModifier: ViewModifier {
    
    @State var dragOffset : CGFloat = 0
    
    @State var visible = false
    
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        GeometryReader { metrics in
            content
                .offset(y: self.visible ? self.dragOffset : metrics.size.height)
                
                .gesture(DragGesture().onChanged({ val in
                    self.dragOffset = val.translation.height
                }).onEnded({ val in
                    if val.predictedEndLocation.y > val.location.y + 100 {
                        self.$visible.animation(Animation.linear).wrappedValue = false
                        self.onDismiss()
                    } else {
                        
                        self.$dragOffset.animation(Animation.bouncy1).wrappedValue = 0
                    }
                }))
                .onAppear {
                    self.$visible.animation(Animation.bouncy3).wrappedValue = true
            }
            
        }
    }
    
    
}

extension View {
    
    func popIn(_ condition: Bool, delay: Double) -> some View {
        return self
            .opacity(condition ? 1 : 0)
            .scaleEffect(condition ? 1 : 0)
        .animation(Animation.bouncy1.delay(delay))

    }
    
}

struct SubscriptionSignupView: View {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass : UserInterfaceSizeClass?
//    @Environment(\.subscriptionState) var subscriptionState : SubscriptionState
  
    @ObservedObject var subscriptionState = SubscriptionState.shared

    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    
    @State var iapDetails: IAPDetails = IAPDetails.empty()
    
    @State var isActive: Bool = false
    
    @State var visible = false
    
    let onDismiss: (() -> Void)?
    
    init(_ onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        GeometryReader { metrics in
            
            ZStack {
                
                Rectangle().fill(Color.clear)
                    .onTapGesture {
                        self.dismiss()
                }
                .zIndex(0)
                
                self.conditionalBody
                    .modifier(SlideOutModifier(onDismiss: {
                        self.dismiss()
                    }))
                    .zIndex(1)
                
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
        }
        .onReceive(self.subscriptionState.$active) { (active) in
            self.isActive = active
        }
        .onAppear {
            Delayed(0.2) {
                self.visible = true
            }
        }
        
    }
    
    @ViewBuilder
    var conditionalBody: some View {
        if self.subscriptionState.active {
            self.activeContent
        } else {
            self.content
        }
    }
    
    func dismiss() {
        self.onDismiss?()
        self.subscriptionState.showUI = false
    }
    
    var activeContent: some View {
        return GeometryReader { metrics in
            
            VStack(spacing: 14) {
                Spacer()
                Stack(self.verticalSizeClass == .compact ? .horizontal : .vertical, spacing: 14) {
                    
                    
                    VStack(spacing: 14) {
                        Image(decorative: "app_icon")
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                            .padding(.bottom, 20)
                            .scaleEffect(0.9)
                            .popIn(self.visible, delay: 0)
                        
                        Text("Thank you for subscribing!").fontWeight(.medium)
                            .shadow(radius: 1)
                            
                            .popIn(self.visible, delay: 0.1)
                    }
                    
                    if self.verticalSizeClass != .compact {
                        Divider()
                            .popIn(self.visible, delay:0.15)
                    }
                    
                    Button(action: {
                        UIApplication.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!, options: [:], completionHandler: nil)
                    }, label: {
                        VStack {
                            Text("Manage your")
                            Text("subscription")
                        }
                        .shadow(radius: 1)
                            
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                            
                        .accentColor(Color.accent)
                        .padding(10)
                        .padding([.leading, .trailing], 10)
                            //                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5).opacity(0.8)) //.opacity(0.5)))
                                
                                .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 2 : metrics.size.width - 120, alignment: .center)
                        )
                    })
                    .popIn(self.visible, delay:0.2)

                    Button(action: {
                        self.dismiss()
                    }, label: {
                            Text(" Done ")
                        .shadow(radius: 1)

                        .accentColor(Color.accent)
                        .padding(10)
                        .padding([.leading, .trailing], 10)
                            //                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5).opacity(0.8)) //.opacity(0.5)))
                                
                                .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 2 : metrics.size.width - 120, alignment: .center)
                        )
                    })
                        
                        .popIn(self.visible, delay:0.3)
                    
                    
                    
                }
                .padding(40)
                .background(VisualEffectView.blur(.prominent).cornerRadius(10))
                .frame(width: metrics.size.width - 80,  alignment: .center)
                .frame(maxWidth: 400)
                Spacer()
            }
            
        }
        .frame(width: self.deviceDetails.uiIdiom == .pad ? 500 : nil)
        .onReceive(IAP.shared.$details) { (details) in
            self.iapDetails = details
        }
    }
    
    func restore() {
        HUDAlertState.global.showLoadingIndicator = true
        
        Async {
            IAP.shared.restore() { (success) in
                Async {
                    self.subscriptionState.active = success
                    
                    Delayed(0.2) {
                        HUDAlertState.global.showLoadingIndicator = false
                    }
                }
            }
        }
    }
    
    func purchase(promo: IAP.PromoID) {
        HUDAlertState.global.showLoadingIndicator = true
        
        Async {
            IAP.shared.purchase(promo: promo) { (success) in
                Async {
                    self.subscriptionState.active = success
                    
                    Delayed(0.2) {
                        HUDAlertState.global.showLoadingIndicator = false
                    }
                }
            }
        }
    }
    
    var content: some View {
        
        return GeometryReader { metrics in
            
            VStack(spacing: 14) {
                Spacer()
                Stack(self.verticalSizeClass == .compact ? .horizontal : .vertical, spacing: 14) {
                    
                    
                    VStack(spacing: 14) {
                        Image(decorative: "app_icon")
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                            .padding(.bottom, 20)
                            .scaleEffect(0.9)
                        .popIn(self.visible, delay:0)

                        
                        Text("Subscribe to enable all of Giffed's features")
                            .fontWeight(.medium)

                            .multilineTextAlignment(.center)
                            .shadow(radius: 1)

                        .popIn(self.visible, delay:0.1)

                    }
                    
                    if self.verticalSizeClass != .compact {
                        Divider()
                        .popIn(self.visible, delay:0.15)

                    }
                    
                    VStack(spacing: self.verticalSizeClass == .compact ? 8 : 14) {
                        Button(action: {
                            self.purchase(promo: .oneWeekFree)
                        }, label: {
                            VStack {
                                Text("One week free")
                                HStack {
                                    Text("then").foregroundColor(Color.primary)
                                    Text("\(self.iapDetails.monthlyPriceString) / month").bold().noAnimations()
                                }
                            }
                                .shadow(radius: 1)

                            .accentColor(Color.accent)
                            .padding(10)
                            .padding([.leading, .trailing], 10)
//                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5).opacity(0.8)) //.opacity(0.5)))

                            .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 2 : metrics.size.width - 120, alignment: .center)
                            )
                        })
                            .popIn(self.visible, delay:0.2)

                        //                    Text("or")
//                        Button(action: {
//                            self.purchase(promo: .oneYear)
//                        }, label: {
//                            VStack {
//                                Text("\(self.iapDetails.yearlyPriceString) / year").bold()
//                            }
//                            .accentColor(Color.accent)
//                            .padding(10)
//                            .padding([.leading, .trailing], 10)
//                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
//                            .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 2 : metrics.size.width - 120, alignment: .center)
//                            )
//                        })
//                            .shadow(radius: 2)
                        
                        //                    Text("or")
                        Button(action: {
                            self.dismiss()
                        }, label: {
                            VStack(spacing:12) {
                                Text("Try for free")
                                Text("Saving and cloud features disabled").foregroundColor(Color.primary)
                                    .minimumScaleFactor(0.5)
                                    .scaleEffect(0.8)
                            }
                            .multilineTextAlignment(.center)
                                .shadow(radius: 1)

                            .accentColor(Color.accent)
                            .padding(10)
                            .padding([.leading, .trailing], 10)
//                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5).opacity(0.8)) //.opacity(0.5)))

                            .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 2 : metrics.size.width - 120, alignment: .center)
                            )
                        })
                            .popIn(self.visible, delay:0.3)

                        
                        Divider()
                        .popIn(self.visible, delay:0.35)

                        Button(action: {
                            self.restore()
                        }, label: {
                            Text("Restore Purchases").padding([.top, .leading, .trailing], 10)
                                .accentColor(Color.accent)
                        })
                            .popIn(self.visible, delay:0.4)

                    }
                }
                .padding(40)
                .background(VisualEffectView.blur(.prominent).cornerRadius(10))
                .frame(width: metrics.size.width - 80,  alignment: .center)
                .frame(maxWidth: 400)
                Spacer()
            }
            
        }
        .frame(width: self.deviceDetails.uiIdiom == .pad ? 500 : nil)
        .onReceive(IAP.shared.$details) { (details) in
            self.iapDetails = details
        }
        
        
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionSignupView().background(Color.black).accentColor(Color.white)
    }
}
