module onlinebiz::onlinebiz {
    use sui::balance::{Balance, Self};
    use sui::coin::{Coin, Self};
    use std::string::{String};
    use sui::event;
    use sui::sui::SUI;

    // Errors
    enum MarketplaceError {
        NotOwner,
        ItemNotAvailable,
        InsufficientAmount,
    }

    // Define data types
    public struct Marketplace has key, store {
        id: UID,
        name: String,
        items: vector<Items>,
        productscount: u64,
        balance: Balance<SUI>
    }

    public struct Items has key, store {
        id: UID,
        itemid: u64,
        name: String,
        description: String,
        price: u64,
        sold: bool,
        owner: address
    }

    public struct AdminCap has key {
        id: UID,
        marketid: ID
    }

    // Events
    public struct MarketCreated has drop, copy {
        nameofmarket: String
    }

    public struct AmountWithdrawn has drop, copy {
        recipient: address,
        amount: u64
    }

    // Functions

    // Function to create market
    public entry fun create_market(name: String, ctx: &mut TxContext) -> UID {
        let id = object::new(ctx);
        let productscount: u64 = 0;
        let balance = balance::zero<SUI>();
        
        let newmarket = Marketplace { 
            id, 
            productscount,
            name,
            items: vector::empty(),
            balance
        };

        transfer::transfer(AdminCap {
            id: object::new(ctx),
            marketid: object::uid_to_inner(&id),
        }, tx_context::sender(ctx));

        transfer::share_object(newmarket);
        event::emit(MarketCreated {
            nameofmarket: name
        });

        id // Return the market ID
    }

    // Function to add products to the marketplace
    public entry fun add_item(
        owner: &AdminCap,
        marketplace: &mut Marketplace,
        name: String,
        price: u64,
        description: String,
        ctx: &mut TxContext
    ) -> Result<(), MarketplaceError> {
        // Verify that only the owner of the market can add items
        if &owner.marketid != object::uid_to_inner(&marketplace.id) {
            return Err(MarketplaceError::NotOwner);
        }

        let itemid = marketplace.items.length();
        let newitem = Items {
            id: object::new(ctx),
            itemid,
            name,
            description,
            price,
            sold: false,
            owner: tx_context::sender(ctx),
        };

        marketplace.items.push_back(newitem);
        marketplace.productscount += 1;

        Ok(())
    }

    // Get details of an item
    public entry fun get_item_details(market: &mut Marketplace, itemid: u64) -> Result<(u64, String, String, u64, bool), MarketplaceError> {
        // Check if item is available
        if itemid >= market.items.length() {
            return Err(MarketplaceError::ItemNotAvailable);
        }

        let item = &market.items[itemid];
        Ok((item.itemid, item.name, item.description, item.price, item.sold))
    }

    // Update price of item
    public entry fun update_item_price(marketplace: &mut Marketplace, owner: &AdminCap, item_id: u64, newprice: u64) -> Result<(), MarketplaceError> {
        // Make sure it's the admin performing the operation
        if &owner.marketid != object::uid_to_inner(&marketplace.id) {
            return Err(MarketplaceError::NotOwner);
        }

        // Make sure the item actually exists
        if item_id >= marketplace.items.length() {
            return Err(MarketplaceError::ItemNotAvailable);
        }

        let item = &mut marketplace.items[item_id];
        item.price = newprice;

        Ok(())
    }

    // Update description of item
    public entry fun update_item_description(marketplace: &mut Marketplace, owner: &AdminCap, item_id: u64, description: String) -> Result<(), MarketplaceError> {
        // Make sure item is available
        if item_id >= marketplace.items.length() {
            return Err(MarketplaceError::ItemNotAvailable);
        }

        // Make sure it's the admin performing the operation
        if &owner.marketid != object::uid_to_inner(&marketplace.id) {
            return Err(MarketplaceError::NotOwner);
        }

        let item = &mut marketplace.items[item_id];
        item.description = description;

        Ok(())
    }

    // Unlist item from marketplace by marking it as sold
    public entry fun delist_item(
        marketplace: &mut Marketplace,
        owner: &AdminCap,
        item_id: u64
    ) -> Result<(), MarketplaceError> {
        // Make sure it's the admin performing the operation
        if &owner.marketid != object::uid_to_inner(&marketplace.id) {
            return Err(MarketplaceError::NotOwner);
        }

        // Check if item is available
        if item_id >= marketplace.items.length() {
            return Err(MarketplaceError::ItemNotAvailable);
        }

        let item = &mut marketplace.items[item_id];
        item.sold = true;

        Ok(())
    }

    // Buy item
    public entry fun buy_item(
        marketplace: &mut Marketplace,
        item_id: u64,
        amount: Coin<SUI>
    ) -> Result<(), MarketplaceError> {
        // Check if item is available
        if item_id >= marketplace.items.length() {
            return Err(MarketplaceError::ItemNotAvailable);
        }

        // Check if item is already sold
        if marketplace.items[item_id].sold {
            return Err(MarketplaceError::ItemNotAvailable);
        }

        // Get price
        let item = &marketplace.items[item_id];
        
        // Ensure the amount is greater than or equal to the price of the item
        if coin::value(&amount) != item.price {
            return Err(MarketplaceError::InsufficientAmount);
        }

        let coin_balance = coin::into_balance(amount);
        // Add the amount to the marketplace balance
        balance::join(&mut marketplace.balance, coin_balance);

        Ok(())
    }

    // Owner withdraw profits
    public entry fun withdraw_funds(user_cap: &AdminCap, marketplace: &mut Marketplace, amount: u64, ctx: &mut TxContext) -> Result<(), MarketplaceError> {
        // Verify it's the owner of the marketplace
        if object::uid_as_inner(&marketplace.id) != &user_cap.marketid {
            return Err(MarketplaceError::NotOwner);
        }

        // Verify the requested amount is less than or equal to the balance
        if amount > balance::value(&marketplace.balance) {
            return Err(MarketplaceError::InsufficientAmount);
        }

        let amount_available: Coin<SUI> = coin::take(&mut marketplace.balance, amount, ctx);
        transfer::public_transfer(amount_available, tx_context::sender(ctx));
        event::emit(AmountWithdrawn {
            recipient: tx_context::sender(ctx),
            amount
        });

        Ok(())
    }
}
