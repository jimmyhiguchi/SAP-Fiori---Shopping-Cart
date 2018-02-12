//
//  DetailViewController.swift
//  Shop
//
//  Created by Jimmy Higuchi on 2/1/18.
//  Copyright © 2018 SAP. All rights reserved.
//

import UIKit
import SAPFiori
import SAPCommon
import SAPOData

class DetailViewController: UIViewController {
    
    let logger = Logger.shared(named: "DetailViewController")

    @IBOutlet var productView: ProductDetailView!
    
    var productID: String?
    
    fileprivate var product: Product? {
        didSet {
            productView.product = product
            navigationController?.title = product?.name
            productView.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    /// Load the product details including reviews and images.
    func loadProductDetails() {
        
        if let productID = productID {
            
            // create a query for products matching the given id
            // (which will return only one product)
            var query = DataQuery().withKey(Product.key(id: productID))
            
            // include all associated images in the result
            query = query.expand(Product.images)
            
            // include associated reviews in the result and sort them by the helpful count in descending order,
            // then limit to 3 entries (= top 3 helpful reviews)
            query = query.expand(Product.reviews, withQuery: DataQuery().orderBy(Review.helpfulCount, .descending).top(3))
            
            let loadingIndicator = FUIModalLoadingIndicator.show(inView: view)
            Shop.shared.oDataService?.product(query: query) { products, error in
                
                loadingIndicator.dismiss()
                
                guard error == nil else {
                    self.logger.warn("Error while loading product details", error: error)
                    self.product = nil
                    return
                }
                
                self.product = products?.first
            }
        }
        
        NotificationCenter.default.post(name: Shop.shoppingCartDidUpdateNotification, object: nil)
    }
    
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        loadProductDetails()
    }

}

extension DetailViewController: ProductDetailViewDelegate {
    
    /// Adds the product to the shopping cart.
    func didSelectAddToCart(_ button: FUIButton) {
        
        guard let product = product else {
            return
        }
        
        // disable button after added to shopping cart 
        button.isEnabled = false
        
        Shop.shared.oDataService?.addProductToShoppingCart(productID: product.id) { shoppingCartItem, error in
            
            button.isEnabled = true
            
            guard error == nil else {
                self.logger.warn("Error adding product \(product.name) (\(product.id)) to shopping cart.", error: error)
                return
            }
            
            FUIToastMessage.show(message: "\(product.name) added to cart.", maxNumberOfLines: 2)
            NotificationCenter.default.post(name: Shop.shoppingCartDidUpdateNotification, object: nil)
        }
    }
    
    func didSelectReview(_ review: Review) {
        
    }
    
    func didSelectShowAllReviews(_ button: FUIButton) {
        
    }
    
    func didSelectWriteReview(_ button: FUIButton) {
        
    }
}
