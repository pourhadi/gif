//
//  SubscriptionView.swift
//  giffed
//
//  Created by Daniel Pourhadi on 3/13/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI
import UIKit
import SnapKit


class FeaturePager : UIView, UIScrollViewDelegate {
    
    let features: [String]
    
    let pageControl = UIPageControl()
    
    let scrollView = UIScrollView()
    
    var pagerTimer: Timer?
    
    var heightConstraint: NSLayoutConstraint?
    
    let updateHeightBlock: (CGFloat) -> Void
    
    init(_ features: [String], updateHeightBlock: @escaping (CGFloat) -> Void) {
        self.features = features
        self.updateHeightBlock = updateHeightBlock
        super.init(frame: CGRect.zero)
        
        pageControl.numberOfPages = features.count
        
        addSubview(pageControl)
        addSubview(scrollView)
        
        scrollView.isPagingEnabled = true
        
        scrollView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
            
        }
        
        heightConstraint = NSLayoutConstraint(item: scrollView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        heightConstraint?.isActive = true
        
        pageControl.snp.makeConstraints { (make) in
            make.top.equalTo(scrollView.snp.bottom).offset(10)
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.lessThanOrEqualTo(40).priority(.required)
        }
        
        scrollView.delegate = self
        
        var lastLabel: UIView?
        for feature in features {
            
            let labelContainer = UIView()
            let label = UILabel()
            label.text = feature
            label.textAlignment = .center
            label.textColor = _accent
            label.numberOfLines = 0
            labelContainer.addSubview(label)
            scrollView.addSubview(labelContainer)
            labelContainer.snp.makeConstraints { (make) in
                make.centerY.equalToSuperview()
                make.width.equalTo(self)
                if let last = lastLabel {
                    make.leading.equalTo(last.snp.trailing)
                }
                
                if feature == features.last {
                    make.trailing.equalToSuperview()
                }
                
                if feature == features.first {
                    make.leading.equalToSuperview()
                }
            }
            
            label.snp.makeConstraints { (make) in
                make.edges.equalToSuperview().inset(10)
            }
            
            lastLabel = labelContainer
        }
        
        self.setTimer()
    }
    
    var heightSet = false
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var largestHeight: CGFloat = 0.0
        
        for view in scrollView.subviews {
            if view.frame.size.height > largestHeight {
                largestHeight = view.frame.size.height
            }
        }
        
        
        let newHeight = largestHeight
        if heightConstraint?.constant != newHeight {
            self.heightSet = true

            heightConstraint?.constant = newHeight
            self.updateConstraintsIfNeeded()
            self.setNeedsLayout()
            
            self.updateHeightBlock(newHeight + pageControl.frame.size.height)
        }
        
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pagerTimer?.invalidate()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(scrollView.contentOffset.x / self.frame.size.width)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setTimer()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        setTimer()
    }
    
    func setTimer() {
        pagerTimer?.invalidate()
        
        pagerTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false, block: { [weak self] (_) in
            guard let weakSelf = self else { return }
            
            var newPage = weakSelf.pageControl.currentPage + 1
            if newPage == weakSelf.features.count {
                newPage = 0
            }
            
            weakSelf.goTo(newPage)
        })
    }
    
    func goTo(_ page: Int) {
        pagerTimer?.invalidate()
        
        let x = self.frame.width * CGFloat(page)
        scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
        
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


struct FeaturePagerView : UIViewRepresentable {
    
    let features: [String]
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> FeaturePager {
        return FeaturePager(features, updateHeightBlock: { height in
            self.height = height
        })
    }
    
    func updateUIView(_ uiView: FeaturePager, context: Context) {
        
    }
    
    typealias UIViewType = FeaturePager
    
    
    
    
}

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

//class SubscriptionController: UIHostingController<ContainedSubscriptionSignupView> {
//
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        return .portrait
//    }
//
//    override var shouldAutorotate: Bool { return false }
//}
//
//struct _SubscriptionSignupView : UIViewControllerRepresentable {
//    let onDismiss: (() -> Void)?
//    init(_ onDismiss: (() -> Void)? = nil) {
//        self.onDismiss = onDismiss
//    }
//    func makeUIViewController(context: Context) -> SubscriptionController {
//        return SubscriptionController(rootView: ContainedSubscriptionSignupView(onDismiss))
//    }
//
//    func updateUIViewController(_ uiViewController: SubscriptionController, context: Context) {
//        uiViewController.view.backgroundColor = UIColor.clear
//        uiViewController.view.isOpaque = false
//    }
//
//    typealias UIViewControllerType = SubscriptionController
//}


struct SubscriptionSignupView: View {
    
//    var verticalSizeClass = UserInterfaceSizeClass.regular
    
    @Environment(\.verticalSizeClass) var verticalSizeClass : UserInterfaceSizeClass?
//    @Environment(\.subscriptionState) var subscriptionState : SubscriptionState
  
    @ObservedObject var subscriptionState = SubscriptionState.shared

    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    
    @State var iapDetails: IAPDetails = IAPDetails.empty()
    
    @State var isActive: Bool = false
    
    @State var visible = false
    
    @State var featureScrollerHeight: CGFloat = 0
    
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
            
            GlobalState.instance.disableRotation = true
            Delayed(0.2) {
                self.visible = true
            }
        }
        
        .onDisappear {
            GlobalState.instance.disableRotation = false
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
    
    var featureView : some View {
        FeaturePagerView(features: ["Sync your GIFs with iCloud Drive",
        "Create public links to your GIFs for easy sharing anywhere",
        "View your GIFs on your Apple Watch",
        "Create GIFs from your online videos"], height: self.$featureScrollerHeight)
            .frame(height: self.featureScrollerHeight)
    }
    
    var content: some View {
        
        return GeometryReader { metrics in
            
            VStack(spacing: 14) {
                Spacer()
                Stack(self.verticalSizeClass == .compact ? .horizontal : .vertical, spacing: 14) {
                    
                    
                    VStack(spacing: 10) {
                        Image(decorative: "app_icon")
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                            //                            .padding(.bottom, 20)
                            .scaleEffect(0.8)
                            //                            .frame(width: 80)
                            .popIn(self.visible, delay:0)
                        
                        
                        Text("Subscribe to unlock saving, and to enable all of Giffed's features:")
                            .fontWeight(.medium)
                            
                            .multilineTextAlignment(.center)
                            
                            .popIn(self.visible, delay:0.1)
                        
                        
                        if self.verticalSizeClass != .compact {
                            Divider()
                                .popIn(self.visible, delay:0.12)
                            self.featureView
                            .popIn(self.visible, delay: 0.13)

                        }
                        
                    }
                    
                    
                    
                    if self.verticalSizeClass != .compact {
                        Divider()
                        .popIn(self.visible, delay:0.15)

                    }
                    
                    VStack(spacing: self.verticalSizeClass == .compact ? 8 : 14) {
                        if self.verticalSizeClass == .compact {
                            self.featureView
                            .popIn(self.visible, delay:0.14)
                            Divider()
                            .popIn(self.visible, delay:0.17)

                        }
                        
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

                            .accentColor(Color.accent)
                            .padding(10)
                            .padding([.leading, .trailing], 10)
//                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5).opacity(0.8)) //.opacity(0.5)))

                            .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 3 : metrics.size.width - 120, alignment: .center)
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

                            .accentColor(Color.accent)
                            .padding(10)
                            .padding([.leading, .trailing], 10)
//                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.3))
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.5).opacity(0.8)) //.opacity(0.5)))

                            .frame(width: self.verticalSizeClass == .compact ? metrics.size.width / 3 : metrics.size.width - 120, alignment: .center)
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
