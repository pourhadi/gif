//
//  ImageAdjustmentView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/19/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Combine
import CoreImage
import SnapKit
import SwiftUI
import UIKit
import CoreGraphics
import YYImage


enum AdjustmentType: Int, CaseIterable {
    case brightness
    case contrast
    case saturation
    case hue
    case highlights
    case shadows
    case bloom
    case exposure
    case vibrance
    
    var resetValue: Double {
        switch self {
        case .brightness: return 0
        case .contrast: return 1
        case .saturation: return 1
        case .hue: return 0
        case .highlights: return 1
        case .shadows: return 0
        case .bloom: return 0
        case .exposure: return 0.5
        case .vibrance: return 0
        }
    }
    
    var name: String {
        return "\(self)".capitalized
    }
    
    var symbol: String {
        switch self {
        case .brightness: return "sun.max.fill"
        case .contrast: return "circle.righthalf.fill"
        case .saturation: return "paintbrush.fill"
        case .hue: return "eyedropper.halffull"
        case .highlights: return "h.circle"
        case .shadows: return "s.circle"
        case .bloom: return "b.circle"
        case .exposure: return "plusminus.circle"
        case .vibrance: return "triangle.lefthalf.fill"
        }
    }
}

class ImageEditor: ObservableObject {
    
    
    @Published var values = [AdjustmentType: Double]()
    
    func reset() {
//        self.brightness = 0
//        self.contrast = 1
//        self.saturation = 1
//        self.hue = 0
//        self.highlights = 1
//        self.shadows = 0
//        self.bloom = 0
//        self.exposure = 0.5
        
        for type in AdjustmentType.allCases {
            self.values[type] = type.resetValue
        }
    }
    
    var originalImages = [UIImage]()
    @Published var images: [UIImage] = []
    
    @Published var duration: Double = 0
    
//    @Published var brightness: Double = 0
//
//    @Published var contrast: Double = 1
//
//    @Published var saturation: Double = 1
//
//    @Published var hue: Double = 0
//
//    @Published var highlights: Double = 1
//
//    @Published var shadows: Double = 0
//
//    @Published var bloom : Double = 0
//
//    @Published var exposure: Double = 0.5
    
    @Published var editing: Bool = false
    
    @Published var reloading: Bool = false
    

    
    
    let originalPreviewImage: UIImage
    @Published var previewImage: UIImage?
    
    
    var cancellables = Set<AnyCancellable>()
    
    let context: CIContext
    
    var renderedImage = PassthroughSubject<UIImage, Never>()
    
    var animating = true
    
    var changeCounter = 0 {
        didSet {
            print(self.changeCounter)
        }
    }
    
    var cancellable: AnyCancellable? = nil
    
    var frameCount = 0
    
    init(gif: GIF) {

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        
        self.context = CIContext(mtlDevice: device)
        
        //        if let animated = gif.animatedImage {
        //            self.duration = animated.duration
        //            self.originalImages = animated.images ?? []
        //            self.images = animated.images ?? []
        //        }
        
        
        self.originalPreviewImage = gif.thumbnail!
        self.previewImage = self.originalPreviewImage
        
        for type in AdjustmentType.allCases {
            self.values[type] = type.resetValue
        }
        
        if let data = gif.getDataSync() {
            var _count = 0
            CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] (x, cgImage, done) in
                guard let weakSelf = self else {
                    done.pointee = true
                    return
                }
                
                if !weakSelf.animating {
                    done.pointee = true
                    return
                }
                
                if weakSelf.frameCount == 0 {
                    if x == 0 {
                        if _count > 0 {
                            weakSelf.frameCount = _count
                        } else {
                            _count += 1
                        }
                    } else {
                        _count += 1
                    }
                }
                
                let uiImage = UIImage(cgImage: cgImage)
                if let output = weakSelf.outputImage(for: uiImage), let cgImage = weakSelf.context.createCGImage(output, from: output.extent) {
                    let newImg = UIImage(cgImage: cgImage)
                    
                    if weakSelf.rendering && weakSelf.frameCount > 0 {
                        if weakSelf.savedVersions.count == weakSelf.frameCount {
                            let allSaved = weakSelf.savedVersions.allSatisfy { (_, val) -> Bool in
                                val == weakSelf.changeCounter
                            }
                            
                            if allSaved {
                                weakSelf.rendering = false
                                weakSelf.rendered = true
                                done.pointee = true
                            }
                        }
                        
                        
//                        if weakSelf.images.count == 0 {
//                            if x == 0 {
//                                weakSelf.images.append(newImg)
//                            }
//                        } else {
//                            if x == 0 {
//                                weakSelf.rendering = false
//                                weakSelf.rendered = true
//
//                                done.pointee = true
//                            } else {
//                                weakSelf.images.append(newImg)
//                            }
//                        }
                    }
                    
                    weakSelf.save(image: newImg, idx: x)
                    weakSelf.renderedImage.send(newImg)
                }
            }
        }
        
        try? FileManager.default.removeItem(at: self.cacheDir)
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true, attributes: nil)
        
        self.cancellable = self.$values.sink { [weak self] _ in
            self?.changeCounter += 1
        }
    }
    
    let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("edited")
    
    var savedVersions = [Int: Int]()
    
    func save(image: UIImage, idx: Int) {
        let change = self.changeCounter

        DispatchQueue.global().async { [weak self] in
            guard let weakSelf = self else { return }
            
            
            func toFile() {
                if let data = image.yy_imageDataRepresentation() {
                    do {
                        try data.write(to: weakSelf.cacheDir.appendingPathComponent("\(idx).jpg"))
                        weakSelf.savedVersions[idx] = change
                        print("wrote file: \(idx)")
                    } catch {
                        print("error writing file")
                    }
                    
                }
            }
            
            if let version = weakSelf.savedVersions[idx] {
                
                if version != change {
                    try? FileManager.default.removeItem(at: weakSelf.cacheDir.appendingPathComponent("\(idx).jpg"))
                    
                    toFile()
                }
            } else {
                toFile()
            }
        }
        
    }
    @Published var rendered = false
    
    var rendering = false
    
    func createRenderedGif(for gif: GIF) -> AnyPublisher<GIF?, Never> {
        
        self.rendering = true
        return self.$rendered
            .first(where: { $0 })
            .map { _ in
                var urls = [URL]()
                
                for x in 0..<self.frameCount {
                    urls.append(self.cacheDir.appendingPathComponent("\(x).jpg"))
                }
                return urls
                
        }
        .flatMap { images in
            
            return generateGif(urls: images, filename: "edited.gif", frameDelay: gif.duration / Double(images.count))
        }
        .map { url -> GIF? in
            if let url = url, let data = try? Data(contentsOf: url) {
                let newGif = GIFFile(id: UUID().uuidString, url: url)
                newGif.data = data
                return newGif
            }
            return nil
        }.eraseToAnyPublisher()
        
    }
    
    func rerenderAll() {
        DispatchQueue.global().async {
            var results = [UIImage]()
            
            for image in self.originalImages {
                if let out = self.outputImage(for: image), let cgImage = self.context.createCGImage(out, from: out.extent) {
                    results.append(UIImage(cgImage: cgImage))
                }
            }
            
            Async {
                self.images = results
                self.reloading = false
            }
            
            
        }
    }
    
    
    let colorControls = CIFilter(name: "CIColorControls")
    let hueControl = CIFilter(name: "CIHueAdjust")
    let highlightsShadowsControls = CIFilter(name: "CIHighlightShadowAdjust")
    let bloomControls = CIFilter(name: "CIBloom")
    let exposureControls = CIFilter(name: "CIExposureAdjust")
    let vibranceControls = CIFilter(name: "CIVibrance")
    
    func outputImage(for image: UIImage) -> CIImage? {
        let original = CIImage(image: image)
        self.colorControls?.setValue(original, forKey: kCIInputImageKey)
        self.colorControls?.setValue(self.values[.saturation], forKey: kCIInputSaturationKey)
        self.colorControls?.setValue(self.values[.brightness], forKey: kCIInputBrightnessKey)
        self.colorControls?.setValue(self.values[.contrast], forKey: kCIInputContrastKey)
        
        self.hueControl?.setValue(self.colorControls?.outputImage, forKey: kCIInputImageKey)
        self.hueControl?.setValue(Angle(degrees: self.values[.hue] ?? 0).radians, forKey: kCIInputAngleKey)
        
        self.highlightsShadowsControls?.setValue(self.hueControl?.outputImage, forKey: kCIInputImageKey)
        self.highlightsShadowsControls?.setValue(self.values[.highlights], forKey: "inputHighlightAmount")
        self.highlightsShadowsControls?.setValue(self.values[.shadows], forKey: "inputShadowAmount")
        
        self.bloomControls?.setValue(self.highlightsShadowsControls?.outputImage, forKey: kCIInputImageKey)
        self.bloomControls?.setValue(self.values[.bloom], forKey: kCIInputIntensityKey)
        
        self.exposureControls?.setValue(self.bloomControls?.outputImage, forKey: kCIInputImageKey)
        self.exposureControls?.setValue(self.values[.exposure], forKey: kCIInputEVKey)
        
        self.vibranceControls?.setValue(self.exposureControls?.outputImage, forKey: kCIInputImageKey)
        self.vibranceControls?.setValue(self.values[.vibrance], forKey: kCIInputAmountKey)
        
        return self.vibranceControls?.outputImage
    }
    
    func rerenderPreview() {
        
        if let out = self.outputImage(for: self.originalPreviewImage), let cgImage = self.context.createCGImage(out, from: out.extent) {
            self.previewImage = UIImage(cgImage: cgImage)
        }
        
    }
}

struct RenderedImageView : View {
    
    let imageEditor : ImageEditor
    
    @State var image: UIImage? = nil
    
    var body: some View {
        Group {
            
            if self.image != nil {
                Image(uiImage: self.image!).resizable()
            } else {
                Image(uiImage: self.imageEditor.originalPreviewImage).resizable()
            }
            
        }.onReceive(self.imageEditor.renderedImage) { (image) in
            self.image = image
        }
    }
    
}

class AnimatedUIImageView: UIView {
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
}

struct AnimationDefinition {
    var images: [UIImage]
    var duration: Double
}

struct AnimatedImageSetView: UIViewRepresentable {
    var animation: AnimationDefinition
    
    func makeUIView(context: UIViewRepresentableContext<AnimatedImageSetView>) -> AnimatedUIImageView {
        let v = AnimatedUIImageView()
        return v
    }
    
    func updateUIView(_ uiView: AnimatedUIImageView, context: UIViewRepresentableContext<AnimatedImageSetView>) {
        uiView.imageView.animationImages = self.animation.images
        uiView.imageView.animationDuration = self.animation.duration
        uiView.imageView.startAnimating()
    }
    
    typealias UIViewType = AnimatedUIImageView
}




struct ImageAdjustmentView: View {
    class Store {
        var originalValue: Double? = nil
    }
    
    var store = Store()
    
    var gif: GIF
    
    @State var visible = false
    
    @State var animated = true
    
    @ObservedObject var editor: ImageEditor
    
    @State var selectedAdjustment = AdjustmentType.brightness
    
    @State var animation: AnimationDefinition
    
    @State var changeMade = false
    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    
    @State var compact = false
    
    init(gif: GIF, editor: ImageEditor) {
        self.gif = gif
        self.editor = editor
        
        self._animation = State<AnimationDefinition>(initialValue: AnimationDefinition(images: editor.images, duration: editor.duration))
    }
    
    var value: Binding<Double> {
        return Binding<Double>(get: { () -> Double in
            return self.editor.values[self.selectedAdjustment] ?? 0
        }) { val in
            self.editor.values[self.selectedAdjustment] = val
        }
    }
    
    
    
    var body: some View {
        GeometryReader { metrics in
            
            VStack {
                Spacer()
                
                RenderedImageView(imageEditor: self.editor)
                    .aspectRatio(self.gif.aspectRatio ?? 1, contentMode: .fit)
                    .frame(width: metrics.size.width)
                
                    .gesture(DragGesture().onEnded({ (_) in
                        self.store.originalValue = nil
                    }).onChanged { (val: DragGesture.Value) in
                        if self.store.originalValue == nil {
                            self.store.originalValue = self.value.wrappedValue
                        }
                        
                        let width = metrics.size.width
                        let percent = CalculatePercentComplete(start: 0, end: width, current: abs(val.translation.width))
                                                
                        if val.translation.width < 0 {
                            self.value.wrappedValue = self.store.originalValue! - Double(percent)
                        } else {
                            self.value.wrappedValue = self.store.originalValue! + Double(percent)
                        }
                    })
                
                Spacer()
                Spacer()
                VStack(spacing: 8) {
                    Text(self.selectedAdjustment.name.uppercased())

                        .font(.subheadline)
                        .foregroundColor(Color.text)
                        .brightness(-0.3)
                    .scaledToFill()
                        .noAnimations()

                        .modifier(PopModifier(visible: self.$visible, delay: 0.2))

                    if !self.compact {
                    Text("\(Int((self.editor.values[self.selectedAdjustment] ?? 0) * 100))")

                        .font(.headline)
                        .foregroundColor(Color.text)
                        .scaledToFill()

                        .noAnimations()

                    .modifier(PopModifier(visible: self.$visible, delay: 0.3))
                    }
                    
                }.animation(nil)
                
                    

                    
                    
                    Group {
                        if self.selectedAdjustment == .brightness {
                            Slider(value: self.value, in: -1...1, onEditingChanged: { _ in
                                self.changeMade = true
                            })
                        } else if self.selectedAdjustment == .contrast {
                            Slider(value: self.value, in: -1...3, onEditingChanged: { _ in
                                self.changeMade = true
                                
                            })
                        } else if self.selectedAdjustment == .saturation {
                            Slider(value: self.value, in: -1...3, onEditingChanged: { _ in
                                self.changeMade = true
                                
                            })
                        } else if self.selectedAdjustment == .hue {
                            Slider(value: self.value, in: -180...180, onEditingChanged: { _ in
                                self.changeMade = true
                                
                            })
                        } else if self.selectedAdjustment == .highlights {
                            Slider(value: self.value, in: -1...2, onEditingChanged: { _ in
                                self.changeMade = true
                            })
                        } else if self.selectedAdjustment == .shadows {
                            Slider(value: self.value, in: -1...1, onEditingChanged: { _ in
                                self.changeMade = true
                            })
                        } else if self.selectedAdjustment == .bloom {
                            Slider(value: self.value, in: 0...1, onEditingChanged: { _ in
                                self.changeMade = true
                            })
                        } else if self.selectedAdjustment == .exposure {
                            Slider(value: self.value, in: -1...2, onEditingChanged: { _ in
                                self.changeMade = true
                            })
                        } else if self.selectedAdjustment == .vibrance {
                            Slider(value: self.value, in: -2...2, onEditingChanged: { _ in
                                self.changeMade = true
                            })
                        }
                        
                    }
                        
                    .padding([.leading, .trailing], 20)
                        
                    .modifier(PopModifier(visible: self.$visible, delay: 0.5))
                
                if !self.compact {
                    Button(action: {
                        self.editor.values[self.selectedAdjustment] = self.selectedAdjustment.resetValue
                    }, label: { Text("Reset") })
                        .opacity(self.editor.values[self.selectedAdjustment] != self.selectedAdjustment.resetValue ? 1 : 0.5)
                        .padding(12)
                        .modifier(PopModifier(visible: self.$visible, delay: 0.4))
                    
                    
                    AdjustmentSelector(selectedType: self.$selectedAdjustment, width: metrics.size.width)
                        .frame(width: metrics.size.width)
                }
                
            }
            .frame(height:metrics.size.height)
            
        }
        .navigationBarTitle("Adjust", displayMode: .inline)
            
        .onReceive(self.editor.$images) { images in
            self.animation = AnimationDefinition(images: images, duration: self.editor.duration)
        }
        .onAppear {
            Delayed(0.2) {
                self.visible = true
            }
        }
        .onReceive(self.deviceDetails.$compact) { (compact) in
            self.$compact.animation(Animation.default).wrappedValue = compact
        }

    }
}

 struct ImageAdjustmentView_Previews: PreviewProvider {
//    static let gif = GIFFile(url: Bundle.main.url(forResource: "3", withExtension: "gif")!, thumbnail: nil, image: nil, asset: nil, id: "1")!
    
    @State static var selectedAdjustment = AdjustmentType.brightness
    static var previews: some View {
        EditNavView(title: "Test", leadingItem: EmptyView().any, trailingItem: EmptyView().any) {
            GeometryReader { metrics in
                VStack {
                    Spacer()
//                    AdjustmentSelector(selectedType: self.$selectedAdjustment, bottomPadding: metrics.safeAreaInsets.bottom)
//                    .frame(width: metrics.size.width, height: 80 + metrics.safeAreaInsets.bottom).edgesIgnoringSafeArea(.bottom)                }
                }
            }
            .edgesIgnoringSafeArea(.bottom)


        }
//        .edgesIgnoringSafeArea(.bottom)

    }
 }
