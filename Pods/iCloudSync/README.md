![Banner](https://github.com/oskarirauta/iCloudSync/raw/master/Documentation/CloudBanner.png)

# iCloudSync

A complete rewrite in Swift, including some fixes from iRareMedia's iCloud Document Sync fork.
Documentation is still partially out-of-date, but it's pretty straight forward if you ever have used iCloud Document Sync.

iCloudSync makes it easy for developers to integrate the iCloud document storage APIs into iOS applications. This is how iCloud document-storage and management should've been out of the box from Apple. Integrate iCloud into iOS Swift document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only a few lines of code. Get iCloud up and running in your iOS app in no time.

If you like the project, please [star it](https://github.com/oskarirauta/iCloudSync) on GitHub!

## Project Features
iCloudSync is a great way to use iCloud document storage in your iOS app. Below are a few key project features and highlights.
* Sync, Upload, Read, Write, Share, Save, Remove, and Edit any iCloud document in only one line of code.  
* Just drag and drop the iCloudSync Framework (`iCloudSync.framework`) into your project and you can begin using iCloud - no complicated setup  
* Access in-depth documentation with docsets, code comments, and verbose logging  
* Useful delegate methods and properties let you access and manage advanced iCloud features
* Manage any kind of file with iCloud through use of Data  
* iOS Sample-app to illustrate how easy it is to use iCloudSync

### Table of Contents

* [**Project Information**](#project-information)
  * [Requirements](#requirements)
  * [License](#license)
  * [Contributions](#contributions)
  * [Sample App](#sample-app)
* [**Installation**](#installation)
  * [CocoaPods](#cocoapods-setup)
  * [Framework](#frameworks-setup)
  * [Traditional](#traditional-setup)
* [**Setup**](#setup)
* [**Documentation**]
  * [Methods](#methods)
  * [Delegate](#delegate)

## Project Information
Learn more about the project requirements, licensing, and contributions.

### Requirements
Lowest minimum requirements are untested, but framework is designed with Xcode 10.1 and iOS 11.4 is set as a minimum deployment target, code should run on lower targets as well, but is not tested.

### License 
This project is licensed under MIT License accordingly to it's successor, iCloud Document Sync. See the [full license here](https://github.com/oskarirauta/iCloudSync/block/master/LICENSE.md).

Attribution is not required, but it's appreciated. iRare Media and I have spend a lot of time, energy and resource on this proejct, so a little *Thanks!* would be great. If you use iCloudSync or iCloud Document Sync in your app, send email to contract@iraremedia.com or send a tweet at @iRareMedia.

### Contributions
Any contribution is more than welcome! You can contribute through pull requests and issues on GitHub.

### Sample App
The iOS Sample App included with this project demonstrates how to use many of the features in iCloudSync. You can refer to the sample app for an understanding of how to use and setup iCloudSync. The app should work with iCloud as-is (you may need to provide your own Bundle ID though).

## Installation
There are multiple ways to add iCloudSync to your project and it is easy. Choose the process below which best suits your needs. Follow the steps to get everything up and running in no time.

### CocoaPods Setup
The easiest way to install iCloud Document Sync is to use CocoaPods. To do so, simply add the following line to your Podfile:

    pod 'iCloudDocumentSync', :git => 'https://github.com/oskarirauta/iCloudSync.git'

### Framework Setup
Clone the project to your computer and build the *Framework* target. The `iCloudSync.framework` file will be copied to the project directory. Drag and drop the `.framework` file into your project.  

### Traditional Setup
Drag and drop the *iCloudSync* folder into your Xcode project. When you do so, check the "Copy items into destination group's folder" box.

## Setup
After installing iCloudSync, it only takes a few lines of code to get it up an running.  
  1. Import iCloudSync (see relevant install instructions above) to your header file(s).  
  2. Subscribe to the `iCloudDelegate` delegate.  
  3. Set the delegate and optionally enable verbose logging:  
   
    iCloud.shared.delegate = self // Set this if you plan to use the delegate
    iCloud.shared.verboseLogging = true // We want detailed feedback on what's going on with iCloud, false by default
        
  4. Setup iCloud when your app starts. It is crucial that you call this method before doing any document handling operations. You can either pass a specific Ubiquity Container ID (see your entitlements file) or `nil` to use the first Ubiquity Container ID in your entitlements.  

    iCloud.shared.setupiCloud(nil)
        
  5. It is recommended that the first call to `iCloud` after setup, is setting delegate. This way all subsequent operations and method calls can interact with the delegate and provide appropriate information.

## Methods
There are many methods available on iCloudSync. The most important / highlight methods are documented below. All other methods are documented with in-code comments.

### Checking for iCloud Availability
iCloudSync checks for iCloud availability before performing any iCloud-related operations. Any method may return prematurely and without a warning if iCloud is unavailable. Therefore, you should always check if iCloud is available before performing any iCloud operations.

    let cloudIsAvailable: Bool = iCloud.shared.cloudAvailable
    if cloudIsAvailable {
        // true
    }

This checks if iCloud is available by looking for the application's ubiquity token. It returns a boolean value; true if iCloud is available, and false if not. Check the log / documentation for details on why it may not be available. You can also check for the availability of the iCloud ubiquity *container* by calling the following method:

    let cloudContainerIsAvailable: Bool = iCloud.shared.ubiquityContainerAvailable

The `cloudAvailable` getter will call the `iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?)` delegate method. 

### Syncing Documents
To get iCloudSync to initialize for the first time, and continue to update when there are changes you'll need to initialize iCloud. By initializing iCloud, it will start syncing with iCloud for the first time and in the future.  

    let _ = iCloud.shared

You can manually fetch changes from iCloud too:

    iCloud.shared.updateFiles()

iCloudSync will automatically detect changes in iCloud documents. When something changes the delegate method below is fired and will pass an array of all the files (NSMetadata Items) and their names (NSStrings) stored in iCloud.

    - iCloudFilesDidChange(_ files: [NSMetadataItem], with filenames: [String])

### Uploading Documents
iCloudSync uses UIDocument and Data to store and manage files. All of the heavy lifting with Data and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloudSync your data, and the rest is done for you.

To create a new document or save and close an existing one, use the method below.

    iCloud.shared.saveAndCloseDocument("Name.ext", with: *content as data*, completion: {
        document, data, error
        if error == nil {
            // Code here to use the UIDocument or Data objects which have been passed with the completion handler
        }
    })

The completion handler will be called when a document is saved or created. The completion handler has a UIDocument and Data parameter that contain the document and it's contents. The third parameter is an Error that will contain an error if one occurs, otherwise it will be `nil`.

You can also upload any documents created while offline, or locally.  Files in the local documents directory that do not already exist in iCloud will be **moved** into iCloud one by one. This process involves lots of file manipulation and as a result it may take a long time. This process will be performed on the background thread to avoid any lag or memory problems. When the upload processes end, the completion block is called on the main thread.

    iCloud.shared.uploadLocalOfflineDocuments(repeatingHandler: {
        name, error in
        if error == nil {
            // This code block is called repeatedly until all files have been uploaded (or an upload has at least been attempted). Code here to use the NSString (the name of the uploaded file) which have been passed with the repeating handler
        }        
    }, completion: {
        // Completion handler could be used to tell the user that the upload has completed
    })

Note the `repeatingHandler` block. This block is called every-time a local file is uploaded, therefore it may be called multiple times in a short period. The Error object contains any error information if an error occurred, otherwise it will be nil.

### Removing Documents
You can delete documents from iCloud by using the method below. The completion block is called when the file is successfully deleted.

    iCloud.shared.deleteDocument("docName.ext", completion: {
        error in
        // Completion handler could be used to update your UI and tell the user that the document was deleted
    })

### Retrieving Documents and Data
You can open and retrieve a document stored in your iCloud documents directory with the method below. This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, Data, and Error all of which contain information about the opened document.

    iCloud.shared.retrieveCloudDocument("docName.ext", completion: {
        document, data, error in
        if 
           (!error),
           let filename: String = document.fileURL.lastPathComponent,
           let filedata: Data = data {
            // You have retrieved document's filename and contents as data, proceed..
        }
    	}
    })

First check if there was an error retrieving or creating the file, if there wasn't you can proceed to get the file's contents and metadata.

You can also check whether or not a file actually exists in iCloud or not by using the method below.

    let fileExists: Bool = iCloud.shared.fileExistsInCloud("docName.ext")
    if fileExists {
        // File Exists in iCloud
    }

### Sharing Documents
You can upload an iCloud document to a public URL by using the method below. The completion block is called when the public URL is created.

    iCloud.shared.shareDocument("docName.ext", completion: {
        sharedURL, expirationDate, error in
        // Completion handler that passes the public URL created, the expiration date of the URL, and any errors. Could be used to update your UI and tell the user that the document was uploaded
    })

### Renaming and Duplicating Documents
Rename a document stored in iCloud

    iCloud.shared.renameDocument("oldName.ext", with: "newName.ext", completion: {
        error in
        // Called when renaming is complete
    })

### Duplicating a document stored in iCloud
Duplicate a document stored in iCloud

    iCloud.shared.duplicateDocument("docName.ext", with: "docNameCopy.ext", completion: {
        error in
        // Called when duplication is complete
    })

### Observing Document State
iCloud tracks the state of a document when stored in iCloud. Document states include: Normal / Open, Closed, In Conflict, Saving Error, and Editing Disabled (learn more about [UIDocumentState](https://developer.apple.com/library/ios/documentation/uikit/reference/UIDocument_Class/UIDocument/UIDocument.html#//apple_ref/doc/c_ref/UIDocumentState)). Get the current document state of a file stored in iCloud with this method:

    iCloud.shared.documentState("docName.ext", completion: {
        state, description, error in
        // Completion handler that passes two parameters, an NSError and a UIDocumentState. The documentState parameter represents the document state that the specified file is currently in (may be nil if the file does not exist). The NSError parameter will contain a 404 error if the file does not exist.
    })

Observe changes in a document's state by subscribing a specific target / selector / method.

    let success: Bool = iCloud.shared.observeDocumentState("docName.ext", observer: self, selector: #selector(self.methodName(_:)))

Stop observing changes in a document's state by removing notifications for a specific target.

    let success: Bool = iCloud.shared.removeDocumentStateObserver("docName.ext", observer: self)
    
### File Conflict Handling
When a document's state changes to *in conflict*, your application should take the appropriate action by resolving the conflict or letting the user resolve the conflict. You can monitor for document state changes with the `iCloud.shared.observeDocumentState(name: String, observer: Any, selector: #Selector)` method. iCloudSync provides two methods that help handle a conflict with a document stored in iCloud. The first method lets you find all conflicting versions of a file:

    if let documentVersions: [NSFileVersion] = iCloud.shared.findUnresolvedConflictingVersionsOfFile("docName.ext") {
        // Handle conflicts..    
    }

The array returned contains a list of NSFileVersion objects for the specified file. You can then use this list of file versions to either automatically merge changes or have the user select the correct version. Use the following method to resolve the conflict by submitting the "correct" version of the file.

    iCloud.shared.resolveConflictForFile("docName.ext", with: NSFileVersion)


## Delegate
iCloudSync delegate methods notify you of the status of iCloud and your documents stored in iCloud. To use the iCloud delegate, subscribe to the `iCloudDelegate` protocol and then set the `delegate` property. To use the iCloudDocument delegate, subscribe to the `iCloudDocumentDelegate` protocol and then set the `delegate` property.

### iCloud Availability Changed // Documentation updated until this section
Called (automatically by iOS) when the availability of iCloud changes.  The first parameter, `cloudIsAvailable`, is a boolean value that is YES if iCloud is available and NO if iCloud is not available. The second parameter, `ubiquityToken`, is an iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason. The third parameter, `ubiquityContainer`, is the root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized.

    - (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer

### iCloud Files Changed
When the files stored in your app's iCloud Document's directory change, this delegate method is called.  The first parameter, `files`, contains an array of NSMetadataItems which can be used to gather information about a file (ex. URL, Name, Dates, etc). The second parameter, `fileNames`, contains an array of the name of each file as NSStrings.

    - (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames

### iCloud File Conflict
When uploading multiple files to iCloud there is a possibility that files may exist both locally and in iCloud - causing a conflict. iCloudSync can handle most conflict cases and will report the action taken in the log. When iCloudSync can't figure out how to resolve the file conflict (this happens when both the modified date and contents are the same), it will pass the files and relevant information to you using this delegate method.  The delegate method contains two NSDictionaries, one which contains information about the iCloud file, and the other about the local file. Both dictionaries contain the same keys with the same types of objects stored at each key:  
* `fileContent` contains the NSData of the file.
* `fileURL` contains the NSURL pointing to the file. This could possibly be used to gather more information about the file.
* `modifiedDate` contains the NSDate representing the last modified date of the file.

Below is the delegate method to be used

    - (void)iCloudFileConflictBetweenCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;

### iCloud Query Parameter
Called before creating an iCloud Query filter. Specify the type of file to be queried. If this delegate method is not implemented or returns nil, all files stored in the documents directory will be queried. Should return a single file extension formatted (as an NSString) like this: `@"txt"`

    - (NSString *)iCloudQueryLimitedToFileExtension

### iCloud Document Error
Delegate method fired when an error occurs during an attempt to read, save, or revert a document. This delegate method is only available on the `iCloudDocumentDelegate` with the `iCloudDocument` class. If you implement the iCloudDocument delegate, then you *must* implement this method - it is required.

    - (void)iCloudDocumentErrorOccured:(NSError *)error
