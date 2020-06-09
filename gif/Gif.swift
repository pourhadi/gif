//
//  Gif.swift
//  gif
//
//  Created by dan on 12/7/19.
//  Copyright © 2019 dan. All rights reserved.
//

import UIKit
import ImageIO.CGImageAnimation
import ImageIO.CGImageSource
import MobileCoreServices
import SwiftUI
import Combine
import AVFoundation

#if os(iOS)
import YYImage
import Drawsana
import Photos
#endif

#if os(watchOS)
typealias PHAsset = AnyObject
#endif

struct GifConfigDiff {
    let selectionChanged: Bool
    let settingsChanged: Bool
    
    let framesChanged: Bool
}

struct GifDefinition {
    let frames: [UIImage]
    let duration: TimeInterval
    
    static var empty: GifDefinition {
        return GifDefinition(frames: [], duration: 0)
    }
    
    var uiImage: UIImage? {
        return UIImage.animatedImage(with: self.frames, duration: self.duration)
    }
}


extension Collection where Element == GifConfig.Selection {
    func selectionDuration(for duration: Double) ->  Double {
        return self.reduce(Double(0)) { (last, selection) -> Double in
            return last + selection.seconds(for: duration)
        }
    }
}


struct AssetInfo {
    var fps: Float
    var duration: Double
    var size: CGSize
    
    var unitFrameIncrement: CGFloat {
        let totalFrames = fps * Float(duration)
        return CGFloat(1 / totalFrames)
    }
    
    static var empty: Self {
        return Self(fps: 0, duration: 0, size: CGSize.zero)
    }
}


class GifConfig: ObservableObject, Equatable {
    enum AnimationType: CaseIterable, Hashable, Identifiable {
        var id: Self { return self }
        
        case regular
        case reverse
        case palindrome
        
        var name: String {
            return "\(self)".capitalized
        }
        
        static var all: [Self] {
            return Self.allCases
        }
        
    }
    
//    @Published
    var imageQuality: Float = 1 {
        didSet {
            self.sendValues()
            self.objectWillChange.send()

        }
    }
    
    @Published
    var regenerateFlag: UUID = UUID() {
        didSet {
            self.sendValues()
            
        }
    }
    
//    @Published
    var animationType = AnimationType.regular {
        didSet {
            self.sendValues()
            self.objectWillChange.send()

        }
    }
    
    struct Selection: Equatable {
        static func == (lhs: GifConfig.Selection, rhs: GifConfig.Selection) -> Bool {
            return lhs.startTime == rhs.startTime && lhs.endTime == rhs.endTime
        }
        
        init(startTime: CGFloat = 0, endTime: CGFloat = 0, fiveSecondValue: CGFloat = 0) {
            self.fiveSecondValue = fiveSecondValue
            
            self.startTime = startTime
            self.endTime = endTime
        }
        
        
        @Clamped
        var startTime: CGFloat = 0 {
            didSet {
                if endTime < startTime {
                    endTime = startTime + fiveSecondValue
                }
            }
        }
        
        @Clamped
        var endTime: CGFloat = 0 {
            didSet {
                if endTime.isInfinite {
                    self.endTime = 1
                }
                
                if endTime < startTime {
                    startTime = endTime - fiveSecondValue
                }
            }
        }
        
        
        var fiveSecondValue: CGFloat
        
        func seconds(for assetDuration: Double) -> Double {
            let diff = self.endTime - self.startTime
            return assetDuration * Double(diff)
        }
        
    }
    
    enum AnimationQuality: CaseIterable, Hashable, Identifiable {
        var id: Self { return self }
        
        case high
        case medium
        case low
        
        var name: String {
            return "\(self)".capitalized
        }
        
        static var all: [Self] {
            return Self.allCases
        }
        
        var frameMultiplier: Int {
            switch self {
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
        
        var jpegQuality: CGFloat {
            switch self {
            case .high: return 1
            case .medium: return 0.7
            case .low: return 0.4
            }
        }
        
        var fps: Double {
            switch self {
            case .high: return 30
            case .medium: return 15
            case .low: return 8
            }
        }
    }
    
    var hideAnimationQuality = false
    
    
    
//    @Published
    var animationQuality: AnimationQuality = .medium {
        didSet {
            self.sendValues()
            self.objectWillChange.send()
        }
    }
    
//    @Published
    var speed: CGFloat = 1.0 {
        didSet {
            self.sendValues()
            self.objectWillChange.send()

        }
    }
    
//    @Published
    var sizeScale: CGFloat = 1.0 {
        didSet {
            self.sendValues()
            self.objectWillChange.send()

        }
    }
    
//    @Published
    var selections = [Selection()] {
        didSet {
            self.sendValues()
            self.objectWillChange.send()

        }
    }
    
    
//    @Published
    var selection = Selection() {
        didSet {
            self.sendValues()
            self.objectWillChange.send()

        }
    }
    
    @Published var visible = false
    
    @Published var selectedSelection = 0
    
    struct Values {
        let animationQuality: AnimationQuality
        let speed: CGFloat
        let sizeScale: CGFloat
        let selection: Selection
        let animationType: AnimationType
        let regenerate: UUID
        let imageQuality: Double
        static var empty: Self {
            return Values(animationQuality: .high, speed: 0, sizeScale: 0, selection: Selection(), animationType: .regular, regenerate: UUID(), imageQuality: 1)
        }
        
        func diff(_ other: Self) -> GifConfigDiff {
            var selectionChanged = selection != other.selection
            
            var settingsChanged = animationQuality != other.animationQuality || speed != other.speed || sizeScale != other.sizeScale
            
            var framesChanged = animationQuality != other.animationQuality || sizeScale != other.sizeScale || selectionChanged || animationType != other.animationType || imageQuality != other.imageQuality
            
            if self.regenerate != other.regenerate {
                selectionChanged = true
                settingsChanged = true
                framesChanged = true
            }
            
            return GifConfigDiff(selectionChanged: selectionChanged, settingsChanged: settingsChanged, framesChanged: framesChanged)
        }
    }
    
    
    func sendValues() {
        self._values.send(Values(animationQuality: animationQuality, speed: speed, sizeScale: sizeScale, selection: selection, animationType: animationType, regenerate: regenerateFlag, imageQuality: Double(imageQuality)))
    }
    
    var _values = PassthroughSubject<GifConfig.Values, Never>()
    
    var values: AnyPublisher<GifConfig.Values, Never> {
        return _values.eraseToAnyPublisher()
//        return $animationQuality.combineLatest($speed, $sizeScale, $selection).combineLatest($animationType).combineLatest($regenerateFlag).combineLatest($imageQuality)
//            .map { (arg0, arg1) in
//                let animationQuality = arg0.0.0
//                let speed = arg0.0.1
//                let sizeScale = arg0.0.2
//                let selection = arg0.0.3
//                let regenerate = arg1
//                let imageQuality = arg
//
//                return Values(animationQuality: animationQuality, speed: speed, sizeScale: sizeScale, selection: selection, animationType: arg0.1, regenerate: regenerate, imageQuality: ) }.eraseToAnyPublisher()
    }
    
    var assetInfo: AssetInfo
    init(assetInfo: AssetInfo) {
        self.assetInfo = assetInfo
        
        let fiveSeconds = 5 / assetInfo.duration
        self.selection.fiveSecondValue = CGFloat(fiveSeconds)
        self.selection.startTime = 0
        self.selection.endTime = CGFloat(fiveSeconds)
    }
    
    
    static func == (lhs: GifConfig, rhs: GifConfig) -> Bool {
        return lhs.animationQuality == rhs.animationQuality && lhs.speed == rhs.speed && lhs.sizeScale == rhs.sizeScale && lhs.selection == rhs.selection
    }
    
    var selectionDuration : Double {
        //        return self.selection.reduce(Double(0)) { (last, selection) -> Double in
        //            return last + selection.seconds(for: self.assetInfo.duration)
        //        }
        
        return self.selection.seconds(for: self.assetInfo.duration)
    }
}




protocol AnimationSubscriber {
    var subscriberId: UUID { get }
}

extension GIF {
    
    
    func animate(id: UUID, block: @escaping (_ ready: Bool) -> ((CGImage) -> Void)) -> Bool {
        
        
        if self.animating {
            self.animationSubscribers[id] = block(true)
            return true
        }
        
        if self.preferredSource == .url {
            if CGAnimateImageAtURLWithBlock(self.url as CFURL, nil, { [weak self] (x, img, done) in
                guard let weakSelf = self else {
                    done.pointee = true
                    return
                }
                
                if !weakSelf.animating {
                    done.pointee = true
                    return
                }
                
                self?.animationSubscribers.forEach({ (key, block) in
                    block(img)
                })
                
            }) == 0 {
                self.animationSubscribers[id] = block(true)
                return true
            } else {
                let _ = block(false)
                return true
            }
        } else {
            
            return self.getData { (data, _, sync) in
                if let data = data, CGAnimateImageDataWithBlock(data as CFData, nil, { [weak self] (x, img, done) in
                    guard let weakSelf = self else {
                        done.pointee = true
                        return
                    }
                    
                    if !weakSelf.animating {
                        done.pointee = true
                        return
                    }
                    
                    self?.animationSubscribers.forEach({ (key, block) in
                        block(img)
                    })
                }) == 0 {
                    self.animationSubscribers[id] = block(true)
                    
                } else {
                    let _ = block(false)
                }
            }
            
            
        }
    }
    
    //    func animate(_ block: @escaping (CGImage) -> Void) {
    //        guard !self.animating else { return  }
    //
    //        self.animating = true
    //
    //
    //        if self.preferredSource == .url {
    //            if CGAnimateImageAtURLWithBlock(self.url as CFURL, nil, { [unowned self] (x, img, done) in
    //
    //                if !self.animating {
    //                    done.pointee = true
    //                    return
    //                }
    //
    //                block(img)
    //
    //            }) != 0 {
    //                self.animating = false
    //            }
    //        } else {
    //
    //
    //
    //        }
    //    }
    
    func stopAnimating(id: UUID) {
        self.animationSubscribers.removeValue(forKey: id)
    }
    
}

#if os(iOS)
struct AnimatedGIFView : View {
    class Store {
        
        var cancellable: AnyCancellable?
        
    }
    
    let store = Store()
    
    @Binding var gif: GIF
    
    @State var image: UIImage?
    @Binding var animated: Bool
    
    @State var loaded = false
    
    let contentMode: ContentMode
    
    init(gif: GIF, animated: Binding<Bool>, contentMode: ContentMode = .fit) {
        self._gif = Binding<GIF>(get: {
            return gif
        }, set: { (_) in
            
        })
        self._animated = animated
        self.contentMode = contentMode
        self.image = self.gif.thumbnail
        
    }
    
    init(gif: Binding<GIF>, animated: Binding<Bool>, contentMode: ContentMode = .fit){
        self._gif = gif
        self._animated = animated
        self.contentMode = contentMode
        self.image = self.gif.thumbnail

    }
    
    var body : some View {
        Group {
            
            if self.animated {
                Group {
                    if self.image != nil {
                        Image(uiImage: self.image!).resizable()
                    }
                }
                .onReceive(self.gif.nextAnimationPublisher) { (img) in
                    self.image = img
                }
            } else {
                
                if self.gif.thumbnail != nil {
                    Image(uiImage: self.gif.thumbnail!).resizable()
                }
            }
            
        }.aspectRatio(self.gif.aspectRatio, contentMode: self.contentMode)
 
//            .onAppear {
//                self.store.cancellable?.cancel()
//
//                self.store.cancellable = self.gif.nextAnimationPublisher
//                    .receive(on: DispatchQueue.main)
//                    .sink { image in
//                        self.image = image
//                }
//        }
//        .onDisappear {
//            self.store.cancellable?.cancel()
//        }
    }
}

class ImageIOAnimationView : UIView, UIScrollViewDelegate, AnimationSubscriber {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        zooming = true
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale == 1.0 {
            zooming = false
        }
    }
    
    let imageView = UIImageView()
    lazy var overlay: UIView = {
       let v = UIView()
        v.backgroundColor = UIColor.black
        addSubview(v)
        v.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        v.isHidden = true
        return v
    }()
    
    
    let scrollView = UIScrollView()
    init() {
        super.init(frame: CGRect.zero)
        
        addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        scrollView.frame = self.bounds
        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        imageView.frame = scrollView.bounds
        imageView.contentMode = .scaleAspectFit
        scrollView.delegate = self
        scrollView.maximumZoomScale = 3
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = false
        
        self.layer.drawsAsynchronously = true
        self.mask = UIView()
        self.mask?.backgroundColor = UIColor.black
        self.mask?.frame = self.bounds
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.mask?.frame = self.bounds
        
        self.imageView.frame = self.bounds

    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil {
            self.stopAnimating()
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var subscriberId: UUID = UUID()
    
    
    var running = true
    
    lazy var loading: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        self.addSubview(v)
        v.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        v.stopAnimating()
        return v
    }()
    
    var gif: GIF?
    
    deinit {
        self.stopAnimating()
    }
    
    var speed: Double = 1 {
        didSet {
            guard speed != oldValue else { return }
            print("set speed imageview: \(speed)")
            self.gif?.speed = speed
            if self.cancellable != nil {
                self.stopAnimating()
                Async {
                    self.startAnimating()
                }
            }
        }
    }
    
//    override var isAnimating: Bool {
//        return self.cancellable != nil
//    }
    
    @Published var zooming = false
    func resize(for size: CGSize) {
        if zooming { return }
        var newSize = self.bounds.size
        if size.width > size.height {
            newSize = size.fittingWidth(self.bounds.size.width)
        } else {
            newSize = size.fittingHeight(self.bounds.size.height)
        }
        
        if imageView.frame.size != newSize {
            imageView.frame.size = newSize
            imageView.center.x = scrollView.bounds.midX
            imageView.center.y = scrollView.bounds.midY
        }
    }
    
    var cancellable: AnyCancellable?
    var connectedToAnimation = false
    func startAnimating() {
        guard let gif = self.gif else { return }
        self.connectedToAnimation = true
        self.cancellable = gif.nextAnimationPublisher
//            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                
                self?.imageView.image = image
//                self?.resize(for: image.size)
//                if !(self?.cancelAnimation ?? false) {
//                    self?.image = image
//                } else {
//                    self?.cancelAnimation = false
//                }
        }
    }
    

    
    var cancelAnimation = false
    func stopAnimating() {
        self.cancellable?.cancel()
        self.cancellable = nil
        
        cancelAnimation = true
        self.connectedToAnimation = false
    }
    
    func set(gif: GIF?, animating: Bool) {
        guard gif != self.gif else {
            if animating != self.connectedToAnimation {
                if animating {
                    self.startAnimating()
                } else {
                    self.stopAnimating()
                }
            }
            
            return
        }
        
        self.stopAnimating()
        
        self.imageView.image = nil
        
        self.gif = gif
        
        self.imageView.image = self.gif?.thumbnail
        //        self.layer.contents = self.gif?.thumbnail?.cgImage
        
        
        
        if animating {
            self.startAnimating()
        }
        
        //        Async {
        //
        //            if animating {
        //                self.startAnimating()
        //            }
        //        }
    }
}
#endif


class GIF: Identifiable, Equatable, Editable {
    var isDeletable = true
    var isSharable = true
    
    var listIndex = 0
    
    @Published var publicURL: URL?
    
    var confirmedExists = false
    
    @Published var cropState: CropState?
    
    enum PreferredSource {
        case url
        case data
    }
    
    var preferredSource = PreferredSource.url
    
    var animationSubscribers = [UUID: (CGImage) -> Void]()
    
    var animating: Bool {
        return self.subscribers > 0
    }
    
    static var subscribers = [GIF.ID: Int]()
    
    var subscribers: Int {
        get {
            if let num = GIF.subscribers[self.id] {
                return num
            } else { return 0 }
        }
        
        set {

            GIF.subscribers[self.id] = newValue >= 0 ? newValue : 0
        }
    }
    
    var speed: Double = 1 {
        didSet {
            guard speed != oldValue else { return }
            
            self.killAnimation = true
            print("set speed: \(speed)")
            
            if self.subscribers >= 1 {
                serialQueue.async {
                    while self.killAnimation {
                        // wait
                    }
                    self.startAnimation()
                }
            }
        }
    }
    
    var frameDelay: Double?
    
    var reAnimate = false
    var isAnimating = false {
        didSet {
            if !self.isAnimating, self.reAnimate {
                self.reAnimate = false
                print("re-animating")
                self.subscribers += 1
                
                self.startAnimation()
            }
        }
    }
    
    var killAnimation = false
    
    lazy var nextAnimationPublisher: AnyPublisher<UIImage, Never> = {
        self.nextAnimationImageSubject.handleEvents(receiveSubscription: { [weak self] _ in
            guard let weakSelf = self else { return }
            weakSelf.subscribers += 1
            
            print(weakSelf.id + " + 1, total: \(weakSelf.subscribers)")
            
            if weakSelf.subscribers == 1 {
                serialQueue.async {
                    while weakSelf.killAnimation {
                        // wait
                    }
                    weakSelf.startAnimation()
                }
            }
        }, receiveCancel: { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.subscribers -= 1
            if weakSelf.subscribers == 0 {
                weakSelf.killAnimation = true
            }
            print(weakSelf.id + " - 1, total: \(weakSelf.subscribers)")
            
        }).eraseToAnyPublisher()
    }()
    
    lazy var nextAnimationImageSubject = PassthroughSubject<UIImage, Never>()
    
    var currentFrame: Int = -1
    func startAnimation() {
        guard !self.isAnimating else { return }
        self.isAnimating = true
        
        serialQueue.async {
            _ = self.getData { data, _, _ in
                
                if let data = data {
                    var dict: [CFString: CFNumber]?
                    
                    if self.speed != 1 {
                        if self.frameDelay == nil {
                            
                            #if os(iOS)
                            if let decoder = YYImageDecoder(data: data, scale: 1) {
                                self.frameDelay = decoder.frameDuration(at: 0)
                            }
                            #else
                            if let image = UIImage.gif(data: data) {
                                self.frameDelay = image.frameDelay
                            }
                            #endif
                        }
                        
                        if let frameDelay = self.frameDelay {
                            dict = [kCGImageAnimationDelayTime: (frameDelay / self.speed) as CFNumber]
                        }
                    }
                    
                    print("start animating")
                    CGAnimateImageDataWithBlock(data as CFData, dict as CFDictionary?) { [weak self] x, img, getNext in
                        //                        print(x)
                        guard let weakSelf = self,
                            weakSelf.subscribers > 0,
                            !weakSelf.killAnimation,
                            (x == weakSelf.currentFrame + 1) || weakSelf.currentFrame == -1 || x == 0 else {
                            //                                self?.speed = 1
                            self?.currentFrame = -1
                            self?.isAnimating = false
                            print("stop animating")
                            getNext.pointee = true
                            
                            Async {
                                self?.killAnimation = false
                            }
                            return
                        }
                        
                        weakSelf.currentFrame = x
                        weakSelf.nextAnimationImageSubject.send(UIImage(cgImage: img))
                    }
                }
            }
        }
    }
    
    func reset() {
        self._animatedImage = nil
        self._data = nil
        GIF.frameData = nil
        ContextStore.context = nil
        self.cropState = nil
    }
    
    var _size: CGSize?
    
    var playState: PlayState = PlayState()
    
    var createdGIF: GIF?
    
    class FrameData {
        let gifId: String
        let animatedImage: UIImage
        
        init(gifId: String, animatedImage: UIImage) {
            self.gifId = gifId
            self.animatedImage = animatedImage
        }
    }
    
    static var frameData: FrameData?
    var _animatedImage: UIImage?
    var animatedImage: UIImage? {
        if let animatedImage = GIF.frameData?.animatedImage, GIF.frameData?.gifId == self.id {
            return animatedImage
        }
        
        #if os(iOS)
        if self.preferredSource == .url {
            if let img = GIFDecoder.decode(from: self.url) {
                GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
                return img
            }
        } else if self.preferredSource == .data {
            if let data = self.getDataSync(), let img = GIFDecoder.decode(from: data) {
                GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
                return img
            }
        }
        
        if let img = GIFDecoder.decode(from: self.url) {
            GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
            return img
        }
        
        if let data = self.getDataSync(), let img = GIFDecoder.decode(from: data) {
            GIF.frameData = FrameData(gifId: self.id, animatedImage: img)
            return img
        }
        #endif
        return nil
    }
    
    #if os(iOS)
    unowned var cacheManager: PHCachingImageManager?
    
    static var cache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 150 * 1000
        return cache
    }()
    
    var cancellables = Set<AnyCancellable>()
    //    var _textEditingContext: EditingContext<TextFrameGenerator>? = nil
    var textEditingContext: EditingContext<TextFrameGenerator> {
        if let context = ContextStore.context as? EditingContext<TextFrameGenerator> {
            return context
        }
        
        let drawsana = DrawsanaView()
        
        let context = EditingContext<TextFrameGenerator>(item: self, gifConfig: self.gifConfig, playState: self.playState, frameIncrement: 1, size: self.size, generator: TextFrameGenerator(gif: self, drawsana: drawsana), thumbGenerator: ThumbGenerator(item: self))
        context.mode = .text
        context.gifConfig.hideAnimationQuality = true
        context.gifConfig.assetInfo.size = self.size
        context.gifConfig.assetInfo.duration = self.animatedImage?.duration ?? 0
        
        let fiveSeconds = 5 / context.gifConfig.assetInfo.duration
        context.gifConfig.selection.fiveSecondValue = CGFloat(fiveSeconds)
        context.gifConfig.selection.endTime = 0.1
        ContextStore.context = context
        
        context.textFormat.objectWillChange.sink {
            Async {
                print(context.textFormat.color)
                
                context.generator.drawsana.userSettings.fillColor = context.textFormat.color
                context.generator.drawsana.userSettings.strokeColor = context.textFormat.color
                context.generator.drawsana.userSettings.fontName = context.textFormat.fontName
                
                let shadow = NSShadow()
                if context.textFormat.shadow {
                    shadow.shadowColor = context.textFormat.shadowColor
                    shadow.shadowOffset = CGSize(width: 0, height: context.textFormat.shadowMeasure)
                    shadow.shadowBlurRadius = CGFloat(context.textFormat.shadowMeasure)
                } else {
                    shadow.shadowColor = UIColor.clear
                    shadow.shadowOffset = CGSize(width: 0, height: 0)
                    shadow.shadowBlurRadius = 0
                }
                
                context.generator.drawsana.userSettings.shadow = shadow.copy() as! NSShadow
                
                context.generator.drawsana.userSettings.fontName = context.generator.drawsana.userSettings.fontName.replacingOccurrences(of: "-Bold", with: "")
                
                if context.textFormat.bold {
                    context.generator.drawsana.userSettings.fontName = context.generator.drawsana.userSettings.fontName + "-Bold"
                }
                
                (context.generator.drawsana.tool as? TextTool)?.updateShapeFrame()
            }
            
        }.store(in: &self.cancellables)
        
        return context
    }
    
    //    var _editingContext: EditingContext<ExistingFrameGenerator>? = nil
    var editingContext: EditingContext<ExistingFrameGenerator> {
        if let context = ContextStore.context as? EditingContext<ExistingFrameGenerator> {
            return context
        }
        
        let context = EditingContext<ExistingFrameGenerator>(item: self, gifConfig: self.gifConfig, playState: self.playState, frameIncrement: 1, size: self.size, generator: ExistingFrameGenerator(gif: self), thumbGenerator: ThumbGenerator(item: self))
        context.gifConfig.selection.endTime = 1
        context.gifConfig.hideAnimationQuality = true
        context.gifConfig.assetInfo.size = self.size
        context.gifConfig.assetInfo.duration = self.duration
        
        /*
         
         70 frames
         
         2.5s
         
         fps = 70 / 2.5 = 28
         
         */
        
        if let animated = self.animatedImage {
            let inc = CalculatePercentComplete(start: 0, end: CGFloat((animated.images ?? []).count), current: 1)
            context.frameIncrement = inc
        }
        let fiveSeconds = 5 / context.gifConfig.assetInfo.duration
        context.gifConfig.selection.fiveSecondValue = CGFloat(fiveSeconds)
        ContextStore.context = context
        return context
    }
    #endif
    var id: String
    var creationDate: Date?
    
    let url: URL
    var image: UIImage?
    
    var _thumbnail: UIImage?
    var thumbnail: UIImage?
    var _data: Data?
    var data: Data?
    
    var resizedThumb: UIImage?
    
    var asset: PHAsset?
    
    @Published var editing = false
    
    @Published var gifConfig: GifConfig = GifConfig(assetInfo: AssetInfo.empty)
    
    func thumb(size: CGSize, mode: ContentMode) -> UIImage {
        if let resized = resizedThumb { return resized }
        guard let thumb = self.thumbnail else { fatalError() }
        
        if thumb.size == size {
            resizedThumb = thumb
            return thumb
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let imageFrame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        if mode == .fill {
            var r = CGRect(x: 0, y: 0, width: thumb.size.width, height: thumb.size.height)
            r.center = imageFrame.center
            thumb.draw(in: r)
        } else {
            let scaled = thumb.size.scaledToFit(size)
            var r = CGRect(x: 0, y: 0, width: scaled.width, height: scaled.height)
            r.center = imageFrame.center
            thumb.draw(in: r)
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        self.resizedThumb = image
        return image
    }
    
    var aspectRatio: CGFloat? {
        if let thumb = self.thumbnail {
            let size = thumb.size
            return size.width / size.height
        } else if let data = self.data, let img = UIImage(data: data) {
            let size = img.size
            return size.width / size.height
        }
        return nil
    }
    
    var _duration: Double = 0
    var duration: Double {
        if self._duration != 0 { return self._duration }
        
        #if os(iOS)
        if let data = self.getDataSync(), let decoder = YYImageDecoder(data: data, scale: 1) {
            var dur: Double = 0
            
            for x in 0..<decoder.frameCount {
                dur += decoder.frameDuration(at: x)
            }
            
            self._duration = dur
            return dur
        }
        #endif
        return 0
    }
    
    func getDataSync() -> Data? {
        if let data = self.data {
            return data
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var foundData: Data?
        let isSync = self.getData { data, _, sync in
            
            foundData = data
            if !sync {
                semaphore.signal()
            }
        }
        
        if !isSync {
            semaphore.wait()
        }
        
        return foundData
    }
    
    @discardableResult
    func getData(done: @escaping (_ data: Data?, _ context: GIF, _ synchronous: Bool) -> Void) -> Bool {
        return false
    }
    

    init(id: String, url: URL) {
        self.id = id
        self.creationDate = nil
        self.url = url
        self.image = nil
        self._thumbnail = nil
        self.thumbnail = nil
        self.asset = nil
        
        self.preferredSource = .url
    }
    
    init?(url: URL, thumbnail: UIImage? = nil, image: UIImage? = nil, asset: PHAsset? = nil, id: String) {
        guard url != nil || thumbnail != nil || image != nil || asset != nil else {
            return nil
        }
        self.url = url
        self._thumbnail = thumbnail
        self.image = image
        self.id = id
        self.asset = asset
        
        if asset != nil {
            self.preferredSource = .data
        }
        
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let date = attr[FileAttributeKey.creationDate] as? Date {
            self.creationDate = date
        }
    }
    
    static func == (lhs: GIF, rhs: GIF) -> Bool {
        return lhs.id == rhs.id
    }
}
