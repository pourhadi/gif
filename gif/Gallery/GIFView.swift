
import Combine
import SnapKit
import SwiftDate
import SwiftUI
import UIKit
// import FLAnimatedImage
// import YYImage




struct GIFViewTopBar: View {
    @Binding var selectedGIFs: [GIF]
    
    var body: some View {
        Group {
            VStack {
                Spacer(minLength: 40)
                HStack {
                    Button(action: {
                        withAnimation {
                            self.$selectedGIFs.animation(Animation.spring(dampingFraction: 0.7)).wrappedValue = []
                        }
                    }, label: { HStack {
                        Image.symbol("chevron.compact.left")
                        Text("GIFs")
                        } }).padding(.leading, 10)
                    Spacer()
                    Spacer()
                }.padding(.bottom, 10)
            }.background(VisualEffectView.blur(.prominent))
        }.frame(height: 80)
    }
}

struct GIFViewState {
    
    var showCrop = false
    
    var cropState: CropState? = nil
}

struct GIFView: View {
    @State var gifViewState = GIFViewState()
    
    @State var croppingGIF: GIF?
    
    @ObservedObject var gallery: Gallery
    
    @Binding var removeGIFView: Bool
    
    @ObservedObject var transitionContext: TransitionContext
    
    @Binding var selectedGIFs: [GIF]
    
    @State var animating = true
    
    @State var opacity: Double = 0
    
    let toolbarBuilder: (_ metrics: GeometryProxy, _ background: AnyView) -> AnyView
    
    @State var disableScrolling = false
    
    @State var showSpeed = false
    
    @State var speed: Double = 1
    
    @State var transitionOut = false
    
    @State var editingVideo: Video?
    
    @State var editingGIF: GIF?
    
    @State private var visualState = VisualState()
    
    @State var showSpeedPopover = false
    
    @Binding var currentTransform: CGAffineTransform
    
    @Binding var imageOffset: CGPoint
    
    @ObservedObject var transitionAnimation: TransitionAnimationContext
    
    var title: String {
        if let gif = selectedGIFs.first {
            if let date = gif.creationDate {
                return ("\(date.monthName(.default)) \(date.day)")
            }
            
            let count = self.gallery.gifs.count
            if let index = self.gallery.gifs.firstIndex(of: gif) {
                return ("\(index + 1) of \(count)")
            }
        }
        
        return ""
    }
    
    @State var dragTranslation = CGSize.zero
    
    func scroller() -> some View {
        GIFImageScrollerView(selectedGIFs: self.$selectedGIFs, disableScrolling: self.$disableScrolling, disableAnimation: self.$transitionContext.disableAnimation, items: self.$gallery.gifs, opacity: self.$opacity, speed: self.$speed, currenTransform: self.$currentTransform, imageOffset: self.$imageOffset, animationInProgress: self.$transitionAnimation.isInProgress, animationComplete: self.$transitionAnimation.isComplete, contentMode: self.transitionAnimation.isInProgress ? .fit : .fill)
            .onTapGesture {
                withAnimation {
                    self.transitionContext.fullscreen.toggle()
                }
        }
    }
    
    func gifImageScroller(metrics: GeometryProxy) -> some View {
        
        var bounds = (self.transitionAnimation.boundsAnchor != nil ? metrics[self.transitionAnimation.boundsAnchor!] : CGRect.zero)
        
        if self.transitionAnimation.isInProgress {
            print("is in progress")
            bounds.size.width = metrics.size.width
            bounds.size.height = metrics.size.height
            bounds.origin = metrics.frame(in: .global).origin
            bounds = bounds.applying(self.transitionAnimation.isInProgress ? self.currentTransform : .identity)
            
//            if self.transitionAnimation.isComplete {
//                bounds.origin.x += self.imageOffset.x
//                bounds.origin.y += self.imageOffset.y
//            }
        } else {
            print("not in progress")
        }
        
        let dragging = !self.currentTransform.isIdentity
        
        return
            
                
//                self.scroller()
                
                AnimatedGIFView(gif: self.transitionAnimation.activeGIF, animated: self.$transitionAnimation.isComplete, contentMode: self.transitionAnimation.isInProgress ? .fit : .fill)
                    .aspectRatio(contentMode: self.transitionAnimation.isInProgress ? .fit : .fill)
                    .frame(width: bounds.size.width, height: bounds.size.height)
                    .mask(Rectangle().size(width: bounds.size.width,
                                           height:  bounds.size.height))
                    .position(bounds.center)
                    .opacity(self.transitionAnimation.isComplete && !dragging ? 0 : 1)
//                    .transformEffect(self.transitionAnimation.isComplete ? CGAffineTransform.init(translationX: self.imageOffset.x, y: 0) : .identity)
                    .edgesIgnoringSafeArea(self.transitionAnimation.isInProgress ? [.top, .bottom] : [])

                    .onAppear {
                        withAnimation(Animation.bouncy1) {
                            self.transitionAnimation.isInProgress = true
                        }
                        
                        Delayed(0.4) {
                            self.transitionAnimation.isComplete = true
                        }
                        
                        Delayed(0.5) {
                            self.transitionContext.disableAnimation = false

                        }
                        self.$opacity.animation(Animation.easeOut(duration: 0.3)).wrappedValue = 1
                    }
//                .drawingGroup()
                .clipped()

                
                
        //.background(Color.black.opacity(self.$opacity.animation().wrappedValue))
        
    }
    
    var navLeading: AnyView { Button(action: {
        withAnimation {
            self.$selectedGIFs.animation(Animation.spring(dampingFraction: 0.7)).wrappedValue = []
        }
    }, label: { HStack {
        Image.symbol("chevron.compact.left")
        Text("GIFs")
        } }).padding(.leading, 10).any }
    
    var navTrailing:AnyView { self.gallery.viewConfig.trailingNavBarItem(self.gallery, self.$selectedGIFs).any }
    
    var body: some View {
        GeometryReader { containerMetrics in
            ZStack {
                self.gifImageScroller(metrics: containerMetrics).zIndex(0)

                CustomNavView(title: self.title, leadingItem: self.navLeading, trailingItem: self.navTrailing, navBarVisible: !self.transitionContext.fullscreen) {
                    
                
//                NavigationView {
                    GeometryReader { metrics in
                        
                        Group {
//                                self.gifImageScroller(metrics: metrics).zIndex(0)

                            self.scroller()
                            .frame(height: metrics.size.height + metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom)
                                .offset(y: -(metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom))
                            
//                                GIFImageScrollerView(selectedGIFs: self.$selectedGIFs, disableScrolling: self.$disableScrolling, disableAnimation: self.$transitionContext.disableAnimation, items: self.$gallery.gifs, opacity: self.$opacity, speed: self.$speed, currenTransform: self.$currentTransform, imageOffset: self.$imageOffset, animationInProgress: self.$transitionAnimation.isInProgress)
//                                    .onTapGesture {
//                                        withAnimation {
//                                            self.transitionContext.fullscreen.toggle()
//                                        }
//                                }

                                
//                                if !self.transitionContext.fullscreen {
                                    self.getToolbar(with: metrics)
                                        
//                                                                    .edgesIgnoringSafeArea([.bottom])
                                        
                                        .opacity(self.opacity)
                                        .offset(x: 0, y: self.transitionContext.fullscreen ? (60 + metrics.safeAreaInsets.bottom) : 0)

//                                        .transition(.opacity)
//                                }
                            
                        }
                        
                    }
                        .background(Color.clear)
                    .navigationBarHidden(self.transitionContext.fullscreen)
                    .navigationBarTitle(Text(self.title), displayMode: NavigationBarItem.TitleDisplayMode.inline)
                    .navigationBarItems(leading: Button(action: {
                        withAnimation {
                            self.$selectedGIFs.animation(Animation.spring(dampingFraction: 0.7)).wrappedValue = []
                        }
                    }, label: { HStack {
                        Image.symbol("chevron.compact.left")
                        Text("GIFs")
                        } }).padding(.leading, 10), trailing: self.gallery.viewConfig.trailingNavBarItem(self.gallery, self.$selectedGIFs))
                }
                
                .navigationViewStyle(StackNavigationViewStyle())
                .statusBar(hidden: self.transitionContext.fullscreen)
                .onReceive(self.gallery.$editingGIF) { (gif) in
                    self.editingGIF = gif
                    
                    Delayed(0.2) {
                        self.editingGIF?.editingContext.gifConfig.selection.startTime = 0
                        self.editingGIF?.editingContext.gifConfig.selection.endTime = 1
                        
                    }
                    
                }
//                .opacity(self.opacity)
                .zIndex(1)
                
            }
            
        }
        .background((self.transitionAnimation.isInProgress ?  Color.black.opacity(self.opacity) : Color.clear).edgesIgnoringSafeArea([.top, .bottom]))
    }
    
    func getPopover(metrics: GeometryProxy, values: PopoverPrefs) -> some View {
        
        let origin = values.origin != nil ? metrics[values.origin!] : CGPoint.zero
        
        return Group {
            
            if self.showSpeedPopover {
                
                PopoverView(origin: origin, edge: .bottom, closeAction: {
                    
                }) {
                    Slider(value: self.$speed, in: 0.25...2)
                }.zIndex(1)
                    .alignmentGuide(VerticalAlignment.center) { (d) -> CGFloat in
                        d.height
                }
                .shadow(radius: 5)
                    //                .frame(width: metrics.size.width, height: metrics.size.height, alignment: .top)
                    .offset(y: origin.y)
                
            }
            
        }
    }
    
    func getEditor() -> some View {
        return NavigationView {
            EditorView<FramePlayerView, ExistingFrameGenerator>()
                .navigationBarTitle("Edit GIF", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    self.$editingGIF.animation().wrappedValue = nil
                    }, trailing: Button("Create GIF") {
                        GlobalState.instance.generateGIF(editingContext: self.editingGIF!.editingContext)
                })
            
            
        }            .navigationViewStyle(StackNavigationViewStyle())
            
            //        .edgesIgnoringSafeArea(self.visualState.compact ? [.leading, .trailing, .top] : [.bottom])
            .environmentObject(self.editingGIF!.editingContext)
            .background(Color.background)
    }
    
    func getToolbar(with metrics: GeometryProxy, background: AnyView = VisualEffectView(effect: .init(style: .systemChromeMaterialDark)) .any) -> AnyView {
        return ToolbarView(metrics: metrics, bottomAdjustment: metrics.safeAreaInsets.bottom, background: background) {
            //            self.gallery.viewConfig.toolbarContent(self.gallery, self.$selectedGIFs, self.$gifViewState)
            
            Group {
                
                if self.showSpeedPopover {
                    HStack(spacing: 12) {
                        Slider(value: self.$speed, in: 0.25...2)
                        Button(action: {
                            self.$showSpeedPopover.animation().wrappedValue = false
                        }, label: { Image.symbol("xmark") } )
                    }
                } else {
                    
                    
                    Group {
                        Button(action: {
                            GlobalPublishers.default.showShare.send([self.selectedGIFs[0]])
                            
                        }, label: { Image.symbol("square.and.arrow.up") } )
                            .padding(12)
                        
                        Spacer()
                        
                        Button(action: {
                            self.$showSpeedPopover.animation().wrappedValue.toggle()
                        }, label: { Image.symbol("speedometer") } )
                            .transformAnchorPreference(key: PopoverPreferencesKey.self, value: .center) { (val, anchor) in
                                val.origin = anchor
                        }
                        
                        
                        if self.selectedGIFs.first?.isDeletable ?? false {
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    self.gallery.remove(self.selectedGIFs)
                                    self.$selectedGIFs.animation().wrappedValue = []
                                    //                        gallery.remove(gallery.viewState.selectedGIFs)
                                    //                        gallery.viewState.selectedGIFs = []
                                }
                            }, label: { Image.symbol("trash") } )
                                .padding(12)
                            
                        }
                    }
                }
            }
            
            //            Button(action: {
            //
            //            }, label: { Image.symbol("square.and.arrow.up") } )
            //                .disabled(self.selectedGIFs.count == 0)
            //                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
            //            Spacer()
            //            Button(action: {
            //                withAnimation {
            //                    self.gallery.remove(self.selectedGIFs)
            //                    self.selectedGIFs = []
            //                }
            //            }, label: { Image.symbol("trash") } )
            //                .disabled(self.selectedGIFs.count == 0)
            //                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
        }.frame(height: metrics.size.height + metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom, alignment: .bottom).any
    }
}

struct GIFImageScrollerView: UIViewRepresentable {
    func makeCoordinator() -> GIFImageScrollerView.Coordinator {
        return Coordinator(self)
    }
    
    @Binding var selectedGIFs: [GIF]
    @Binding var disableScrolling: Bool
    @Binding var disableAnimation: Bool
    
    @Binding var items: [GIF]
    
    @Binding var opacity: Double
    
    @Binding var speed: Double
    
    @Binding var currenTransform: CGAffineTransform
    
    @Binding var imageOffset: CGPoint
    
    @Binding var animationInProgress: Bool
    
    @Binding var animationComplete: Bool
    
    var contentMode: ContentMode
    
    func action(_ action: GIFImageScroller.Action) {
        DispatchQueue.main.async {
            self.speed = 1
            if let index = self.items.firstIndex(of: self.selectedGIFs[0]) {
                switch action {
                case .backward:
                    if self.items.first != self.selectedGIFs[0] {
//                        withAnimation {
                            self.selectedGIFs = [self.items[index - 1]]
                            //                            self.scaledGIF = self.selectedGIFs.first
//                        }
                    }
                case .forward:
                    if self.items.last != self.selectedGIFs[0] {
//                        withAnimation {
                            self.selectedGIFs = [self.items[index + 1]]
                            //                            self.scaledGIF = self.selectedGIFs.first
//                        }x
                    }
                }
            }
        }
    }
    
    func dragDismiss(_ percent: CGFloat, _ dismiss: Bool) {
        print("drag dismiss")
        if dismiss {
//            self.$selectedGIFs.animation().wrappedValue = []
            self.$opacity.animation(Animation.easeOut(duration: 0.2)).wrappedValue = 0

            self.$animationInProgress.animation(Animation.easeOut(duration: 0.15)).wrappedValue = false
            
            self.$selectedGIFs.animation(Animation.default.delay(0.2)).wrappedValue = []

        } else {
//            self.$opacity.animation(.easeInOut(duration: 0.3)).wrappedValue = Double(CalculatePercentComplete(start: 1, end: 0, current: percent))
            
            if percent >= 1 {
                Delayed(0.15) {
//                    self.$selectedGIFs.animation().wrappedValue = []
                    self.$animationInProgress.animation().wrappedValue = false

                }
            }
        }
    }
    
    func transformUpdated(_ transform: CGAffineTransform, _ percent: CGFloat) {
        self.currenTransform = transform
        
        self.opacity = Double(1 - percent)
    }
    
    func offsetUpdated(_ offset: CGPoint) {
        self.imageOffset = offset
    }
    
    func makeUIView(context: UIViewRepresentableContext<GIFImageScrollerView>) -> GIFImageScroller {
        let v = GIFImageScroller(actionBlock: self.action, dragDismissBlock: self.dragDismiss, transformUpdatedBlock: self.transformUpdated, offsetUpdateBlock: self.offsetUpdated)
        return v
    }
    
    func updateUIView(_ uiView: GIFImageScroller, context: UIViewRepresentableContext<GIFImageScrollerView>) {
        if let gif = selectedGIFs.first {
            var images = [GIF?]()
            if let index = self.items.firstIndex(of: gif) {
                if self.items.first != gif {
                    images.append(self.items[index - 1])
                } else {
                    images.append(nil)
                }
                
                images.append(gif)
                
                if self.items.last != gif {
                    images.append(self.items[index + 1])
                } else {
                    images.append(nil)
                }
                
                uiView.images = images
            }
        }
        
        uiView.speed = self.speed
        uiView.disableAnimation = self.disableAnimation
        uiView.scrollView.isScrollEnabled = !self.disableScrolling
        
        uiView.imageViews[1].alpha = self.animationComplete && self.currenTransform.isIdentity ? 1 : 0
        
//        uiView.imageViews[1].layer.contentsGravity = mode
//        if uiView.imageViews[1].contentMode != mode {
//                UIView.animate(withDuration: 2) {
//        uiView.imageViews[1].contentMode = mode
//        //
//                }
//        }
//        print(uiView.imageViews[1].contentMode)
    }
    
    typealias UIViewType = GIFImageScroller
    
    class Coordinator: ObservableObject {
        let parent: GIFImageScrollerView
        
        init(_ parent: GIFImageScrollerView) {
            self.parent = parent
        }
    }
}

class GIFImageScroller: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let dragDismissBlock: (_ percent: CGFloat, _ dismiss: Bool) -> Void
    
    var speed: Double = 1 {
        didSet {
            guard speed != oldValue else { return }
            self.imageViews[1].speed = speed
        }
    }
    
    enum Action {
        case forward
        case backward
    }
    
    lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        self.addSubview(v)
        
        v.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        v.layer.zPosition = 1000
        v.startAnimating()
        v.isHidden = true
        return v
    }()
    
    var disableAnimation = true {
        didSet {
            guard oldValue != self.disableAnimation else { return }
            print("set disable animation: " + (disableAnimation ? "true" : "false"))
            self.setNeedsLayout()
        }
    }
    
    let actionBlock: (_ action: Action) -> Void
    
    let dragGesture: UIPanGestureRecognizer
    
    let transformUpdatedBlock: (CGAffineTransform, CGFloat) -> Void
    
    let offsetUpdateBlock: (CGPoint) -> Void
    
    @IBAction public func drag() {
        if self.dragGesture.state == .changed {
            self.imageViews[1].alpha = 0

            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [], animations: {
                let percent = CalculatePercentComplete(start: 0, end: self.frame.size.height, current: self.dragGesture.translation(in: self).y)

                self.dragDismissBlock(percent, false)
                let scale = ExtrapolateValue(from: 1, to: 0.5, percent: percent)
//                self.imageViews[1].transform = CGAffineTransform(translationX: 0, y: self.dragGesture.translation(in: self).y).scaledBy(x: scale, y: scale)
                let t = self.dragGesture.translation(in: self)
                self.transformUpdatedBlock(CGAffineTransform(translationX: t.x, y: t.y).scaledBy(x: scale, y: scale), percent)
            }, completion: nil)
            
        } else {
            if self.dragGesture.state == .ended {
                if self.dragGesture.velocity(in: self).y > 500 {
                    self.disableAnimation = true
                    let totalDistance = self.frame.size.height - self.imageViews[1].center.y
                    let animVel = totalDistance / self.dragGesture.velocity(in: self).y
                    let scale = ExtrapolateValue(from: 1, to: 0.5, percent: 1)
                    
                    self.dragDismissBlock(2, false)
                    
                    UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: animVel, options: [], animations: {
                        //                        self.imageViews[1].transform = CGAffineTransform(translationX: 0, y: totalDistance).scaledBy(x: scale, y: scale)
                        
                    }, completion: { _ in
                        
                        self.dragDismissBlock(2, true)
                    })
                    
                    return
                }
            }
            
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [], animations: {
                self.dragDismissBlock(0, false)
                
                self.transformUpdatedBlock(.identity, 0)
                self.imageViews[1].alpha = 1
//                self.imageViews[1].transform = .identity
            }, completion: nil)
        }
    }
    
    init(actionBlock: @escaping (_ action: Action) -> Void, dragDismissBlock: @escaping (_ percent: CGFloat, _ dismiss: Bool) -> Void, transformUpdatedBlock: @escaping (CGAffineTransform, CGFloat) -> Void, offsetUpdateBlock: @escaping (CGPoint) -> Void) {
        self.dragDismissBlock = dragDismissBlock
        self.actionBlock = actionBlock
        self.dragGesture = UIPanGestureRecognizer()
        self.transformUpdatedBlock = transformUpdatedBlock
        self.offsetUpdateBlock = offsetUpdateBlock
        super.init(frame: CGRect.zero)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.animated = true
        }
        
        self.dragGesture.addTarget(self, action: Selector(("drag")))
        self.dragGesture.delegate = self
        self.dragGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(self.dragGesture)
        
        self.backgroundColor = UIColor.clear
        self.isOpaque = false
        
//        self.frameCancellable = scrollView.publisher(for: \.contentOffset).sink { [weak self] _ in
//            guard let weakSelf = self else { return }
//            let translatedFrame = weakSelf.convert(weakSelf.imageViews[1].bounds.origin, from: weakSelf.imageViews[1])
//            Async {
//                weakSelf.offsetUpdateBlock(translatedFrame)
//            }
//        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        
        let offset: CGFloat = 40
        
        let firstPagePercent = CalculatePercentComplete(start: self.imageViews[1].frame.origin.x, end: 0, current: scrollView.contentOffset.x)
        
        let lastPagePercent = CalculatePercentComplete(start: self.imageViews[1].frame.origin.x, end: self.imageViews[2].frame.origin.x, current: scrollView.contentOffset.x)
        
        let firstPageXOff = ExtrapolateValue(from: -offset, to: 0, percent: firstPagePercent)
        let lastPageXOff = ExtrapolateValue(from: offset, to: 0, percent: lastPagePercent)
        
        let firstFrame = CGRect(x: firstPageXOff, y: 0, width: self.frame.size.width, height: self.imageViews[0].bounds.size.height)
        let lastFrame = CGRect(x: lastPageXOff, y: 0, width: self.frame.size.width, height: self.imageViews[2].bounds.size.height)
        
        var currentFrame: CGRect
        
        let endPoint = self.imageViews[0].isHidden ? self.frame.size.width : self.imageViews[2].frame.origin.x
        
        let currentPercent = CalculatePercentComplete(start: 0, end: endPoint, current: scrollView.contentOffset.x)
        let currentXOff = ExtrapolateValue(from: offset, to: -offset, percent: currentPercent)
        
        currentFrame = CGRect(x: currentXOff, y: 0, width: self.imageViews[1].bounds.size.width, height: self.imageViews[1].bounds.size.height)
        
        if scrollView.contentOffset.x <= 0 {
            self.imageViews[1].mask?.frame = self.imageViews[1].bounds
            return
        }
        
        if self.imageViews[0].isHidden {
            let currentPercent = CalculatePercentComplete(start: 0, end: endPoint, current: scrollView.contentOffset.x)
            let currentXOff = ExtrapolateValue(from: 0, to: -offset, percent: currentPercent)
            
            currentFrame = CGRect(x: currentXOff, y: 0, width: self.imageViews[1].bounds.size.width, height: self.imageViews[1].bounds.size.height)
        }
        
        self.imageViews[1].mask?.frame = currentFrame
        
        if !self.imageViews[0].isHidden {
            self.imageViews[0].mask?.frame = firstFrame
        }
        self.imageViews[2].mask?.frame = lastFrame
        
        
    }
    
//    scroll
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x == self.imageViews[0].frame.origin.x, !self.imageViews[0].isHidden {
            self.actionBlock(.backward)
        } else if scrollView.contentOffset.x == self.imageViews[2].frame.origin.x, !self.imageViews[2].isHidden {
            self.actionBlock(.forward)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x == self.imageViews[0].frame.origin.x, !self.imageViews[0].isHidden {
            self.actionBlock(.backward)
        } else if scrollView.contentOffset.x == self.imageViews[2].frame.origin.x, !self.imageViews[2].isHidden {
            self.actionBlock(.forward)
        }
    }
    
    
    
    //    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    //        return self.zoomView
    //    }
    ////
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var images = [GIF?]() {
        didSet {
            guard images != oldValue else { return }
            
            self.setNeedsLayout()
        }
    }
    
    var animated = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    let pinch = UIPinchGestureRecognizer()
    
    
    var prevScale: CGFloat = 1
    @objc func didPinch() {
        self.scrollView.isScrollEnabled = false
        self.prevScale = self.pinch.scale
        
        if self.pinch.state == .cancelled || self.pinch.state == .failed || self.pinch.state == .ended {
            self.scrollView.isScrollEnabled = true
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
                self.imageViews[1].transform = .identity
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
                self.imageViews[1].transform = .init(scaleX: self.pinch.scale, y: self.pinch.scale)
            }, completion: nil)
            
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        for (x, gif) in self.images.enumerated() {
            if let gif = gif {
                self.imageViews[x].isHidden = false
                
                if x == 1 {
                    print("set 1 animating: " + (self.animated && !self.disableAnimation ? "true" : "false"))
                    self.imageViews[x].set(gif: gif, animating: self.animated && !self.disableAnimation)
                    self.imageViews[x].speed = self.speed
                } else {
                    self.imageViews[x].set(gif: gif, animating: false)
                }
            } else {
                self.imageViews[x].isHidden = true
            }
        }
        
        let xOffset = self.imageViews[0].isHidden ? 0 : frame.size.width
        self.scrollView.contentOffset = CGPoint(x: xOffset, y: 0)
        
        self.imageViews[1].mask?.frame = self.imageViews[1].bounds
        
//        let translatedFrame = self.convert(self.imageViews[1].bounds.origin, from: self.imageViews[1])
//                self.offsetUpdateBlock(translatedFrame)
    }
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.maximumZoomScale = 2
        scrollView.backgroundColor = UIColor.clear
        scrollView.isOpaque = false
        //        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        self.addSubview(scrollView)
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        
        
        return scrollView
    }()
    
    let zoomView = GifuImageView()
    
    var containers = [UIView(), UIView(), UIView()]
    var stack: UIStackView?
    var scaleCancellable: AnyCancellable?
    var frameCancellable: AnyCancellable?
    lazy var imageViews: [ImageIOAnimationView] = {
        let imgViews = [ImageIOAnimationView(), ImageIOAnimationView(), ImageIOAnimationView()]
        
        
        //        for x in 0..<3 {
        //            containers[x].addSubview(imgViews[x])
        //            imgViews[x].snp.makeConstraints { (make) in
        //                make.edges.equalToSuperview()
        //            }
        //        }
        ////
        
        let stack = UIStackView(arrangedSubviews: imgViews)
        stack.axis = .horizontal
        stack.alignment = .center
        
        //        let fillerView = UIView()
        //        scrollView.addSubview(fillerView)
        //        fillerView.snp.makeConstraints { (make) in
        //            make.leading.trailing.top.equalToSuperview()
        //            make.height.equalTo(self)
        //        }
        
        scrollView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        imgViews.forEach { $0.snp.makeConstraints { make in
            make.width.equalTo(self)
            make.height.equalTo(self)
            } }
        
        self.stack = stack
        imgViews.forEach {
            $0.backgroundColor = UIColor.clear
            $0.isOpaque = false
            //            scrollView.addSubview($0)
            $0.contentMode = .scaleAspectFit
            //            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        
        imgViews[1].addGestureRecognizer(self.pinch)
        imgViews[1].alpha = 0
        

        self.pinch.addTarget(self, action: Selector(("didPinch")))
        return imgViews
    }()
}

