//
//  TimelineView.swift
//  gif
//
//  Created by dan on 11/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import AVFoundation
import UIKit
import SnapKit

struct TimelineControlsView<Generator>: View where Generator : GifGenerator {
    
    @State var showSettings = false
    @ObservedObject var context: EditingContext<Generator>
    @Binding var previewing: Bool
    
    
    var body: some View {
        HStack {
            Button(action: {
                self.$previewing.animation().wrappedValue.toggle()
            }, label: { Text("Preview").padding(10) } )
                .background(self.previewing ? Color.accent: Color.clear)
                .cornerRadius(6)
                .padding(10)
                .foregroundColor(self.previewing ? Color.background : Color.accent)
//            Spacer()
//            Button(action: {
//                self.context.cropState.visible = true
//            }, label: { Image.symbol("crop") } )
//            Spacer()
//            Spacer()
//            Button(action: {
//                self.$context.mode.animation().wrappedValue = (self.context.mode == .text ? .trim : .text)
//            }, label: { Text("Text").padding(10) } )
//                .background(self.context.mode == .text ? Color(white: 0.4) : Color.clear)
//                .cornerRadius(6)
//                .padding(10)
            Spacer()
            Button(action: {
                Async {
                    self.$context.gifConfig.visible.animation().wrappedValue = true
                }
            }, label: { Image.symbol("gear").padding(20) } ).transformAnchorPreference(key: EditorPreferencesKey.self, value: .bounds) { (val, anchor) in
                val.settingsButtonRect = anchor
            }
        }
    }
}

struct TimelineView<Generator>: View where Generator : GifGenerator {
    @EnvironmentObject var context: EditingContext<Generator>
    
    @Binding var selection: GifConfig.Selection
    @Binding var playState: PlayState
    
    @State var thumbnailMultiplier: CGFloat = 1
    
    @Environment(\.verticalSizeClass) var verticalSize: UserInterfaceSizeClass?

    var body: some View {
        GeometryReader { metrics in
            VStack(spacing: 0) {
                if self.verticalSize != .compact {
                    TimelineControlsView(context: self.context, previewing: self.$context.playState.previewing)
                }
                TimelineUIView<Generator>(selection: self.$selection,
                               playState: self.playState,
                               currentPlayhead: self.$playState.currentPlayhead,
                               thumbnailMultiplier: self.$thumbnailMultiplier)
//                    .fadedEdges(0.05)
            }

            Rectangle()
                .background(Color.text)
                .frame(width: 2, height: metrics.size.height - 20)
                .offset(x: (metrics.size.width - 2) / 2, y: 20)
        }
        .gesture(MagnificationGesture().onChanged({ (value) in
            let m = value < 0.25 ? 0.25 : floorf(Float(value * 4)) / 4
            print(value)
            self.$thumbnailMultiplier.animation(Animation.easeInOut(duration: 0.3)).wrappedValue = CGFloat(value)
        }))
    }
}

struct TimelineUIView<Generator>: UIViewRepresentable where Generator : GifGenerator {
    
    
    @EnvironmentObject var context: EditingContext<Generator>
    
    @Binding var selection: GifConfig.Selection
    var playState: PlayState
    @Binding var currentPlayhead: CGFloat
    @Binding var thumbnailMultiplier: CGFloat

    @Environment(\.timelineState) var timelineState: TimelineState
    
    lazy var thumbGenerator = self.context.thumbGenerator
    func makeUIView(context: UIViewRepresentableContext<TimelineUIView>) -> TimelineContainerView {
        return TimelineContainerView(timelineState: self.timelineState, scrollPercentChanged: context.coordinator.scrollPercentChanged(_:))
    }
    
    func updateUIView(_ uiView: TimelineContainerView, context: UIViewRepresentableContext<TimelineUIView>) {
        if context.coordinator.obj == nil || self.thumbnailMultiplier != context.coordinator.lastThumbnailMultipler {
            context.coordinator.lastThumbnailMultipler = self.thumbnailMultiplier
            context.coordinator.obj = context.coordinator.thumbGenerator.getThumbs(for: self.context.item, multiplier: self.thumbnailMultiplier).sink { results in
                DispatchQueue.main.async {
                    uiView.timelineItems = results.map { TimelineItem(image: $0.image, time: $0.time) }
                }
            }
        }
        
        if context.coordinator.updated {
            context.coordinator.updated = false
        } else {
            let time: CGFloat
            time = currentPlayhead

            guard !time.isNaN else { return }
            uiView.setPercent(percent: CGFloat(time))
        }
        
        uiView.duration = self.context.gifConfig.assetInfo.duration
        uiView.selection = selection
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    
    typealias UIViewType = TimelineContainerView
    
    class Coordinator: NSObject {
        lazy var thumbGenerator = self.parent.context.thumbGenerator
        var parent: TimelineUIView
        var obj: AnyObject?
        var lastThumbnailMultipler: CGFloat = -1

        var updated = false
        init(_ parent: TimelineUIView) {
            self.parent = parent
        }
        
        func scrollPercentChanged(_ percent: CGFloat) -> Void {
            let time = percent
            self.updated = true
            parent.currentPlayhead = time

        }
    }
}

struct TimelineView_Previews: PreviewProvider {
//    @State static var generator = GifGenerator.init(video: Video.preview)

   static var previews: some View {
        GlobalPreviewView()
    }
}

class TimelineItem: Identifiable {
    let image: UIImage?
    let time: CMTime
    
    init(image: UIImage, time: CMTime) {
        self.image = image
        self.time = time
    }
    
    var id: CMTime {
        return self.time
    }
}

class TimelineContainerView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var duration : Double = 0
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.timelineItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! TimelineCell
        
        let item = timelineItems[indexPath.item]
        cell.timelineItem = item
        return cell
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.timelineState.isDragging = true
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.timelineState.isDragging = false
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.timelineState.isDragging = false
    }
    
    var timelineItems = [TimelineItem]() {
        didSet {
            self.collectionView.reloadData()
            DispatchQueue.main.async {
                self.redrawSelectionView()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.collectionView.contentInset = UIEdgeInsets(top: 0, left: self.frame.size.width / 2, bottom: 0, right: self.frame.size.width / 2)
    
        self.collectionView.collectionViewLayout.invalidateLayout()
        
        DispatchQueue.main.async {
            self.redrawSelectionView()
        }
    }
    
    let collectionView: UICollectionView
    let scrollPercentChanged: (CGFloat) -> Void
    let selectionView = [SelectionView()]
    let playheadLine = UIView()
    let timelineState: TimelineState
    
    init(timelineState: TimelineState, scrollPercentChanged: @escaping (CGFloat) -> Void) {
        self.timelineState = timelineState
        self.scrollPercentChanged = scrollPercentChanged
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 10
        self.collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        super.init(frame: CGRect.zero)
        
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.register(TimelineCell.self, forCellWithReuseIdentifier: "cell")
        
        self.addSubview(self.collectionView)
        self.collectionView.frame = self.bounds
        self.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        self.collectionView.snp.makeConstraints { (make) in
//            make.edges.equalToSuperview()
//        }
        
        self.collectionView.showsHorizontalScrollIndicator = false
        
        self.backgroundColor = UIColor.clear
        self.collectionView.backgroundColor = UIColor.clear
        
        self.collectionView.addSubview(selectionView[0])
        selectionView[0].layer.zPosition = 100

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var cellSize: CGSize {
        return CGSize(width: (self.frame.size.width / 10), height: (self.frame.size.height - (insets.top + insets.bottom)))
    }
    
    var insets: UIEdgeInsets {
//        var vInset: CGFloat = self.visualState.compact ? (20) : self.frame.size.height / 2.5
        var vInset: CGFloat = self.frame.size.height / 2.5

        vInset = vInset < 0 ? 0 : vInset
        return UIEdgeInsets(top: vInset, left: 0, bottom: vInset, right: 0)

    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {

        return insets
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let insetWidth = scrollView.contentSize.width
        
        let adjustedX = (self.frame.size.width / 2) + (scrollView.contentOffset.x)
        
        let percent = adjustedX / insetWidth
        guard !percent.isInfinite else { return }
        
        if ignoreUpdate {
            ignoreUpdate = false
        } else {
            self.scrollPercentChanged(percent.clamp())
        }
    }
    
    var ignoreUpdate = false
    func setPercent(percent: CGFloat) {
        let insetWidth = self.collectionView.contentSize.width
        
        let x = (percent.clamp() * insetWidth) - (self.collectionView.contentInset.left)
        guard !x.isNaN else { return }
        ignoreUpdate = true
        self.collectionView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        
        
    }
    
    var selection = GifConfig.Selection() {
        didSet {
            
            redrawSelectionView()
            
        }
    }
    
    func redrawSelectionView() {
        
        let insetWidth = self.collectionView.contentSize.width
        
        let startX = (selection.startTime.clamp() * insetWidth)
        let endX = (selection.endTime.clamp() * insetWidth)
        
        //            let height = visualState.compact ? self.frame.size.height - 30 : (self.frame.size.height / 2)
//        let height = (self.frame.size.height / 2)
        let height = self.cellSize.height + 8
        let y = (self.frame.size.height - height) / 2
        let frame = CGRect(x: startX, y: y, width: endX - startX, height: height)
        selectionView[0].frame = frame
        
        let s = self.selection.seconds(for: self.duration)
        let formatted = String(format: "%.1fs", s)
        selectionView[0].label.text = formatted
    }
    
}

class SelectionView: UIView {
    
    let labelContainer = UIView()
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.borderColor = _accent.cgColor
        self.layer.borderWidth = 3
        self.layer.cornerRadius = 10
        
        self.backgroundColor = _accent.withAlphaComponent(0.1)
        self.isOpaque = false
        
        addSubview(labelContainer)
        labelContainer.addSubview(label)
        
        labelContainer.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        
        label.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(10)
        }
        
        labelContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        labelContainer.layer.cornerRadius = 4
        
        label.textColor = UIColor.white
        label.textAlignment = .center
        
        
//        self.translatesAutoresizingMaskIntoConstraints = false
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}

class TimelineCell: UICollectionViewCell {
    
    lazy var imgView: UIImageView = {
        let v = UIImageView()
        self.contentView.addSubview(v)
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        v.backgroundColor = UIColor.clear
        v.isOpaque = false
        return v
    }()
    
    var timelineItem: TimelineItem? {
        didSet {
            guard oldValue?.id != timelineItem?.id else { return }
            
            imgView.image = timelineItem?.image
        }
    }
    
}
