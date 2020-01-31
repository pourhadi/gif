//
//  iCloudDocumentDelegate.swift
//  iCloud
//
//  Created by Oskari Rauta on 25/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import Foundation

@objc public protocol iCloudDocumentDelegate {

    /**
     Delegate method fired when an error occurs during an attempt to read, save, or revert a document.
     
     - Parameter error: The error that occured during an attempt to read, save, or revert a document.
     */
    @objc func iCloudDocumentErrorOccurred(_ error: Error)

}
