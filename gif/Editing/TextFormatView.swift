//
//  TextFormatView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/13/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI
import IGColorPicker


struct ColorPicker : UIViewRepresentable {
    
    @Binding var selectedColor: UIColor
    let selectedColorAction: () -> Void
    func makeCoordinator() -> ColorPicker.Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: UIViewRepresentableContext<ColorPicker>) -> ColorPickerView {
        let v = ColorPickerView()
        v.colors.insert(UIColor.white, at: 0)
        v.colors.insert(UIColor.black, at: 1)
        v.style = .square
        v.preselectedIndex = v.colors.firstIndex(of: self.selectedColor) ?? 0
        v.delegate = context.coordinator
        v.layoutDelegate = context.coordinator
        context.coordinator.colors = v.colors
        return v
    }
    
    func updateUIView(_ uiView: ColorPickerView, context: UIViewRepresentableContext<ColorPicker>) {
        
    }
    
    typealias UIViewType = ColorPickerView
    
    
    class Coordinator: ColorPickerViewDelegate, ColorPickerViewDelegateFlowLayout {
        var colors = [UIColor]()
        
        func colorPickerView(_ colorPickerView: ColorPickerView, didSelectItemAt indexPath: IndexPath) {
            self.parent.selectedColor = self.colors[indexPath.item]
            self.parent.selectedColorAction()
        }
        
        let parent: ColorPicker
        
        init(_ parent: ColorPicker) {
            self.parent = parent
        }
        
        func colorPickerView(_ colorPickerView: ColorPickerView, sizeForItemAt indexPath: IndexPath) -> CGSize {
            // The size for each cell
            return CGSize(width: 30, height: 30)
        }
        
        func colorPickerView(_ colorPickerView: ColorPickerView, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return 0
        }
        
        func colorPickerView(_ colorPickerView: ColorPickerView, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            return 0
        }
        
        func colorPickerView(_ colorPickerView: ColorPickerView, insetForSectionAt section: Int) -> UIEdgeInsets {
            return UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        }
    }
}

struct PopoverPrefs {
    var origin: Anchor<CGPoint>?
    
    var content: Anchor<CGRect>?
}

struct PopoverPreferencesKey: PreferenceKey {
    static var defaultValue: PopoverPrefs = PopoverPrefs()
    
    static func reduce(value: inout PopoverPrefs, nextValue: () -> PopoverPrefs) {
        let next = nextValue()
        if let origin = next.origin {
            value.origin = origin
        }
    }
    
    typealias Value = PopoverPrefs
}


extension Edge {
    var isHorizontal: Bool {
        return self == .leading || self == .trailing
    }
    
    var leadingOrTop: Bool {
        if self.isHorizontal { return self == .leading }
        return self == .top
    }
}

struct PopoverView<Content>: View where Content: View {
    let origin: CGPoint
    let edge: Edge
    let content: () -> Content
    let closeAction: () -> Void
    
    init(origin: CGPoint, edge: Edge, closeAction: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.origin = origin
        self.edge = edge
        self.content = content
        self.closeAction = closeAction
    }
    
    var arrow: some View {
        var rotation: Double = 0
        if self.edge == .top {
            rotation = -90
        } else if self.edge == .bottom {
            rotation = 90
        } else if self.edge == .leading {
            rotation = 180
        }
        
        let length: CGFloat = 30
        return Path { (path: inout Path) in
            path.move(to: CGPoint.zero)
            path.addLine(to: CGPoint(x: length / 2, y: length / 2))
            path.addLine(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint.zero)
            path.closeSubpath()
        }.rotation(.degrees(rotation))
            .foregroundColor(Color(white: 0.1))
            .frame(width: length, height: length)
    }
    
    func getContent() -> some View {
        self.content()
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color(white: 0.1)))
    }
    
    var body: some View {
        Group {
            
            if self.edge.isHorizontal {
                
                HStack(spacing: 0) {
                    self.arrow.position(y: self.origin.y)
                    self.getContent()
                }
                
            } else {
                VStack(spacing: 0) {
                    self.getContent()
                    self.arrow.offset(x: self.origin.x)
                }
            }
            
            
            
        }
        
        
        
        
        //        Stack(self.edge.isHorizontal ? .horizontal : .vertical, spacing: 0) {
        //            if self.edge.leadingOrTop {
        //                self.arrow
        //                self.getContent()
        //
        //            } else {
        //                self.getContent()
        //                self.arrow
        //            }
        //        }
    }
}

extension String: Identifiable {
    public var id: String { return self }
}

class TextFormat: ObservableObject {
    
    let fontNames = ["Helvetica", "Georgia", "Noteworthy"]
    
    @Published var font: Font = .title
    
    @Published var fontName: String = "Helvetica"
    
    @Published var fontScale: CGFloat = 1
    
    @Published var color: UIColor = UIColor.white
    
    @Published var bold = false
    
    @Published var shadow = false
    
    @Published var shadowColor = UIColor.black
    
    @Published var shadowMeasure = 1
    
    @Published var shadowRadius = 1
}


struct FontPickerView : View {
    
    @EnvironmentObject var textFormat: TextFormat
    
    var body: some View {
        
        VStack {
            ForEach(self.textFormat.fontNames) { name in
                Button(action: {
                    self.textFormat.fontName = name
                }, label: {
                    VStack {
                        HStack {
                            Image.symbol("checkmark").opacity(self.textFormat.fontName == name ? 1 : 0)
                            Text(name)
                            Spacer()
                            
                        }
                        if name != self.textFormat.fontNames.last {
                            Divider().background(Color.white)
                        }
                    }
                })
            }
            
            Divider().background(Color.white)
            
            HStack{
                
                Text("A").scaleEffect(0.8)
                Slider(value: self.$textFormat.fontScale, in: 0.5...2)
                Text("A")
                
            }
        }.frame(width: 200)
        
    }
}

enum PopoverType {
    case textFormat
    case color
}

struct TextFormatView: View {
    @EnvironmentObject var textFormat: TextFormat
    
    @State var selected = true
    
    @State var visiblePopover: PopoverType? = nil
    
    func popoverButton<Content: View>(tag: PopoverType, @ViewBuilder content: () -> Content) -> some View {
        
        Button(action: {
            self.visiblePopover = tag
            
        }) {
            
            content()
        }
            
        .transformAnchorPreference(key: PopoverPreferencesKey.self, value: .center) { val, anchor in
            if self.visiblePopover == tag {
                val.origin = anchor
            }
        }
    }
    
    
    var body: some View {
        GeometryReader { _ in
            VStack {
                
                HStack(spacing: 12) {
                    Button(action: {
                        self.textFormat.bold.toggle()
                    }, label: {
                        Image.symbol("bold")
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(self.textFormat.bold ?  Color.white.opacity(0.2) : Color.clear))
                    })
                    
                    Divider()
                    
                    self.popoverButton(tag: .color) {
                        Circle()
                        
                            .stroke(Color.accent, lineWidth: 2)
                            .foregroundColor(Color.clear)
                            .background(Circle().fill(Color(self.textFormat.color)))

                            .frame(width: 20, height: 20)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            self.$textFormat.shadow.animation().wrappedValue.toggle()
                        }, label: {
                            
                            Text(self.textFormat.shadow ? "S" : "Shadow").fontWeight(.medium)
                            .padding(4)
                                .background(RoundedRectangle(cornerRadius: 10).fill(self.textFormat.shadow ? Color.white.opacity(0.1) : Color.clear))
                        })
                        
                        if self.textFormat.shadow {
                            
                            Button(action: {
                                self.textFormat.shadowColor = UIColor.black
                            }, label: {
                                Circle()
                                    .stroke(Color.black, lineWidth: 4)
                                    .foregroundColor(Color.clear)
                                    .background(Circle().fill(Color.background))
                                    .frame(width: 20, height: 20)
                                    .overlay(self.textFormat.shadowColor == UIColor.black ? Circle().inset(by: -2).stroke(Color.accent, lineWidth: 2).foregroundColor(Color.clear).any : EmptyView().any)
                            })
                            
                            
                            Button(action: {
                                self.textFormat.shadowColor = UIColor.white
                            }, label: {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .foregroundColor(Color.clear)
                                    .background(Circle().fill(Color.white))
                                    .frame(width: 20, height: 20)
                                    .overlay(self.textFormat.shadowColor == UIColor.white ? Circle().inset(by: -3).stroke(Color.accent, lineWidth: 2).foregroundColor(Color.clear).any : EmptyView().any)
                            })
                            
                            
                            VStack {
                                
                                
//                                Text("Offset")
                                
                                Stepper(onIncrement: {
                                    
                                    self.textFormat.shadowMeasure += 1
                                    
                                }, onDecrement: {
                                    self.textFormat.shadowMeasure -= 1
                                    
                                }, label: {
                                    EmptyView()
                                }).labelsHidden()
                                
//                                Text("Radius")

//
//                                Stepper(onIncrement: {
//
//                                    self.textFormat.shadowRadius += 1
//
//                                }, onDecrement: {
//                                    self.textFormat.shadowRadius -= 1
//
//                                }, label: {
//                                    EmptyView()
//                                }).labelsHidden()
//
                                
                                
                            }
                            
                            
                            
                        }
                    }
                .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).foregroundColor(self.textFormat.shadow ?  Color.white.opacity(0.2) : Color.clear))
                }
                
            }
        }
        .overlayPreferenceValue(PopoverPreferencesKey.self) { (val: PopoverPrefs) in
            GeometryReader { metrics in
                self.getPopover(metrics: metrics, values: val)
            }.background(Group {
                if self.visiblePopover != nil {
                    Button(action: {
                        self.visiblePopover = nil
                    }, label: {
                        Rectangle().fill(Color.clear)
                    })
                }})
        }.background(Color.black.opacity(0.5))
    }
    
    func getPopover(metrics: GeometryProxy, values: PopoverPrefs) -> some View {
        let origin = values.origin != nil ? metrics[values.origin!] : CGPoint.zero
        
        let center = CGPoint(x: metrics.size.width / 2, y: metrics.size.height / 2)
        return ZStack {
            
            EmptyView()
            if self.visiblePopover != nil {
                PopoverView(origin: CGPoint(x: origin.x - center.x, y: origin.y - center.y), edge: .bottom, closeAction: {
                    self.visiblePopover = nil
                }) {
                    if self.visiblePopover == .textFormat {
                        FontPickerView().environmentObject(self.textFormat)
                    } else if self.visiblePopover == .color {
                        ColorPicker(selectedColor: self.$textFormat.color, selectedColorAction: {
                            self.visiblePopover = nil
                        }).frame(width: 200, height: 80)
                    }
                }.zIndex(1)
                    .alignmentGuide(VerticalAlignment.center) { (d) -> CGFloat in
                        d.height
                }
                .shadow(radius: 5)
                .frame(width: metrics.size.width, height: metrics.size.height, alignment: .center)
            }
        }
    }
}

struct TextFormatView_Previews: PreviewProvider {
    static var previews: some View {
//        TextEditorView(gif: GIF(id: "1", url: Bundle.main.url(forResource: "2", withExtension: "gif")!)).environmentObject(TextFormat()).colorScheme(.dark)
        TextFormatView().background(Color.init(white: 0.2)).environmentObject(TextFormat()).colorScheme(.dark)
    }
}


//struct TextEditorView : View {
//
//    var gif : GIF
//
//    @EnvironmentObject var textFormat: TextFormat
//
//    @Environment(\.keyboardManager) var keyboardManager : KeyboardManager
//
//    @State var keyboardHeight: CGFloat = 0
//
//    var body : some View {
//
//        CustomNavView(title: String(""), leadingItem: Button(action: {
//
//        }, label: { Text("Cancel")}).any, trailingItem: Button(action: {
//
//            }, label: { Text("Done")}).any) {
//
//                VStack {
//                    .padding(20)
//                }
//
//
//        }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { (note) in
//            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
//                self.keyboardHeight = frame.size.height
//            }
//        }
//        .edgesIgnoringSafeArea([.bottom])
//
//    }
//
//}
