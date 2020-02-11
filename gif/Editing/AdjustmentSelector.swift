//
//  AdjustmentSelector.swift
//  gif
//
//  Created by Daniel Pourhadi on 2/6/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI

struct AdjustmentSelector: View {
    @State var visible = false
    
    @Binding var selectedType: AdjustmentType
    
    let width: CGFloat
    
    var body: some View {
        
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
        
    }
    
    var renderedButtons: some View {
        ForEach(0..<AdjustmentType.allCases.count) { x in
            
            Button(action: {
                self.selectedType = AdjustmentType.allCases[x]
            }, label: {
                VStack {
                    Image.symbol(AdjustmentType.allCases[x].symbol)
                    Text(AdjustmentType.allCases[x].name).font(.footnote)
                }
                .foregroundColor(self.selectedType == AdjustmentType.allCases[x] ? Color.accent : Color.white.opacity(0.5))
                .padding([.top, .bottom], 12)
                    
                    //                        .padding(.bottom, self.bottomPadding)
                    //                        .background(Color(white: self.selectedType == AdjustmentType.allCases[x] ? 0.2 : 0.1).frame(width: 80))
                    .scaledToFill()
            })
                .frame(width: 80)
                .scaleEffect(self.selectedType == AdjustmentType.allCases[x] ? 1.15 : 1)
                .zIndex(self.selectedType == AdjustmentType.allCases[x] ? 1 : 0)
                .shadow(radius: self.selectedType == AdjustmentType.allCases[x] ? 3 : 0)
                
                .animation(Animation.default.delay(0))
                .modifier(SlideUpModifier(visible: self.$visible, delay: 0.2 + (Double(x) / 10)))
            
        }
    }
    
    var fadedEdgeGradient: Gradient {
        return Gradient(stops: [Gradient.Stop(color: Color.clear, location: 0),
                                Gradient.Stop.init(color: Color.black, location: 0.1),
                                Gradient.Stop.init(color: Color.black, location: 0.9),
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
    static var previews: some View {
        EditNavView(title: "Test", leadingItem: EmptyView().any, trailingItem: EmptyView().any) {
            GeometryReader { metrics in
                VStack {
                    Spacer()
                    AdjustmentSelector(selectedType: self.$selectedAdjustment, width: metrics.size.width)
                        .frame(width: metrics.size.width, height: 80 + metrics.safeAreaInsets.bottom).edgesIgnoringSafeArea(.bottom)
                    
                }
                
            }
            .edgesIgnoringSafeArea(.bottom)
            
            
        }
        //        .edgesIgnoringSafeArea(.bottom)
        
    }
    
}
