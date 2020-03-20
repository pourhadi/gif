//
//  CollectionView.swift
//
//  Created by Daniel Pourhadi on 12/26/19.
//  Copyright © 2019 dan pourhadi. All rights reserved.
//

import Combine
import Introspect
import SnapKit
import SwiftUI
import UIKit

class Cell: UICollectionViewCell {
    var host = UIHostingController(rootView: EmptyView().any)
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.host.view.superview == nil {
            self.contentView.addSubview(self.host.view)
            //            self.host.view.snp.makeConstraints { make in
            //                make.edges.equalToSuperview()
            //            }
            
            self.contentView.clipsToBounds = true
            self.clipsToBounds = true
            self.host.view.clipsToBounds = true
        }
        
        self.host.view.frame = self.contentView.bounds
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct FlowCollectionView<Item, ItemContent, PreviewContent>: UIViewRepresentable, Equatable where ItemContent: View, Item: Identifiable & Equatable, PreviewContent: View {
    static func == (lhs: FlowCollectionView<Item, ItemContent, PreviewContent>, rhs: FlowCollectionView<Item, ItemContent, PreviewContent>) -> Bool {
        lhs.items.count == rhs.items.count && lhs.selectedItems == rhs.selectedItems && lhs.selectionMode == rhs.selectionMode && lhs.scrolled == rhs.scrolled && lhs.contentHeight == rhs.contentHeight && lhs.layout == rhs.layout && lhs.verticalSizeClass == rhs.verticalSizeClass
    }
    
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    
    @State private var storedLayout: CollectionViewLayout? = nil
    
    private var layout: CollectionViewLayout = CollectionViewLayout()
    
    @Binding private var items: [Item]
    
    @Binding private var selectedItems: [Item]
    @Binding private var selectionMode: Bool
    
    private var numberOfColumns: Int {
        return self.layout.numberOfColumns
    }
    
    private var itemSpacing: CGFloat {
        return self.layout.itemSpacing
    }
    
    private var rowHeight: CollectionViewRowHeight {
        return self.layout.rowHeight
    }
    
    private let itemBuilder: (Int, Item, CGSize, Bool) -> ItemContent
    private let tapAction: ((Item) -> Void)?
    private let longPressAction: ((Item) -> Void)?
    private let pressAction: ((Item, Bool) -> Void)?
    private let previewContent: ((Item) -> PreviewContent)?
    
    @State private var metrics: GeometryProxy? = nil
    @State private var metricsFrame: CGRect = .zero
    
    @State private var load = false
    
    @State var scrolled = false
    
    @State var appeared = false
    
    @State var contentHeight: CGFloat = 0
    
    @State var invalidateLayout: Bool = false
    
    @State var reloadData = false
    
    public init(items: Binding<[Item]>,
                selectedItems: Binding<[Item]>,
                selectionMode: Binding<Bool>,
                layout: CollectionViewLayout = CollectionViewLayout(),
                tapAction: ((Item) -> Void)? = nil,
                longPressAction: ((Item) -> Void)? = nil,
                pressAction: ((Item, Bool) -> Void)? = nil,
                @ViewBuilder previewContent: @escaping (Item) -> PreviewContent,
                             @ViewBuilder itemBuilder: @escaping (Int, Item, CGSize, Bool) -> ItemContent) {
        self._items = items
        self._selectedItems = selectedItems
        self._selectionMode = selectionMode
        self.itemBuilder = itemBuilder
        self.tapAction = tapAction
        self.longPressAction = longPressAction
        self.pressAction = pressAction
        self.previewContent = previewContent
        
        print("\(layout.numberOfColumns)")
        self.layout = layout
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        let cv = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        cv.delegate = context.coordinator
        cv.dataSource = context.coordinator
        cv.register(Cell.self, forCellWithReuseIdentifier: "cell")
        cv.contentInsetAdjustmentBehavior = .always
        cv.isPrefetchingEnabled = false
        
     
        return cv
    }
    
    func updateUIView(_ uiView: UICollectionView, context: Context) {
        print("update collection view representable")
        
        Async {
            context.coordinator.transaction = context.transaction
            var reload = false
            var invalidateLayout = false
            var added = [IndexPath]()
            var removed = [IndexPath]()
            
            if context.environment.verticalSizeClass == .compact, self.layout.numberOfColumns == 3 {
                invalidateLayout = true
            } else if context.environment.verticalSizeClass != .compact, self.layout.numberOfColumns == 5, context.environment.deviceDetails.uiIdiom != .pad {
                invalidateLayout = true
            }
            
            if context.coordinator.previousValues.layout != self.layout || context.coordinator.firstRun {
                print("layout changed")
                context.coordinator.firstRun = false

                
                let layout = uiView.collectionViewLayout as! UICollectionViewFlowLayout
                
                layout.sectionInset = UIEdgeInsets(top: self.layout.scrollViewInsets.top, left: 0, bottom: self.layout.scrollViewInsets.bottom, right: 0)
                
                layout.itemSize = CGSize(width: self.getColumnWidth(for: uiView.frame.size.width), height: self.getRowHeight(for: 0, metrics: uiView.frame.size))
                
                invalidateLayout = true
                reload = true
            }
            
            if context.coordinator.selectionMode != self.selectionMode {
                print("reload data")
                reload = true
            }
            
            if context.coordinator.selectedItems != self.selectedItems {
                reload = true
            }
            
            if context.coordinator.items != self.items {
                reload = true 
                if context.coordinator.items.count == 0 && false {
                    reload = true
                } else {
                    
                    let diff = self.items.difference(from: context.coordinator.items)
                    
                    for change in diff {
                        switch change {
                        case .insert(let offset, _, _):
                            added.append(IndexPath(item: offset, section: 0))
                        case .remove(let offset, _, _):
                            removed.append(IndexPath(item: offset, section: 0))
                        }
                    }
                }
            }
            
            var scrollDown = false
            
            if context.coordinator.items.count < self.items.count {
                scrollDown = true
            }
            
//            uiView.performBatchUpdates({
                context.coordinator.previousValues.layout = self.layout
                context.coordinator.previousValues.itemCount = self.items.count
                context.coordinator.selectedItems = self.selectedItems
                context.coordinator.selectionMode = self.selectionMode
                context.coordinator.items = self.items
                
//                uiView.insertItems(at: added)
//                uiView.deleteItems(at: removed)
                
                if invalidateLayout {
                    uiView.collectionViewLayout.invalidateLayout()
                    uiView.reloadData()
                } else if reload {
                    uiView.reloadData()
                }
                

                
//            }) { _ in
                
                
                context.coordinator.transaction = nil
                
                
                if scrollDown {
//                    uiView.scrollToItem(at: IndexPath(item: context.coordinator.items.count - 1, section: 0), at: .bottom, animated: false)
                }
            }
            
//        }
    }
    
    typealias UIViewType = UICollectionView
    
    class Coordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var transaction: Transaction?
        
        var firstRun = true
        
        class PreviousValues {
            var itemCount: Int = 0
            
            var layout: CollectionViewLayout = CollectionViewLayout()
        }
        
        var selectedItems: [Item] = [] {
            didSet {
                
                guard self.selectedItems != self.parent.selectedItems else {
                    return
                }
                
                self.parent.selectedItems = self.selectedItems
            }
        }
        var selectionMode: Bool = false {
            didSet {
                guard self.selectionMode != self.parent.selectionMode else { return }
                self.parent.selectionMode = self.selectionMode
            }
        }
        
        var items: [Item] = []
        
        let previousValues = PreviousValues()
        
        var scrolled = false
        
        //        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        //            return UIEdgeInsets(top: self.parent.layout.scrollViewInsets.top, left: 0, bottom: 0, right: 0)
        //        }
        //
        
        
        
        func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
            let item = self.items[indexPath.item]
            return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: { () -> UIViewController? in
                
                if let preview = self.parent.previewContent {
                    let vc = UIHostingController(rootView: preview(item))
                    vc.view.backgroundColor = UIColor.clear
                    return vc
                } else {
                    return nil
                }
            }) { elements -> UIMenu? in
                
                for element in elements {}
                
                return nil
            }
        }
        
        func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
            let indexPath = configuration.identifier as! IndexPath
            
            let item = self.items[indexPath.item]
            self.selectedItems = [item]
            collectionView.reloadItems(at: [indexPath])
        }
        
        func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
            let item = self.items[indexPath.item]
            collectionView.reloadItems(at: [indexPath])
            
            if self.selectionMode {
                if let index = self.selectedItems.firstIndex(of: item) {
                    self.selectedItems.remove(at: index)
                } else {
                    self.selectedItems.append(item)
                }
            } else {
                self.selectedItems = [item]
            }
            
            self.parent.tapAction?(self.items[indexPath.item])
            
            collectionView.reloadItems(at: [indexPath])
            
            return false
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return self.parent.itemSpacing
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            return self.parent.itemSpacing
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            print("item count: \(self.items.count)")
            return self.items.count
        }
        
        //        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //            return CGSize(width: self.parent.getColumnWidth(for: collectionView.frame.size.width), height: self.parent.getRowHeight(for: indexPath.item, metrics: collectionView.frame.size))
        //        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! Cell
            let item = self.items[indexPath.item]
            let content = self.parent.itemBuilder(indexPath.item,
                                                  item,
                                                  CGSize(width: self.parent.getColumnWidth(for: collectionView.frame.size.width), height: self.parent.getRowHeight(for: indexPath.item, metrics: collectionView.frame.size)),
                                                  self.selectedItems.contains(item))
            //                .animation(self.transaction?.animation)
            
            var anyContent = content.any
            
            if self.selectionMode {
                anyContent = ZStack {
                    content.zIndex(0)
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .background(self.selectedItems.contains(item) ? Color.accentColor : Color.clear)
                        .clipShape(Circle())
                        
                        .frame(width: 20, height: 20)
                        //                                .position(x: itemMetrics.size.width - 18, y: itemMetrics.size.height - 18)
                        .shadow(radius: 2)
                        .zIndex(1)
                }.drawingGroup(opaque: true).any
            }
            
            cell.host.rootView = anyContent
            return cell
        }
        
        //        func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        //            let cell = cell as! Cell
        //
        //            cell.host.rootView = EmptyView().any
        //        }
        //
        //        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        //            let cell = cell as! Cell
        //
        //
        //        }
        
        let parent: FlowCollectionView
        var cancellable: AnyCancellable?
        init(_ parent: FlowCollectionView) {
            self.parent = parent
            super.init()
        }
    }
    
    private func getColumnWidth(for width: CGFloat) -> CGFloat {
        let totalRowPadding = self.layout.rowPadding.leading + self.layout.rowPadding.trailing
        let totalSpacing = self.itemSpacing * CGFloat(self.layout.numberOfColumns - 1)
        let totalInsets = self.layout.scrollViewInsets.leading + self.layout.scrollViewInsets.trailing
        var w = width - (totalRowPadding + totalSpacing + totalInsets)
        w /= CGFloat(self.layout.numberOfColumns)
        
        //        let w = ((width - (self.layout.rowPadding.leading + self.layout.rowPadding.trailing + (self.layout.itemSpacing * CGFloat(self.layout.numberOfColumns - 1)))) / CGFloat(self.layout.numberOfColumns))
        
        //        return width / CGFloat(self.layout.numberOfColumns)
        
        return w
    }
    
    private func getRowHeight(for row: Int, metrics: CGSize) -> CGFloat {
        switch self.rowHeight {
        case .constant(let constant): return constant
        case .sameAsItemWidth:
            return self.getColumnWidth(for: metrics.width)
        case .dynamic(let rowHeightBlock):
            return rowHeightBlock(row, self.itemSpacing, self.numberOfColumns)
        }
    }
}

struct CollectionScrollView<Content>: UIViewRepresentable where Content: View {
    @Binding var appeared: Bool
    var content: () -> Content
    
    init(appeared: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self._appeared = appeared
        self.content = content
    }
    
    @State var scrolled = false
    
    let vc = UIHostingController(rootView: EmptyView().any)
    
    func makeUIView(context: Context) -> UIScrollView {
        let v = UIScrollView()
        
        v.addSubview(self.vc.view)
        
        self.vc.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return v
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        self.vc.rootView = self.content().any
        
        if self.appeared, !self.scrolled, uiView.contentSize.height > uiView.frame.size.height {
            uiView.scrollRectToVisible(CGRect(x: 0, y: uiView.contentSize.height - 5, width: uiView.contentSize.width, height: 5), animated: false)
            
            Async {
                self.scrolled = true
            }
        }
    }
    
    typealias UIViewType = UIScrollView
}

extension View {
    func scrollDown(scrolled: Binding<Bool>) -> some View {
        return self
        //        self.introspectScrollView { scrollView in
        //            if !scrolled.wrappedValue, scrollView.contentSize.height > scrollView.frame.size.height {
        //                scrollView.scrollRectToVisible(CGRect(x: 0, y: scrollView.contentSize.height - 5, width: scrollView.contentSize.width, height: 5), animated: false)
        //                scrolled.wrappedValue = true
        //            }
        //        }
    }
}

struct ScrollDownModifier: ViewModifier {
    @State var scrolled = false
    
    func body(content: Content) -> some View {
        return content
        //        content.introspectScrollView { scrollView in
        //            if !self.scrolled, scrollView.contentSize.height > scrollView.frame.size.height {
        //                scrollView.scrollRectToVisible(CGRect(x: 0, y: scrollView.contentSize.height - 5, width: scrollView.contentSize.width, height: 5), animated: false)
        //                self.scrolled = true
        //            }
        //        }
    }
}

extension View {
    func tweakTableView() -> some View {
        self.introspectTableView { tableView in
            tableView.separatorStyle = .none
            tableView.separatorInset = UIEdgeInsets.zero
            tableView.directionalLayoutMargins.leading = 0
            Delayed(2) {
                print(tableView.contentInset)
                print(tableView.safeAreaInsets)
            }
        }
    }
}

public let ScrollViewCoordinateSpaceKey = "ScrollViewCoordinateSpace"

public typealias CollectionViewRowHeightBlock = (_ row: Int, _ itemSpacing: CGFloat, _ numberOfColumns: Int) -> CGFloat

public enum CollectionViewRowHeight: Equatable {
    public static func == (lhs: CollectionViewRowHeight, rhs: CollectionViewRowHeight) -> Bool {
        lhs.val == rhs.val
    }
    
    case constant(CGFloat)
    case sameAsItemWidth
    case dynamic(CollectionViewRowHeightBlock)
    
    var val: String {
        switch self {
        case .constant: return "constant"
        case .sameAsItemWidth: return "sameAsItemWidth"
        case .dynamic: return "dynamic"
        }
    }
}

public struct CollectionViewLayout: Equatable {
    public static func == (lhs: CollectionViewLayout, rhs: CollectionViewLayout) -> Bool {
        lhs.rowPadding == rhs.rowPadding &&
            lhs.numberOfColumns == rhs.numberOfColumns &&
            lhs.itemSpacing == rhs.itemSpacing &&
            lhs.rowHeight == rhs.rowHeight &&
            lhs.scrollViewInsets == rhs.scrollViewInsets
    }
    
    public var rowPadding: EdgeInsets
    
    @Clamped(min: 2, max: 7)
    public var numberOfColumns: Int = 2
    
    public var itemSpacing: CGFloat
    public var rowHeight: CollectionViewRowHeight
    public var scrollViewInsets: EdgeInsets
    
    
    public init(rowPadding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
                numberOfColumns: Int = 3,
                itemSpacing: CGFloat = 2,
                rowHeight: CollectionViewRowHeight = .sameAsItemWidth,
                scrollViewInsets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) {
        self.rowPadding = rowPadding
        self.itemSpacing = itemSpacing
        self.rowHeight = rowHeight
        self.scrollViewInsets = scrollViewInsets
        
        self.numberOfColumns = numberOfColumns
    }
    
    mutating func withSafeAreaInsets(_ safeAreaInsets: EdgeInsets) -> Self {
        self.scrollViewInsets += safeAreaInsets
        return self
    }
}

public struct CollectionView<Item, ItemContent>: View where ItemContent: View, Item: Identifiable & Equatable {
    private var layout: CollectionViewLayout
    
    @Binding private var items: [Item]
    
    @Binding private var selectedItems: [Item]
    @Binding private var selectionMode: Bool
    
    private var numberOfColumns: Int {
        return self.layout.numberOfColumns
    }
    
    private var itemSpacing: CGFloat {
        return self.layout.itemSpacing
    }
    
    private var rowHeight: CollectionViewRowHeight {
        return self.layout.rowHeight
    }
    
    private let itemBuilder: (Int, Item, CGSize) -> ItemContent
    private let tapAction: ((Item) -> Void)?
    private let longPressAction: ((Item) -> Void)?
    private let pressAction: ((Item, Bool) -> Void)?
    
    @State private var metrics: GeometryProxy? = nil
    @State private var metricsFrame: CGRect = .zero
    
    @State private var load = false
    
    @State var scrolled = false
    
    @State var appeared = false
    
    public init(items: Binding<[Item]>,
                selectedItems: Binding<[Item]>,
                selectionMode: Binding<Bool>,
                layout: CollectionViewLayout = CollectionViewLayout(),
                tapAction: ((Item) -> Void)? = nil,
                longPressAction: ((Item) -> Void)? = nil,
                pressAction: ((Item, Bool) -> Void)? = nil,
                @ViewBuilder itemBuilder: @escaping (Int, Item, CGSize) -> ItemContent) {
        self._items = items
        self._selectedItems = selectedItems
        self._selectionMode = selectionMode
        self.itemBuilder = itemBuilder
        self.tapAction = tapAction
        self.longPressAction = longPressAction
        self.pressAction = pressAction
        self.layout = layout
    }
    
    private struct ItemRow: Identifiable {
        let id: Int
        let items: [Item]
    }
    
    public var body: some View {
        var currentRow = [Item]()
        var rows = [ItemRow]()
        
        for item in self.items {
            currentRow.append(item)
            
            if currentRow.count >= self.numberOfColumns {
                rows.append(ItemRow(id: rows.count, items: currentRow))
                currentRow = []
            }
        }
        
        if currentRow.count > 0 {
            rows.append(ItemRow(id: rows.count, items: currentRow))
        }
        
        return
            GeometryReader { metrics in
                
                if self.load && self.items.count > 0 {
                    /*
                     List(rows) { row in
                     
                     self.getRow(for: row, collectionViewBounds: {
                     
                     var size = metrics.size
                     size.width -= metrics.safeAreaInsets.leading + metrics.safeAreaInsets.trailing
                     return size
                     
                     }())
                     .padding([.top, .bottom], (-6.0 + (self.layout.itemSpacing / 2.0)))
                     .padding(self.padding(for: row.id, rowCount: rows.count))
                     .tweakTableView()
                     .offset(x: -15)
                     
                     }
                     .edgesIgnoringSafeArea([.leading, .trailing])
                     .coordinateSpace(name: "test")
                     */
                    
                    //                    CollectionScrollView(appeared: self.$appeared) {
                    
                    ScrollView {
                        VStack(spacing: self.itemSpacing) {
                            ForEach(rows) { row in
                                
                                self.getRow(for: row, collectionViewBounds: {
                                    var size = metrics.size
                                    size.width -= metrics.safeAreaInsets.leading + metrics.safeAreaInsets.trailing
                                    return size
                                    
                                }())
                                    .padding(self.padding(for: row.id, rowCount: rows.count))
                                //                                .drawingGroup(opaque: true)
                            }
                        }
                            
                        .padding(EdgeInsets(top: 0, leading: self.layout.scrollViewInsets.leading, bottom: 0, trailing: self.layout.scrollViewInsets.trailing)).zIndex(1)
                        .frame(width: metrics.size.width)
                    }
                    .modifier(ScrollDownModifier())
                    
                    //                    .coordinateSpace(name: ScrollViewCoordinateSpaceKey)
                }
            }
                
            .onAppear {
                self.appeared = true
                DispatchQueue.main.async {
                    self.load = true
                }
        }
    }
    
    //    private func getScrollView(pref: CollectionViewPreferences, metrics: GeometryProxy, rows: [ItemRow]) -> some View {
    //        let bounds = pref.bounds != nil ? metrics[pref.bounds!] : CGRect.zero
    //
    //        return
    //    }
    //
    //    private func getContents(bounds: CollectionViewMetrics, metrics: GeometryProxy, row: ItemRow) -> some View {
    //        let scrollViewBounds = bounds.scrollViewBounds != nil ? metrics[bounds.scrollViewBounds!] : CGRect.zero
    //        print(scrollViewBounds)
    //        func getRowIfVisible() -> some View {
    //            let itemBounds = bounds.itemBounds[row.id] != nil ? metrics[bounds.itemBounds[row.id]!] : CGRect.zero
    //
    //            return Group {
    //
    //                if itemBounds.size.height != 0 && scrollViewBounds.size != CGSize.zero && scrollViewBounds.intersects(itemBounds) {
    //                    self.getRow(for: row, collectionViewBounds: self.metricsFrame.size)
    //                        .frame(width: itemBounds.size.width, height: itemBounds.size.height)
    //
    //
    //                }
    //
    //            }
    //        }
    //
    //        return getRowIfVisible()
    //
    //
    /// /        return Rectangle().foregroundColor(Color.clear).frame(width: metrics.size.width, height: metrics.size.height)
    //    }
    
    func updateMetricsFrame(_ metrics: GeometryProxy) -> some View {
        let frame = metrics.frame(in: .global)
        return Run {
            if self.metricsFrame.size.width != frame.size.width {
                self.metricsFrame = frame
            }
        }
    }
    
    private func padding(for row: Int, rowCount: Int) -> EdgeInsets {
        let leading = self.layout.rowPadding.leading
        let trailing = self.layout.rowPadding.trailing
        
        var top = self.layout.rowPadding.top
        var bottom = self.layout.rowPadding.bottom
        
        if row == 0 {
            top += self.layout.scrollViewInsets.top
        }
        
        if row == rowCount - 1 {
            bottom += self.layout.scrollViewInsets.bottom
        }
        
        return EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
    
    private func getRow(for row: ItemRow, collectionViewBounds: CGSize) -> some View {
        func content(_ idx: Int, _ row: ItemRow, item: Item) -> some View {
            return
                ZStack {
                    Group {
                        self.itemBuilder(idx + (row.id * self.layout.numberOfColumns), item, CGSize(width: self.getColumnWidth(for: collectionViewBounds.width), height: self.getRowHeight(for: row.id, metrics: collectionViewBounds)))
                        
                        if self.selectionMode {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .background(self.selectedItems.contains(item) ? Color.accentColor : Color.clear)
                                .clipShape(Circle())
                                
                                .frame(width: 20, height: 20)
                                //                                .position(x: itemMetrics.size.width - 18, y: itemMetrics.size.height - 18)
                                .shadow(radius: 2)
                        }
                    }
                    .zIndex(2)
                    .allowsHitTesting(false)
                    Group {
                        Rectangle().foregroundColor(Color.clear)
                    }
                    .background(Color(UIColor.systemBackground))
                    .allowsHitTesting(true)
                    .zIndex(1)
                    .onTapGesture {
                        if self.selectionMode {
                            if let index = self.selectedItems.firstIndex(of: item) {
                                self.selectedItems.remove(at: index)
                            } else {
                                self.selectedItems.append(item)
                            }
                        } else {
                            self.selectedItems = [item]
                        }
                        
                        self.tapAction?(item)
                    }
                    .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 10, pressing: { pressing in
                        self.pressAction?(item, pressing)
                        
                    }) {
                        self.longPressAction?(item)
                    }
            }
            //            }
        }
        
        return
            
            HStack(spacing: self.itemSpacing) {
                ForEach(row.items) { item in
                    content(row.items.firstIndex(of: item)!, row, item: item)
                }
                
                if row.items.count < self.layout.numberOfColumns {
                    ForEach(row.items.count..<self.layout.numberOfColumns) { _ in
                        Rectangle()
                            .frame(width: self.getColumnWidth(for: collectionViewBounds.width))
                            .foregroundColor(Color.clear)
                    }
                }
            }
            .frame(width: collectionViewBounds.width,
                   height: self.getRowHeight(for: row.id, metrics: collectionViewBounds))
        //            EquatableView(content: EquatableRowContainer(rowId: row.id, height: self.getRowHeight(for: row.id, metrics: collectionViewBounds), content: {
        //
        //            }))
    }
    
    private func getColumnWidth(for width: CGFloat) -> CGFloat {
        let totalRowPadding = self.layout.rowPadding.leading + self.layout.rowPadding.trailing
        let totalSpacing = self.itemSpacing * CGFloat(self.layout.numberOfColumns - 1)
        let totalInsets = self.layout.scrollViewInsets.leading + self.layout.scrollViewInsets.trailing
        var w = width - (totalRowPadding + totalSpacing + totalInsets)
        w /= CGFloat(self.layout.numberOfColumns)
        
        //        let w = ((width - (self.layout.rowPadding.leading + self.layout.rowPadding.trailing + (self.layout.itemSpacing * CGFloat(self.layout.numberOfColumns - 1)))) / CGFloat(self.layout.numberOfColumns))
        
        //        return width / CGFloat(self.layout.numberOfColumns)
        
        return w
    }
    
    private func getRowHeight(for row: Int, metrics: CGSize) -> CGFloat {
        switch self.rowHeight {
        case .constant(let constant): return constant
        case .sameAsItemWidth:
            return self.getColumnWidth(for: metrics.width)
        case .dynamic(let rowHeightBlock):
            return rowHeightBlock(row, self.itemSpacing, self.numberOfColumns)
        }
    }
}

struct EquatableRowContainer<Content>: View, Equatable where Content: View {
    static func == (lhs: EquatableRowContainer<Content>, rhs: EquatableRowContainer<Content>) -> Bool {
        return lhs.rowId == rhs.rowId && lhs.height == rhs.height
    }
    
    let rowId: Int
    let height: CGFloat
    let content: Content
    
    init(rowId: Int, height: CGFloat, @ViewBuilder content: () -> Content) {
        self.rowId = rowId
        self.height = height
        self.content = content()
    }
    
    var body: some View {
        self.content
    }
}

struct CollectionView_Previews: PreviewProvider {
    struct ItemModel: Identifiable, Equatable {
        let id: Int
        let color: Color
    }
    
    @State static var items = [ItemModel(id: 0, color: Color.red),
                               ItemModel(id: 1, color: Color.blue),
                               ItemModel(id: 2, color: Color.green),
                               ItemModel(id: 3, color: Color.yellow),
                               ItemModel(id: 4, color: Color.orange),
                               ItemModel(id: 5, color: Color.purple)]
    
    @State static var selectedItems = [ItemModel]()
    @State static var selectionMode = false
    
    static var previews: some View {
        CollectionView(items: $items,
                       selectedItems: $selectedItems,
                       selectionMode: $selectionMode)
        { _, item, _ in
            Rectangle()
                .foregroundColor(item.color)
        }
    }
}
