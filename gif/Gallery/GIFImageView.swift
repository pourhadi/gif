//
//  GIFImageView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import UIKit
import Gifu

struct AnimatedImageView: UIViewRepresentable {
    var gif: GIF?
    @Binding var animating: Bool
    let cornerRadius: CGFloat
    let contentMode: UIView.ContentMode
    
    init(gif: GIF?, animating: Binding<Bool>? = nil, cornerRadius: CGFloat = 0, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.gif = gif
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        
        self._animating = animating ?? Binding<Bool>(get: {
            return true
        }, set: { _ in })
    }
    
    func makeUIView(context: UIViewRepresentableContext<AnimatedImageView>) -> GifuImageView {
        let v = GifuImageView()
        v.contentMode = self.contentMode
        return v
    }
    
    func updateUIView(_ uiView: GifuImageView, context: UIViewRepresentableContext<AnimatedImageView>) {
        uiView.set(gif: self.gif, animating: self.animating)
//        uiView.imageView.sizeToFit()
    }
    
    typealias UIViewType = GifuImageView
}

class GifuImageView: UIView {
    func stopAnimating() {
        self.imageView.stopAnimating()
    }
    
    func startAnimating() {
        self.imageView.startAnimating()
    }
    
    var gif: GIF?
    
    let loadingView = UIActivityIndicatorView(style: .large)
    
    func set(gif: GIF?, animating: Bool) {
        self.loadingView.stopAnimating()
        
        guard gif != self.gif else {
            if let gif = gif, animating != self.imageView.isAnimating {
                if animating {
                    loadAndAnimate(gif: gif)
                } else {
                    self.imageView.stopAnimating()
                    self.imageView.image = gif.thumbnail
                }
            }
            return
        }
        
        self.gif = gif
        self.imageView.stopAnimating()
        
        guard let gif = gif else { return }
        
        self.imageView.image = gif.thumbnail
        
        if animating {
            loadAndAnimate(gif: gif)
        }
    }
    
    func loadAndAnimate(gif: GIF) {
        self.imageView.prepareForReuse()
        
        let synchronous = gif.getData { [unowned self] data, context, synchronous in
            if !synchronous {
                DispatchQueue.main.async {
                    self.loadingView.stopAnimating()
                }
            }
            guard context == self.gif, let data = data else { return }
            self.imageView.animate(withGIFData: data)
        }
        
        if !synchronous {
            DispatchQueue.main.async {
                self.loadingView.startAnimating()
            }
        }
    }
    
    let imageView = Gifu.GIFImageView()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.mask?.frame = self.bounds
    }
    
    init() {
        super.init(frame: CGRect.zero)
        
        self.addSubview(self.imageView)
        self.imageView.contentMode = .scaleAspectFit
        
        self.imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.addSubview(self.loadingView)
        self.loadingView.center = self.center
        self.loadingView.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        self.loadingView.stopAnimating()
        
        self.mask = UIView()
        self.mask?.backgroundColor = UIColor.black
        self.mask?.frame = self.bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}




//struct GIFImageView: UIViewRepresentable {
//    let isAnimating: Bool
//    let gif: GIF?
//    
//    let contentMode: UIView.ContentMode
//    
//    init(isAnimating: Bool, gif: GIF?, contentMode: UIView.ContentMode = .scaleAspectFit) {
//        self.isAnimating = isAnimating
//        self.gif = gif
//        self.contentMode = contentMode
//    }
//    
//    func makeUIView(context: UIViewRepresentableContext<GIFImageView>) -> AnimatedImageContainer {
//        let imgView = AnimatedImageContainer(frame: CGRect.zero)
//        imgView.imageView.contentMode = self.contentMode
//        imgView.imageView.clipsToBounds = true
//        
////        if let gif = self.gif?.image {
////            imgView.imageView.setGifImage(gif)
////        } else {
////            if let url = self.gif?.url {
////                imgView.imageView.setGifFromURL(url)
////            }
////        }
////
////        if self.isAnimating {
////            imgView.imageView.startAnimatingGif()
////        } else {
////            imgView.imageView.stopAnimatingGif()
////        }
//        return imgView
//    }
//    
//    func updateUIView(_ uiView: AnimatedImageContainer, context: UIViewRepresentableContext<GIFImageView>) {
//        
//        if let thumb = self.gif?.thumbnail {
//            uiView.imageView.image = thumb
//        }
//        
//        if self.isAnimating {
//            if let gif = self.gif?.image {
//                uiView.imageView.setGifImage(gif)
//            } else {
//                if let url = self.gif?.url {
//                    uiView.imageView.setGifFromURL(url)
//                }
//            }
//            uiView.imageView.startAnimatingGif()
//        } else {
//            uiView.imageView.stopAnimatingGif()
//        }
//        
//        uiView.imageView.contentMode = self.contentMode
//    }
//    
//    typealias UIViewType = AnimatedImageContainer
//    
//    
//}
//
////struct GIFImageView_Previews: PreviewProvider {
////    static var previews: some View {
////        GIFImageView()
////    }
////}
