//
//  iCloud+notifications.swift
//  iCloud
//
//  Created by Oskari Rauta on 25/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import Foundation

extension iCloud {
    
    @objc open func startUpdate(_ notification: Notification) {
        // Log file update
        if self.verboseLogging { NSLog("[iCloud] Beginning file update with NSMetadataQuery") }
        
        // Notify delegate of the results
        DispatchQueue.main.async {
            self.delegate?.iCloudFileUpdateDidBegin()
        }
    }
    
    @objc open func receivedUpdate(_ notification: Notification) {
        // Log file update
        if self.verboseLogging { NSLog("[iCloud] An update has been pushed from iCloud with NSMetadataQuery") }
        
        // Get the updated files
        self.updateFiles()
    }
    
    @objc open func endUpdate(_ nofication: Notification) {
        // Get the updated files
        self.updateFiles()

        // Notify the delegate of the results on the main thread
        DispatchQueue.main.async { self.delegate?.iCloudFileUpdateDidEnd() }

        if self.verboseLogging { NSLog("[iCloud] Finished file update with NSMetadataQuery") }
    }
    
}
