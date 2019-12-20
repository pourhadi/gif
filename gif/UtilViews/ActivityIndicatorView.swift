//
//  ActivityIndicatorView.swift
//  gif
//
//  Created by dan on 12/11/19.
//  Copyright © 2019 dan. All rights reserved.1 
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            ActivityIndicatorView().background(Color.background.opacity(0.5))
            Text("Reloading...").font(.largeTitle)
        }
    }
}

struct ActivityIndicatorView: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ActivityIndicatorView>) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: .large)
        v.startAnimating()
        return v
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicatorView>) {
        
    }
    
    typealias UIViewType = UIActivityIndicatorView
}


