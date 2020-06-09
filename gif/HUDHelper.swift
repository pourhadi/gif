//
//  HUDHelper.swift
//  giffed
//
//  Created by Daniel Pourhadi on 6/4/20.
//  Copyright © 2020 dan. All rights reserved.
//

import Foundation


func showHUDLoading() {
    DispatchQueue.main.async {
    HUDAlertState.global.showLoadingIndicator = true
    }
}

func hideHUDLoading() {
    DispatchQueue.main.async {
        HUDAlertState.global.showLoadingIndicator = false
    }
}
