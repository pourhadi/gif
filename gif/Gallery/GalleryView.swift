
import QuickLook
import SwiftUI
import AVFoundation

struct SizeModifier: ViewModifier {
    let size: CGSize
    func body(content: _ViewModifier_Content<SizeModifier>) -> AnyView {
        content.frame(width: self.size.width, height: self.size.height).any
    }
    
    typealias Body = AnyView
}

struct ScaleModifier: ViewModifier {
    let scale: CGSize
    let translation: CGSize
    func body(content: _ViewModifier_Content<ScaleModifier>) -> AnyView {
        content.scaleEffect(self.scale).offset(self.translation).any
    }
    
    typealias Body = AnyView
}

struct RevealModifier: ViewModifier {
    let size: CGSize
    let position: CGPoint
    func body(content: _ViewModifier_Content<RevealModifier>) -> AnyView {
        content.frame(width: self.size.width, height: self.size.height).position(self.position).any
    }
    
    typealias Body = AnyView
}

class TransitionContext: ObservableObject {
    @Published var scaledGIFIndex: Int? = nil
    @Published var yDrag: CGFloat? = nil
    @Published var dragScale: CGFloat? = nil
    @Published var fullscreen = false
    @Published var disableAnimation = false
    
    var itemMetrics: GeometryProxy?
    
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

struct ContextPopupView: View {
    let gif: GIF
    
    @State var animating = true
    
    var body: some View {
        GeometryReader { metrics in
            Group {
                AnimatedGIFView(gif: self.gif, animated: self.$animating)
                    .aspectRatio(self.gif.aspectRatio, contentMode: .fit)
                    .cornerRadius(20)
                    .clipped()
                    .shadow(radius: 2)
                    .padding(20)
            }.frame(width: metrics.size.width, height: metrics.size.height)
        }
    }
}

class LongPressCoordinator {
    var timer: Timer?
    
    var item: GIF?
    
    var parent: CollectionViewWrapper?
    
    func resetTimer() {
        self.timer?.invalidate()
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { t in
            guard t.isValid else { return }
            self.parent?.$pressingGIF.animation().wrappedValue = self.item
        })
    }
    
    func cancel() {
        self.timer?.invalidate()
        self.item = nil
    }
}

struct CollectionViewWrapper: View {
    let _longPressCoordinator: LongPressCoordinator = LongPressCoordinator()
    
    var longPressCoordinator: LongPressCoordinator {
        let coord = self._longPressCoordinator
        coord.parent = self
        return coord
    }
    
        @Environment(\.verticalSizeClass) var verticalSize: UserInterfaceSizeClass?

    @Environment(\.hapticController) var hapticController: HapticController
    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    
    @EnvironmentObject var gallery: Gallery
    
    @State var gifCount: Int = 0
    
    @Binding var selectedGIFs: [GIF]
    
    @Binding var selectionMode: Bool
    
    @Binding var transitionContext: TransitionContext
    
    @Binding var highlightedGIF: GIF?
    
    @Binding var pressingGIF: GIF?
    
    @State var loaded = false
    
    var body: some View {
        let layout = CollectionViewLayout(rowPadding: self.deviceDetails.uiIdiom == .pad ? EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20) : EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
                                          numberOfColumns: self.deviceDetails.uiIdiom == .pad || self.verticalSize == .compact ? 5 : 3,
                                          itemSpacing: self.deviceDetails.uiIdiom == .pad ? 20 : 2,
                                          rowHeight: .sameAsItemWidth,
                                          scrollViewInsets: EdgeInsets(top: 0, leading: 0, bottom: 60, trailing: 0))
        
        return
//            GeometryReader { metrics in
            
            CollectionView(items: self.$gallery.gifs.animation(),
                           selectedItems: self.$selectedGIFs,
                           selectionMode: self.$selectionMode,
                           layout: layout,
                           tapAction: { _ in
                            
                            if !self.selectionMode {
//                                self.transitionContext.itemMetrics = metrics
                                self.transitionContext.yDrag = nil
                                self.transitionContext.dragScale = nil
                                self.transitionContext.disableAnimation = true
                            }
            }, longPressAction: { item in
                self.hapticController.longPressHaptic()
                self.longPressCoordinator.cancel()
                
                DispatchQueue.main.async {
                    self.$pressingGIF.animation().wrappedValue = nil
                    self.$highlightedGIF.animation().wrappedValue = item
                }
            }, pressAction: { item, pressing in
                if pressing {
                    self.longPressCoordinator.item = item
                    self.longPressCoordinator.resetTimer()
                } else {
                    self.longPressCoordinator.cancel()
                }
                
            }) { idx, item, size in
                //            Group {
                
                self.item(idx, item, size)
            }
            .onAppear {
                Delayed(0.2) {
                    self.loaded = true
                }
            }
            

                //            .numberOfColumns(self.deviceDetails.uiIdiom == .pad ? 5 : 3)
                //            .itemSpacing(self.deviceDetails.uiIdiom == .pad ? 20 : 2)
                //            .rowPadding(self.deviceDetails.uiIdiom == .pad ? EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20) : EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                //            .scrollViewInsets(EdgeInsets(top: 0, leading: 0, bottom: 60 + metrics.safeAreaInsets.bottom, trailing: 0))
//                .onReceive(self.gallery.objectWillChange) { _ in
//                    Async {
//                        self.$gifCount.animation(Animation.default.delay(0.1)).wrappedValue = self.gallery.gifs.count
//                    }
            //            }
            
//        }
        
        
    }
    
    func item(_ idx: Int, _ item: GIF, _ size: CGSize) -> some View {
        
//        let f = itemMetrics.frame(in: .global)
//        let visible = UIScreen.main.bounds.intersects(f) && f.size.height > 0 && f.size.height > 10
//
        return
            
//            ConditionalVisibleView(visible: visible, id: item.id) {
//                Rectangle().foregroundColor(Color.gray)
            Image(uiImage: item.thumbnail!)
                .resizable()
                .aspectRatio(nil, contentMode: self.deviceDetails.uiIdiom == .pad ? .fit : .fill)
//                .scaled(self.deviceDetails.uiIdiom == .pad ? .toFit : .toFill)

//        }.equatable()

        .frame(width: size.width, height: size.height)
        .addItemOpacity(item: item, highlightedGIF: self.highlightedGIF, selectedGIFs: self.selectedGIFs, selectionMode: self.selectionMode)
        .scaleEffect(self.highlightedGIF == item ? 0.8 : 1)
        .brightness(self.pressingGIF == item ? 0.3 : 0)
        .clipped()
        .modifier(ItemAppearModifier(visible: self.$loaded, delay: 0.2 + (Double(idx) / 20), condition: idx < 50))
        
        .saveAnchorFrame(to: SelectedItemFrameKey.self, condition: self.selectedGIFs.first == item)
    }
    
    
    
    
}

class VisibleCounter {
    
    static var visible = [String]() {
        didSet {
            print("\(visible.count)")
        }
    }
}

struct ConditionalVisibleView<Content> : View, Equatable where Content: View {
    
    static func == (lhs: ConditionalVisibleView<Content>, rhs: ConditionalVisibleView<Content>) -> Bool {
        lhs.visible == rhs.visible
    }
    
    
    let visible: Bool
    
    let id: String
    
    let content: Content
    
    init(visible: Bool, id: String, @ViewBuilder content: () -> Content) {
        self.visible = visible
        self.content = content()
        self.id = id
        
        if visible {
            if !VisibleCounter.visible.contains(id) {
                VisibleCounter.visible.append(id)
            }
        } else {
            if let idx = VisibleCounter.visible.firstIndex(of: id) {
                VisibleCounter.visible.remove(at: idx)
            }
        }
    }
    
    var body : some View {
        Group {
            if visible {
                self.content
            } else {
                Rectangle().foregroundColor(Color.background)
            }
        }
    }
    
}

struct EquatableImage: View, Equatable {
    
    let gif: GIF
    
    
    var body: some View {
            
                Image(uiImage: gif.thumbnail!)
                    .resizable()
            
        //                    .clipped()
    }
    
}

struct ItemAppearModifier : ViewModifier {
    
    @Binding var visible: Bool
    let delay: Double
    
    let condition: Bool
    
    func body(content: Self.Content) -> some View {
        Group {
            if condition {
                content
                    .opacity(self.visible ? 1 : 0)
                    .blur(radius: self.visible ? 0 : 30)
                    .scaleEffect(self.visible ? 1 : 0.5)
//                .compositingGroup()
                    .animation(Animation.spring(response: 0.3, dampingFraction: 0.5).delay(self.delay), value: self.visible)
            } else {
                content
            }
        }
        
    }
    
    init(visible: Binding<Bool>, delay: Double, condition: Bool = true) {
        self._visible = visible
        self.delay = delay
        self.condition = condition
    }
}

fileprivate extension View {
    func addItemOpacity(item: GIF, highlightedGIF: GIF?, selectedGIFs: [GIF], selectionMode: Bool) -> some View {
        return self.opacity(highlightedGIF == item ? 0.2 : selectedGIFs.first == item && !selectionMode ? 0 : 1)
        
    }
    
    func conditionalClipped(_ clipped: Bool) -> some View {
        Group {
            if clipped {
                self.clipped()
            } else {
                self
            }
        }
    }
}

class TransitionAnimationContext: ObservableObject {
    @Published var isInProgress = false
    @Published var isComplete = false
    @Published var hideTransitionImage = false
    @Published var transitioningOut = false
    @Published var detailViewVisible = false
    @Published var currentTransform: CGAffineTransform = .identity
    
    var metrics: GeometryProxy?
    var center = CGPoint.zero
    var bounds = CGRect.zero
    
    var boundsAnchor: Anchor<CGRect>?
    
    var activeGIF: GIF!
    var isActive: Bool { return !isInProgress && !isComplete }
    
    func reset() {
        self.isInProgress = false
        self.isComplete = false
        self.hideTransitionImage = false
        self.transitioningOut = false
        self.detailViewVisible = false
        self.currentTransform = .identity
    }
    
    init() {
        print("initing animation contet")
    }
}

struct GalleryContainer: View {
    
    
//    GalleryContainer(activePopover: self.$globalState.activePopover, galleryStore: self.$globalState.galleryStore, transitionAnimation: self.transitionAnimationContext)
    
    init(activePopover: Binding<ActivePopover?>, galleryStore: Binding<GalleryStore>, transitionAnimation: TransitionAnimationContext) {
        self._activePopover = activePopover
        self._galleryStore = galleryStore
        self.transitionAnimation = transitionAnimation
    }
    @State var transitionContext = TransitionContext()
    
    @State var pressingGIF: GIF? = nil
    
    @State var selectedGIFs = [GIF]()
    @State var selectionMode = false
    @State var gifs = [GIF]()
    
    enum ActiveGallery: Int {
        case photoLibrary
        
        case local
    }
    
    @State var activeTab: Int = 0
    
    var activeGallery: Int {
        if self.activeTab >= self.galleryStore.galleries.count {
            return self.galleryStore.galleries.count - 1
        }
        
        return self.activeTab
    }
    
    var gallery: some Gallery {
        return self.galleryStore.galleries[self.activeGallery]
    }
    
    var galleryBinding: Binding<Gallery> {
        return self.$galleryStore.galleries[self.activeGallery]
    }
    
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
        return !self.selectionMode && self.selectedGIFs.count > 0
    }
    
    @State var highlightedGIF: GIF? = nil
    
    @State var removeGIFView = false
    
    @State var loaded = false
    
    @State var showPlusMenu = false
    
    
    let hudAlertState: HUDAlertState = HUDAlertState.global
    
    @Environment(\.deviceDetails) var deviceDetails: DeviceDetails
    
    var body: some View {
        var tabs = [TabModel]()
        for gallery in self.galleryStore.galleries {
            if let x = self.galleryStore.galleries.firstIndex(of: gallery) {
                tabs.append(TabModel(x, title: Text(gallery.title), image: gallery.tabImage))
            }
        }
        
        tabs.append(TabModel(tabs.count, title: Text("Settings"), image: Image.symbol("gear")!))
        
        return ZStack {
            if !self.loaded {
                ActivityIndicatorView().zIndex(0)
            }
            
//            TabView(selection: self.$activeTab) {
//                self.getMainView(gallery: self.galleryStore.galleries[0], title: self.galleryStore.galleries[0].title, leadingNavItems: self.getLeadingNavItem(), trailingNavItems: self.getTrailingBarItem())
//                    .tabItem {
//                        self.galleryStore.galleries[0].tabImage
//                        Text(self.galleryStore.galleries[0].title)
//                }.tag(0)
//
//                self.getMainView(gallery: self.galleryStore.galleries[1], title: self.galleryStore.galleries[1].title, leadingNavItems: EmptyView(), trailingNavItems: EmptyView())
//                    .tabItem {
//                        self.galleryStore.galleries[1].tabImage
//                        Text(self.galleryStore.galleries[1].title)
            //                }.tag(1)
            //
            //                SettingsView()
            //                    .environmentObject(Settings.shared).tabItem {
            //                        Image.symbol("gear")
            //                        Text("Settings")
            //                }.tag(2)
            //            }
            //            .navigationViewStyle(StackNavigationViewStyle())
            //
            //            .opacity(self.loaded ? 1 : 0)
            //            .edgesIgnoringSafeArea(.top)
            //
            //            .zIndex(0)
            
            CustomTabView(selectedTab: self.$activeTab, tabs: tabs, content: { tab in
                
//                Group {
                    if tab.id == tabs.count - 1 {
                        SettingsView()
                            .environmentObject(Settings.shared)
                        
                    } else {
                        if tab.id == 0 {
                            self.getMainView(gallery: self.galleryStore.galleries[tab.id],
                            title: self.galleryStore.galleries[tab.id].title, leadingNavItems: tab.id == 0 ? self.getLeadingNavItem().any : EmptyView().any,
                            trailingNavItems: tab.id == 0 ? self.getTrailingBarItem().any : EmptyView().any)
                        } else {
                            self.getMainView(gallery: self.galleryStore.galleries[tab.id],
                            title: self.galleryStore.galleries[tab.id].title, leadingNavItems: tab.id == 0 ? self.getLeadingNavItem().any : EmptyView().any,
                            trailingNavItems: tab.id == 0 ? self.getTrailingBarItem().any : EmptyView().any)
                        }
                        
                    }
//                }

            })
                .navigationViewStyle(StackNavigationViewStyle())
                
                .opacity(self.loaded ? 1 : 0)
                .zIndex(0)
            
            
            
            
            if self.highlightedGIF != nil {
                Group {
                    Rectangle().foregroundColor(Color.primary.opacity(0.01)).edgesIgnoringSafeArea([.top, .bottom]).zIndex(300)
                    
                    VisualEffectView.blur(.regular)
                        //                        .opacity(0.95)
                        .edgesIgnoringSafeArea([.top, .bottom])
                        .zIndex(301)
                        .transition(AnyTransition.opacity.animation(.easeIn))
                    
                    ContextPopupView(gif: self.highlightedGIF!)
                        .zIndex(302)
                        .transition(AnyTransition.scale(scale: 0.4)
                            .combined(with: .opacity)
                            .animation(Animation.spring(dampingFraction: 0.5)
                                .speed(1.1)))
                }.zIndex(299).onTapGesture {
                    self.pressingGIF = nil
                    self.$highlightedGIF.animation().wrappedValue = nil
                }
            }
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.75) {
                self.$loaded.animation().wrappedValue = true
            }
        }.actionSheet(item: self.$visibleActionSheet) { (_) -> ActionSheet in
            self.getActionSheet()
        }.overlay(ZStack {
            EmptyView().zIndex(0)
            
            if self.showPlusMenu {
                self.getPlusMenu().zIndex(1)
            }
            
        })
            .overlayPreferenceValue(SelectedItemFrameKey.self) { val in
                GeometryReader { overlayMetrics in
                    
                    Group {
                        
                        //                        self.getTransitionViewOverlay(metrics: overlayMetrics, frame: val).contentShape(Rectangle().size(CGSize.zero)).allowsHitTesting(false).zIndex(999)
                        //
                        if self.showingGIF {
                            self.getGIFView(metrics: overlayMetrics, selectedItemFrame: val)
                            
                                //                    .opacity(self.transitionAnimation.isComplete ? 1 : 0)
                                .zIndex(1000)
                        }
                        
                        
                        
                    }.background(Color.clear)
                    
                }.background(Color.clear)
        }
    }
    
    @State var imageOffset = CGPoint.zero
    
    
    
    @ObservedObject var transitionAnimation: TransitionAnimationContext
    
    
    func add(with data: Data) {
        self.gallery.add(data: data) { _, error in
            DispatchQueue.main.async {
                let message: HUDAlertMessage
                if error != nil {
                    message = HUDAlertMessage(text: "Error adding GIF", symbolName: "hand.thumbsdown.fill")
                } else {
                    message = HUDAlertMessage(text: "GIF Added", symbolName: "hand.thumbsup.fill")
                }
                
                self.hudAlertState.hudAlertMessage = [message]
            }
        }
    }
    
    func getPlusMenu() -> some View {
        
        
        var createItems = [MenuItem(image: Image.symbol("photo.on.rectangle", .init(scale: .large)),
                                    text: Text("Photo Library"),
                                    action: .action {
                                        Delayed(0.1) {
                                            self.activePopover = .videoPicker
                                        }
                                        
            }),
                           MenuItem(image: Image.symbol("magnifyingglass", .init(scale: .large)),
                                    text: Text("Browse Files"),
                                    action: .action {
                                        
                                        Delayed(0.1) {
                                            self.activePopover = .docBrowser
                                        }}),
                           
                           
                           MenuItem(image: Image.symbol("pencil.and.ellipsis.rectangle", .init(scale: .large)),
                                    text: Text("From URL"),
                                    action: .action {
                                        
                                        Delayed(0.1) {
                                            self.activePopover = .urlDownload
                                        }
                                                                                
                            })]
        
        if let prevUrl = (GlobalState.instance.previousURL?.nilOrNotEmpty ?? GlobalState.instance.video.url.nilOrNotEmpty), FileManager.default.fileExists(atPath: prevUrl.path),  AVURLAsset.init(url: prevUrl).isReadable {
            createItems.append(MenuItem(image: Image.symbol("arrowshape.turn.up.left", .init(scale: .large)), text: Text("Last Video"), action: .action {
                Delayed(0.1) {
                    GlobalState.instance.video.reset(prevUrl)
                }
                }))
        }
        
        let items = [
            MenuItem(image: Image.symbol("plus", .init(scale: .large)),
                     text: Text("Create from Video"),
                     action: .expand("Select a video", createItems)),
            MenuItem(image: Image.symbol("doc.on.clipboard.fill", .init(scale: .large)),
                     text: Text("Paste GIF"),
                     action: .action {
                        self.hudAlertState.showLoadingIndicator = true
                        
                        self.handlePaste()
                }),
        ]
        
        return MenuView(menuItems: items) {
            self.$showPlusMenu.animation().wrappedValue = false
        }.onDisappear {
            self.showPlusMenu = false
        }
    }
    
    func handlePaste() {
        
//        DispatchQueue.main.async {
//            if let image = UIPasteboard.general.data(forPasteboardType: "com.compuserve.gif") {
//                self.add(with: image)
//                return
//            }
//            
//            
//            if let url = UIPasteboard.general.url,
//                url.absoluteString.lowercased().contains(".gif"),
//                let data = try? Data(contentsOf: url),
//                data.count > 0 {
//                self.add(with: data)
//            } else {
//                for item in UIPasteboard.general.items {
//                    let dataItems = item.values.compactMap { v in
//                        return v as? Data
//                    }
//                    for value in dataItems {
//                        self.add(with: value)
//                    }
//                }
//                
//                let message = HUDAlertMessage(text: "No GIF found", symbolName: "questionmark.circle.fill")
//                self.hudAlertState.hudAlertMessage = [message]
//            }
//        }
        
    }
    
    func getGIFView(metrics: GeometryProxy, selectedItemFrame: AnchoredFrame) -> some View {
        print("get gif view")
        let localbounds = selectedItemFrame.bounds != nil ? metrics[selectedItemFrame.bounds!] : CGRect.zero
        
        if self.selectedGIFs.count > 0 {
            self.transitionAnimation.activeGIF = self.selectedGIFs.first
            self.transitionAnimation.bounds = localbounds
            self.transitionAnimation.boundsAnchor = selectedItemFrame.bounds
        }
        
        self.transitionAnimation.metrics = metrics
        return
            GIFView(gallery: self.gallery, removeGIFView: self.$removeGIFView, transitionContext: self.transitionContext,
                    selectedGIFs: self.$selectedGIFs,
                    toolbarBuilder: self.getToolbar,
                    currentTransform: self.$transitionAnimation.currentTransform,
                    imageOffset: self.$imageOffset,
                    transitionAnimation: self.transitionAnimation)
                .onAppear(perform: {
                    print("appeared")
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                        self.transitionContext.disableAnimation = false
                    }
                })
                .onDisappear(perform: {
                    print("disappear")
                    self.transitionContext.fullscreen = false
                    self.selectedGIFs = []
                    self.transitionAnimation.reset()
                })
        //                .transition(AnyTransition.opacity.animation(Animation.easeIn(duration: 0.2)))
        
    }
    
    @State var loadCV = true
    @State var galleryLoaded = false
    @State var navLoaded = false
    @State var hideActivityIndicator = true
    func getMainView<L, T>(gallery: Gallery, title: String, leadingNavItems: L, trailingNavItems: T) -> some View where T: View, L: View {
        
        GalleryMainView(gallery: gallery, title: title, leadingNavItems: leadingNavItems, trailingNavItems: trailingNavItems, selectionMode: self.selectionMode) {
            Group {
                CollectionViewWrapper(selectedGIFs: self.$selectedGIFs, selectionMode: self.$selectionMode, transitionContext: self.$transitionContext, highlightedGIF: self.$highlightedGIF, pressingGIF: self.$pressingGIF)
                    .environmentObject(gallery)
                    .zIndex(1)
                
                if self.showToolbar {
                    GeometryReader { metrics in
                        self.getToolbar(with: metrics).background(Color.clear)
                            .transition(.opacity)
                    }.zIndex(2)
                }
                
            }
            
        }

        .equatable()
        
                        


        
    }
    
    func getToolbar(with metrics: GeometryProxy, background: AnyView = VisualEffectView(effect: .init(style: .prominent)).any) -> AnyView {
        return ToolbarView(metrics: metrics, background: background) {
            Button(action: {
                GlobalPublishers.default.showShare.send(self.selectedGIFs)
            }, label: { Image.symbol("square.and.arrow.up") })
                .disabled(self.selectedGIFs.count == 0)
                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
            Spacer()
            Button(action: {
//                withAnimation {
//                    self.gallery.remove(self.selectedGIFs)
//                    self.selectedGIFs = []
//                }
            }, label: { Image.symbol("trash") })
                .disabled(self.selectedGIFs.count == 0)
                .padding(12).opacity(self.selectedGIFs.count > 0 ? 1 : 0.5)
        }.frame(height: metrics.size.height, alignment: .bottom).any
    }
    
    func getLeadingNavItem() -> some View {
        Group {
            if !self.selectionMode {
                Button(action: {
                                  withAnimation {
                                      self.selectionMode = true
                                      self.showToolbar = true
                                  }
                                  
                              }, label: { Text("Select") })
            }
        }
    }
    
    func getTrailingBarItem() -> some View {
        if self.selectionMode {
            return Button(action: {
                withAnimation {
                    self.selectedGIFs = []
                    self.selectionMode = false
                    self.showToolbar = false
                }
                
            }, label: { Text("Done") }).any
        } else {
            return Button(action: {
                //                    self.visibleActionSheet = .addMenu
                self.$showPlusMenu.animation().wrappedValue = true
            }, label: { Image.symbol("plus", .init(scale: .medium))?.padding(5) }).any
        }
    }
    
    func getActionSheet() -> ActionSheet {
        func add(with data: Data) {
            self.gallery.add(data: data) { _, error in
                DispatchQueue.main.async {
                    let message: HUDAlertMessage
                    if error != nil {
                        message = HUDAlertMessage(text: "Error adding GIF", symbolName: "hand.thumbsdown.fill")
                    } else {
                        message = HUDAlertMessage(text: "GIF Added", symbolName: "hand.thumbsup.fill")
                    }
                    
                    self.hudAlertState.hudAlertMessage = [message]
                }
            }
        }
        
        switch self.visibleActionSheet {
        case .addMenu:
            fatalError()
            //            return ActionSheet(title: Text("Add or Create"), message: nil, buttons: [.default(Text("Create from Video").foregroundColor(Color.accent), action: {
            //                self.visibleActionSheet = nil
            //                DispatchQueue.main.async {
            //                    self.visibleActionSheet = .createMenu
            //                }
            //                }), .default(Text("Paste GIF").foregroundColor(Color.accent), action: {
            //                    self.hudAlertState.showLoadingIndicator = true
            //                    DispatchQueue.main.async {
            //                        if let image = UIPasteboard.general.data(forPasteboardType: "com.compuserve.gif") {
            //                            add(with: image)
            //                        } else if let url = UIPasteboard.general.url, url.absoluteString.lowercased().contains(".gif"), let data = try? Data(contentsOf: url), data.count > 0 {
            //                            add(with: data)
            //                        } else {
            //                            for item in UIPasteboard.general.items {
            //                                for value in item.values {
            //                                    if value is Data {
            //                                        add(with: value as! Data)
            //                                        return
            //                                    }
            //                                }
            //                            }
            //
            //                            let message = HUDAlertMessage(text: "No GIF found", symbolName: "questionmark.circle.fill")
            //                            self.hudAlertState.hudAlertMessage = [message]
            //                        }
            //                    }
            //                }), .cancel {
            //                    self.showingActionSheet = false
            //            }])
        //
        case .createMenu:
            return ActionSheet(title: Text("Create GIF from Video"), message: nil, buttons: [.default(Text("Photo Library").foregroundColor(Color.accent), action: {
                self.activePopover = .videoPicker
            }), .default(Text("Browse").foregroundColor(Color.accent), action: {
                self.activePopover = .docBrowser
            }), .cancel {
                self.showingActionSheet = false
                }])
        case .none:
            fatalError()
        }
    }
}


struct GalleryMainView<Content, L, T>: View, Equatable where Content : View, L: View, T: View {
    static func == (lhs: GalleryMainView<Content, L, T>, rhs: GalleryMainView<Content, L, T>) -> Bool {
        return lhs.title == rhs.title && lhs.selectionMode == rhs.selectionMode
    }
    
    
    let gallery: Gallery
    let title: String
    let leadingNavItems: L
    let trailingNavItems: T
    let selectionMode: Bool
    
    let content: () -> Content
    
    init(gallery: Gallery, title: String, leadingNavItems: L, trailingNavItems: T, selectionMode: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.gallery = gallery
        self.title = title
        self.leadingNavItems = leadingNavItems
        self.trailingNavItems = trailingNavItems
        self.content = content
        self.selectionMode = selectionMode
        self.loadCV = false
        self.galleryLoaded = false
        self.navLoaded = false
        
    }
    
    
    @State var loadCV = false
    @State var galleryLoaded = false
    @State var navLoaded = false
    @State var hideActivityIndicator = true
    var body: some View {
        return NavigationView {
            ZStack {
                if gallery.unableToLoad != nil {
                    gallery.unableToLoad
                } else {
                    
                    if self.loadCV {
                        content()
                        .opacity(self.galleryLoaded ? 1 : 0)
                            .onAppear {
                                Delayed(0.5) {
                                    self.galleryLoaded = true

                                }
                        }
                        .transition(AnyTransition.opacity.animation(Animation.default))
             

                        
                    }
                }
                
            }.navigationBarTitle(title)
                .navigationBarItems(leading: leadingNavItems, trailing: self.hideActivityIndicator ? trailingNavItems.any : LoadingCircleView().frame(width: 30, height: 30).any)
        }
        .navigationViewStyle(StackNavigationViewStyle())
            
            
        .onDisappear {
            self.galleryLoaded = false
            self.loadCV = false
            self.$navLoaded.animation(Animation.default).wrappedValue = false
            self.hideActivityIndicator = false
        }
        .onAppear {
            Delayed(0.2) {
                self.loadCV = true
            }

            Delayed(2) {
                self.$hideActivityIndicator.animation(Animation.default).wrappedValue = true
            }
        }
        .opacity(self.navLoaded ? 1 : 0)
        .onAppear {
            self.$navLoaded.animation(Animation.easeIn(duration: 0.1)).wrappedValue = true

        }

        
    }
    
    
}
