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


struct DocumentPickerUIView: UIViewControllerRepresentable {
    
    var video: Video
    
    let cancelBlock: () -> Void
    
    func makeCoordinator() -> DocumentPickerUIView.Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPickerUIView>) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(documentTypes: [kUTTypeMovie as String], in: .import)
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<DocumentPickerUIView>) {
        
    }
    
    typealias UIViewControllerType = UIDocumentPickerViewController
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerUIView
        
        init(_ parent: DocumentPickerUIView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            GlobalPublishers.default.prepVideo.send(urls[0])
//            self.parent.video = Video(data: nil, url: urls[0])
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            self.parent.cancelBlock()
        }
    }
    
    
}

struct DocumentBrowserView: UIViewControllerRepresentable {
    
    @Binding var activePopover: ActivePopover?
    
    func makeCoordinator() -> DocumentBrowserView.Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentBrowserView>) -> UIDocumentBrowserViewController {
        let vc = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: nil)
        vc.delegate = context.coordinator
        vc.allowsDocumentCreation = false
        vc.allowsPickingMultipleItems = false
        vc.additionalTrailingNavigationBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .cancel, target: context.coordinator, action: #selector(Coordinator.close))]
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
        
        @objc func close() {
            self.parent.activePopover = nil
        }
    }
}

