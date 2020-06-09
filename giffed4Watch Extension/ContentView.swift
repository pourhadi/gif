//
//  ContentView.swift
//  giffed4Watch Extension
//
//  Created by Daniel Pourhadi on 6/2/20.
//  Copyright © 2020 dan. All rights reserved.
//

import AVFoundation
import Combine
import SwiftUI
import WatchKit

struct MoviePlayer: WKInterfaceObjectRepresentable {
    let item: URL
    
    let playing: Bool
    
    func makeWKInterfaceObject(context: Context) -> WKInterfaceInlineMovie {
        return WKInterfaceInlineMovie()
    }
    
    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceInlineMovie, context: Context) {
        wkInterfaceObject.setMovieURL(item)
        wkInterfaceObject.setLoops(true)
//                wkInterfaceObject.setAutoplays(true)
        
        wkInterfaceObject.setVideoGravity(.resizeAspect)
        wkInterfaceObject.setRelativeWidth(1.0, withAdjustment: 0.0)
        wkInterfaceObject.setRelativeHeight(1.0, withAdjustment: 0.0)
//        if let thumb = self.item.thumb {
//            wkInterfaceObject.setPosterImage(WKImage(image: UIImage(contentsOfFile: thumb.path)!))
//        }
        
        wkInterfaceObject.playFromBeginning()
    }
    
    typealias WKInterfaceObjectType = WKInterfaceInlineMovie
}

struct PlayerContainerView: View {
    @Binding var items: [WatchGIF]
    @Binding var index: Int
    var body: some View {
        GeometryReader { metrics in
            
            ZStack {
                if self.items.count > 0 {
                    MoviePlayer(item: self.items[Int(self.index)].data!, playing: true)
                        .scaledToFit()
                        .frame(width: metrics.size.width, height: metrics.size.height)
                        .border(Color.blue, width: 4)
                        .zIndex(2)
                }
            }
        }
    }
}

struct EquatableAnimatedImage: View, Equatable {
    static func == (lhs: EquatableAnimatedImage, rhs: EquatableAnimatedImage) -> Bool {
        return lhs.imageSequence.id == rhs.imageSequence.id
    }
    
    let imageSequence: ImageSequence
    var body: some View {
        AnimatedImage(self.imageSequence)
    }
}

struct GIFContainerView: View {
    @Binding var items: [WatchGIF]
    @Binding var index: Int
    
    var body: some View {
        GeometryReader { metrics in
            if self.items.count > 0 {
                EquatableAnimatedImage(imageSequence: self.items[self.index].data!)
                    .equatable()
                    .scaledToFit()
                    .frame(width: metrics.size.width, height: metrics.size.height)
            }
        }
    }
}

struct ContentView: View {
    let playGIFBlock: (URL) -> Void
    let showErrorBlock: (String) -> Void
    @State var animated = true
    @State var message = ""
    @State var items = WatchController.shared.uploadedGIFs
    
    @State var index: Int = -1
    
    @State var playURL: URL? = nil
    
    @State var loading = false
    
    var body: some View {
        ZStack {
            GeometryReader { metrics in
                
                if self.items.count == 0 {
                    
                    if !self.loading {
                        Text("Use the giffed app on your iPhone or iPad to add GIFs")
                    }
                    
                } else {
                    List(self.items) { item in
                        Button(action: {
                            //                            self.playGIFBlock(item)
                            
                            DispatchQueue.main.async {
                                self.loading = true
                            }
                            
                            item.getDataURL { (url) in
                                
                                DispatchQueue.main.async {
                                    guard let url = url else {
                                        self.showErrorBlock("Sorry, something went wrong")
                                        return
                                    }
                                    
                                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("play").appendingPathExtension("mp4")
                                    do {
                                        try? FileManager.default.removeItem(at: tmpURL)
                                        try FileManager.default.copyItem(at: url, to: tmpURL)
                                    } catch {
                                        self.showErrorBlock(error.localizedDescription)
                                    }
                                    
                                    self.loading = false
                                    self.playGIFBlock(tmpURL)
                                }
                            }
                        }, label: {
                            Group {
                                if item.thumb != nil {
                                    Image(uiImage: UIImage(contentsOfFile: item.thumb!.path)!)
                                        .resizable()
                                    
                                } else {
                                    Rectangle().fill(Color.gray)
                                }
                            }
                            .aspectRatio(item.aspectRatio, contentMode: .fill)
                            .clipped()
                            .frame(width: metrics.size.width)
                        })
                            
                            .listRowInsets(.zero)
                            .listRowBackground(Color.clear)
                            .listRowPlatterColor(Color.clear)
                    }
                    
                    .pickerStyle(WheelPickerStyle())
                    .defaultWheelPickerItemHeight(metrics.size.height)
                    .labelsHidden()
                    .border(Color.clear)
                    .listRowInsets(.zero)
                    
                    .zIndex(1)
                }
            }
            
            if self.loading {
                Text("Loading...")
                .padding(10)
                    .background(Color.black.opacity(0.8))
                .cornerRadius(6)
            }
            
        }
        .onReceive(WatchController.shared.$uploadedGIFs) { list in
            DispatchQueue.main.async {
                var newList = [WatchGIF]()
                for (x, gif) in list.enumerated() {
                    var gif = gif
                    gif.index = x
                    newList.append(gif)
                }
                self.items = newList
            }
        }
        .onReceive(WatchController.shared.$loading, perform: { loading in
            DispatchQueue.main.async {
                self.loading = loading
            }
        })
        .navigationBarTitle("\(self.items.count)")
    }
}

struct ContentView_Previews: PreviewProvider {
    @State static var items: [WatchGIF] = [WatchGIF(data: Bundle.main.url(forResource: "test", withExtension: "mp4")!, name: "001", thumb: nil)]
    @State static var index = 0
    static var previews: some View {
        PlayerContainerView(items: self.$items, index: self.$index)
    }
}
