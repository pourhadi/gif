//
//  LoadingCircleView.swift
//  gif
//
//  Created by Daniel Pourhadi on 2/4/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI
import UIKit
import Combine

@objc
class LoadingCircleStore: NSObject {
    static let instance = LoadingCircleStore()
    var lastStart: Double = 360
    var lastRotation: Double = 0
    var endStartAdj: Double = 0
    
    var duration: Double = 1
    var percent: Double = 0
    
    
    var displayLink : CADisplayLink?
    var pct: Binding<Double>?
    func startAnimating(pct: Binding<Double>, duration: Double = 1) {
        self.duration = duration
        self.pct = pct
        let link = CADisplayLink(target: self, selector: #selector(LoadingCircleStore.increment))
        self.displayLink = link
        
        link.add(to: RunLoop.main, forMode: .default)
        
    }
    
    func stopAnimating() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    deinit {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    @objc func increment() {
        let duration = self.duration
        let frameInterval = self.displayLink?.duration ?? 0
        let incr = CalculatePercentComplete(start: 0, end: duration, current: frameInterval)
//        print("\(duration) - \(frameInterval) - \(incr) - \(self.percent)")
        let current = self.pct?.wrappedValue ?? 0
        if current >= 1.0 {
            print("update")

            self.pct?.wrappedValue = incr
        } else {
            self.pct?.wrappedValue = current + incr
        }
    }
}

func ParametricBlend(_ t: Double) -> Double
{
    let sqt = t * t
    return sqt / (2.0 * (sqt - t) + 1.0)
}

func InOutQuadBlend(_ t: Double) -> Double
{
    var t = t
    if(t <= 0.5) {
        return 2.0 * t * t
    }
    t -= 0.5
    return 2.0 * t * (1.0 - t) + 0.5
}


struct InnerRing : Shape {

    @State var store: LoadingCircleStore
    var lagAmmount = 0.15
    var pct: Double
    var rotation: Double

    func path(in rect: CGRect) -> Path {

        var start: Double = 0
        


        let adjp = CalculatePercentComplete(start: 0, end: 0.25, current: rotation)
        start = Double(ExtrapolateValue(from: 0, to: 360, percent: ( pct)))
        
        var endadj = ExtrapolateValue(from: 180, to: 300, percent: adjp)
        
        let endstartadj = ExtrapolateValue(from: 45, to: 120, percent: Double.random(in: 0.01...1))
        
        if rotation == 0 {
            self.store.endStartAdj = endstartadj
        }
        
        self.store.endStartAdj = 45
        endadj = 240
//        let end = Double(CalculatePercentComplete(start: start, end: start - 90, current: (rotation)))
//        start += (pct * 360)
//        start = self.store.lastStart
        var end: Double = 0
        if pct <= 0.5 {
            let newPct = CalculatePercentComplete(start: 0, end: 0.5, current: (pct))
            end = (Double(ExtrapolateValue(from: start - self.store.endStartAdj, to: start - endadj, percent: newPct)))
        } else {
            let newPct = CalculatePercentComplete(start: 0.5, end: 1, current:(pct))
            end = (Double(ExtrapolateValue(from: start - endadj, to: start - self.store.endStartAdj, percent:newPct)))
        }
        
            self.store.lastStart += 1
            if self.store.lastStart >= 360 {
                self.store.lastStart = 0
            }
            
        self.store.percent = self.pct
        
        
        
//        if pct > (1 - lagAmmount) {
//            start = 360 * (2 * pct - 1.0)
//        } else if pct > lagAmmount {
//            start = self.store.lastStart * (pct - lagAmmount)
//        } else {
//            start = self.store.lastStart
//            self.store.lastStart += 80
//            if self.store.lastStart >= 360 {
//                self.store.lastStart = 0
//            }
//        }

        var p = Path()

        p.addArc(center: CGPoint(x: rect.size.width/2, y: rect.size.width/2),
                 radius: rect.size.width/2,
                 startAngle: Angle(degrees: start),
                 endAngle: Angle(degrees: end),
            clockwise: true)

        let adjRotation = ExtrapolateValue(from: 0, to: 0.5, percent: self.pct)
        let r = self.store.lastRotation + adjRotation
        if adjRotation >= 0.5 {
            self.store.lastRotation = r
//            if self.store.lastRotation >= 1 {
//                self.store.lastRotation = 0
//            }
        }
        
        return p.rotation(.degrees(r * 360)).path(in: rect)

    }
    
    var animatableData: Double {
        get { return pct }
        set { pct = newValue }
    }

//    var animatableData: AnimatablePair<Double, Double> {
//        get { return AnimatablePair(pct, rotation) }
//        set {
//            pct = newValue.first
//            rotation = newValue.second
//        }
//    }
}

struct LoadingCircleView: View {
    
//    init() {
//        self._percent.wrappedValue = self.store.percent
//    }
//
    let store: LoadingCircleStore = LoadingCircleStore.instance
    @State var percent: Double = 0
    @State var angle: Double = 0
    @State var rotation: Double = 0
    @State var end: Double = 0
    var body: some View {
        
        InnerRing(store: self.store, pct: self.percent, rotation: self.rotation)
            .stroke(Color.accent, lineWidth: 3)
            .animation(Animation.linear(duration: 1.25).repeatForever(autoreverses: false))
            //            .rotationEffect(Angle.init(degrees: self.angle))
            .onAppear {
//                Async {
                    print("start animating")
//                    self.store.startAnimating(pct: self.$percent, duration: 1.25)
                    //                RunLoop.main.perform(inModes: [.common]) {
                    self.percent = 1
//                    self.rotation = 0.5
//                }
                //                }
                
                
                //                    self.$percent.animation(Animation.linear(duration: 1).repeatForever(autoreverses: false)).wrappedValue = 1
                //                    self.$rotation.animation(Animation.linear(duration: 2).repeatForever(autoreverses: false)).wrappedValue = 180
                //
                //                self.$end.animation(Animation.linear(duration: 2).repeatForever(autoreverses: true)).wrappedValue = 1
                
        }
            //        .drawingGroup()
            .frame(width: 40, height: 40)
            .frame(width: 60, height: 60)
//            .drawingGroup()
            .onDisappear {
                print("stop animating")
                Async {
                    self.store.stopAnimating()
                }
        }
    .compositingGroup()
//        .onReceive(self.store.$percent) { (percent) in
//            print(percent)
//
//            self.$percent.animation(.none).wrappedValue = percent
//        }
        //        .rotationEffect(.degrees(self.rotation))
        //            .animation(Animation.linear(duration: 10).repeatForever(autoreverses: false))
        
    }
}

struct LoadingCircleView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingCircleView().frame(width: 60, height: 60)
    }
}
