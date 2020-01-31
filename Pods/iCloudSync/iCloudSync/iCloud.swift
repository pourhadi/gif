//
//  iCloud.swift
//  iCloud
//
//  Created by Oskari Rauta on 25/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import Foundation

open class iCloud: NSObject {

    static public private(set) var DOCUMENT_DIRECTORY: String = "Documents"

    /**
     iCloud shared instance object
     
     - Returns: The shared instance of iCloud
     */
    static public internal(set) var `shared`: iCloud = iCloud()

    /**
     iCloud Delegate helps call methods when document processes begin or end
     */
    open var delegate: (NSObject & iCloudDelegate)? = nil
    
    /**
     The current NSMetadataQuery object
     */
    open internal(set) var query: NSMetadataQuery = NSMetadataQuery()
    
    /**
     File extension that queries are limited to, or "*"
     */
    open internal(set) var fileExtension: String = "*"
    
    /**
     A list of iCloud files from the previous query
     */
    open internal(set) var previousQueryResults: [UbiquitousMetaDataItem] = []
    
    /**
     Enable verbose logging for detailed feedback in the log. Turning this off only prints crucial log notes such as errors.
     */
    open var verboseLogging: Bool = false
    
    /**
     Enable verbose availability logging for repeated feedback about iCloud availability in the log. Turning this off will prevent availability-related messages from being printed in the log. This property does not relate to the verboseLogging property.
     
     - Returns: a boolean value.
     */
    open var verboseAvailabilityLogging: Bool = false
    
    lazy open internal(set) var fileManager: FileManager = FileManager.default
    lazy open internal(set) var notificationCenter: NotificationCenter = NotificationCenter.default
    
    /**
     Return application's ubiquitous root URL
     
     - Returns: URL with the app's root iCloud Ubiquitous URL. May return nil if iCloud is not properly setup or available.
     */
    open internal(set) var ubiquityContainer: URL? = nil
    
    deinit {
        self.notificationCenter.removeObserver(self)
    }

    /**
     Check if iCloud files are being updated right now
     
     - Returns: true if file updating is in progress at the moment.
     */
    open internal(set) var isUpdatingFiles: Bool = false
    
    /**
     Check if iCloud files should be updated.
     
     More than one file updating shouldn't be ongoing, so there's a queue system in place.
     This returns true when file updating is requested and false when updating has started.
     If update is requested during update, this get's set to true again, and after update
     has finished, it will restart updating.
     
     - Returns: true if file updating is requested and in queue.
     */
    open internal(set) var shouldUpdateFiles: Bool = false
    
    /**
     Setup iCloud Document Sync and begin the initial document syncing process.
     
     You \b must call this method before using iCloud Document Sync to avoid potential issues with syncing. This setup process ensures that all variables are initialized. A preliminary file sync will be performed when this method is called.
     
     - Parameter containerID: The fully-qualified container identifier for an iCloud container directory. The string you specify must not contain wildcards and must be of the form <TEAMID>.<CONTAINER>, where <TEAMID> is your development team ID and <CONTAINER> is the bundle identifier of the container you want to access. The container identifiers for your app must be declared in the com.apple.developer.ubiquity-container-identifiers array of the .entitlements property list file in your Xcode project. If you specify nil for this parameter, this method uses the first container listed in the com.apple.developer.ubiquity-container-identifiers entitlement array.
     */
    open func setupiCloud(_ containerID: String? = nil) {

        if self.verboseLogging { NSLog("[iCloud] Initializing Ubiquity Container") }
        
        self.ubiquityContainer = self.fileManager.url(forUbiquityContainerIdentifier: containerID)

        guard
            self.ubiquityContainer != nil,
            let token: UbiquityIdentityToken = self.fileManager.ubiquityIdentityToken
            else {
                
                NSLog("[iCloud] The system could not retrieve a valid iCloud container URL. iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, does not have properly configured entitlements\n• Your app, has a provisioning profile which does not support iCloud.\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud")
                
                DispatchQueue.main.async { self.delegate?.iCloudAvailabilityDidChange(to: false, token: nil, with: self.ubiquityContainer) }
                
                return
        }

        let _ = self.cloudDocumentsURL
        
        DispatchQueue.global().async {

            // Log document enumeration
            if self.verboseLogging { NSLog("[iCloud] Initializing Document Enumeration") }
            self.enumerateCloudDocuments()
            
            self.notificationCenter.addObserver(self, selector: #selector(getter: self.cloudAvailable), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
            
            DispatchQueue.main.async { self.delegate?.iCloudDidFinishInitializing(with: token, with: self.ubiquityContainer) }
            
            // Log the setup
            NSLog("[iCloud] Ubiquity Container Created and Ready")
        }

        // Log the setup
        NSLog("[iCloud] Initialized")
    }
    
    open func enumerateCloudDocuments() {
        
        // Log document enumeration
        if self.verboseLogging { NSLog("[iCloud] Creating metadata query and notifications") }
        
        // Setup iCloud Metadata query and request file extension limitation from delegate
        self.query.searchScopes = [ NSMetadataQueryUbiquitousDocumentsScope ]
        
        if
            let _fileExtensions: [String] = self.delegate?.iCloudQueryLimitedToFileExtension,
            !_fileExtensions.isEmpty {
            self.fileExtension = _fileExtensions.joined(separator: ",")
            // Log file extension
            NSLog("[iCloud] Document query filter has been set to IN { " + self.fileExtension + " }")
            self.query.predicate = NSPredicate(format: "(%K.pathExtension IN { " + _fileExtensions.map { "'" + $0 + "'" }.joined(separator: ",") + " })", NSMetadataItemFSNameKey)

        } else {
            self.fileExtension = "*"
            self.query.predicate = NSPredicate(format: "(%K.pathExtension LIKE '" + self.fileExtension + "')", NSMetadataItemFSNameKey)
        }
        
        // Setup iCloud Metadata query sorting order
        self.query.sortDescriptors = [ NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: false) ]
        
        // Notify the responder that an update has begun
        self.notificationCenter.addObserver(self, selector: #selector(self.startUpdate(_:)), name: NSNotification.Name.NSMetadataQueryDidStartGathering, object: self.query)
        
        // Notify the responder that an update has been pushed
        self.notificationCenter.addObserver(self, selector: #selector(self.receivedUpdate(_:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: self.query)
        
        // Notify the responder that the update has completed
        self.notificationCenter.addObserver(self, selector: #selector(self.endUpdate(_:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: self.query)

        // Start query
        DispatchQueue.main.async {
            if !self.query.start() {
                NSLog("[iCloud] Failed to start query.")
            } else if self.verboseLogging {
                NSLog("[iCloud] Query initialized successfully")
            }
        }
    }
    
    /* Checking for iCloud. */
    
    /**
     Check whether or not iCloud is available and that it can be accessed.
     
     You should always check if iCloud is available before performing any iCloud operations (every method checks to make sure iCloud is available before continuing). Additionally, you may want to check if your users want to opt-in to iCloud on a per-app basis (according to Apple's documentation, you should only ask the user once to opt-in to iCloud). The Return value could be **NO** (iCloud Unavailable) for one or more of the following reasons:
        - iCloud is turned off by user
        - Entitlements profile, code signing identity, and/or provisioning profile are invalid
     
     This method uses the ubiquityIdentityToken to check if iCloud is available. The delegate method iCloudAvailabilityDidChange(isAvailable: Bool, with ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) can be used to automatically detect changes in the availability of iCloud. A ubiquity token is passed in that method which lets you know if the iCloud account has changed.
     
     - Returns: a boolean value.
     */
    @objc open var cloudAvailable: Bool {
        get {
            guard
                let token: UbiquityIdentityToken = self.fileManager.ubiquityIdentityToken,
                let ubiquityContainer: URL = self.ubiquityContainer
                else {
                    
                    NSLog(self.verboseAvailabilityLogging ? ( "[iCloud] iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, " + (( Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ) ?? "") + ", does not have properly configured entitlements\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud" ) : "[iCloud] iCloud unavailable" )
                    
                    DispatchQueue.main.async { self.delegate?.iCloudAvailabilityDidChange(to: false, token: nil, with: self.ubiquityContainer) }
                    
                    return false
            }
            
            if self.verboseAvailabilityLogging {
                NSLog("[iCloud] iCloud is available. Ubiquity URL: " + ubiquityContainer.path + "\nUbiquity Token: " + token.description)
            }
            
            DispatchQueue.main.async { self.delegate?.iCloudAvailabilityDidChange(to: true, token: token, with: ubiquityContainer) }
            
            return true
        }
    }

    /**
     Check that the current application's iCloud Ubiquity Container is available. Returns a boolean value.
     
     This method may not return immediately, depending on a number of factors. It is not necessary to call this method directly, although it may become useful in certain situations.
     
     - Returns: true if ubiquity container is available. Otherwise false.
     */
    open var ubiquityContainerAvailable: Bool {
        get { return self.ubiquityContainer != nil }
    }
    
    open var quickCloudCheck: Bool {
        get { return self.fileManager.ubiquityIdentityToken != nil }
    }

    /**
     Return application's local documents directory URL
     
     - Returns: URL with the local documents directory URL for the current app.
     */

    open var localDocumentsURL: URL? {
        get { return self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first }
    }
    
    /**
     Return application's ubiquitous documents directory URL
     
     - Warning: If iCloud is not properly setup, this method will return the local (non-ubiquitous) documents directory. This may cause other document handling methods to return nil values. Ensure that iCloud is properly setup \b before calling any document handling methods.
     
     - Returns: URL with the iCloud ubiquitous documents directory URL for the current app. Returns the local documents directory if iCloud is not properly setup or available.
     */
    open var cloudDocumentsURL: URL? {
        get {

            guard
                let documentsURL: URL = (self.ubiquityContainer ?? FileManager.default.url(forUbiquityContainerIdentifier: nil))?.appendingPathComponent(iCloud.DOCUMENT_DIRECTORY)
                else {
                    
                    NSLog("[iCloud] iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, does not have properly configured entitlements\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud")
                    
                    NSLog("[iCloud] WARNING: Using local documents directory until iCloud is available.")

                    DispatchQueue.main.async { self.delegate?.iCloudAvailabilityDidChange(to: false, token: nil, with: self.ubiquityContainer) }
                    
                    return self.localDocumentsURL
            }

            if
                var isDir: ObjCBool = ObjCBool(false) as ObjCBool?,
                self.fileManager.fileExists(atPath: documentsURL.path, isDirectory: &isDir) {
                
                guard !isDir.boolValue else { return documentsURL }
                try? self.fileManager.removeItem(at: documentsURL)
            }
            
            try? self.fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
            return self.fileManager.fileExists(atPath: documentsURL.path) ? documentsURL : nil
        }
    }
    
    /* Syncing with iCloud */
    
    /**
     Check for and update the list of files stored in your app's iCloud Documents Folder.
     
     This method is automatically called by iOS when there are changes to files in the iCloud Directory. The iCloudFilesDidChange(files: [NSMetadataItem], with filenames: [String]) delegate method is triggered by this method.
     */
    open func updateFiles() {

        self.shouldUpdateFiles = true
        guard !self.isUpdatingFiles else { return }

        self.isUpdatingFiles = true

        // Log file update
        if self.verboseLogging { NSLog("[iCloud] Beginning file update with NSMetadataQuery") }
        
        func doUpdateFiles() {
            
            self.shouldUpdateFiles = false
            guard self.quickCloudCheck else { return }

            var discoveredFiles: [NSMetadataItem] = []
            var names: [String] = []

            let results: [UbiquitousMetaDataItem] = self.query.results.compactMap {
                UbiquitousMetaDataItem($0 as! NSMetadataItem)
            }
            
            results.forEach {
                
                if $0.status == .downloaded {
                    // File will be updated soon
                } else if $0.status == .current {
                    // Append metadata and filenames into arrays
                    discoveredFiles.append($0.item)
                    names.append($0.name)
                } else if $0.status == .notDownloaded {
                    
                    var downloading: Bool = true
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(at: $0.url)
                    } catch {
                        downloading = false
                        NSLog("[iCloud] Ubiquitous item failed to start downloading with error: " + error.localizedDescription)
                    }
                    
                    if self.verboseLogging { NSLog("[iCloud] " + $0.url.lastPathComponent + " started downloading locally, successfull? " + ( downloading ? "true" : "false")) }
                }
            }
            
            self.previousQueryResults = results

            // Notify delegate about results
            DispatchQueue.main.async { self.delegate?.iCloudFilesDidChange(discoveredFiles, with: names) }

        }
        
        DispatchQueue.global(qos: .background).async {

            while self.shouldUpdateFiles {
                doUpdateFiles()
            }
            self.isUpdatingFiles = false
        }
        
    }
    
    /* Uploading to iCloud */
    
    /**
     Create, save, and close a document in iCloud.
     
     First, iCloud Document Sync checks if the specified document exists. If the document exists it is saved and closed. If the document does not exist, it is created then closed.
     
     iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.
     
     To create a new document or save an existing one (close the document), use this method.     Documents can be created even if the user is not connected to the internet. The only case in which a document will not be created is when the user has disabled iCloud or if the current application is not setup for iCloud.
     
     - Parameter name: Filename of document being written to iCloud.
     - Parameter content: Data containing file content.
     - Parameter completion: Code block which is called after succesful file saving. Error will be nil if no error was present.
     */
    open func saveAndCloseDocument(_ name: String, with content: Data, completion: ((UIDocument?, Data?, Error?) -> Void)? = nil) {
        
        if self.verboseLogging { NSLog("[iCloud] Beginning document save") }

        // Don't Check for iCloud... we need to save the file
        // regardless of being connected so that the saved file
        // can be pushed to the cloud later on.
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name) else {
            NSLog("[iCloud] Cannot create URL for file")
            completion?(nil, nil, NSError(domain: "Cannot create URL for file. Check iCloud's cloudDocumentsURL.", code: 001, userInfo: nil) as Error)
            return
        }
        
        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        document.contents = content
        document.updateChangeCount(.done)
        
        if self.fileManager.fileExists(atPath: fileURL.path) {
            
            if self.verboseLogging { NSLog("[iCloud] Document exists; overwriting, saving and closing") }
            
            // Save and create the new document, then close it
            document.save(to: document.fileURL, for: .forOverwriting, completionHandler: {
                success in
                
                if success {
                    document.close(completionHandler: {
                        closed in
                        if closed {
                            if self.verboseLogging { NSLog("[iCloud] Written, saved and closed document") }
                            completion?(document, document.contents, nil)
                        } else {
                            NSLog("[iCloud] Error while saving document: @saveAndCloseDocument")
                            completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while saving document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["fileURL": fileURL]) as Error)
                        }
                    })
                } else {
                    NSLog("[iCloud] Error while writing to the document: @saveAndCloseDocument")
                    completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while writing to the document " + document.fileURL.path + " at iCloud", code: 100, userInfo: ["fileURL": fileURL]) as Error)
                }
            })
        } else {
            
            if self.verboseLogging { NSLog("[iCloud] Document is new; creating, saving and then closing") }
            
            document.save(to: document.fileURL, for: .forCreating, completionHandler: {
                success in
                if success {
                    document.close(completionHandler: {
                        closed in
                        if closed {
                            // Log the save and close
                            if self.verboseLogging { NSLog("[iCloud] New document created, saved and closed successfully") }
                            completion?(document, document.contents, nil)
                        } else {
                            NSLog("[iCloud] Error while saving and closing document: @saveAndCloseDocument")
                            completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while saving document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["fileURL": fileURL]) as Error)
                        }
                    })
                } else {
                    NSLog("[iCloud] Error while creating the document: @saveAndCloseDocument")
                    completion?(document, document.contents, NSError(domain: "saveAndCloseDocument: error while creating the document " + document.fileURL.path + " in iCloud", code: 100, userInfo: ["fileURL": fileURL]) as Error)
                }
            })
        }
    }
    
    open func uploadLocalOfflineDocuments(repeatingHandler: ((String?, Error?) -> Void)!, completion: (() -> Void)? = nil) {
        
        // Log upload
        if self.verboseLogging { NSLog("[iCloud] Beginning local file upload to iCloud. This process may take a long time.") }
        
        guard
            self.quickCloudCheck,
            let localDocuments: URL = self.localDocumentsURL,
            let localFiles: [String] = try? self.fileManager.contentsOfDirectory(atPath: localDocuments.path)
            else { return }
        
        DispatchQueue.global(qos: .background).async {
            
            if self.verboseLogging { NSLog("[iCloud] Files stored locally available for uploading: ", localFiles) }
            
            for item in localFiles {
                
                guard !item.hasPrefix(".") else {
                    DispatchQueue.main.async {
                        repeatingHandler(item, NSError(domain: "File in directory is hidden and will not be uploaded to iCloud.", code: 520, userInfo: ["Filename": item]) as Error)
                    }
                    continue
                }
                
                let cloudURL: URL = self.cloudDocumentsURL!.appendingPathComponent(item)
                let localURL: URL = localDocuments.appendingPathComponent(item)
                
                guard (self.previousQueryResults.map{ $0.name }).contains(item) else {
                    if self.verboseLogging { NSLog("[iCloud] Uploading " + item + " to iCloud") }
                    
                    // Move file to iCloud
                    var err: Error? = nil
                    
                    do {
                        try self.fileManager.setUbiquitous(true, itemAt: localURL, destinationURL: cloudURL)
                    } catch {
                        err = error
                        NSLog("[iCloud] Error while uploading document from local directory: " + error.localizedDescription)
                    }
                    
                    DispatchQueue.main.async {
                        repeatingHandler(item, err)
                    }
                    continue
                }
                
                // Log conflict
                if self.verboseLogging { NSLog("[iCloud] Conflict between local file and remote file, attempting to automatically resolve") }
                
                let document: iCloudDocument = iCloudDocument(fileURL: cloudURL)
                
                if
                    let cloud_modDate: Date = document.fileModificationDate,
                    let fileAttrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: localURL.path),
                    let local_modDate: Date = fileAttrs[FileAttributeKey.modificationDate] as? Date,
                    let local_fileData: Data = self.fileManager.contents(atPath: localURL.path) {
                    
                    if cloud_modDate.compare(local_modDate) == .orderedDescending {
                        
                        NSLog("[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.")
                        
                        do {
                            try self.fileManager.removeItem(at: localURL)
                        } catch {
                            NSLog("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                        }
                    } else if cloud_modDate.compare(local_modDate) == .orderedAscending {
                        
                        NSLog("[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.")
                        
                        // Replace iCloud document's content
                        document.contents = local_fileData
                        
                        DispatchQueue.main.async {
                            // Save and close the document in iCloud
                            document.save(to: document.fileURL, for: .forOverwriting, completionHandler: {
                                success in
                                if success {
                                    // Close the document
                                    document.close(completionHandler: {
                                        closed in
                                        repeatingHandler(item, nil)
                                    })
                                } else {
                                    NSLog("[iCloud] Error while overwriting old iCloud file: @uploadLocalOfflineDocuments")
                                    repeatingHandler(item, NSError(domain: "uploadLocalOfflineDocuments: error while saving the document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["Filename": item]) as Error)
                                }
                            })
                        }
                    } else { // Modification date is same for both, local and cloud file
                        
                        NSLog("[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, we will check if both files have the same content.")
                        
                        if self.fileManager.contentsEqual(atPath: cloudURL.path, andPath: localURL.path) {
                            
                            NSLog("[iCloud] The contents of local file and remote file match. The local file will be deleted.")
                            
                            do {
                                try self.fileManager.removeItem(at: localURL)
                            } catch {
                                NSLog("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                            }
                        } else { // Local and remote file did not match with equal contents.
                            
                            NSLog("[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                            
                            DispatchQueue.main.async {
                                self.delegate?.iCloudFileConflictBetweenCloudFile([
                                    "fileContents": document.contents,
                                    "fileURL": cloudURL,
                                    "modifiedDate": cloud_modDate
                                    ], with: [
                                        "fileContents": local_fileData,
                                        "fileURL": localURL,
                                        "modifiedDate": local_modDate
                                    ])
                            }
                        }
                    }
                } else {
                    
                    NSLog("[iCloud] Failed to retrieve information about either or both, local and remote file. You will need to handle the conflict using iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                    
                    DispatchQueue.main.async {
                        self.delegate?.iCloudFileConflictBetweenCloudFile([
                            "fileURL": cloudURL
                            ], with: [
                                "fileURL": localURL
                            ])
                    }
                }
            }

            // Log completion
            if self.verboseLogging { NSLog("[iCloud] Finished uploading all local files to iCloud") }
            
            DispatchQueue.main.async { completion?() }
        }
    }

    open func uploadLocalDocumentToCloud(_ name: String, completion: ((Error?) -> Void)? = nil ) {

        // Log download
        if self.verboseLogging { NSLog("[iCloud] Attempting to upload document: " + name) }
        
        guard
            self.quickCloudCheck,
            let localDocuments: URL = self.localDocumentsURL,
            let localURL: URL = localDocuments.appendingPathComponent(name) as URL?,
            let cloudURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }

        // Perform tasks on background thread to avoid problems on the main / UI thread
        DispatchQueue.global(qos: .background).async {
            
            // If the file does not exist in iCloud, upload it
            if (self.previousQueryResults.map{ $0.name }).contains(name) {
                
                if self.verboseLogging { NSLog("[iCloud] Uploading " + name + " to iCloud") }
                
                var err: Error? = nil
                // Move the file to iCloud
                do {
                    try self.fileManager.setUbiquitous(true, itemAt: localURL, destinationURL: cloudURL)
                } catch {
                    NSLog("[iCloud] Error while uploading document from local directory: " +  error.localizedDescription);
                    err = error
                }

                DispatchQueue.main.async { completion?(err) }
                
            } else {
                
                // Check if the local document is newer than the cloud document
                
                // Log conflict
                if self.verboseLogging { NSLog("[iCloud] Conflict between local file and remote file, attempting to automatically resolve") }
                
                let document: iCloudDocument = iCloudDocument(fileURL: cloudURL)

                if
                    let cloud_modDate: Date = document.fileModificationDate,
                    let fileAttrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: localURL.path),
                    let local_modDate: Date = fileAttrs[FileAttributeKey.modificationDate] as? Date,
                    let local_fileData: Data = self.fileManager.contents(atPath: localURL.path) {
                    
                    if cloud_modDate.compare(local_modDate) == .orderedDescending {
                        NSLog("[iCloud] The iCloud file was modified more recently than the local file. The local file will be deleted and the iCloud file will be preserved.")
                        
                        do {
                            try self.fileManager.removeItem(at: localURL)
                        } catch {
                            NSLog("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                        }
                    } else if cloud_modDate.compare(local_modDate) == .orderedAscending {
                        
                        NSLog("[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be overwritten with the contents of the local file.")
                        
                        // Replace iCloud document's content
                        document.contents = local_fileData
                        
                        DispatchQueue.main.async {
                            // Save and close the document in iCloud
                            document.save(to: document.fileURL, for: .forOverwriting, completionHandler: {
                                success in
                                if success {
                                    // Close the document
                                    document.close(completionHandler: {
                                        closed in
                                        completion?(nil)
                                    })
                                } else {
                                    NSLog("[iCloud] Error while overwriting old iCloud file: @uploadLocalDocumentToCloud")
                                    completion?(NSError(domain: "uploadLocalDocumentToCloud: error while saving the document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["Filename": name]) as Error)
                                }
                            })
                        }
                    } else { // Modification date is same for both, local and cloud file
                        
                        NSLog("[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, we will check if both files have the same content.")
                        
                        if self.fileManager.contentsEqual(atPath: cloudURL.path, andPath: localURL.path) {
                            
                            NSLog("[iCloud] The contents of local file and remote file match. The local file will be deleted.")
                            
                            do {
                                try self.fileManager.removeItem(at: localURL)
                            } catch {
                                NSLog("[iCloud] Error deleting " + localURL.path + ".\n\n" + error.localizedDescription);
                            }
                        } else { // Local and remote file did not match with equal contents.
                            
                            NSLog("[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                            
                            DispatchQueue.main.async {
                                self.delegate?.iCloudFileConflictBetweenCloudFile([
                                    "fileContents": document.contents,
                                    "fileURL": cloudURL,
                                    "modifiedDate": cloud_modDate
                                    ], with: [
                                        "fileContents": local_fileData,
                                        "fileURL": localURL,
                                        "modifiedDate": local_modDate
                                    ])
                            }
                        }
                    }
                } else {
                    
                    NSLog("[iCloud] Failed to retrieve information about either or both, local and remote file. You will need to handle the conflict using iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")

                    DispatchQueue.main.async {
                        self.delegate?.iCloudFileConflictBetweenCloudFile([
                            "fileURL": cloudURL
                            ], with: [
                                "fileURL": localURL
                            ])
                    }
                }
            }
        
            // Log completion
            if self.verboseLogging { NSLog("[iCloud] Finished uploading local file to iCloud") }
            
            DispatchQueue.main.async { completion?(nil) }

        }
    }
    
    /* Sharing iCloud content */

    /**
     Share an iCloud document by uploading it to a public URL.
     
     Upload a document stored in iCloud to a public location on the internet for a limited amount of time.
     
     - Parameter name: The name of the iCloud file being uploaded to a public URL.
     - Parameter completion: Code block called after document is uploaded.
     
     - Returns: The public URL where the file is available
     */
    @discardableResult
    open func shareDocument(_ name: String, completion: ((URL?, Date?, Error?) -> Void)? = nil) -> URL? {
        
        if self.verboseLogging { NSLog("[iCloud] Attempting to share document: " + name) }
        
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return nil }

        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return nil
        }

        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            completion?(nil, nil, NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return nil
        }
        
        if self.verboseLogging { NSLog("[iCloud] File exists, preparing to share it") }
        
        var resultURL: URL? = nil
        
        // Move to the background thread for safety
        DispatchQueue.global(qos: .background).async {
            
            var date: NSDate? = nil
            var err: Error? = nil
            
            do { // Create URL
                resultURL = try self.fileManager.url(forPublishingUbiquitousItemAt: fileURL, expiration: &date)
            } catch {
                resultURL = nil
                err = error
            }
            
            // Log share
            if self.verboseLogging { NSLog("[iCloud] Shared iCloud document") }
            
            DispatchQueue.main.async { completion?(resultURL, date == nil ? nil : Date(timeIntervalSinceReferenceDate: date!.timeIntervalSinceReferenceDate), err) }
        }
        
        return resultURL
    }
    
    /* Deleting iCloud content */
    
    /**
     Delete a document from iCloud.
     
     Permanently delete a document stored in iCloud. This will only affect copies of the specified file stored in iCloud, if there is a copy stored locally it will not be affected.
     
     - Parameter name: The name of the document to delete from iCloud.
     - Parameter completion: called when a file is successfully deleted from iCloud. Error object contains any error information if an error occurred, otherwise it will be nil.
     */
    open func deleteDocument(_ name: String, completion: ((Error?) -> Void)? = nil) {
        // Log delete
        if self.verboseLogging { NSLog("[iCloud] Attempting to delete document: " + name) }
        
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            completion?(NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return
        }
        
        func finish() {
            completion?(nil)
        }
        
        if self.verboseLogging { NSLog("[iCloud] File exists, attempting to delete it") }

        let successfulSecurityScopedResourceAccess = fileURL.startAccessingSecurityScopedResource()

        // Use a file coordinator to safely delete the file
        let fileCoordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: nil)
        let writingIntent: NSFileAccessIntent = NSFileAccessIntent.writingIntent(with: fileURL, options: .forDeleting)
        let backgroundQueue: OperationQueue = OperationQueue()
        fileCoordinator.coordinate(with: [writingIntent], queue: backgroundQueue, byAccessor: {
            accessError in
            
            if accessError != nil {
                NSLog("[iCloud] Access error occurred while deleting document: " + accessError!.localizedDescription)
                completion?(accessError)
            } else {
                
                var success: Bool = true
                var _error: Error? = nil

                do {
                    try self.fileManager.removeItem(at: writingIntent.url)
                } catch {
                    success = false
                    NSLog("[iCloud] An error occurred while deleting document: " + error.localizedDescription)
                    _error = error
                    DispatchQueue.main.async { completion?(error) }
                }

                if successfulSecurityScopedResourceAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }

                DispatchQueue.main.async {
                    if success {
                        self.updateFiles()
                    }
                    completion?(_error)
                }
            }
        })
    }

    /**
     Evict a document from iCloud, move it from iCloud to the current application's local documents directory.
     
     Remove a document from iCloud storage and move it into the local document's directory. This method may call the iCloudFileConflictBetweenCloudFile(cloudFile: [String: Any]?, with localFile: [String: Any]?)  iCloud Delegate method if there is a file conflict.
     */
    open func evictCloudDocument(_ name: String, completion: ((Error?) -> Void)? = nil) {
        // Log delete
        if self.verboseLogging { NSLog("[iCloud] Attempting to evict iCloud document: " + name) }

        guard
            self.quickCloudCheck,
            let localDocuments: URL = self.localDocumentsURL,
            let localURL: URL = localDocuments.appendingPathComponent(name) as URL?,
            let cloudURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return }

        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        // Move to the background thread for safety
        DispatchQueue.global(qos: .background).async {
            
            if (self.previousQueryResults.map{ $0.name }).contains(name) {
                
                // Log conflict
                if self.verboseLogging { NSLog("[iCloud] Conflict between local file and remote file, attempting to automatically resolve") }
                
                // Create UIDocument object from URL
                let document: iCloudDocument = iCloudDocument(fileURL: cloudURL)
                
                if
                    let cloud_modDate: Date = document.fileModificationDate,
                    let fileAttrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: localURL.path),
                    let local_modDate: Date = fileAttrs[FileAttributeKey.modificationDate] as? Date,
                    let local_fileData: Data = self.fileManager.contents(atPath: localURL.path) {
                    
                    if local_modDate.compare(cloud_modDate) == .orderedDescending {
                        
                        NSLog("[iCloud] The local file was modified more recently than the iCloud file. The iCloud file will be deleted and the local file will be preserved.")
                        
                        self.deleteDocument(name, completion: {
                            err in
                            if err != nil {
                                NSLog("[iCloud] Error deleting " + localURL.path + ".\n\n" + err!.localizedDescription)
                            }
                            DispatchQueue.main.async { completion?(err) }
                        })
                        
                    } else if local_modDate.compare(cloud_modDate) == .orderedAscending {
                        
                        NSLog("[iCloud] The iCloud file was modified more recently than the local file. The local file will be overwritten with the contents of the iCloud file.")
                        
                        var err: Error? = nil
                        
                        do {
                            try document.contents.write(to: localURL, options: Data.WritingOptions.atomicWrite)
                        } catch {
                            NSLog("[iCloud] Failed to overwrite file at URL: " + localURL.path)
                            err = error
                        }

                        DispatchQueue.main.async { completion?(err) }
                        
                    } else { // Same

                        NSLog("[iCloud] The local file and iCloud file have the same modification date. Before overwriting or deleting, we will check if both files have the same content.")

                        if self.fileManager.contentsEqual(atPath: cloudURL.path, andPath: localURL.path) {
                            
                            NSLog("[iCloud] The contents of local file and remote file match. Remote file will be deleted.")
                            
                            self.deleteDocument(name, completion: {
                                err in
                                if err != nil {
                                    NSLog("[iCloud] Error deleting " + localURL.path + ".\n\n" + err!.localizedDescription)
                                }
                                DispatchQueue.main.async { completion?(err) }
                            })
                            
                            return
                            
                        } else { // Local and remote file did not match with equal contents.
                            
                            NSLog("[iCloud] Both the iCloud file and the local file were last modified at the same time, however their contents do not match. You'll need to handle the conflict using the iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")
                            
                            DispatchQueue.main.async {
                                self.delegate?.iCloudFileConflictBetweenCloudFile([
                                    "fileContents": document.contents,
                                    "fileURL": cloudURL,
                                    "modifiedDate": cloud_modDate
                                    ], with: [
                                        "fileContents": local_fileData,
                                        "fileURL": localURL,
                                        "modifiedDate": local_modDate
                                    ])
                            }
                        }
                    }
                    
                } else {
                    
                    NSLog("[iCloud] Failed to retrieve information about either or both, local and remote file. You will need to handle the conflict using iCloudFileConflictBetweenCloudFile(_ cloudFile: [String: Any]?, with localFile: [String: Any]?) delegate method.")

                    DispatchQueue.main.async {
                        self.delegate?.iCloudFileConflictBetweenCloudFile([
                            "fileURL": cloudURL
                            ], with: [
                                "fileURL": localURL
                            ])
                    }
                }
                
            } else {
                
                var err: Error? = nil
                
                do {
                    try self.fileManager.setUbiquitous(false, itemAt: cloudURL, destinationURL: localURL)
                } catch {
                    err = error
                }
                
                DispatchQueue.main.async { completion?(err) }
            }
            
        }

    }
    
    /* Retrieving iCloud Content and info */
    
    /**
     Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
     
     This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, Data, and Error all of which contain information about the opened document.
     
     - Parameter name: The name of the document in iCloud.
     - Parameter completion: Called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and Data objects containing the opened document and it's contents in the form of Data. If there is an error, the Error object will have an error message (may be nil if there is no error). This value must not be nil.
     */
    
    open func retrieveCloudDocument(_ name: String, completion: ((UIDocument?, Data?, Error?) -> Void)!) {
        // Log retrieval
        
        if self.verboseLogging { NSLog("[iCloud] Retrieving iCloud document: " + name) }

        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return }

        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }

        // If file exists, open it - otherwise, create it
        if self.fileManager.fileExists(atPath: fileURL.path) {
            // Log open
            if self.verboseLogging { NSLog("[iCloud] The document, " + name + ", already exists and will be opened") }
            
            // Create the UIDocument object from the URL
            let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
            
            if document.documentState == .closed {
                if self.verboseLogging { NSLog("[iCloud] Document is closed and will be opened") }
                
                document.open(completionHandler: {
                    success in
                    if success { // Log open
                        if self.verboseLogging { NSLog("[iCloud] Opened document") }
                        
                        // Pass data on to the completion handler
                        DispatchQueue.main.async { completion(document, document.contents, nil) }
                        return
                    } else {
                        NSLog("[iCloud] Error while retrieving document: @retrieveCloudDocument")
                        // Pass data on to the completion handler
                        DispatchQueue.main.async {
                            completion(document, document.contents, NSError(domain: "retrieveCloudDocument: error while retrieving document, " + document.fileURL.path + " from iCloud", code: 200, userInfo: ["fileURL": fileURL]) as Error)
                        }
                        return
                    }
                })
            } else if document.documentState == .normal {

                // Log open
                if self.verboseLogging { NSLog("[iCloud] Document already opened, retrieving content") }
                
                // Pass data on to the completion handler
                DispatchQueue.main.async { completion(document, document.contents, nil) }
                return
            
            } else if document.documentState == .inConflict {
                
                // Log open
                if self.verboseLogging { NSLog("[iCloud] Document in conflict. The document may not contain correct data. An error will be returned along with the other parameters in the completion handler") }
                
                NSLog("[iCloud] Error while retrieving document, " + name + ", because the document is in conflict")
                
                // Pass data on to the completion handler
                DispatchQueue.main.async { completion(document, document.contents, NSError(domain: "The iCloud document, " + name + ", is in conflict. Please resolve this conflict before editing the document.", code: 200, userInfo: ["fileURL": fileURL]) as Error) }
                return

                
            } else if document.documentState == .editingDisabled {
                
                // Log open
                if self.verboseLogging { NSLog("[iCloud] Document editing disabled. The document is not currently editable, use the documentState: method to determine when the document is available again. The document and its contents will still be passed as parameters in the completion handler.") }
                
                // Pass data on to the completion handler
                DispatchQueue.main.async { completion(document, document.contents, nil) }
                return
            }
        } else { // File did not exists, create it
            // Log creation
            if self.verboseLogging { NSLog("[iCloud] The document, " + name + ", does not exist and will be created as an empty document") }
            
            // Create UIDocument
            let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
            document.contents = Data()
            
            // Save the new document to disk
            document.save(to: fileURL, for: .forCreating, completionHandler: {
                success in
                
                var err: Error? = nil
                
                // Log saving
                if self.verboseLogging { NSLog("[iCloud] Saved and opened the document: " + name) }
                
                if !success {
                    NSLog("[iCloud] Failure when saving document " + name + " to iCloud: @retrieveCloudDocument")
                    err = NSError(domain: "retrieveCloudDocument: error while saving the document " + document.fileURL.path + " to iCloud", code: 110, userInfo: ["Filename": name]) as Error
                }
                
                DispatchQueue.main.async { completion(document, document.contents, err) }
            })
        }
    }

    /**
     Get the relevant iCloudDocument object for the specified file
     
     This method serves a very different purpose from the retrieveCloudDocument(_ name: String, completion: (UIDocument?, Data?, Error?) -> Void) method. Understand the differences between both methods and ensure that you are using the correct one. This method does not open, create, or save any UIDocuments - it simply returns the iCloudDocument object which you can then use for various purposes.
     
     - Parameter name: The name of the document in iCloud.
     */
    open func retrieveCloudDocumentObject(_ name: String) -> iCloudDocument? {
        
        // Log retrieval
        if self.verboseLogging { NSLog("[iCloud] Retrieving iCloud document: " + name) }
        
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return nil }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            return nil
        }

        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        
        // If file exists, open it - otherwise, create it
        if self.fileManager.fileExists(atPath: fileURL.path), self.verboseLogging { NSLog("[iCloud] The document, " + name + ", already exists and will be returned as iCloudDocument object")
        } else if self.verboseLogging {
            NSLog("[iCloud] The document, " + name + ", does not exist but will be returned as an empty iCloudDocument object")
        }

        return document
    }

    /**
     Check if a file exists in iCloud
     
     - Parameter name: The name of the document in iCloud.
     
     - Returns: Boolean value. True if the file does exist in iCloud, false if it does not. May return false also if iCloud is unavailable.
     */
    open func fileExistInCloud(_ name: String) -> Bool {
        // Check for iCloud
        guard
            self.quickCloudCheck,
            !name.isEmpty,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return false }
        
        return self.fileManager.fileExists(atPath: fileURL.path)
    }

    /**
     Returns a Boolean indicating whether the item is targeted for storage in iCloud.
     
     This method reflects only whether the item should be stored in iCloud because a call was made to the setUbiquitous(_:itemAt:destinationURL:) method with a value of true for its flag parameter. This method does not reflect whether the file has actually been uploaded to any iCloud servers. To determine a file’s upload status, check the NSURLUbiquitousItemIsUploadedKey attribute of the corresponding NSURL object.
     
     - Parameter name: Specify the name for the file or directory whose status you want to check.
     
     - Returns: true if the item is targeted for iCloud storage or false if it is not. This method also returns false if no item exists at url or iCloud is not available.
     */
    open func isUbiquitousItem(_ name: String) -> Bool {
        // Check for iCloud
        guard
            self.quickCloudCheck,
            !name.isEmpty,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return false }
        
        return self.fileManager.isUbiquitousItem(at: fileURL)
    }
    
    /**
     Get the size of a file stored in iCloud
     
     - Parameter name: name of file in iCloud.
     
     - Returns: The number of bytes in an unsigned long long. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable.
     */
    
    open func fileSize(_ name: String) -> NSNumber? {
        // Check for iCloud
        guard
            self.quickCloudCheck,
            !name.isEmpty,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return nil }

        // Check if file exists, and return it's size
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return nil
        }
        
        guard
            let attrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
            let size: NSNumber = attrs[FileAttributeKey.size] as? NSNumber
            else { return nil }

        return size
    }

    /**
     Get the last modified date of a file stored in iCloud
     
     - Parameter name: name of file in iCloud.
     
     - Returns: The date that the file was last modified. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable.
     */
    open func fileModified(_ name: String) -> Date? {
        // Check for iCloud
        guard
            self.quickCloudCheck,
            !name.isEmpty,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return nil }
        
        // Check if file exists, and return it's modification date
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return nil
        }
        
        guard
            let attrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
            let date: Date = attrs[FileAttributeKey.modificationDate] as? Date
            else { return nil }
        
        return date
    }
    
    /**
     Get the creation date of a file stored in iCloud
     
     - Parameter name: name of file in iCloud.
     
     - Returns: The date that the file was created. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable.
     */
    open func fileCreated(_ name: String) -> Date? {
        // Check for iCloud
        guard
            self.quickCloudCheck,
            !name.isEmpty,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return nil }
        
        // Check if file exists, and return it's creation date
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return nil
        }
        
        guard
            let attrs: [FileAttributeKey: Any] = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
            let date: Date = attrs[FileAttributeKey.creationDate] as? Date
            else { return nil }
        
        return date
    }
    
    /**
     Get a list of files stored in iCloud
     
     - Returns: String array with a list of all the files currently stored in your app's iCloud Documents directory. May return a nil value if iCloud is unavailable.
     */
    open var listCloudFiles: [URL]? {
        get {
            if self.verboseLogging { NSLog("[iCloud] Getting list of iCloud documents") }
            
            guard
                self.quickCloudCheck,
                let documentURL: URL = self.cloudDocumentsURL,
                let documentDirectoryContents: [URL] = try? self.fileManager.contentsOfDirectory(at: documentURL, includingPropertiesForKeys: nil, options: [])
                else { return nil }

            if self.verboseLogging { NSLog("[iCloud] Retrieved list of iCloud documents") }
            
            return documentDirectoryContents
        }
    }

    /* iCloud content managing */
    
    /**
     Rename a document in iCloud
     
     - Parameter name: name of file in iCloud to be renamed.
     - Parameter newName: The new name which the document should be renamed with. The file specified should not exist, otherwise an error will occur. This value must not be empty.
     - Parameter completion: Code block called when the document renaming has completed. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil.
     */
    open func renameDocument(_ name: String, with newName: String, completion: ((Error?) -> Void)? = nil) {
        
        // Log rename
        if self.verboseLogging { NSLog("[iCloud] Attempting to rename document, " + name + ", to the new name " + newName) }

        // Check for iCloud
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name),
            let newFileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(newName)
            else { return }

        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            completion?(NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return
        }

        guard !self.fileManager.fileExists(atPath: newFileURL.path) else {
            NSLog("[iCloud] Rename failed. File already exists at: " + newFileURL.path)
            completion?(NSError(domain: "The document, " + newName + ", already exist at path " + newFileURL.path, code: 404, userInfo: ["fileURL": newFileURL]) as Error)
            return
        }

        // Log rename
        if self.verboseLogging { NSLog("[iCloud] Renaming Files") }
        
        DispatchQueue.global(qos: .background).async {
            
            var coordinatorError: NSError? = nil
            var _coordinatorError: NSError? {
                get { return coordinatorError }
            }
            
            let fileCoordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: nil)
            fileCoordinator.coordinate(writingItemAt: fileURL, options: .forMoving, writingItemAt: newFileURL, options: .forReplacing, error: &coordinatorError, byAccessor: {
                url1, url2 in

                var err: Error? = nil
                
                do {
                    try self.fileManager.moveItem(at: fileURL, to: newFileURL)
                } catch {
                    NSLog("[iCloud] Failed to rename file, " + name + ", to new name: " + newName + ". Error: " + error.localizedDescription);
                    err = error
                }

                if err == nil, _coordinatorError == nil {
                    // Log success
                    if self.verboseLogging { NSLog("[iCloud] Renamed Files") }
                    
                    DispatchQueue.main.async { completion?(nil) }
                    return
                } else if err != nil {
                    // Log failure
                    NSLog("[iCloud] Failed to rename file, " + name + ", to new name: " + newName + ". Error: " + err!.localizedDescription)
                    
                    DispatchQueue.main.async { completion?(err) }
                    return
                } else if _coordinatorError != nil {
                    // Log failure
                    NSLog("[iCloud] Failed to rename file, " + name + ", to new name: " + newName + ". Error: " + (_coordinatorError! as Error).localizedDescription)
                    
                    DispatchQueue.main.async { completion?(_coordinatorError! as Error) }
                    return
                }
            })
        }
    }

    /**
     Duplicate a document in iCloud
     
     - Parameter name: name of file in iCloud to be renamed.
     - Parameter newName: The new name which the document should be duplicated to. The file specified should not exist, otherwise an error will occur. This value must not be empty.
     - Parameter completion: Code block called when the document duplication has completed. The completion block passes and NSError object which contains any error information if an error occurred, otherwise it will be nil.
     */
    open func duplicateDocument(_ name: String, with newName: String, completion: ((Error?) -> Void)? = nil) {
        // Log duplication
        if self.verboseLogging { NSLog("[iCloud] Attempting to duplicate document, " + name + ", to " + newName) }
        
        // Check for iCloud
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name),
            let newFileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(newName)
            else { return }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion?(NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            completion?(NSError(domain: "The document, " + name + ", does not exist at path " + fileURL.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
            return
        }
        
        guard !self.fileManager.fileExists(atPath: newFileURL.path) else {
            NSLog("[iCloud] Duplication failed. Target file already exists at: " + newFileURL.path)
            completion?(NSError(domain: "The document, " + newName + ", already exist at path " + newFileURL.path, code: 404, userInfo: ["fileURL": newFileURL]) as Error)
            return
        }
        
        // Log success of existence and duplication
        if self.verboseLogging {
            NSLog("[iCloud] Files passed existence check, preparing to duplicate")
            NSLog("[iCloud] Duplicating Files")
        }
        
        DispatchQueue.global(qos: .background).async {
            
            var err: Error? = nil
            
            do {
                try self.fileManager.copyItem(at: fileURL, to: newFileURL)
            } catch {
                NSLog("[iCloud] Failed to duplicate file, " + name + ", with new name: " + newName + ". Error: " + error.localizedDescription)
                err = error
            }
            
            DispatchQueue.main.async { completion?(err) }
        }
    }

    /* iCloud Document State */

    /**
     Get the current document state of a file stored in iCloud
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter completion: Completion handler that passes three parameters, an NSError, NSString and a UIDocumentState. The documentState parameter represents the document state that the specified file is currently in (may be nil if the file does not exist). The userReadableDocumentState parameter is an NSString which succinctly describes the current document state; if the file does not exist, a non-scary error will be displayed. The NSError parameter will contain a 404 error if the file does not exist.
     */
    open func documentState(_ name: String, completion: ((UIDocument.State?, String?, Error?) -> Void)!) {
        
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            completion(nil, nil, NSError(domain: "The specified document name was empty / blank and could not be saved. Specify a document name next time.", code: 001, userInfo: nil) as Error)
            return
        }

        if self.fileManager.fileExists(atPath: fileURL.path) {
            // Create the document
            let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
            let state: UIDocument.State = document.documentState
            let description: String = document.stateDescription
            completion(state, description, nil)
        } else { // The document didn't exist            
            NSLog("[iCloud] File not found: " + name)
            
            completion(nil, nil, NSError(domain: "The document, " + name + ", does not exist at path: " + self.cloudDocumentsURL!.path, code: 404, userInfo: ["fileURL": fileURL]) as Error)
        }
    }

    /**
     Observe changes in the state of a document stored in iCloud
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter observer: Object registering as an observer. This value must not be nil.
     - Parameter selector: Selector to be called when the document state changes. Must only have one argument, an instance of NSNotifcation whose object is an iCloudDocument (UIDocument subclass). This value must not be nil.

     - Returns: true if observing was succesfully setup, otherwise false.
     */
    
    @discardableResult
    open func observeDocumentState(_ name: String, observer: Any, selector: Selector) -> Bool {
        
        // Log observing
        if self.verboseLogging { NSLog("[iCloud] Preparing to observe changes to " + name) }

        // Check for iCloud
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return false }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            return false
        }

        // Log monitoring
        if self.verboseLogging { NSLog("[iCloud] Checking for existance of " + name) }

        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return false
        }

        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        
        self.notificationCenter.addObserver(observer, selector: selector, name: UIDocument.stateChangedNotification, object: document)
        
        // Log monitoring success
        if self.verboseLogging { NSLog("[iCloud] Observing for changes to " + name) }
        return true
    }

    /**
     Stop observing changes to the state of a document stored in iCloud
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter observer: Object registered as an observer. This value must not be nil.
     
     - Returns: true if observing was succesfully ended, otherwise false.
     */
    
    @discardableResult
    open func removeDocumentStateObserver(_ name: String, observer: Any) -> Bool {
        
        // Log observing
        if self.verboseLogging { NSLog("[iCloud] Preparing to stop observing changes to " + name) }
        
        // Check for iCloud
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return false }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            return false
        }
        
        // Log monitoring
        if self.verboseLogging { NSLog("[iCloud] Checking for existance of " + name) }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return false
        }
        
        let document: iCloudDocument = iCloudDocument(fileURL: fileURL)
        
        self.notificationCenter.removeObserver(observer, name: UIDocument.stateChangedNotification, object: document)
        
        // Log monitoring success
        if self.verboseLogging { NSLog("[iCloud] Stopped observing for changes to " + name) }
        return true
    }

    /**
     Observe changes in the state of iCloud availability
     
     - Parameter observer: Object registering as an observer. This value must not be nil.
     - Parameter selector: Selector to be called when state changes. Must only have one argument, an instance of NSNotifcation whose object is an bool. This value must not be nil.
     
     - Returns: nothing.
     */

    open func observeCloudState(_ observer: Any, selector: Selector) {

        self.notificationCenter.addObserver(observer, selector: selector, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: self.cloudAvailable)
        
        // Log monitoring success
        if self.verboseLogging { NSLog("[iCloud] Observing for changes to iCloud availability") }
    }

    /**
     Stop observing changes to state of iCloud availability
     
     - Parameter observer: Object registered as an observer. This value must not be nil.
     
     - Returns: nothing.
     */

    open func removeCloudStateObserver(observer: Any) {
        
        self.notificationCenter.removeObserver(observer, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: self.cloudAvailable)

        // Log monitoring success
        if self.verboseLogging { NSLog("[iCloud] Stopped observing for changes to iCloud availability") }
    }
    
    /* Resolving iCloud Conflicts */
    
    /**
     Find all the conflicting versions of a specified document
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     
     - Returns: Array of NSFileVersion objects, or nil if no such version object exists.
     */
    open func findUnresolvedConflictingVersionsOfFile(_ name: String) -> [NSFileVersion]? {
        
        // Log conflict search
        if self.verboseLogging { NSLog("[iCloud] Preparing to find all version conflicts for " + name) }
        
        // Check for iCloud
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return nil }
        
        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            return nil
        }

        // Log conflict search
        if self.verboseLogging { NSLog("[iCloud] Checking for existance of " + name) }
        
        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return nil
        }

        // Log conflict search
        if self.verboseLogging { NSLog("[iCloud] " + name + " exists at the correct path, proceeding to find conflicts") }
        
        var fileVersions: [NSFileVersion] = []
        
        if let currentVersion: NSFileVersion = NSFileVersion.currentVersionOfItem(at: fileURL) {
            fileVersions.append(currentVersion)
        }
        
        if let otherVersions: [NSFileVersion] = NSFileVersion.otherVersionsOfItem(at: fileURL) {
            fileVersions.append(contentsOf: otherVersions)
        }
        
        return fileVersions
    }

    /**
     Resolve a document conflict for a file stored in iCloud
     
     Your application can follow one of three strategies for resolving document-version conflicts:
     
     * Merge the changes from the conflicting versions.
     * Choose one of the document versions based on some pertinent factor, such as the version with the latest modification date.
     * Enable the user to view conflicting versions of a document and select the one to use.
     
     - Parameter name: The name of the file in iCloud. This value must not be nil.
     - Parameter documentVersion: The version of the document which should be kept and saved. All other conflicting versions will be removed.
     */
    open func resolveConflictForFile(_ name: String, with documentVersion: NSFileVersion) {
        
        if self.verboseLogging { NSLog("[iCloud] Preparing to resolve version conflict for " + name) }

        // Check for iCloud
        guard
            self.quickCloudCheck,
            let fileURL: URL = self.cloudDocumentsURL?.appendingPathComponent(name)
            else { return }

        guard !name.isEmpty else {
            NSLog("[iCloud] Specified document name must not be empty")
            return
        }
        
        // Log resolution
        if self.verboseLogging { NSLog("[iCloud] Checking for existance of " + name) }

        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            NSLog("[iCloud] File not found: " + name)
            return
        }
        
        // Log resolution
        if self.verboseLogging { NSLog("[iCloud] " + name + " exists at the correct path, proceeding to resolve conflict") }

        // Force the current version to win comparison in conflict
        if documentVersion != NSFileVersion.currentVersionOfItem(at: fileURL) {
            // Log resolution
            
            if self.verboseLogging { NSLog("iCloud] The current version (" + documentVersion.description + ") of " + name + " matches the selected version. Resolving conflict...") }
            
            let _ = try? documentVersion.replaceItem(at: fileURL, options: [])
        }
        
        try? NSFileVersion.removeOtherVersionsOfItem(at: fileURL)

        // Log resolution
        if self.verboseLogging { NSLog("[iCloud] Removing all unresolved other versions of " + name) }
        
        if let conflictVersions: [NSFileVersion] = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) {
            for fileVersion in conflictVersions {
                fileVersion.isResolved = true
            }
        }

        // Log resolution
        if self.verboseLogging { NSLog("[iCloud] Finished resolving conflicts for " + name) }
    }
    
}
