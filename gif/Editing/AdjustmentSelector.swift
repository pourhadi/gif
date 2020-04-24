//
//  AdjustmentSelector.swift
//  gif
//
//  Created by Daniel Pourhadi on 2/6/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI

struct SelectorItem: View {
    
    let type: AdjustmentType
    let selected: Bool
    @Binding var visible: Bool
    var body: some View {
//        VStack {
        Image.symbol(self.type.symbol, .init(scale: .large))?
            .renderingMode(.template)
            .foregroundColor(self.selected ? Color.accent : Color.primary.opacity(0.8))

                .frame(height: 60)

//            Text(self.type.name).font(.footnote)

//        }

        .padding([.top, .bottom], 12)
        .scaledToFill()
        .frame(width: 60)
            .scaleEffect(self.selected ? 1.15 : 1)
        .zIndex(self.selected ? 1 : 0)
        .shadow(radius: self.selected ? 3 : 0)
            
        .animation(Animation.default.delay(0))
        .modifier(SlideUpModifier(visible: self.$visible, delay: 0.2 + (Double(AdjustmentType.allCases.firstIndex(of: self.type)!) / 10)))
        .background(Color.background)

    }
    
}

struct AdjustmentSelector: View {
    @State var visible = false
    
    @Binding var selectedType: AdjustmentType
    
    @State var selectedIndex: Int = 0
    
    let width: CGFloat
    
    @Binding var touchDown : Bool
    
    var body: some View {
        
        SlidingMenuView(items: self.getRenderedButtons(), itemWidth: 80, selectedIndex: self.$selectedIndex, touchDown: self.$touchDown) { x in
            
            self.selectedType = AdjustmentType.allCases[x]
                HapticController.shared.selectionHaptic()
        }
        .onAppear {
            Delayed(0.2) {
                self.visible = true
            }
        }
        .frame(height: 80)
        .mask(LinearGradient(gradient: self.fadedEdgeGradient, startPoint: UnitPoint.leading, endPoint: UnitPoint.trailing))
        /*
        //        GeometryReader { metrics in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                Spacer(minLength: self.width * 0.2)
                self.renderedButtons
                Spacer(minLength: self.width * 0.2)
            }.onAppear {
                Delayed(0.2) {
                    self.visible = true
                }
            }
            
        }
        .mask(LinearGradient(gradient: self.fadedEdgeGradient, startPoint: UnitPoint.leading, endPoint: UnitPoint.trailing))
        */
    }
    
    func getRenderedButtons() -> [SelectorItem] {
        return AdjustmentType.allCases.map { x in
            
            SelectorItem(type: x, selected: self.selectedType == x, visible: self.$visible)
            
            
            
        }
    }
    
    var renderedButtons: some View {
        ForEach(AdjustmentType.allCases) { (x: AdjustmentType) in
            
            Button(action: {
                self.selectedType = x
            }, label: {
                VStack {
                    Image.symbol(x.symbol)
                    Text(x.name).font(.footnote)
                }
                .foregroundColor(self.selectedType == x ? Color.accent : Color.white.opacity(0.5))
                .padding([.top, .bottom], 12)
                    
                    //                        .padding(.bottom, self.bottomPadding)
                    //                        .background(Color(white: self.selectedType == AdjustmentType.allCases[x] ? 0.2 : 0.1).frame(width: 80))
                    .scaledToFill()
            })
                .frame(width: 80)
                .scaleEffect(self.selectedType == x ? 1.15 : 1)
                .zIndex(self.selectedType == x ? 1 : 0)
                .shadow(radius: self.selectedType == x ? 3 : 0)
                
                .animation(Animation.default.delay(0))
                .modifier(SlideUpModifier(visible: self.$visible, delay: 0.2 + (Double(AdjustmentType.allCases.firstIndex(of: x)!) / 10)))
            
        }
    }
    
    var fadedEdgeGradient: Gradient {
        return Gradient(stops: [Gradient.Stop(color: Color.clear, location: 0),
                                Gradient.Stop.init(color: Color.black, location: 0.2),
                                Gradient.Stop.init(color: Color.black, location: 0.8),
                                Gradient.Stop.init(color: Color.clear, location: 1)])
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
                    .any,
                
                
                Button(action: {
                    self.selectedType = .vibrance
                }, label: {
                    VStack {
                        Image.symbol("triangle.lefthalf.fill").rotationEffect(.degrees(180))
                        Text("Vibrance").font(.footnote)
                    }
                })
                    .foregroundColor(self.selectedType == .vibrance ? Color.accent : Color.white)
                    .any
            
            
            //
        ]
    }
}



struct AdjustmentSelector_Previews: PreviewProvider {
    @State static var selectedAdjustment = AdjustmentType.brightness
    @State static var touchDown = false
    static var previews: some View {
        EditNavView(title: "Test", leadingItem: EmptyView().any, trailingItem: EmptyView().any) {
            GeometryReader { metrics in
                VStack {
                    Spacer()
                    AdjustmentSelector(selectedType: self.$selectedAdjustment, width: metrics.size.width, touchDown: self.$touchDown)
                        .frame(width: metrics.size.width, height: 80 + metrics.safeAreaInsets.bottom).edgesIgnoringSafeArea(.bottom)
                    
                }
                
            }
            .edgesIgnoringSafeArea(.bottom)
            
            
        }
        //        .edgesIgnoringSafeArea(.bottom)
        
    }
    
}
