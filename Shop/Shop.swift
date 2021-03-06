//
//  Shop.swift
//  Shop
//
//  Copyright © 2017 SAP SE or an SAP affiliate company. All rights reserved.
//  Use of this software subject to the End User License Agreement located in /src/EULA.pdf
//

import UIKit
import SAPCommon
import SAPFiori
import SAPOData
import SAPFoundation

/// The Shop singleton is the master instance of the shop. It creates and holds data that is global and
/// unique to the shop implementation, like a reference to the OData service proxy and an image cache
class Shop {

    // the Shop singleton
    static let shared = Shop()

    static let shoppingCartDidUpdateNotification = Notification.Name("shoppingCartDidUpdateNotification")

    let imageCache = NSCache<NSString, UIImage>()

    let oDataService: ShopService<OnlineODataProvider>?

    /// Initializes the dataService and dataProvider
    private init() {

        imageCache.name = "Loaded Images"
        
        guard let connectionParameters = ConnectionManager.shared.connectionParameters,
            let serviceEndpointURL = connectionParameters.serverURL else {
                oDataService = nil
                return
        }
        
        let onlineOdataProvider = OnlineODataProvider(serviceRoot: serviceEndpointURL, sapURLSession: ConnectionManager.shared.sapUrlSession!)
        
        //choose desired tracing  settings for  OData traffic
        onlineOdataProvider.prettyTracing = true
        onlineOdataProvider.traceRequests = true
        onlineOdataProvider.traceWithData = false
        
        // allow PATCH to be tunneled via POST (potential gateway restrictions)
        onlineOdataProvider.networkOptions.tunneledMethods.append("PATCH")
        
        //NOTE: to actually see  the requeted output from above, logging for OData needs to be forced to the debug level
//        Logger.shared(named: "SAP.OData").loglevel = .debug
        oDataService = ShopService(provider: onlineOdataProvider)
    }
}
