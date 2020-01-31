//
//  ActivityIndicatorView.swift
//  gif
//
//  Created by dan on 12/11/19.
//  Copyright © 2019 dan. All rights reserved.1 
//

import SwiftUI

struct LargeLoadingView: View {
    
    var body: some View {
        GeometryReader { metrics in
            ActivityIndicatorView()
                .padding(60)
                .background(VisualEffectView.blur(.prominent))
                .cornerRadius(10)
                .frame(width: metrics.size.width, height: metrics.size.height, alignment: .center)
        }
    }
}

struct LargeLoadingView_preview: PreviewProvider {

    static var previews: some View {
        LargeLoadingView()
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ActivityIndicatorView()
            Text("Reloading...").font(.largeTitle)
        }
    }
}

struct ActivityIndicatorView: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ActivityIndicatorView>) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: .large)
        v.color = _accent
        v.startAnimating()
        return v
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicatorView>) {
        
    }
    
    typealias UIViewType = UIActivityIndicatorView
}


