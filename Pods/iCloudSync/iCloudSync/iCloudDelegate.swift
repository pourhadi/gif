//
//  iCloudDelegate.swift
//  iCloud
//
//  Created by Oskari Rauta on 25/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import Foundation

@objc public protocol abstractiCloudDelegate {
    /**
     Called before creating a iCloud Query filter. Specify the type of file to be queried.
     
     If this delegate is not implemented or returns nil, all files stored in the documents directory will be queried.
     
     - returns: String with one file extension formatted like this: "txt"
     */
    @objc optional var iCloudQueryLimitedToFileExtension: [String] { get set }
}

public protocol iCloudDelegate: abstractiCloudDelegate {
    
    /**
     Called when the availability of iCloud changes
     
     - Parameter isAvailable: Boolean value that is true when iCloud is available. False otherwise.
     - Parameter ubiquityToken: A iCloud ubiquity identity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has changed (for e.g. user has logged out and again logged in with another account). This object maybe nil if iCloud is not available for any reason.
     - Parameter ubiquityContainer: The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container has been initialized.
     */
    func iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?)

    /**
     Called when the iCloud initialization process is finished and the iCloud is available
     
     - Parameter ubiquityToken: A iCloud ubiquity identity token that represents current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has changed ( for e.g. user has logged out and back in with another account ). This object may be nil if iCloud is not available for any reason.
     - Parameter ubiquityContainer: The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized.
     */
    func iCloudDidFinishInitializing(with ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?)

    /**
     Called before iCloud query begins.
     
     This may be useful to display interface updates.
     */
    func iCloudFileUpdateDidBegin()

    /**
     Called when iCloud query ends.
     
     This may be useful to display interface updates.
     */
    func iCloudFileUpdateDidEnd()

    /**
     Tells the delegate that the files in iCloud were modified
 
     - Parameter files: List of the files now in the app's iCloud documents directory - each  contains information such as file version, url, localized name, date, etc.
     - Parameter filenames: list of filename's (String) now in the app's iCloud documents directory
     */
    func iCloudFilesDidChange(_ files: [NSMetadataItem], with filenames: [String])

    /**
     Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload or download
 
     When both files have the same modification date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting.
     
     It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately.
     
     The delegate is only notified about conflicts during upload and download procedures with iCloud. This method does not monitor for document conflicts between documents which already exist in iCloud. There are other methods provided to you to detect document state and state changes / conflicts.
 
     - Parameter cloudFile: Dictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
     - Parameter localFile: Dictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
     */
    func iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?)
}

public extension iCloudDelegate {
    
    func iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) { }
    
    func iCloudDidFinishInitializing(with ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) { }
    
    func iCloudFileUpdateDidBegin() { }
    
    func iCloudFileUpdateDidEnd() { }
    
    func iCloudFilesDidChange(_ files: [NSMetadataItem], with filenames: [String]) { }
    
    func iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) { }
}
