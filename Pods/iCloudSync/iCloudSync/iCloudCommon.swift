//
//  iCloudCommon.swift
//  iCloud
//
//  Created by Oskari Rauta on 25/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import Foundation

public typealias UbiquityIdentityToken = (NSCoding & NSCopying & NSObjectProtocol)

public struct UbiquitousMetaDataItem {
    public var item: NSMetadataItem
    public var url: URL
    public var name: String
    public var status: URLUbiquitousItemDownloadingStatus
    
    public init?(_ item: NSMetadataItem) {
        guard
            let _url: URL = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
            let _name: String = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
            let _values: URLResourceValues = try? _url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey
                ]),
            let _status: URLUbiquitousItemDownloadingStatus = _values.allValues[.ubiquitousItemDownloadingStatusKey] as? URLUbiquitousItemDownloadingStatus
            else { return nil }
        self.item = item
        self.url = _url
        self.name = _name
        self.status = _status
    }
}
