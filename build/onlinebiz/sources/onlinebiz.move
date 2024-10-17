
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

 //function to create market
 public entry fun createmarket(name:String,ctx:&mut TxContext): String{

    let id=object::new(ctx);
   
    let balance = balance::zero<SUI>();
    let marketid=object::uid_to_inner(&id);
    let newmarket=Marketplace{ 
            id, 
            name,
            items:vector::empty(),
            balance
    };

     transfer::transfer(AdminCap {
        id: object::new(ctx),
        marketid,
    }, tx_context::sender(ctx));


      transfer::share_object(newmarket);
    event::emit(MarketCreated{
       nameofmarket:name
    });

   name

 }

 //function to  add products to the marketplace
public entry fun additem(
        marketplace: &mut Marketplace,
        name:String,
        price:u64,
        description:String,
        ctx: &mut TxContext
    ) {
        let itemid=marketplace.items.length()+1;
        
        let newitems = Items {
            id:object::new(ctx),
            itemid,
            name,
            description,
            price,
            sold:false,
            owner: tx_context::sender(ctx),
        };

        marketplace.items.push_back(newitems);
       
    }
 public entry fun get_item(marketplace: &Marketplace,item_id: u64):(u64, String, String){
    assert!(item_id <= marketplace.items.length(),  EitemNotAvailable);
    let item = &marketplace.items[item_id];

    //check if items is sold
    assert!(item.sold==false, EitemNotAvailable);
    // Return a copy of the item
    (item.price,item.name,item.description)

  }

   //update details of an item

   //update price of item
   public entry fun update_item_price(marketplace:&mut Marketplace,item_id:u64,newprice:u64){
      assert!(item_id <= marketplace.items.length(),  EitemNotAvailable);
     
     let item=&mut marketplace.items[item_id];
     item.price=newprice;

   }

   //update decription of  item
  public entry fun update_item_description(marketplace:&mut Marketplace,item_id:u64,description:String){
      assert!(item_id <= marketplace.items.length(),  EitemNotAvailable);
     
     let item=&mut marketplace.items[item_id];
     item.description=description;

   }

//unlist item from marketplace by marking it as sold

public entry fun delist_item(
        marketplace: &mut Marketplace,
        item_id: u64
    ){
    
       assert!(item_id <= marketplace.items.length(),  EitemNotAvailable);
     
     let item=&mut marketplace.items[item_id];
     item.sold=true;


    }
    
//buy item

public entry fun buy_item(
        marketplace: &mut Marketplace,
        item_id: u64,
        amount: Coin<SUI>,
    ){

//check if item is avaialble

assert!(item_id <= marketplace.items.length(),  EitemNotAvailable);

//check if item is already sold
assert!(marketplace.items[item_id].sold==false,EitemNotAvailable);
      //get price
      let item=&marketplace.items[item_id];
    //ensure amount is greater or equals to price of item
      assert!(coin::value(&amount)== item.price, ErrorInsufficientamount);
 
   let coin_balance = coin::into_balance(amount);
     // add the amount to the marketplace balance
    //  let paid = split(amount, item.price, ctx);  

    //   put(&mut marketplace.balance, paid); 
    balance::join(&mut marketplace.balance, coin_balance);
    }

// //owner withdraw profits
public entry fun withdraw_funds(user_cap:&AdminCap, marketplace: &mut Marketplace, ctx: &mut TxContext) {

    // verify its the owner of article
    assert!(object::uid_as_inner(&marketplace.id)==&user_cap.marketid, ENotOwner);
      
   

     let amount: u64 = balance::value(&marketplace.balance);

    let amountavailable: Coin<SUI> = coin::take(&mut marketplace.balance, amount, ctx);

    transfer::public_transfer(amountavailable, tx_context::sender(ctx));
    event::emit( AmountWithdrawn{
        recipient:tx_context::sender(ctx),
        amount:amount
    });
}

}

