//
//  MenuView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/12/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI


struct MenuButtonStyle : ButtonStyle {
    let colorScheme: ColorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label

    }
}

enum MenuItemAction {
    case expand(String?, [MenuItem])
    case action(() -> Void)
}

struct MenuItem: Equatable, Identifiable {
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let image: Image?
    let text: Text
    
    let action: MenuItemAction
}

// struct MenuItem {
//    var image: Image? { get }
//    var text: Text { get }
// }

// struct MenuItemSection: MenuItem {
//
//    var id: UUID = UUID()
//
//    let image: Image?
//    let text: Text
//    let items: [MenuItemAction]
// }
//
// struct MenuItemAction: MenuItem {
//    let image: Image?
//    let text: Text
//
//    let action: () -> Void
// }


extension Animation {
    
    static var bouncy1 : Animation {
        return Animation.interpolatingSpring(stiffness: 300, damping: 22).speed(0.8)
    }
    
    static var bouncy2 : Animation {
        return Animation.interpolatingSpring(stiffness: 300, damping: 15).speed(0.8)
    }
    
    static var bouncy3 : Animation {
        return Animation.spring()
    }
}

extension AnyTransition {
    static func pop(delayed: Double = 0) -> AnyTransition { AnyTransition.scale.combined(with: .opacity).animation(Animation.bouncy1.delay(delayed))
    }
}

struct ConditionallyStacked<Content> : View where Content : View {
    
    let content: Content
    let hStacked: Bool
    
    init(hStacked: Bool, @ViewBuilder content:() -> Content) {
        self.hStacked = hStacked
        self.content = content()
    }
    
    var body: some View{
        Group {
            if hStacked {
                HStack(spacing: 10) {
                    self.content
                }
            } else {
                self.content
            }
            
        }
        
    }
    
}

struct MenuView: View {
    @State var menuItems: [MenuItem]
    @State var buttonsVisible = false
    
    @State var subMenu: [MenuItem]?
    @State var subVisible = false
    
    @State var title: String? = nil
    
    @State var dismissing = false
    
    @State var dismissingMenuItem : MenuItem?
    
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    
    @Environment(\.deviceDetails) var deviceDetails : DeviceDetails
    
    var bouncyAnimation : Animation {
        return Animation.bouncy1
    }
    
    let cancelAction: () -> Void
    var body: some View {
        ZStack {
            Button(action: {
                self.dismiss()
                self.cancelAction()
            }, label: { Rectangle().fill(Color.clear) }).zIndex(0)
//            VisualEffectView.blur(.systemUltraThinMaterial)
//                .brightness(-0.1)
//                .transition(.opacity)
//                .opacity(self.dismissing ? 0 : 1)
//                .edgesIgnoringSafeArea(.all)
//                .zIndex(0)
            VStack(spacing: 20) {
                if self.subMenu != nil {
                    if self.title != nil {
                        Group {
                            Text(self.title!).font(.title).foregroundColor(Color.primary)
                            Divider()
                        }.transition(AnyTransition.pop())
                    }
                    
                    ConditionallyStacked(hStacked: self.verticalSizeClass == .compact) {
                        ForEach(self.subMenu!) { x in
                            self.button(x)
                                .scaleEffect(x: self.subVisible ? 1 : 0.05, y: self.subVisible ? 1 : 0.5)
                                .opacity(self.subVisible ? 1 : 0)
                                .animation(self.bouncyAnimation.delay(Double(self.subMenu!.firstIndex(of: x)!) * Double(0.2) + 0.2))
                                .transformEffect(self.dismissingMenuItem == x ? .init(scaleX: 0.95, y: 0.95) : .identity)
                            
                        }
                    }
                    .onAppear {
                        self.$subVisible.animation(self.bouncyAnimation).wrappedValue = true
                    }
                } else {
                    
                    ConditionallyStacked(hStacked: self.verticalSizeClass == .compact) {
                        ForEach(self.menuItems) { x in
                            
                            self.button(x)
                                .scaleEffect(x: self.buttonsVisible ? 1 : 0.05, y: self.buttonsVisible ? 1 : 0.5)
                                .opacity(self.buttonsVisible ? 1 : 0)

                                .transition(AnyTransition.pop(delayed: Double(self.menuItems.firstIndex(of: x)!) * Double(0.2)))
                                .animation(self.bouncyAnimation.delay(Double(self.menuItems.firstIndex(of: x)!) * Double(0.2)))
                                
                                .transformEffect(self.dismissingMenuItem == x ? .init(scaleX: 0.95, y: 0.95) : .identity)
                            
                        }
                        
                        
                        
                    }
                    .onAppear {
                        Delayed(0.2) {
                            self.$buttonsVisible.animation(self.bouncyAnimation).wrappedValue = true
                            //                                                                                                self.buttonsVisible = true
                        }
                    }
                    
                }
                
                //                Spacer()
                Divider()
                Button("Cancel") {
                    self.dismiss()
                    self.cancelAction()
                }
                .scaleEffect(self.buttonsVisible ? 1 : 0.25)
                .opacity(self.buttonsVisible ? 1 : 0)
            }
                
                
                
            .padding(40)
            .scaleEffect(self.dismissing ? 1.2 : 1)
            .opacity(self.dismissing ? 0 : 1)
            .zIndex(1)
        }
            .frame(width: self.deviceDetails.uiIdiom == .pad ? 500 : nil)
        .edgesIgnoringSafeArea([.top, .bottom])
        .accentColor(Color.accent)
        .onTapGesture {
            self.dismiss()
            self.cancelAction()
            
        }
    .padding(20)
    }
    
    func dismiss(_ menuItem: MenuItem? = nil) {
        withAnimation(Animation.easeInOut(duration: 0.4)) {
            self.dismissingMenuItem = menuItem
            self.dismissing = true
            self.subVisible = false
            self.buttonsVisible = false
        }
    }
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    func button(_ item: MenuItem) -> some View {
        BouncyButton(content: {

            HStack {
                Spacer()
                Stack(self.verticalSizeClass == .compact ? .vertical : .horizontal,
                      spacing: 20) {
                        item.image?.accentColor(.accent)
                    item.text.font(.headline).minimumScaleFactor(0.9).foregroundColor(Color.primary)
                }
                Spacer()
            }
            
            .shadow(radius: self.colorScheme == .dark ? 1 : 0)
            .padding([.leading, .trailing], self.verticalSizeClass == .compact ? 20 : 20)
            .padding([.top, .bottom], 20)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: self.colorScheme == .dark ? 0.5 : 1.0).opacity(0.8))) //.opacity(0.5)))

        }) {
            switch item.action {
            case .action(let action):
                self.dismiss(item)
                
                Delayed(0.5) {
                    action()
                    self.cancelAction()
                }
            case .expand(let title, let items):
                self.$title.animation().wrappedValue = title
                self.$subMenu.animation().wrappedValue = items
            }
        }
    }
}

struct BouncyButton<Content>: View where Content: View {
    internal init(@ViewBuilder content: @escaping () -> Content, action: @escaping () -> Void) {
        self.content = content
        self.action = action
    }
    
    @State var pressed = false
    
    let content: () -> Content
    let action: () -> Void
    
    
    
    
    var body: some View {
        Button(action: {
            self.action()
        }, label: { self.content() })
            .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
                self.$pressed.animation(Animation.spring(dampingFraction: 0.5)).wrappedValue = pressing
            }) {}.scaleEffect(self.pressed ? 0.9 : 1)
    }
}

struct TestView: View {
    @State var showing = false
    @State var items: [MenuItem] = {
        let createItems = [MenuItem(image: Image.symbol("photo.fill.on.rectangle.fill"),
                                    text: Text("Photo Library"),
                                    action: .action {}),
                           MenuItem(image: Image.symbol("magnifyingglass.circle.fill"),
                                    text: Text("Browse"),
                                    action: .action {})]
        
        let items = [
            MenuItem(image: Image.symbol("plus"),
                     text: Text("Create from Video"),
                     action: .expand("Select a video", createItems)),
            MenuItem(image: Image.symbol("doc.on.clipboard"),
                     text: Text("Paste GIF"),
                     action: .action {}),
        ]
        
        return items
    }()
    
    var body: some View {
        Group {
            if self.showing {
                MenuView(menuItems: self.items, cancelAction: {}).zIndex(1)
            }
            
            VStack {
                Spacer()
                Button("Toggle") {
                    self.$showing.animation().wrappedValue.toggle()
                }
            }
        }
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Rectangle().fill(Color.black).zIndex(0)
            
            TestView().zIndex(1)
        }
    }
}
