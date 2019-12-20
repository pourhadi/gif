//
//  PreviewView.swift
//  gif
//
//  Created by dan on 12/11/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import SnapKit

struct PreviewModal: View {
    @Binding var presentedPopover: Bool
    
    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                PreviewView().frame(width: metrics.size.width - 20, height: metrics.size.height - 20).scaledToFit().clipped().centered()
            }
        }.navigationBarTitle("Preview GIF")
            .navigationBarItems(trailing: Button(action: {
                self.presentedPopover = false
            }, label: { Text("Done") } ))
    }
}

struct PreviewView: View {
    
    @EnvironmentObject var generator: GifGenerator

    var body: some View {
        GeometryReader { metrics in
            AnimatedImage(gifDefinition: self.$generator.gifDefinition)
            if self.generator.reloading {
                LoadingView().frame(width: metrics.size.width, height: metrics.size.height)
            }
        }
    }
}

class AnimatedImageContainer: UIView {
    let imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct AnimatedImage: UIViewRepresentable {
    @Binding var gifDefinition: GifDefinition

    func makeUIView(context: UIViewRepresentableContext<AnimatedImage>) -> AnimatedImageContainer {
        let imgView = AnimatedImageContainer(frame: CGRect.zero)
        imgView.imageView.startAnimating()
        imgView.imageView.contentMode = .scaleAspectFit
        imgView.imageView.clipsToBounds = true
        return imgView
    }
    
    func updateUIView(_ uiView: AnimatedImageContainer, context: UIViewRepresentableContext<AnimatedImage>) {
        uiView.imageView.image = gifDefinition.uiImage
        uiView.imageView.animationDuration = gifDefinition.duration
        uiView.imageView.startAnimating()
    }
    
    typealias UIViewType = AnimatedImageContainer
    
    
}
