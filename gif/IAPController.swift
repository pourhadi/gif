//
//  IAPController.swift
//  giffed
//
//  Created by Daniel Pourhadi on 3/7/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import StoreKit
import InAppPurchase


class StoreObserver: NSObject {
    
    var purchased = false
    
    enum ProductID: String {
        case monthly = "monthly_299"
        case yearly = "one_year_999_1"
    }
    

    static let shared = StoreObserver()
    
    //Initialize the store observer.
    override init() {
        super.init()
        //Other initialization here.
        
//        SKPaymentQueue.default().delßegate = self
        
        let iap = InAppPurchase.default
        iap.addTransactionObserver()
    }
    
    
    func restore() {
        let iap = InAppPurchase.default
        iap.restore(handler: { (result) in
            switch result {
            case .success(_):
                self.purchased = true
                break
                
            case .failure(let error):
               
                
                break
            }
        })
    }
    
    func purchase(_ productId: ProductID) {
        let iap = InAppPurchase.default
        iap.purchase(productIdentifier: "PRODUCT_ID", handler: { (result) in
            // This handler is called if the payment purchased, restored, deferred or failed.

            switch result {
            case .success(let state):
                // Handle `InAppPurchase.PaymentState`
                
                break
            case .failure(let error):
                // Handle `InAppPurchase.Error`
                
                break
            }
        })
    }

}

extension SKProduct {
    /// - returns: The cost of the product formatted in the local currency.
    var regularPrice: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.priceLocale
        return formatter.string(from: self.price)
    }
}
