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

struct TimelineControlsView: View {
    
    @State var showSettings = false
    @EnvironmentObject var video: Video
    
    var body: some View {
        HStack {
            Button(action: {
                self.video.playState.previewing.toggle()
            }, label: { Text("Preview").padding(10) } )
                .background(self.video.playState.previewing ? Color(white: 0.4) : Color.clear)
                .cornerRadius(6)
                .padding(10)
            Spacer()
            Button(action: {
                self.video.gifConfig.visible = true
            }, label: { Image.symbol("gear").padding(20) } )
        }
    }
}

struct TimelineView: View {
    @EnvironmentObject var video: Video
    
    @Binding var selection: GifConfig.Selection
    @Binding var playState: PlayState
    @Binding var videoMode: VideoMode
    @Binding var visualState: VisualState
    
    @State var thumbnailMultiplier: CGFloat = 1
    
    var body: some View {
        GeometryReader { metrics in
            VStack(spacing: 0) {
                if !self.visualState.compact {
                    TimelineControlsView()
                }
                TimelineUIView(selection: self.$selection,
                               playState: self.$playState,
                               videoMode: self.$videoMode,
                               visualState: self.$visualState,
                               thumbnailMultiplier: self.$thumbnailMultiplier)
            }

            Rectangle()
                .background(Color.text)
                .frame(width: 2, height: metrics.size.height - 10)
                .offset(x: (metrics.size.width - 2) / 2, y: 5)
        }
        .gesture(MagnificationGesture().onChanged({ (value) in
            let m = value < 0.5 ? 0.5 : floorf(Float(value * 2)) / 2
            print(m)
            self.thumbnailMultiplier = CGFloat(m)
        }))
    }
}

struct TimelineUIView: UIViewRepresentable {
    
    
    @EnvironmentObject var video: Video
    
    @Binding var selection: GifConfig.Selection
    @Binding var playState: PlayState
    @Binding var videoMode: VideoMode
    @Binding var visualState: VisualState
    @Binding var thumbnailMultiplier: CGFloat

    
    lazy var thumbGenerator = ThumbGenerator(url: self.video.url)
    func makeUIView(context: UIViewRepresentableContext<TimelineUIView>) -> TimelineContainerView {
        return TimelineContainerView(scrollPercentChanged: context.coordinator.scrollPercentChanged(_:))
    }
    
    func updateUIView(_ uiView: TimelineContainerView, context: UIViewRepresentableContext<TimelineUIView>) {
        if context.coordinator.obj == nil || self.thumbnailMultiplier != context.coordinator.lastThumbnailMultipler {
            context.coordinator.lastThumbnailMultipler = self.thumbnailMultiplier
            context.coordinator.obj = context.coordinator.thumbGenerator.getThumbs(for: video.url, multiplier: self.thumbnailMultiplier).sink { results in
                DispatchQueue.main.async {
                    uiView.timelineItems = results.map { TimelineItem(image: $0.image, time: $0.time) }
                }
            }
        }
        
        if context.coordinator.updated {
            context.coordinator.updated = false
        } else {
            let time: CGFloat
            time = playState.currentPlayhead

            guard !time.isNaN else { return }
            uiView.setPercent(percent: CGFloat(time))
        }
        
        uiView.selection = selection
        uiView.visualState = self.visualState
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    
    typealias UIViewType = TimelineContainerView
    
    class Coordinator: NSObject {
        let thumbGenerator: ThumbGenerator
        var parent: TimelineUIView
        var obj: AnyObject?
        var lastThumbnailMultipler: CGFloat = -1

        var updated = false
        init(_ parent: TimelineUIView) {
            self.parent = parent
            self.thumbGenerator = ThumbGenerator(url: parent.video.url)
        }
        
        func scrollPercentChanged(_ percent: CGFloat) -> Void {
            let time = percent
            self.updated = true
            parent.playState.currentPlayhead = time

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
    
    var visualState = VisualState()
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.timelineItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! TimelineCell
        
        let item = timelineItems[indexPath.item]
        cell.timelineItem = item
        return cell
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
    let selectionView = SelectionView()
    let playheadLine = UIView()
    init(scrollPercentChanged: @escaping (CGFloat) -> Void) {
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
        
        self.collectionView.addSubview(selectionView)
        selectionView.layer.zPosition = 100

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var cellSize: CGSize {
        return CGSize(width: (self.frame.size.width / 10), height: (self.frame.size.height - (insets.top + insets.bottom)))
    }
    
    var insets: UIEdgeInsets {
        var vInset: CGFloat = self.visualState.compact ? (20) : self.frame.size.height / 2.5
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
    
    var selection: GifConfig.Selection? {
        didSet {
            guard let selection = selection, selection != oldValue else { return }
            
            redrawSelectionView()

        }
    }
    
    func redrawSelectionView() {
        guard let selection = selection else { return }
        let insetWidth = self.collectionView.contentSize.width

        let startX = (selection.startTime.clamp() * insetWidth)
        let endX = (selection.endTime.clamp() * insetWidth)
        
        let height = visualState.compact ? self.frame.size.height - 30 : (self.frame.size.height / 2)
        let y = (self.frame.size.height - height) / 2
        let frame = CGRect(x: startX, y: y, width: endX - startX, height: height)
        selectionView.frame = frame
    }

}

class SelectionView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.borderColor = UIColor(hue: 0.55, saturation: 0.62, brightness: 0.96, alpha: 1.00).cgColor
        self.layer.borderWidth = 2
        self.layer.cornerRadius = 6
        
        self.backgroundColor = UIColor(hue: 0.55, saturation: 0.62, brightness: 0.96, alpha: 0.10)
        self.isOpaque = false
        
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
