
module onlinebiz::onlinebiz {
    use sui::balance::{Balance, Self};
    use sui::coin::{Coin, Self};
    use std::string::{String};
    use sui::event;
    use sui::sui::SUI;


    //errors
    const ENotOwner:u64=0;
    const  EitemNotAvailable:u64=2;
    const ErrorInsufficientamount:u64=3;

    //define data types
    public struct Marketplace  has key,store{
      
      id:UID,
      name:String,
      items:vector<Items>,
      balance:Balance<SUI>
   
   }

 public struct Items has key,store{
    id: UID,
    itemid:u64,
    name:String,
    description:String,
    price:u64,
    sold:bool,
    owner:address
 }

 public struct AdminCap has key{
    id:UID,
    marketid:ID
 }

 //events

 public struct MarketCreated has drop,copy{
    nameofmarket:String
 }

public struct AmountWithdrawn has drop,copy{
     recipient:address,
        amount:u64
}


 //functions

 // Function to create market
public entry fun createmarket(name: String, ctx: &mut TxContext): String {
    let id = object::new(ctx);
    let balance = balance::zero<SUI>();

    let newmarket = Marketplace { 
        id, 
        name,
        items: vector::empty(),
        balance,
        owner: tx_context::sender(ctx), // Store the owner's address
    };

    transfer::transfer(AdminCap {
        id: object::new(ctx),
        marketid: object::uid_to_inner(&id),
    }, tx_context::sender(ctx));

    transfer::share_object(newmarket);
    event::emit(MarketCreated {
        nameofmarket: name,
    });

    name
}

 // Function to add products to the marketplace
public entry fun additem(
    marketplace: &mut Marketplace,
    name: String,
    price: u64,
    description: String,
    ctx: &mut TxContext
) {
    let itemid = object::new(ctx); // Unique ID for the item
    let newitems = Items {
        id: itemid,
        itemid: object::uid_to_inner(&itemid), // Assign a unique ID
        name,
        description,
        price,
        sold: false,
        owner: tx_context::sender(ctx),
    };

    marketplace.items.push_back(newitems);
}

 // Get item details
public entry fun get_item(marketplace: &Marketplace, item_id: u64) -> (u64, String, String) {
    assert!(item_id < marketplace.items.length(), EitemNotAvailable); // Change to '<' to avoid out-of-bounds
    let item = &marketplace.items[item_id];

    // Check if item is sold
    assert!(!item.sold, EitemNotAvailable);
    // Return a copy of the item
    (item.price, item.name, item.description)
}
    

   //update details of an item
   // Update price of item
public entry fun update_item_price(marketplace: &mut Marketplace, item_id: u64, newprice: u64, ctx: &mut TxContext) {
    assert!(item_id < marketplace.items.length(), EitemNotAvailable); // Change to '<' to avoid out-of-bounds
     
    let item = &mut marketplace.items[item_id];
    assert!(item.owner == tx_context::sender(ctx), ENotOwner); // Ensure the caller is the owner
    item.price = newprice;
}

  // Update description of item
public entry fun update_item_description(marketplace: &mut Marketplace, item_id: u64, description: String, ctx: &mut TxContext) {
    assert!(item_id < marketplace.items.length(), EitemNotAvailable); // Change to '<' to avoid out-of-bounds
     
    let item = &mut marketplace.items[item_id];
    assert!(item.owner == tx_context::sender(ctx), ENotOwner); // Ensure the caller is the owner
    item.description = description;
}

// Unlist item from marketplace by marking it as sold
public entry fun delist_item(
    marketplace: &mut Marketplace,
    item_id: u64,
    ctx: &mut TxContext
) {
    assert!(item_id < marketplace.items.length(), EitemNotAvailable); // Change to '<' to avoid out-of-bounds
     
    let item = &mut marketplace.items[item_id];
    assert!(item.owner == tx_context::sender(ctx), ENotOwner); // Ensure the caller is the owner
    item.sold = true;
}
    
//buy item

// Buy item
public entry fun buy_item(
    marketplace: &mut Marketplace,
    item_id: u64,
    amount: Coin<SUI>,
    ctx: &mut TxContext
) {
    // Check if item is available
    assert!(item_id < marketplace.items.length(), EitemNotAvailable); // Change to '<' to avoid out-of-bounds

    // Check if item is already sold
    assert!(!marketplace.items[item_id].sold, EitemNotAvailable);

    // Get price
    let item = &marketplace.items[item_id];

    // Ensure the amount is greater than or equal to the price of the item
    assert!(coin::value(&amount) >= item.price, ErrorInsufficientamount);

    let coin_balance = coin::into_balance(amount);
    balance::join(&mut marketplace.balance, coin_balance);

    // Refund any excess amount if applicable
    if coin::value(&amount) > item.price {
        let excess_amount = coin::take(&amount, coin::value(&amount) - item.price, ctx);
        transfer::public_transfer(excess_amount, tx_context::sender(ctx));
    }
}

// Owner withdraw profits
public entry fun withdraw_funds(user_cap: &AdminCap, marketplace: &mut Marketplace, ctx: &mut TxContext) {
    // Verify it's the owner of the marketplace
    assert!(object::uid_as_inner(&marketplace.id) == &user_cap.marketid, ENotOwner);
    
    let amount: u64 = balance::value(&marketplace.balance);
    assert!(amount > 0, EInsufficientamount); // Check if there's a balance to withdraw

    let amountavailable: Coin<SUI> = coin::take(&mut marketplace.balance, amount, ctx);
    transfer::public_transfer(amountavailable, tx_context::sender(ctx));
    
    event::emit(AmountWithdrawn {
        recipient: tx_context::sender(ctx),
        amount: amount,
    });
}

}

