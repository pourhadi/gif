//
//  GalleryView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import QuickLook

struct GalleryContainer: View {
    
    @Binding var activePopover: ActivePopover?
    
    enum VisibleActionSheet: Identifiable {
        var id: VisibleActionSheet {
            return self
        }
        
        case addMenu
        case createMenu
    }
    
    @EnvironmentObject var gallery: Gallery
    @State var showingActionSheet = false
    @State var visibleActionSheet: VisibleActionSheet? = nil
    
    @State var showingCreateMenu = false
        
    @State var showingPreview:Bool? = nil
    
    @State var selectedGIFs = [GIF]()
    
    @State var selectionMode = false
    
    @State var fullscreen = false
    
    @State var showToolbar = false
    
    var showingGIF: Bool {
        return !self.selectionMode && self.selectedGIFs.count > 0
    }
    
    var body: some View {
        Group {
                
                NavigationView {
                    Group {
                        GeometryReader { metrics in

                        GalleryView(gifs: self.$gallery.gifs,
                                    selectedGIFs: self.$selectedGIFs,
                                    selectionMode: self.$selectionMode)
                        
                        
                        
                        NavigationLink(destination: GIFView(gif: self.selectedGIFs.first,
                                                            fullscreen: self.$fullscreen,
                                                            toolbarBuilder: self.getToolbar),
                                       isActive: Binding<Bool>(get: { () -> Bool in
                                        return self.showingGIF
                                       }, set: { (active) in
                                        if !active {
                                            withAnimation {
                                                self.selectedGIFs = []
                                            }
                                        }
                                       }), label: { EmptyView() })
                        if self.showToolbar {
                            
                            self.getToolbar(with: metrics)
                                .transition(.move(edge: .bottom))
                        }
                        
                        }}.navigationBarTitle("GIFs")
                        .navigationBarItems(trailing: self.getTrailingBarItem())
                        .navigationBarHidden(self.fullscreen)
                        .actionSheet(item: self.$visibleActionSheet) { (val) -> ActionSheet in
                            return self.getActionSheet()
                    
                    
                }
                
            }.edgesIgnoringSafeArea(self.showToolbar ? .bottom : [])
            
        }
    }
    
    func getToolbar(with metrics: GeometryProxy, background: AnyView = VisualEffectView(effect: .init(style: .systemMaterialDark)).asAny) -> AnyView {
        return ToolbarView(metrics: metrics, background: background) {
            Button(action: {
                
            }, label: { Image.symbol("square.and.arrow.up", useDefault: true) } )
                .disabled(self.selectedGIFs.count == 0)
                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
            Spacer()
            Button(action: {
                withAnimation {
                    self.gallery.remove(self.selectedGIFs)
                    self.selectedGIFs = []
                }
            }, label: { Image.symbol("trash", useDefault: true) } )
                .disabled(self.selectedGIFs.count == 0)
                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
        }.asAny
        
        
//        return VStack {
//            HStack {
//                Button(action: {
//
//                }, label: { Image.symbol("square.and.arrow.up") } )
//                    .disabled(self.selectedGIFs.count == 0)
//                    .padding(12)
//                Spacer()
//                Button(action: {
//                    withAnimation {
//                        self.gallery.remove(self.selectedGIFs)
//                        self.selectedGIFs = []
//                    }
//                }, label: { Image.symbol("trash") } )
//                    .disabled(self.selectedGIFs.count == 0)
//                    .padding(12)
//            }
//            Spacer(minLength: metrics.safeAreaInsets.bottom)
//        }.opacity(self.selectedGIFs.count > 0 ? 1 : 0.5).background(VisualEffectView(effect: .init(style: .systemMaterialDark)))
//            .frame(height: 60 + metrics.safeAreaInsets.bottom)
//            .position(x: metrics.size.width / 2, y: metrics.size.height - metrics.safeAreaInsets.bottom)
    }
    
    func getTrailingBarItem() -> some View {
        if self.selectionMode {
            return Button(action: {
                withAnimation {
                    self.selectedGIFs = []
                    self.selectionMode = false
                    self.showToolbar = false
                }
                
            }, label: { Text("Done") } ).asAny
        } else {
            return HStack {
                
                Button(action: {
                    withAnimation {
                        self.selectionMode = true
                        self.showToolbar = true
                    }
                    
                    }, label: { Text("Select") } )
                Spacer(minLength: 30)
                Button(action: {
                    self.visibleActionSheet = .addMenu
                    
                    }, label: { Image.symbol("plus", useDefault: true) } )
            }.asAny
        }
    }
    
    func getActionSheet() -> ActionSheet {
        switch self.visibleActionSheet {
        case .addMenu:
            return ActionSheet(title: Text("Add or Create"), message: nil, buttons: [.default(Text("Create"), action: {
                self.visibleActionSheet = nil
                DispatchQueue.main.async {
                    self.visibleActionSheet = .createMenu
                }
            }), .default(Text("Import"), action: {
                
            }), .default(Text("Paste"), action: {
                if let image = UIPasteboard.general.data(forPasteboardType: "com.compuserve.gif") {
                    withAnimation {
                        self.gallery.add(data: image)
                    }
                    
                    //                    if let gif = GIF(image: try? UIImage(gifData: image)) {
                    //                        self.selectedGIF = gif
                    //                        self.showingPreview = true
                    //                    }
                }
            }), .cancel({
                self.showingActionSheet = false
            })])
            
        case .createMenu:
            return ActionSheet(title: Text("Create GIF from Video"), message: nil, buttons: [.default(Text("Photo Library"), action: {
                self.activePopover = .videoPicker
            }), .default(Text("Browse"), action: {
                self.activePopover = .docBrowser
            }), .cancel({
                self.showingActionSheet = false
            })])
        case .none:
            fatalError()
        }
    }
}

struct GalleryView: View {
    
    struct GIFRow: Identifiable {
        let id: Int
        let items: [GIF]
    }
    
    @State var animatingGIF: GIF? = nil
    
    @Binding var gifs: [GIF]
        
    @Binding var selectedGIFs: [GIF]
    
    @Binding var selectionMode: Bool
    
    var body: some View {
        
        var currentRow = [GIF]()
        var rows = [GIFRow]()
        
        for gif in self.gifs {
            if currentRow.count == 3 {
                rows.append(GIFRow(id: rows.count, items: currentRow))
                currentRow = []
                
            } else {
                currentRow.append(gif)
                
                if self.gifs.last == gif {
                    rows.append(GIFRow(id: rows.count, items: currentRow))
                    currentRow = []
                }
            }
        }
        
        let itemSpacing:CGFloat = 4
        return GeometryReader { metrics in
            
            ScrollView {
                VStack(spacing: itemSpacing) {
                    ForEach(rows) { row in
                        HStack(spacing: itemSpacing) {
                            ForEach(row.items) { gif in
                                GeometryReader { itemMetrics in
                                    Group {
                                        GIFImageView(isAnimating: false, gif: gif, contentMode: .scaleAspectFill)
                                        
                                        
                                        if self.selectionMode {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 20, height: 20)
                                                .background(self.selectedGIFs.contains(gif) ? Color.blue : Color.clear)
                                                .position(x: itemMetrics.size.width - 18, y: itemMetrics.size.height - 18)
                                                
                                                .shadow(radius: 2)
                                        }
                                    }
                                }.onTapGesture {
                                    if self.selectionMode {
                                        if let index = self.selectedGIFs.firstIndex(of: gif) {
                                            self.selectedGIFs.remove(at: index)
                                        } else {
                                            self.selectedGIFs.append(gif)
                                        }
                                    } else {
                                        self.selectedGIFs = [gif]
                                    }
                                }
                            }
                        }.frame(height: (metrics.size.width / 3) - (itemSpacing * 2))
                    }
                }
                //                Spacer()
                
            }
        }
    }
    
}

struct GalleryView_Previews: PreviewProvider {
    @State static var activePopover: ActivePopover? = nil
    static var previews: some View {
        GalleryContainer(activePopover: $activePopover).environmentObject(Gallery())
    }
}
