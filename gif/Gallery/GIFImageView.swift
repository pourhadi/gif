//
//  GIFImageView.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/22/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import SwiftyGif

struct GIFImageView: UIViewRepresentable {
    let isAnimating: Bool
    let gif: GIF?
    
    let contentMode: UIView.ContentMode
    
    init(isAnimating: Bool, gif: GIF?, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.isAnimating = isAnimating
        self.gif = gif
        self.contentMode = contentMode
    }
    
    func makeUIView(context: UIViewRepresentableContext<GIFImageView>) -> AnimatedImageContainer {
        let imgView = AnimatedImageContainer(frame: CGRect.zero)
        imgView.imageView.contentMode = self.contentMode
        imgView.imageView.clipsToBounds = true
        
//        if let gif = self.gif?.image {
//            imgView.imageView.setGifImage(gif)
//        } else {
//            if let url = self.gif?.url {
//                imgView.imageView.setGifFromURL(url)
//            }
//        }
//
//        if self.isAnimating {
//            imgView.imageView.startAnimatingGif()
//        } else {
//            imgView.imageView.stopAnimatingGif()
//        }
        return imgView
    }
    
    func updateUIView(_ uiView: AnimatedImageContainer, context: UIViewRepresentableContext<GIFImageView>) {
        
        if let thumb = self.gif?.thumbnail {
            uiView.imageView.image = thumb
        }
        
        if self.isAnimating {
            if let gif = self.gif?.image {
                uiView.imageView.setGifImage(gif)
            } else {
                if let url = self.gif?.url {
                    uiView.imageView.setGifFromURL(url)
                }
            }
            uiView.imageView.startAnimatingGif()
        } else {
            uiView.imageView.stopAnimatingGif()
        }
        
        uiView.imageView.contentMode = self.contentMode
    }
    
    typealias UIViewType = AnimatedImageContainer
    
    
}

//struct GIFImageView_Previews: PreviewProvider {
//    static var previews: some View {
//        GIFImageView()
//    }
//}
