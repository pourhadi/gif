
import SwiftUI

struct HeightKey: PreferenceKey {
    static func reduce(value: inout Anchor<CGRect>.Source?, nextValue: () -> Anchor<CGRect>.Source?) {}
    
    static var defaultValue: Anchor<CGRect>.Source? {
        return nil
    }
}

struct GifCreatedView: View {
    @EnvironmentObject var globalState: GlobalState
    
    @State var animating = true
    @State var visible = false
    
    @State var fillerHeight: CGFloat? = nil
    let gif: GIF
    
    @State var dragOffset: CGFloat = 0
    
    let dismissBlock: () -> Void
    
    var body: some View {
        GeometryReader { outerMetrics in
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 10) {
                    AnimatedGIFView(gif: self.gif, animated: self.$animating)
                        .aspectRatio(self.gif.aspectRatio, contentMode: .fit)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .shadow(radius: 1)
                    
                    HStack(spacing: 10) {
                        self.textButton()
                        self.cropButton()
                    }
                    Divider()
                    self.saveButton()
                    self.cancelButton()
                    
                    Rectangle().fill(Color.clear).frame(height: -self.dragOffset + 100)
                }
                .padding(.bottom, outerMetrics.safeAreaInsets.bottom)
                .background(ZStack {
//                    AnimatedImageView(gif: self.gif, animating: self.$animating, cornerRadius: 0, contentMode: .scaleAspectFill)
                    AnimatedGIFView(gif: self.gif, animated: self.$animating, contentMode: .fill)
                        .edgesIgnoringSafeArea([.top, .bottom])
//                        .grayscale(0.1)
//                        .saturation(2)
//                        .brightness(1)
//                    .luminanceToAlpha()
//                    .blur(radius: 60, opaque: true)
                        .zIndex(1)
                    
                    VisualEffectView.blur(.systemThickMaterial).zIndex(2)

                })
                    .cornerRadius(10, corners: [.topLeft, .topRight])
                    .shadow(radius: 5)
            }
            .onAppear {
                self.$visible.animation(Animation.spring(dampingFraction: 0.6)).wrappedValue = true
                
                Delayed(0.3) {
                    self.animating = true
                }
                
            }

            .offset(x: 0, y: 100)
            .coordinateSpace(name: "gifCreatedContainer")
                .gesture(DragGesture().onChanged({ (val) in
                    self.dragOffset = val.translation.height
                })
                    .onEnded({ (val) in
                         if (val.location.y - val.startLocation.y) >= (outerMetrics.size.height / 5) {
                            self.$dragOffset.animation(Animation.easeOut(duration: 0.3)).wrappedValue = outerMetrics.size.height

                            Delayed(0.3) {
                                self.dismiss()
                            }
                         } else {
                            self.$dragOffset.animation(Animation.interpolatingSpring(stiffness: 300, damping: 18)).wrappedValue = 0
                        }
                    }))
                
                .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    func dismiss() {
        self.dismissBlock()
    }
    
    func cropButton() -> some View {
        Button(action: {
            let gif = self.gif
            Async {
                
                GlobalPublishers.default.dismissEditor.send(())
                self.dismiss()
                
                
                Delayed(1) {
                    GlobalPublishers.default.crop.send(gif)
                }
            }
            
            
        }, label: {
            Text("Crop")
                .font(.system(size: 20))
                .fontWeight(.medium)
                .accentColor(Color.accent)
                .centered(.horizontal)
                .frame(height: 60)
            
            
        })
            .background(Color.white .opacity(0.2))
            .cornerRadius(10)
            .padding(.trailing, 20)
    }
    
    func textButton() -> some View {
        Button(action: {
            Async {
                GlobalPublishers.default.dismissEditor.send(())
                self.dismiss()
                GlobalPublishers.default.addText.send(self.gif)
            }
            
        }, label: {
            Text("Add Text")
                .font(.system(size: 20))
                .fontWeight(.medium)
                .accentColor(Color.accent)
                .centered(.horizontal)
                .frame(height: 60)
            
            
        })
            .background(Color.white .opacity(0.2))
            .cornerRadius(10)
            .padding(.leading, 20)
    }
    
    func saveButton() -> some View {
        Button(action: {
            self.globalState.saveGeneratedGIF(gif: self.gif, done: { success in
                if success {
                    Delayed(2) {
                        self.dismiss()

                    }
                }
            })
        }, label: {
            Text("Save")
                .font(.system(size: 20))
                .fontWeight(.medium)
                .accentColor(Color.accent)
                .centered(.horizontal)
                .frame(height: 60)
            
            
        })
            .background(Color.white .opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal, 20)
    }
    
    func cancelButton() -> some View {
        Button(action: {
            self.dismiss()
        }, label: {
            Text("Cancel")
                .accentColor(Color.accent)
                .font(.system(size: 20))
                .centered(.horizontal)
                .frame(height: 60)

            
        })
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 20)
    }
}

struct GifCreatedView_Previews: PreviewProvider {
    static let gif = GIFFile(url: Bundle.main.url(forResource: "1", withExtension: ".gif")!, id: "test")!
    static var previews: some View {
        GifCreatedView(gif: gif, dismissBlock: {}).accentColor(Color.primary).environmentObject(GlobalState())
    }
}
