//
//  Env.swift
//  gif
//
//  Created by dan on 12/16/19.
//  Copyright © 2019 dan. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

//public protocol EnvironmentKey {
//
//    associatedtype Value
//
//    static var defaultValue: Self.Value { get }
//}


struct DeviceDetailsKey: EnvironmentKey {
    static let defaultValue: DeviceDetails = DeviceDetails()
}

extension EnvironmentValues {
    var deviceDetails: DeviceDetails {
        get {
            return self[DeviceDetailsKey.self]
        }
        set {
            self[DeviceDetailsKey.self] = newValue
        }
    }
}
