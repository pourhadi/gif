
import SwiftUI
import UIKit
import SwiftyGif
import SnapKit
import Combine
import SwiftDate
import Gifu

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
                        }}).padding(.leading, 10)
                    Spacer()
                    Spacer()
                }.padding(.bottom, 10)
            }.background(VisualEffectView.blur(.prominent))
        }.frame(height:80)
    }
}

struct GIFView: View{
    
    @Binding var removeGIFView: Bool
    @EnvironmentObject var gallery: Gallery
    
    @ObservedObject var transitionContext: TransitionContext
    
    
    @Binding var gifs: [GIF]
    @Binding var selectedGIFs: [GIF]
    
    @State var animating = true
    
    
    @State var opacity: Double = 1
    
    let toolbarBuilder: (_ metrics: GeometryProxy, _ background: AnyView) -> AnyView
    
    @State var disableScrolling = false
    
    
    
    @State var showSpeed = false
    
    @State var speed: Double = 1
    
    
    @State var transitionOut = false
    
    var title: String {
        if let gif = selectedGIFs.first {
            if let date = gif.creationDate {
                    return ("\(date.monthName(.default)) \(date.day)")
            }
            
            let count = gifs.count
            if let index = gifs.firstIndex(of: gif) {
                return ("\(index + 1) of \(count)")
            }
        }
        
        return ""
    }
    
    var body: some View {
        NavigationView {
        GeometryReader { outerMetrics -> AnyView in
            
            let out = Group {
                GeometryReader { metrics in
                    
                    GIFImageScrollerView(selectedGIFs: self.$selectedGIFs, disableScrolling: self.$disableScrolling, disableAnimation: self.$transitionContext.disableAnimation, gifs: self.gifs)
                        .onTapGesture {
                            self.transitionContext.disableAnimation = true
                            withAnimation {
                                self.transitionContext.fullscreen.toggle()
                            }
                            
                            DispatchQueue.main.async {
                                self.transitionContext.disableAnimation = false
                            }
                    }
                        .edgesIgnoringSafeArea([.top, .bottom])
                    .scaleEffect(self.transitionContext.dragScale != nil ? self.transitionContext.dragScale! : 1)
                    .frame(height:metrics.size.height + (metrics.safeAreaInsets.top + metrics.safeAreaInsets.bottom))
                    .offset(y: self.transitionContext.yDrag != nil ? self.transitionContext.yDrag! : -( metrics.safeAreaInsets.bottom + metrics.safeAreaInsets.top))
                        
                        .gesture(DragGesture(minimumDistance: 30, coordinateSpace: .local).onChanged({ (val) in
                            self.disableScrolling = true
                            self.transitionContext.yDrag = val.translation.height > 0 ? val.translation.height : nil
                            let percent = CGFloat((val.translation.height / 300))
                            self.transitionContext.dragScale = ExtrapolateValue(from: 1, to: 0.7, percent: percent)
                            self.opacity = Double(1 - (val.translation.height / 300))
                            print("drag")
                            
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                                if self.opacity < 1 && self.selectedGIFs.count > 0 {
                                    withAnimation(Animation.spring(dampingFraction: 0.7)) {
                                        self.transitionContext.yDrag = nil
                                        self.transitionContext.dragScale = nil
                                        self.opacity = 1
                                        self.disableScrolling = false
                                        
                                    }
                                }
                            }
                        }).onEnded({ (val) in
                            print("end drag")
                            self.disableScrolling = false
                            if val.predictedEndTranslation.height > 300 {
                                self.transitionContext.disableAnimation = true
                                
                                
                                withAnimation(.linear(duration: 0.1)) {
                                    
                                    
                                    self.opacity = 0
                                    
                                }
                                
                                
                                DispatchQueue.main.async { self.$transitionContext.yDrag.animation(.easeInOut(duration: 0.3)).wrappedValue = val.predictedEndTranslation.height
                                }
                                
                                
                                
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
                                    
                                    self.selectedGIFs = []
                                    self.transitionOut = false
                                }
                                
                            } else {
                                withAnimation(Animation.spring(dampingFraction: 0.7)) {
                                    self.transitionContext.yDrag = nil
                                    self.transitionContext.dragScale = nil
                                    self.opacity = 1
                                }
                            }
                        }))
                    
                    if !self.transitionContext.fullscreen {
                        
                        self.getToolbar(with: metrics, background: VisualEffectView(effect: .init(style: .prominent))
                            .opacity(self.opacity).any)
//                            .edgesIgnoringSafeArea([.bottom])
                            .transition(.opacity)
                    }
                }
            }
            return out.background(self.transitionContext.fullscreen ? Color.black : Color.background).any
        }.navigationBarHidden(self.transitionContext.fullscreen).navigationBarTitle(Text(self.title), displayMode: NavigationBarItem.TitleDisplayMode.inline)
            .navigationBarItems(leading: Button(action: {
            withAnimation {
                self.$selectedGIFs.animation(Animation.spring(dampingFraction: 0.7)).wrappedValue = []
            }
        }, label: { HStack {
            Image.symbol("chevron.compact.left")
            Text("GIFs")
            }}).padding(.leading, 10))
        }.opacity(self.opacity).statusBar(hidden: self.transitionContext.fullscreen).edgesIgnoringSafeArea(self.transitionContext.fullscreen ? [.top, .bottom] : [])
    }
    
    func getToolbar(with metrics: GeometryProxy, background: AnyView = VisualEffectView(effect: .init(style: .prominent)).any) -> AnyView {
        return ToolbarView(metrics: metrics, bottomAdjustment: metrics.safeAreaInsets.bottom, background: background) {
            Button(action: {
                
            }, label: { Image.symbol("square.and.arrow.up") } )
                .disabled(self.selectedGIFs.count == 0)
                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
            Spacer()
            Button(action: {
                withAnimation {
                    self.gallery.remove(self.selectedGIFs)
                    self.selectedGIFs = []
                }
            }, label: { Image.symbol("trash") } )
                .disabled(self.selectedGIFs.count == 0)
                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
        }.any
        
    }
    
}

struct GIFImageScrollerView<G : GIF>: UIViewRepresentable {
    
    @Binding var selectedGIFs: [G]
    @Binding var disableScrolling: Bool
    @Binding var disableAnimation: Bool
    
    
    let gifs: [G]
    
    func action(_ action: GIFImageScroller<G>.Action) {
        DispatchQueue.main.async {
            if let index = self.gifs.firstIndex(of: self.selectedGIFs[0]) {
                switch action {
                case .backward:
                    if self.gifs.first != self.selectedGIFs[0] {
                        withAnimation {
                            self.selectedGIFs = [self.gifs[index - 1]]
//                            self.scaledGIF = self.selectedGIFs.first
                        }
                    }
                case .forward:
                    if self.gifs.last != self.selectedGIFs[0] {
                        withAnimation {
                            self.selectedGIFs = [self.gifs[index + 1]]
//                            self.scaledGIF = self.selectedGIFs.first
                        }
                    }
                }
            }
        }
        
    }
    
    func makeUIView(context: UIViewRepresentableContext<GIFImageScrollerView<G>>) -> GIFImageScroller<G> {
        let v = GIFImageScroller(actionBlock: self.action)
        return v
    }
    
    func updateUIView(_ uiView: GIFImageScroller<G>, context: UIViewRepresentableContext<GIFImageScrollerView<G>>) {
        
        if let gif = selectedGIFs.first {
            var images = [G?]()
            if let index = gifs.firstIndex(of: gif) {
                if gifs.first != gif {
                    images.append(gifs[index - 1])
                } else {
                    images.append(nil)
                }
                
                images.append(gif)
                
                if gifs.last != gif {
                    images.append(gifs[index + 1])
                } else {
                    images.append(nil)
                }
                
                uiView.images = images
            }
            
        }
        
        uiView.scrollView.isScrollEnabled = !self.disableScrolling
        
    }
    
    typealias UIViewType = GIFImageScroller
    
    
    
}

class GIFImageScroller<G: GIF>: UIView, UIScrollViewDelegate {
    
    enum Action {
        case forward
        case backward
    }
    
    lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        self.addSubview(v)
        
        v.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        v.layer.zPosition = 1000
        v.startAnimating()
        v.isHidden = true
        return v
    }()
    
    var disableAnimation = false {
        didSet {
            guard oldValue != disableAnimation else { return }
            self.setNeedsLayout()
        }
    }
    
    let actionBlock: (_ action: Action) -> Void
    
    init(actionBlock: @escaping (_ action: Action) -> Void) {
        self.actionBlock = actionBlock
        
        super.init(frame: CGRect.zero)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.animated = true
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x == imageViews[0].frame.origin.x && !imageViews[0].isHidden {
            actionBlock(.backward)
        } else if scrollView.contentOffset.x == imageViews[2].frame.origin.x && !imageViews[2].isHidden {
            actionBlock(.forward)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x == imageViews[0].frame.origin.x && !imageViews[0].isHidden {
            actionBlock(.backward)
        } else if scrollView.contentOffset.x == imageViews[2].frame.origin.x && !imageViews[2].isHidden {
            actionBlock(.forward)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var images = [G?]() {
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
    override func layoutSubviews() {
        super.layoutSubviews()
        
        for (x, gif) in images.enumerated() {
            if let gif = gif {
                imageViews[x].isHidden = false
                
                if x == 1 {
                    
//                    self.imageViews[x].clear()
                    self.imageViews[x].image = gif.thumbnail
                    
                    if animated && !self.disableAnimation {
                        if let image = gif.image {
                            self.imageViews[x].setGifImage(image)
                        } else if let data = gif.data {
                            self.imageViews[x].animate(withGIFData: data)

//                            if let img = try? UIImage(gifData: data) {
//                                self.imageViews[x].setGifImage(img)
//                            }
                            
                        } else {
                            self.loadingView.isHidden = false
                            gif.getData { (data) in
                                self.loadingView.isHidden = true

                                if let data = data {
                                    self.imageViews[x].animate(withGIFData: data)

//                                    if let img = try? UIImage(gifData: data) {
//                                        self.imageViews[x].setGifImage(img)
//                                    }
                                }
                            }
                        }
//                        self.imageViews[x].startAnimatingGif()
                        
                    }
                } else {
                    if let thumb = gif.thumbnail {
                        imageViews[x].image = thumb
                    }
                }
            } else {
                imageViews[x].isHidden = true
            }
        }
        
        let xOffset = imageViews[0].isHidden ? 0 : frame.size.width
        scrollView.contentOffset = CGPoint(x: xOffset, y: 0)
    }
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        self.addSubview(scrollView)
        
        scrollView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        return scrollView
    }()
    
    
    var containers = [UIView]()
    
    lazy var imageViews: [Gifu.GIFImageView] = {
        
        let imgViews = [Gifu.GIFImageView(), Gifu.GIFImageView(), Gifu.GIFImageView()]
        
        let stack = UIStackView(arrangedSubviews: imgViews)
        stack.axis = .horizontal
        stack.alignment = .center
        
        scrollView.addSubview(stack)
        stack.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        imgViews.forEach { $0.snp.makeConstraints { (make) in
            make.width.equalTo(self)
            make.height.lessThanOrEqualTo(self)
            make.centerY.equalTo(self)
            }}
        imgViews.forEach { $0.contentMode = .scaleAspectFit }
        return imgViews
    }()
    
    
    
}
