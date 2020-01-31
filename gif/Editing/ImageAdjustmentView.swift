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
    
    init(gif: GIF) {
        
        for type in AdjustmentType.allCases {
            self.values[type] = type.resetValue
        }
        
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
        
        
        if let data = gif.getDataSync() {
            CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] (x, cgImage, done) in
                guard let weakSelf = self else {
                    done.pointee = true
                    return
                }
                
                if !weakSelf.animating {
                    done.pointee = true
                    return
                }
                
                let uiImage = UIImage(cgImage: cgImage)
                if let output = weakSelf.outputImage(for: uiImage), let cgImage = weakSelf.context.createCGImage(output, from: output.extent) {
                    let newImg = UIImage(cgImage: cgImage)
                    
                    if weakSelf.rendering {
                        if weakSelf.images.count == 0 {
                            if x == 0 {
                                weakSelf.images.append(newImg)
                            }
                        } else {
                            if x == 0 {
                                weakSelf.rendering = false
                                weakSelf.rendered = true
                                
                                done.pointee = true
                            } else {
                                weakSelf.images.append(newImg)
                            }
                        }
                    }
                    
                    
                    weakSelf.renderedImage.send(newImg)
                }
            }
        }
        
        
    }
    
    
    @Published var rendered = false
    
    var rendering = false
    
    func createRenderedGif(for gif: GIF) -> AnyPublisher<GIF?, Never> {
        
        self.rendering = true
        return self.$rendered
            .first(where: { $0 })
            .map { _ in self.images }
            .flatMap { images in
                
                return generateGif(photos: images, filename: "edited.gif", frameDelay: gif.duration / Double(images.count))
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
        
        return self.exposureControls?.outputImage
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



struct AdjustmentSelector: View {
    @State var visible = false
    
    @Binding var selectedType: AdjustmentType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Spacer()
                
                ForEach(0..<self.buttons.count) { x in
                    
                    self.buttons[x]
                        .modifier(SlideUpModifier(visible: self.$visible, delay: 0.2 + (Double(x) / 10)))
                    
                    Spacer()
                }
            }.onAppear {
                Delayed(0.2) {
                    self.visible = true
                }
            }.padding([.top, .bottom], 10)
                .scaledToFill()
        }
        
    }
    
    var buttons: [AnyView] {
        return [Button(action: {
            self.selectedType = .brightness
        }, label: {
            VStack {
                Image.symbol("sun.max.fill")
                Text("Brightness").font(.footnote)
            }
        })
            .foregroundColor(self.selectedType == .brightness ? Color.accent : Color.white)
            
            
            .any,
                
                Button(action: {
                    self.selectedType = .contrast
                }, label: {
                    VStack {
                        Image.symbol("circle.righthalf.fill")
                        Text("Contrast").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .contrast ? Color.accent : Color.white).any,
                
                Button(action: {
                    self.selectedType = .saturation
                }, label: {
                    VStack {
                        Image.symbol("paintbrush.fill")
                        Text("Saturation").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .saturation ? Color.accent : Color.white).any,
                
                Button(action: {
                    self.selectedType = .hue
                }, label: {
                    VStack {
                        Image.symbol("eyedropper.halffull")
                        Text("Hue").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .hue ? Color.accent : Color.white).any,
                
                Button(action: {
                    self.selectedType = .highlights
                }, label: {
                    VStack {
                        Image.symbol("h.circle")
                        Text("Highlights").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .highlights ? Color.accent : Color.white)
                    .any,
                
                Button(action: {
                    self.selectedType = .shadows
                }, label: {
                    VStack {
                        Image.symbol("s.circle")
                        Text("Shadows").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .shadows ? Color.accent : Color.white)
                    .any,
                
                Button(action: {
                    self.selectedType = .bloom
                }, label: {
                    VStack {
                        Image.symbol("b.circle")
                        Text("Bloom").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .bloom ? Color.accent : Color.white)
                    .any,
                
                Button(action: {
                    self.selectedType = .exposure
                }, label: {
                    VStack {
                        Image.symbol("plusminus.circle")
                        Text("Exposure").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .exposure ? Color.accent : Color.white)
                    .any
            
            
            
        ]
    }
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
    
    init(gif: GIF, editor: ImageEditor) {
        self.gif = gif
        self.editor = editor
        
        self._animation = State<AnimationDefinition>(initialValue: AnimationDefinition(images: editor.images, duration: editor.duration))
    }
    
    var value: Binding<Double> {
        return Binding<Double>(get: { () -> Double in
            if self.selectedAdjustment == .brightness {
                return self.editor.brightness
            } else if self.selectedAdjustment == .contrast {
                return self.editor.contrast
            } else if self.selectedAdjustment == .saturation {
                return self.editor.saturation
            } else if self.selectedAdjustment == .hue {
                return self.editor.hue
            } else if self.selectedAdjustment == .highlights {
                return self.editor.highlights
            } else if self.selectedAdjustment == .shadows {
                return self.editor.shadows
            } else if self.selectedAdjustment == .bloom {
                return self.editor.bloom
            } else if self.selectedAdjustment == .exposure {
                return self.editor.exposure
            }
            
            return 0
        }) { val in
            if self.selectedAdjustment == .brightness {
                self.editor.brightness = val
            } else if self.selectedAdjustment == .contrast {
                self.editor.contrast = val
            } else if self.selectedAdjustment == .saturation {
                self.editor.saturation = val
            } else if self.selectedAdjustment == .hue {
                self.editor.hue = val
            } else if self.selectedAdjustment == .highlights {
                self.editor.highlights = val
            } else if self.selectedAdjustment == .shadows {
                self.editor.shadows = val
            } else if self.selectedAdjustment == .bloom {
                self.editor.bloom = val
            } else if self.selectedAdjustment == .exposure {
                self.editor.exposure = val
            }
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
                    }
                    
                }
                .padding([.leading, .trailing], 40)
                .padding(.bottom, 20)
                
                AdjustmentSelector(selectedType: self.$selectedAdjustment).frame(width: metrics.size.width)
            }
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
    }
}

// struct ImageAdjustmentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ImageAdjustmentView(gif: GIFFile(url: Bundle.main.url(forResource: "1", withExtension: "gif")!, thumbnail: nil, image: nil, asset: nil, id: "1")!).colorScheme(.dark)
//    }
// }
