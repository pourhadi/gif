//
//  Cropping.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/8/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI



struct CropControlView<Content>: View where Content: View {
    let content: () -> Content
    
    init(touchDownBlock: ((Bool) -> Void)? = nil, @ViewBuilder maskedContent: @escaping () -> Content) {
        self.touchDownBlock = touchDownBlock
        self.content = maskedContent
    }
    
    @EnvironmentObject var state: CropState
    
    @State var tmpInsets = EdgeInsets.zero
    
    @State var tmpFrame = CGRect.zero
    
    @State var size = CGSize.zero
    
    @State var originalFrame = CGRect.zero
    
    @GestureState var gestureState: EdgeInsets? = nil
    
    let touchDownBlock: ((Bool) -> Void)?
    var body: some View {
        GeometryReader { outmetrics in
            
            ZStack {
                GeometryReader { _ in
                    
                    self.content().mask(Color.background.padding(self.gestureState ?? self.state.inset).cornerRadius(15))
                    //                .position(x: outmetrics.size.width / 2, y: outmetrics.size.height / 2)
                    
                    GeometryReader { metrics in
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white,
                                    style: StrokeStyle(lineWidth: 2,
                                                       lineCap: .square,
                                                       lineJoin: .round,
                                                       miterLimit: 0,
                                                       dash: [5],
                                                       dashPhase: 0))
                            .shadow(color: Color.black.opacity(1), radius: 1, x: 2, y: 2)
                            
                            .zIndex(0).onAppear {
                                self.size = outmetrics.size
                                self.originalFrame = metrics.frame(in: .global)
                            }
                        
                        self.rect(for: .topLeading, metrics: metrics)
                        self.rect(for: .topTrailing, metrics: metrics)
                        self.rect(for: .bottomLeading, metrics: metrics)
                        self.rect(for: .bottomTrailing, metrics: metrics)
                        
                    }.coordinateSpace(name: "a").padding(self.gestureState ?? self.state.inset)
                    //                .position(x: outmetrics.size.width / 2, y: outmetrics.size.height / 2)
                }.aspectRatio(self.state.aspectRatio, contentMode: .fit)
            }
            .transformAnchorPreference(key: CropPreferenceKey.self, value: .topLeading, transform: { val, anchor in
                val.contentTopLeading = anchor
            })
            .transformAnchorPreference(key: CropPreferenceKey.self, value: .bottomTrailing, transform: { val, anchor in
                val.contentBottomTrailing = anchor
            })
            .transformAnchorPreference(key: CropPreferenceKey.self, value: .bounds, transform: { val, anchor in
                val.contentBounds = anchor
            })
            .frame(width: outmetrics.size.width, height: outmetrics.size.height, alignment: .center)
                .overlayPreferenceValue(CropPreferenceKey.self) { (val: CropPreferenceData) in
                GeometryReader { metrics -> AnyView in
                    self.getDragGesture(overlayMetrics: metrics, outmetrics: outmetrics, vals: val).any
                }.any
                
            }.zIndex(0)
        }
    }
    
    func getDragGesture(overlayMetrics: GeometryProxy, outmetrics: GeometryProxy, vals: CropPreferenceData) -> some View {
//        let contentTopLeading = outmetrics[vals.contentTopLeading!]
//        let contentBottomTrailing = outmetrics[vals.contentBottomTrailing!]
//
        return GeometryReader { _ in
            
            Rectangle().fill(Color.clear)
            
        }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 10, coordinateSpace: .global).updating(self.$gestureState, body: { val, state, tx in
            
            self.touchDownBlock?(true)
            
            tx.isContinuous = true
            
            var insets = EdgeInsets.zero
            
            let selectionFrame = outmetrics.frame(in: .global).inset(by: (self.state.inset + self.tmpInsets).uiEdgeInsets())
            
            var location = val.startLocation
            location.x -= selectionFrame.origin.x
            location.y -= selectionFrame.origin.y
            
            let size = selectionFrame.size
            
            if location.x > size.width / 2 {
                insets.trailing = -val.translation.width
                
            } else {
                insets.leading = val.translation.width
            }
            
            if location.y > size.height / 2 {
                insets.bottom = -val.translation.height
            } else {
                insets.top = val.translation.height
            }
            
            let sum = insets + self.state.inset
            
            if sum.top < 0 {
                insets.top += -sum.top
            }
            
            if sum.leading < 0 {
                insets.leading += -sum.leading
            }
            
            if sum.bottom < 0 {
                insets.bottom += -sum.bottom
            }
            
            if sum.trailing < 0 {
                insets.trailing += -sum.trailing
            }
            
            self.state.tmpInset = insets
            state = insets + self.state.inset
            
            let contentBounds = outmetrics[vals.contentBounds!]
            
            let unitInsets = self.state.inset.unitSpaceInsets(actualSize: contentBounds.size)
            self.state.cropUnitRect = CGRect(x: 0, y: 0, width: 1, height: 1).inset(by: unitInsets.uiEdgeInsets())
        }).onEnded { _ in
            self.state.inset = self.state.inset + self.state.tmpInset
            
            let contentBounds = outmetrics[vals.contentBounds!]
                       
                       let unitInsets = self.state.inset.unitSpaceInsets(actualSize: contentBounds.size)
                       self.state.cropUnitRect = CGRect(x: 0, y: 0, width: 1, height: 1).inset(by: unitInsets.uiEdgeInsets())
            self.touchDownBlock?(false)
            
        })
    }
    
    func rect(for alignment: Alignment, metrics: GeometryProxy) -> some View {
        let size = metrics.frame(in: .named("a")).size
        
        return Circle()
            .fill(Color.clear)
            .frame(width: 30, height: 30)
            .transformAnchorPreference(key: CropPreferenceKey.self, value: .bounds) { v, a in
                v.bounds[alignment.unitPoint] = a
            }

            .scaledToFill()
            .background(Circle().fill(Color.white).scaleEffect(0.5, anchor: alignment.unitPoint)            .shadow(color: Color.black.opacity(0.5),
                    radius: 2, x: 0, y: 0))
            .frame(width: size.width,
                   height: size.height,
                   alignment: alignment)
    }
}

struct PreviewCroppingView<Generator>: View where Generator: GifGenerator {
    @EnvironmentObject var context: EditingContext<Generator>
    
    var body: some View {
        NavigationView {
            ZStack {
                PreviewView<Generator>().environmentObject(self.context.generator)
                VisualEffectView.blur(.dark).zIndex(1)
                CropControlView {
                    PreviewView<Generator>().environmentObject(self.context.generator)
                }.environmentObject(self.context.cropState)
                    .zIndex(2)
            }
            
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct GIFCroppingView: View {
    var croppingGIF: GIF?
    
    @State var animating = true
    
    var body: some View {
        ZStack {
            
            AnimatedGIFView(gif: self.croppingGIF!, animated: self.$animating).blur(radius: 5)
            
            Rectangle().fill(Color.background.opacity(0.6)).zIndex(1)
            
            CropControlView(touchDownBlock: { down in
                
                
            }) {
                AnimatedGIFView(gif: self.croppingGIF!, animated: self.$animating)
                
            }.environmentObject(self.croppingGIF!.cropState!)
                .zIndex(2)
            
        }
    }
}

struct Cropping_Previews: PreviewProvider {
    static let gif = GIFFile(url: Bundle.main.url(forResource: "1", withExtension: ".gif")!, id: "test")!
    
    static let cropState = CropState(aspectRatio: 1)
    
    static var previews: some View {
        EmptyView()
        //        CroppingView().environmentObject(cropState).environment(\.colorScheme, .dark)
    }
}
