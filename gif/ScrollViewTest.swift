//
//  ScrollViewTest.swift
//  gif
//
//  Created by Daniel Pourhadi on 12/20/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import Combine
import SnapKit


enum ScrollAction {
    case none
    case set(CGFloat)
}

struct OffsetVal {
    
    var leading: Anchor<CGPoint>? = nil
    
}

struct OffsetKey: PreferenceKey {
    static var defaultValue: OffsetVal = OffsetVal()
    
    static func reduce(value: inout OffsetVal, nextValue: () -> OffsetVal) {
        let next = nextValue()
        if let nextLeading = next.leading {
            value.leading = nextLeading
        }
    }
    
    typealias Value = OffsetVal
    
    
}

struct ScrollViewTest: View {

    @State var offset: CGFloat = 0
    @State var contentOffset: CGPoint = CGPoint.zero
    @State var setOffset: CGFloat? = nil
    @State var disableUpdate = false
    
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: true, content: {
            Rectangle().fill(Color.blue).frame(width: CGFloat.greatestFiniteMagnitude)
        })
    }
    
    var scrollViewContent: some View {
        HStack {
            
            Rectangle().foregroundColor(Color.red).frame(width: 300)
            Rectangle().foregroundColor(Color.blue).frame(width: 300)
            Rectangle().foregroundColor(Color.green).frame(width: 300)
            
        }

        .frame(height: 100)
        .transformAnchorPreference(key: OffsetKey.self, value: .leading) { (val, anchor) in
            val.leading = anchor
        }.offset(x: self.offset)
        
    }
    
}

struct ScrollUIView: UIViewRepresentable{
    func makeCoordinator() -> ScrollUIView.Coordinator {
        return Coordinator(self)
    }
    
    @Binding var offset: CGPoint
    
    init(offset: Binding<CGPoint>, @ViewBuilder content: @escaping () -> AnyView) {
        self.content = content
        self._offset = offset
    }
    
    let content: () -> AnyView
    
    func makeUIView(context: UIViewRepresentableContext<ScrollUIView>) -> CustomScrollView {
        let v = CustomScrollView(contentHost: UIHostingController(rootView: content()).view)
        v.delegate = context.coordinator
        return v
    }
    
    func updateUIView(_ uiView: CustomScrollView, context: UIViewRepresentableContext<ScrollUIView>) {
        
        uiView.contentOffset = self.offset
    }
    
    typealias UIViewType = CustomScrollView

    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ScrollUIView
        
        init(_ parent: ScrollUIView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.parent.offset = scrollView.contentOffset
        }
    }
}

class CustomScrollView : UIScrollView {
    
    let contentHost : UIView
    
    init(contentHost: UIView) {
        self.contentHost = contentHost
        super.init(frame: CGRect.zero)
        
        addSubview(self.contentHost)
        self.contentHost.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

struct ScrollViewTest_Previews: PreviewProvider {
    @State static var offset: CGFloat = 0
    static var previews: some View {
        ScrollViewTest()
    }
}
