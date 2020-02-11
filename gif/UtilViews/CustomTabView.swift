//
//  CustomTabView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/28/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI

struct TabModel: Identifiable {
    var id: Int
    
    var title: Text
    var image: Image
    
    
    init(_ id: Int, title: Text, image: Image) {
        self.id = id
        self.title = title
        self.image = image
    }
}

struct CustomTabView<Content>: View where Content : View {
    
    
    @Binding var selectedTab: Int
    
    let tabs: [TabModel]
    
    let content: (TabModel) -> Content
    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    
    @Environment(\.verticalSizeClass) var sizeClass: UserInterfaceSizeClass?
    
    init(selectedTab: Binding<Int>, tabs: [TabModel], @ViewBuilder content: @escaping (TabModel) -> Content) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.content = content
    }
    
    var body: some View {
        ZStack {
            
            self.content(self.tabs[self.selectedTab]).zIndex(0)
            
            GeometryReader { metrics in
                
                Group {
                    
                    VStack {
                        Divider().edgesIgnoringSafeArea([.leading, .trailing])
                        Spacer(minLength: 4)
                        HStack {
                            ForEach(self.tabs) { tab in
                                Stack(self.deviceDetails.uiIdiom == .pad || self.sizeClass == .compact ? .horizontal : .vertical) {
                                    tab.image.renderingMode(.template)
                                    tab.title.font(.footnote)
                                }
                                .opacity(tab.id == self.selectedTab ? 1.0 : 0.5)
                                .foregroundColor(tab.id == self.selectedTab ? Color.accent : Color.secondary)
                                .onTapGesture {
                                    self.selectedTab = tab.id
                                }
                                .frame(width: metrics.size.width / CGFloat(self.tabs.count), alignment: .center)
                                
                            }
                        }
                        Spacer(minLength: metrics.safeAreaInsets.bottom)
                        
                    }.background(VisualEffectView(effect: .init(style: .systemChromeMaterial)).edgesIgnoringSafeArea(.all))
                        .frame(height: (self.sizeClass == .compact ? 30 : 55) + metrics.safeAreaInsets.bottom)
                }
                .frame(height:metrics.size.height, alignment: .bottom)
                .offset(y: metrics.safeAreaInsets.bottom)
                
                //            .frame(height: metrics.size.height + metrics.safeAreaInsets.bottom, alignment: .bottom)
            }
            .zIndex(20)
        }
    }
}

//struct CustomTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        CustomTabView()
//    }
//}

