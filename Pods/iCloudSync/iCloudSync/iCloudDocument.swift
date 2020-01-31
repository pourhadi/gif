//
//  iCloudDocument.swift
//  iCloud
//
//  Created by Oskari Rauta on 25/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import Foundation

open class iCloudDocument: UIDocument {
   
    /**
     iCloudDocument Delegate helps call methods when document processes begin or end
     */
    open var delegate: (NSObject & iCloudDocumentDelegate)? = nil

    internal var _contents: Data? = nil
    
    /**
     The data to read or write to UIDocument
     */
    open var contents: Data {
        get {
            if self._contents == nil { self.contents = Data() }
            return self._contents!
        }
        set { self._contents = newValue }
    }

    /**
     Retrieve the localized name of the current document
     
     - Returns: Name of document including file extension
     */
    open override var localizedName: String {
        get { return self.fileURL.lastPathComponent }
    }
    
    /**
     Retrieve a user-readable form of the document state
     
     - Returns: Current state of the document as a user-readable string
     */
    open var stateDescription: String {
        get {
            switch self.documentState {
            case .closed: return "Document is closed"
            case .inConflict: return "Document is in conflict"
            case .savingError: return "Document has error while saving"
            case .editingDisabled: return "Document editing has been disabled"
            default: return "Document state is normal"
            }
        }
    }
    
    /**
     Initialize a new UIDocument with the specified file path
     
     - Parameter fileURL: The path to the UIDocument file
     
     - Returns: UIDocument at specified URL
     */
    public override init(fileURL: URL) {
        self._contents = Data()
        super.init(fileURL: fileURL)
    }
    
    open override func contents(forType typeName: String) throws -> Any {
        return self.contents
    }

    open override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let content: Data = contents as? Data, content.count > 0 {
            self._contents = content
        } else {
            self._contents = Data()
        }
    }
    
    open override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
        NSLog("[iCloudDocument] " + error.localizedDescription)
        
        if self.delegate?.responds(to: #selector(iCloudDocumentDelegate.iCloudDocumentErrorOccurred(_:))) ?? false {
            self.delegate?.iCloudDocumentErrorOccurred(error)
        }
    }
    
}
