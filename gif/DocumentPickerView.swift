//
//  DocumentPickerView.swift
//  gif
//
//  Created by dan on 12/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import SwiftUI
import UIKit
import MobileCoreServices

struct DocumentBrowserView: UIViewControllerRepresentable {
    func makeCoordinator() -> DocumentBrowserView.Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentBrowserView>) -> UIDocumentBrowserViewController {
        let vc = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: [(kUTTypeMovie as String)])
        vc.delegate = context.coordinator
        vc.allowsDocumentCreation = false
        vc.allowsPickingMultipleItems = false
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentBrowserViewController, context: UIViewControllerRepresentableContext<DocumentBrowserView>) {
        
    }
    
    typealias UIViewControllerType = UIDocumentBrowserViewController
    
    
    class Coordinator: NSObject, UIDocumentBrowserViewControllerDelegate {
        let parent: DocumentBrowserView
        
        init(_ parent: DocumentBrowserView) {
            self.parent = parent
        }
        
        func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
            print("did pick document")
        }
        
        func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
            print("did import document")
        }
    }
}

