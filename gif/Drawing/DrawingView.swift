//
//  DrawingView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/7/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI
import Drawsana
import SnapKit

struct DrawsanaContainerView : UIViewRepresentable {
    
    let drawsanaView: DrawsanaView
    @EnvironmentObject var context: EditingContext<TextFrameGenerator>
    
    func makeCoordinator() -> DrawsanaContainerView.Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: UIViewRepresentableContext<DrawsanaContainerView>) -> DrawsanaView {
        let v = self.drawsanaView
        let text = TextTool()
        context.coordinator.textTool = text
        text.delegate = context.coordinator
        v.set(tool: text)
        
        v.userSettings.fillColor = UIColor.white
        v.userSettings.strokeWidth = 0
        v.userSettings.strokeColor = UIColor.white
        
        return v
    }
    
    func updateUIView(_ uiView: DrawsanaView, context: UIViewRepresentableContext<DrawsanaContainerView>) {
        
        if self.context.editingText {
            if let tool = context.coordinator.textTool {
                uiView.set(tool: tool)
            } else {
                let text = TextTool()
                context.coordinator.textTool = text
                text.delegate = context.coordinator
                uiView.set(tool: text)
                
                uiView.userSettings.fillColor = UIColor.white
                uiView.userSettings.strokeWidth = 0
                uiView.userSettings.strokeColor = UIColor.white
            }
        }
    }
    
    typealias UIViewType = DrawsanaView
    
    
    class Coordinator: TextToolDelegate {
        func textToolPointForNewText(tappedPoint: CGPoint) -> CGPoint {
                return tappedPoint
        }
        
        func textToolDidTapAway(tappedPoint: CGPoint) {
            self.parent.context.editingText = false
            self.parent.context.gifConfig.regenerateFlag = UUID()
        }
        
        func textToolWillUseEditingView(_ editingView: TextShapeEditingView) {
            self.parent.context.editingText = true
            editingView.addStandardControls()

            let sizeImg = UIImageView(image: UIImage(systemName: "arrow.left.and.right"))
            let scaleImg = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"))
            let x = UIImageView(image: UIImage(systemName: "xmark"))
            
            editingView.deleteControlView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            editingView.deleteControlView.layer.cornerRadius = 10
            editingView.deleteControlView.addSubview(x)
            x.snp.makeConstraints { (make) in
                make.edges.equalToSuperview()
            }
            
            editingView.changeWidthControlView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            editingView.changeWidthControlView.layer.cornerRadius = 10
            editingView.changeWidthControlView.addSubview(sizeImg)
            sizeImg.snp.makeConstraints { (make) in
                make.edges.equalToSuperview()
            }
            
            editingView.resizeAndRotateControlView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            editingView.resizeAndRotateControlView.layer.cornerRadius = 10
            editingView.resizeAndRotateControlView.addSubview(scaleImg)
            scaleImg.snp.makeConstraints { (make) in
                make.edges.equalToSuperview()
            }
            
        }
        
        func textToolDidUpdateEditingViewTransform(_ editingView: TextShapeEditingView, transform: ShapeTransform) {

        }
        
        let parent: DrawsanaContainerView
        var textTool: TextTool?

        init(_ parent: DrawsanaContainerView) {
            self.parent = parent
        }
        
 
    }
}

//struct DrawingView: View {
//    
//    @Binding var gif: GIF
//    
//    var body: some View {
//        ZStack {
//            AnimatedImageView(gif: self.gif)
//                .aspectRatio(self.gif.aspectRatio ?? 1, contentMode: .fit)
//                .zIndex(1)
//            
//            DrawsanaContainerView()
//                .aspectRatio(self.gif.aspectRatio ?? 1, contentMode: .fit)
//                .zIndex(2)
//            
//        }
//    }
//}
//
//struct DrawingView_Previews: PreviewProvider {
//    
//    @State static var gif: GIF = GIFFile(url: Bundle.main.url(forResource: "1", withExtension: "gif")!, id: "a")!
//    
//    static var previews: some View {
//        DrawingView(gif: $gif)
//    }
//}
