//
//  ShoppingCartViewController.swift
//  Shop
//
//  Created by Jimmy Higuchi on 2/5/18.
//  Copyright © 2018 SAP. All rights reserved.
//

import UIKit
import SAPCommon
import SAPFoundation
import SAPFiori
import SAPOData


class ShoppingCartViewController: UIViewController {

    let logger = Logger.shared(named: "ShoppingCartViewController")
    
    @IBOutlet var worklist: WorklistView!
    @IBAction func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBOutlet weak var checkoutButton: UIBarButtonItem!
    
    @IBAction func didTapCheckout(_ sender: Any) {
        checkoutButton.isEnabled = false
        
        let modalCheckoutViewController = FUIModalCheckoutViewController.instantiateViewController()
        modalCheckoutViewController.delegate = self
        
        modalCheckoutViewController.title = "Checkout"
        modalCheckoutViewController.text = "Processing"
        
        self.present(modalCheckoutViewController, animated: true)
        
        Shop.shared.oDataService?.buyShoppingCart() { shoppingCarts, error in
            guard error == nil else {
                self.checkoutButton.isEnabled = true
                self.logger.error("Error checking out.", error: error)
                
                let optionMenu = UIAlertController(title: "Error during checkout",
                                                   message: error?.localizedDescription, preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "OK", style: .cancel)
                
                optionMenu.addAction(cancelAction)
                
                modalCheckoutViewController.dismiss(animated: false) {
                    self.present(optionMenu, animated: true)
                }
                
                return
            }
            
            // empty the shopping cart so that the items do not still show up when closing the worklist
            self.shoppingCart = nil
            self.worklist.reloadData()
            self.worklist.emptyListText = ""
            
            modalCheckoutViewController.text = "Order Received"
            modalCheckoutViewController.changeDisplayState(to: .completed) {
                NotificationCenter.default.post(name:
                    Shop.shoppingCartDidUpdateNotification, object: nil)
            }
        }
    }
    var shoppingCart: ShoppingCart? {
        didSet {
            let items = shoppingCart?.shoppingCartItems ?? []
            self.checkoutButton.isEnabled = !items.isEmpty
        }
    }
    
    /// return the data query required to retrieve all shopping cart information we'll
    /// need
    var dataQuery: DataQuery {
        // Each shopping cart (and there will be at most one per user) has a list of
        // shopping cart items. Each item has a list of products. Each product has a
        // set of properties that we want. This builds a query which returns all of
        // these at once.
        
        // Select the product attributes to be returned
        var productPropertiesQuery = DataQuery().select(Product.id, Product.name, Product.description, Product.price, Product.currencyCode)
        
        // Include the primary image of the product in the results
        productPropertiesQuery = productPropertiesQuery.expand(Product.primaryImage)
        
        // Include the fields defined by productPropertiesQuery in the results for each shopping cart item
        let itemProductsQuery = DataQuery().expand(ShoppingCartItem.product, withQuery: productPropertiesQuery)
        
        // Query the Shopping Cart with virtual key -1 to get the shopping cart of the current user
        // and expand into the contained items with the above constructed sub-query
        return DataQuery().withKey(ShoppingCart.key(id: -1)).expand(ShoppingCart.shoppingCartItems, withQuery: itemProductsQuery)
    }
    
    /// updates the footer text
    func updateFooter() {
        if let shoppingCart = self.shoppingCart {
            self.worklist.totalValueText = shoppingCart.formattedString(forPrice: shoppingCart.total)
        }
    }
    
    /// Load the current shopping cart data and update the UI
    func loadShoppingCart(completionHandler: @escaping () -> () = {}) {
        let loadingIndicator = FUIModalLoadingIndicator.show(inView: worklist)
        
        Shop.shared.oDataService?.shoppingCart(query: dataQuery) {
            shoppingCarts, error in
            loadingIndicator.dismiss()
            
            guard error == nil else {
                self.logger.error("Error loading shopping carts.", error: error)
                completionHandler()
                return
            }
            
            self.shoppingCart = shoppingCarts?.first
            
            let totalQuantity = self.shoppingCart?.totalQuantity ?? 0
            if totalQuantity == 0 {
                self.worklist.emptyListText = "Your shopping cart is empty."
            }
            
            self.worklist.reloadData()
            self.updateFooter()
            completionHandler()
        }
    }
    
    /// initializes the footer text, loads the shopping cart items, shows the loading indicator and shows "loading" or "empty" message
    ///
    /// - Parameter animated: whether the view will be animated when it appears
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        worklist.totalLabelText = "Subtotal"
        worklist.dataSource = self
        
        loadShoppingCart()
    }
    
}

// MARK: - WorklistViewDataSource
extension ShoppingCartViewController: WorklistViewDataSource {
    
    func numberOfRows(in worklistView: WorklistView) -> Int {
        return shoppingCart?.shoppingCartItems.count ?? 0
    }
    
    func worklistView(_ worklistView: WorklistView, didUpdateItemQuantity: Int, for cell: WorklistCell, atRow indexPath: IndexPath) {
        
        // check if quantity has been changed
        if let shoppingCartItem = shoppingCart?.shoppingCartItems[indexPath.row],
            shoppingCartItem.quantity != didUpdateItemQuantity {
            
            shoppingCartItem.quantity = didUpdateItemQuantity
            
            // updating inventory back to odata
            Shop.shared.oDataService?.updateEntity(shoppingCartItem) { error in
                
                guard error == nil else {
                    self.logger.error("Error updating shopping cart item quantity.",error: error)
                    return
                }
                
                // update shopping cart counter
                NotificationCenter.default.post(name: Shop.shoppingCartDidUpdateNotification, object: nil)
                self.loadShoppingCart()
            }
        }
        
    }
    
    func worklistView(_ worklistView: WorklistView, for cell: WorklistCell, atRow indexPath: IndexPath, imageCompletionHandler: @escaping (UIImage?) -> Void) {
        
        if let shoppingCartItem = shoppingCart?.shoppingCartItems[indexPath.row],
            let product = shoppingCartItem.product {
            
            cell.headlineText = product.description
            cell.statusText = product.formattedPrice
            cell.quantityText = String(shoppingCartItem.quantity)
            
            // reset the deletion parameter after the cell is rendered again
            cell.deletionRequested = false
            
            product.loadPrimaryImage { image, error in
                if let error = error {
                    self.logger.warn("Error while loading image.", error: error)
                }
                imageCompletionHandler(image ?? #imageLiteral(resourceName: "Placeholder"))
            }
        }
        
    }
    
    func worklistView(_ worklistView: WorklistView, deleteRowAt indexPath: IndexPath, completionHandler: @escaping (_ deleteRow: Bool) -> Void) {
        
        if let shoppingCartItem = shoppingCart?.shoppingCartItems[indexPath.row] {
            
            let loadingIndicator = FUIModalLoadingIndicator.show(inView: worklist)
            
            Shop.shared.oDataService?.deleteEntity(shoppingCartItem) { error in
                
                guard error == nil else {
                    self.logger.error("Error deleting shopping cart item.", error:  error)
                    
                    loadingIndicator.dismiss()
                    // nothing has been deleted
                    completionHandler(false)
                    return
                }
                
                // don't ask worklist to delete the row because we'll reload the
                // complete shopping cart
                completionHandler(false)
                
                // refresh the shopping cart
                self.loadShoppingCart {
                    loadingIndicator.dismiss()
                }
                
                // update shopping cart counter
                NotificationCenter.default.post(name: Shop.shoppingCartDidUpdateNotification, object: nil)
            }
        }
    }
    
}
// MARK: - FUIModalCheckoutViewControllerDelegate
extension ShoppingCartViewController: FUIModalCheckoutViewControllerDelegate {
    
    func cancelTapped(onController controller: FUIModalCheckoutViewController) {
        
        self.dismiss(animated: false) {
            self.parent?.dismiss(animated: true)
        }
    }
}
