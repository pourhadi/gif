//
//  EnterURLView.swift
//  gif
//
//  Created by Daniel Pourhadi on 1/29/20.
//  Copyright © 2020 dan. All rights reserved.
//

import SwiftUI
import Introspect
import Combine

struct TextView : UIViewRepresentable {
    
    @Binding var takeFocus: Bool
    @Binding var url: URL?
    
    func makeCoordinator() -> TextView.Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: UIViewRepresentableContext<TextView>) -> UITextView {
        let v = UITextView()
        v.delegate = context.coordinator
        v.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        v.textColor = UIColor.white
        v.backgroundColor = UIColor.clear
        v.keyboardType = .URL
        v.returnKeyType = .go
        return v
    }
    
    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<TextView>) {
        if self.takeFocus {
            Delayed(0.4) {
            uiView.becomeFirstResponder()
            }
            
            Async {
                self.takeFocus = false

            }
        }
    }
    
    typealias UIViewType = UITextView
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextView
        
        init(_ parent: TextView) {
            self.parent = parent
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            
            var t = textView.text ?? ""
            if let range = Range(range, in: t) {
                t.replaceSubrange(range, with: text)
                Async {
                    self.parent.$url.animation().wrappedValue = URL(string: textView.text)
                }

            }
            
            return true
        }
        func textViewDidChange(_ textView: UITextView) {
            self.parent.url = URL(string: textView.text)
        }
        
        func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
            self.parent.url = URL(string: textView.text)
            return self.parent.url != nil
        }
    }
    
    
}

class URLFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        if let url = obj as? URL {
            return url.absoluteString
        }
        
        return nil
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let url = URL(string: string) {
            obj?.pointee = url as AnyObject
            return true
        }
        
        return false
    }
}

struct EnterURLView: View {
    
    class Store {
        var cancellables = Set<AnyCancellable>()
    }
    
    let store = Store()
    
    @Binding var url: URL?
    
    @Environment(\.keyboardManager) var keyboardManager: KeyboardManager
    
    @State var takeFocus = false
    
//    @State var validURL = false
    
    var validURL: Bool {
        return self.url != nil
    }
    
    let dismissBlock: () -> Void
    let goBlock: () -> Void
    
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button("Cancel") {
                    self.dismissBlock()
                }
                Spacer()
                Button(action: {
                    self.goBlock()
                }, label: { Text("Get Video") }).opacity(self.url != nil ? 1 : 0.5)
//                    .disabled(self.url == nil)
            }

            Text("type or paste a video URL").font(.headline)
            
            TextView(takeFocus: self.$takeFocus, url: self.$url)
            
//            TextField("URL", value: self.$url, formatter:URLFormatter(), onEditingChanged: { (_) in
//
//            }) {
//                if self.validURL {
//                    self.goBlock()
//                }
//            }
//                .introspectTextField { (textField) in
//
//
//                    textField.returnKeyType = .go
//                    textField.keyboardType = .URL
//                    textField.publisher(for: \.text)
//                        .receive(on: DispatchQueue.main)
//                        .sink { _ in
//                            print("updated")
//                    }.store(in: &self.store.cancellables)
//                    if self.takeFocus {
//                        Delayed(0.4) { textField.becomeFirstResponder() }
//                        self.takeFocus = false
//                    }
//            }
            Spacer(minLength: self.keyboardManager.keyboardHeight)
                .animation(.default)
        }.padding(40)
            .onAppear {
                self.takeFocus = true
        }
    }
}

//struct EnterURLView_Previews: PreviewProvider {
//
//    @State static var text: String = ""
//    static var previews: some View {
//        EnterURLView(text: self.$text).colorScheme(.dark).background(Color.black)
//    }
//}
