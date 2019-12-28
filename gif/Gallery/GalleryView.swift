
import SwiftUI
import QuickLook

struct SizeModifier: ViewModifier {
    
    let size: CGSize
    func body(content: _ViewModifier_Content<SizeModifier>) -> AnyView {
        content.frame(width: size.width, height: size.height).any
    }
    
    typealias Body = AnyView
    
    
}

struct ScaleModifier: ViewModifier {
    
    let scale: CGSize
    let translation: CGSize
    func body(content: _ViewModifier_Content<ScaleModifier>) -> AnyView {
        content.scaleEffect(scale).offset(translation).any
    }
    
    typealias Body = AnyView
    
    
}


struct RevealModifier: ViewModifier {
    
    let size: CGSize
    let position: CGPoint
    func body(content: _ViewModifier_Content<RevealModifier>) -> AnyView {
        content.frame(width: size.width, height: size.height).position(position).any
    }
    
    typealias Body = AnyView
    
    
}

class TransitionContext: ObservableObject {
    
    @Published var scaledGIFIndex: Int? = nil
    
    @Published var yDrag: CGFloat? = nil
    @Published var dragScale: CGFloat? = nil
    
    @Published var fullscreen = false
    @Published var disableAnimation = true
    
    var itemMetrics: GeometryProxy? = nil
    
    var itemFrame: CGRect? {
        if let metrics = itemMetrics {
            return metrics.frame(in: .global)
        }
        return nil
    }
    
    func offsetRelativeTo(metrics: GeometryProxy) -> CGSize {
        if let itemFrame = self.itemFrame {
            let mainFrame = metrics.frame(in: .global)
            
            return CGSize(width: itemFrame.midX - mainFrame.midX, height: itemFrame.midY - mainFrame.midY)
        }
        return CGSize.zero
    }
    
    func position(in coordinateSpace: CoordinateSpace) -> CGPoint {
        if let itemMetrics = itemMetrics {
            let frame = itemMetrics.frame(in: GalleryCoordinateSpace)
            
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        
        return CGPoint.zero
    }
}

extension GeometryProxy {
    
    func midpoint(in coordinateSpace: CoordinateSpace) -> CGPoint {
        let frame = self.frame(in: coordinateSpace)
        return CGPoint(x: frame.midX, y: frame.midY)
    }
    
}

let GalleryCoordinateSpace: CoordinateSpace = .named("galleryCoordinate")

class GalleryState<G: GIF>: ObservableObject {
    
    @Published var selectedGIFs: [G]
    @Published var selectionMode = false
    
    
    init(selectedGIFs: [G]) {
        self.selectedGIFs = selectedGIFs
    }
}

struct GalleryContainer: View {
    
    enum ActiveGallery: Int {
        case photoLibrary
        
        case local
    }
    
    @State var activeGallery: Int = 0
    
    var gallery: some Gallery {
        return self.galleryStore.galleries[self.activeGallery]
    }
    
    var galleryBinding: Binding<Gallery> {
        return self.$galleryStore.galleries[self.activeGallery]
    }
    
    @State var transitionContext = TransitionContext()
    
    @Binding var activePopover: ActivePopover?
    
    enum VisibleActionSheet: Identifiable {
        var id: VisibleActionSheet {
            return self
        }
        
        case addMenu
        case createMenu
    }
    
    @Binding var galleryStore: GalleryStore
    @State var showingActionSheet = false
    @State var visibleActionSheet: VisibleActionSheet? = nil
    
    @State var showingCreateMenu = false

    
    @State var showToolbar = false
    
    
    var showingGIF: Bool {
        return !self.gallery.viewState.selectionMode && self.gallery.viewState.selectedGIFs.count > 0
    }
    
    @State var removeGIFView = false
    var body: some View {
        TabView(selection: self.$activeGallery) {
            ForEach(0..<self.galleryStore.galleries.count) { x in
                self.getMainView(gallery: self.$galleryStore.galleries[x],
                                 title: self.galleryStore.galleries[x].title,
                                 trailingNavItems: x == 0 ? self.getTrailingBarItem().any : EmptyView().any)
                    .tabItem {
                        return self.galleryStore.galleries[x].tabItem
                        
                }.tag(x)
            }
            
        }.edgesIgnoringSafeArea([.top]).actionSheet(item: self.$visibleActionSheet) { (val) -> ActionSheet in
            return self.getActionSheet()
        }.overlay(self.showingGIF ? self.getGIFView().any : EmptyView().any)
    }
    
    
    func getGIFView() -> some View {
        return
            GIFView(removeGIFView: self.$removeGIFView, transitionContext: self.transitionContext, gifs: self.galleryBinding.gifs,
                    selectedGIFs: self.galleryBinding.viewState.selectedGIFs,
                    toolbarBuilder: self.getToolbar)
                .onAppear(perform: {
                    print("appeared")
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                        self.transitionContext.disableAnimation = false
                    }
                })
                .onDisappear(perform: {
                    print("disappear")
                    self.transitionContext.fullscreen = false
                    self.gallery.viewState.selectedGIFs = []
                }).transition(.opacity)
    }
    
    func getMainView<T>(gallery: Binding<Gallery>, title: String, trailingNavItems: T) -> some View where T : View {
        return NavigationView {
            Group {
                GeometryReader { metrics in
                    CollectionView(items: gallery.gifs, selectedItems: gallery.viewState.selectedGIFs, selectionMode: gallery.viewState.selectionMode, tapAction: { item, metrics in
                        
                        if !gallery.viewState.selectionMode.wrappedValue {
                            self.transitionContext.itemMetrics = metrics
                            self.transitionContext.yDrag = nil
                            self.transitionContext.dragScale = nil
                            self.transitionContext.disableAnimation = true
                        }
                    }) { (item, cvMetrics, itemMetrics) -> AnyView in
                        return Group {
                            
                            return Image(uiImage: item.thumbnail!).resizable().scaledToFill()
                        }.frame(width: itemMetrics.size.width, height: itemMetrics.size.height).clipped().any
                    }
                    if self.showToolbar {
                        self.getToolbar(with: metrics)
                            .transition(.opacity)
                    }
                    
                }
                
            }.navigationBarTitle(title)
                .navigationBarItems(trailing: trailingNavItems)
            
            
        }
        
    }
    
    func getToolbar(with metrics: GeometryProxy, background: AnyView = VisualEffectView(effect: .init(style: .prominent)).any) -> AnyView {
        return ToolbarView(metrics: metrics, background: background) {
            Button(action: {
                
            }, label: { Image.symbol("square.and.arrow.up") } )
                .disabled(self.gallery.viewState.selectedGIFs.count == 0)
                .padding(12).opacity(self.gallery.viewState.selectedGIFs.count > 0 ? 1 : 0.5)
            Spacer()
            Button(action: {
                withAnimation {
                    self.gallery.remove(self.gallery.viewState.selectedGIFs)
                    self.gallery.viewState.selectedGIFs = []
                }
            }, label: { Image.symbol("trash") } )
                .disabled(self.gallery.viewState.selectedGIFs.count == 0)
                .padding(12).opacity(self.gallery.viewState.selectedGIFs.count > 0 ? 1 : 0.5)
        }.any
        
    }
    
    func getTrailingBarItem() -> some View {
        if self.gallery.viewState.selectionMode {
            return Button(action: {
                withAnimation {
                    self.gallery.viewState.selectedGIFs = []
                    self.gallery.viewState.selectionMode = false
                    self.showToolbar = false
                }
                
            }, label: { Text("Done") } ).any
        } else {
            return HStack {
                
                Button(action: {
                    withAnimation {
                        self.gallery.viewState.selectionMode = true
                        self.showToolbar = true
                    }
                    
                }, label: { Text("Select") } )
                Spacer(minLength: 30)
                Button(action: {
                    self.visibleActionSheet = .addMenu
                    
                }, label: { Image.symbol("plus") } )
            }.any
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
                        let _ = self.gallery.add(data: image)
                    }
                } else if let url = UIPasteboard.general.url, url.absoluteString.lowercased().contains(".gif"), let data = try? Data(contentsOf: url), data.count > 0 {
                    let _ = self.gallery.add(data: data)
                } else {
                    for item in UIPasteboard.general.items {
                        for value in item.values {
                            if value is Data {
                                let _ = self.gallery.add(data: value as! Data)
                            }
                        }
                    }
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




