//
//  IAPController.swift
//  giffed
//
//  Created by Daniel Pourhadi on 3/7/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation
import StoreKit
import Alamofire
import Purchases
import Combine

struct IAPDetails {
    let monthlyPriceString: String
    let yearlyPriceString: String
    
    static func empty() -> Self {
        return IAPDetails(monthlyPriceString: "", yearlyPriceString: "")
    }
}

class IAP: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    var debug = true

    
    var signature: String?
    
    func getSignature(productID: String, offerID: String, complete: @escaping (_ sig: String) -> Void) {
        let url = API.apiURL.appendingPathComponent("subscription").appendingPathComponent("generate_sig").appendingPathComponent(FileGallery.shared.userId)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.authorize()
        let params = ["productID": productID, "offerID": offerID]
        if let req = try? JSONParameterEncoder.default.encode(params, into: req) {
            
        }
        
    }
    
    func checkActive(complete: @escaping (Bool) -> Void) {
        if debug {
            complete(true)
            return
        }
        
        
        Purchases.shared.purchaserInfo { (purchaserInfo, error) in
            if purchaserInfo?.entitlements.all["subscription"]?.isActive == true {
                complete(true)
            } else {
                complete(false)
            }
        }
    }
    
    func purchaseMonthly(complete: @escaping (Bool) -> Void) {
        self.purchase(promo: .oneWeekFree, complete: complete)
    }
    
    func purchaseYearly(complete: @escaping (Bool) -> Void) {
        self.purchase(promo: .oneYear, complete: complete)
    }
    
    func purchase(promo: PromoID, complete: @escaping (Bool) -> Void) {
        Purchases.shared.offerings { (offerings, error) in
            if let package = offerings?.current?.availablePackages.first {
                
                Purchases.shared.purchasePackage(package) { (tx, info, error, done) in
                    if info?.entitlements.all["subscription"]?.isActive == true {
                        complete(true)
                    } else {
                        complete(false)
                    }
                }

            } else {
                complete(false)
            }
        }
    }
    
    var availableProducts = [SKProduct]()
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !response.products.isEmpty {
            availableProducts = response.products
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    var isAuthorizedForPayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    
    var purchased = false
    
    enum ProductID: String {
        case monthly = "monthly_299"
    }
    
    enum PromoID: String {
        case oneWeekFree = "one_week_free"
        case oneYear = "one_year"
    }
    
    static let shared = IAP()
    
    @Published var packages = [Purchases.Package]()
    @Published var details: IAPDetails = IAPDetails.empty()
    //Initialize the store observer.
    override init() {
        super.init()
        
        self.fetchProducts(matchingIdentifiers: [ProductID.monthly.rawValue])
        
        Purchases.shared.offerings { (offerings, error) in
            if let package = offerings?.current?.availablePackages.first {
                // Display packages for sale
                
                let monthly = package.localizedPriceString
                var yearly = ""

                for discount in package.product.discounts {
                    if discount.identifier == PromoID.oneYear.rawValue {
                        yearly = "$\(discount.price)"
                    }
                }
                
                self.details = IAPDetails(monthlyPriceString: monthly, yearlyPriceString: yearly)
            }
        }
    }
    
    var productRequest: SKProductsRequest?
    
    fileprivate func fetchProducts(matchingIdentifiers identifiers: [String]) {
        // Create a set for the product identifiers.
        let productIdentifiers = Set(identifiers)
        
        // Initialize the product request with the above identifiers.
        productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productRequest?.delegate = self
        
        // Send the request to the App Store.
        productRequest?.start()
    }
    
    
    func restore(_ complete: @escaping (Bool) -> Void) {
        Purchases.shared.restoreTransactions { (info, error) in
            if info?.entitlements.all["subscription"]?.isActive == true {
                complete(true)
            } else {
                complete(false)
            }
        }
    }
    
    func purchase(_ productId: ProductID) {
        
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
