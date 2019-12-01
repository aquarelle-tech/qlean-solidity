pragma solidity ^0.5.0;

contract SupplyChain {

  /* set owner */
  address owner;

  /* Add a variable called skuCount to track the most recent sku # */
  uint bolsaCount;

  uint public REWARD_PRICE = 20;
  uint public SURPLUS_PRICE = 5;
  uint public VALIDATOR_CONFIRMATION = 1;

  address payable public liquidityPool;
  // here 1 equals a positive response from the validator and anything else is negative.

  /* Add a line that creates a public mapping that maps the SKU (a number) to a Bolsa.
     Call this mappings bolsas
  */
  mapping(uint => Bolsa) public bolsas;

  /* Add a line that creates an enum called State.
  */
  enum State { Opened, Filled, Deposited, Transported, Processed, Recycled, Disposed }

  /* Create a struct named Bolsa.
  */
  struct Bolsa {
    uint hash;
    // uint: count;
    uint state;
    address payable seller;
    address payable buyer;
  }
  //jjj

  /* Create 4 events with the same name as each possible State (see above)
    Prefix each event with "Log" for clarity
    Each event should accept one argument, the hash */
    event NewUser(address _address);
    event LogOpened(uint hash);
    event LogFilled(uint hash);
    event LogDeposited(uint hash);
    event LogTransported(uint hash);
    event LogProcessed(uint hash);
    event LogRecycled(uint hash);
    event LogDisposed(uint hash);

// function // from ayutamiento to new user 100


  modifier isOwner() {
    require (owner == msg.sender);
    _;
  }

  modifier verifyCaller (address _address) { require (msg.sender == _address); _;}
  // we are not using the modifier in this case because upon calling it, it exceeds our gas allowance and makes our transaction fail

  // // modifier paidEnough(uint _price) { require(msg.value >= _price); _;}
  // modifier checkValue(uint _sku) {
  //   //refund them after pay for item (why it is before, _ checks for logic before func)
  //   _;
  //   uint _price = items[_sku].price;
  //   uint amountToRefund = msg.value - _price;
  //   items[_sku].buyer.transfer(amountToRefund);

  // }


  modifier Opened(uint hash) { bolsas[hash].state == 0; _; }
  modifier Filled(uint hash) { bolsas[hash].state == 1; _; }
  modifier Deposited(uint hash) { bolsas[hash].state == 2; _; }
  modifier Transported(uint hash) { bolsas[hash].state == 3; _; }
  modifier Processed(uint hash) { bolsas[hash].state == 4; _; }
  modifier Recycled(uint hash) { bolsas[hash].state == 5; _; }
  modifier Disposed(uint hash) { bolsas[hash].state == 6; _; }

  constructor() public {
    /* Here, set the owner as the person who instantiated the contract
       and set your bolsaCount to 0. */
    owner = msg.sender;
    bolsaCount = 0;
  }

  function OpenBolsa(uint _hash) public returns(bool){

    bolsas[bolsaCount] = Bolsa({hash: _hash, state: 0, seller: msg.sender, buyer: address(0)});
    bolsaCount = bolsaCount + 1;
    emit LogOpened(bolsaCount);
    return true;
  }

  /* Add a keyword so the function can be paid. This function should transfer money
    to the seller, set the buyer as the person who called this transaction, and set the state
    to Sold. Be careful, this function should use 3 modifiers to check if the item is for sale,
    if the buyer paid enough, and check the value after the function is called to make sure the buyer is
    refunded any excess ether sent. Remember to call the event associated with this function!*/

  // function buyItem(uint sku)
  //   public payable
  //   forSale(sku)
  //   paidEnough(items[sku].price)
  //   checkValue(sku)
  // {
  //   emit LogSold(sku);
  //   items[sku].buyer = msg.sender;
  //   items[sku].state = 1;
  //   items[sku].seller.transfer(items[sku].price);

  // }


  /* Add 2 modifiers to check if the item is opened already, and that the person calling this function
  is the seller. Change the state of the item to filled.*/
  function FillBolsa(uint hash)
    public
    Opened(hash)
    // verifyCaller(bolsas[hash].seller)
  {
    bolsas[hash].state = 1;
    emit LogFilled(hash);
  }

  /* Add 2 modifiers to check if the item is filled already, and that the person calling this function
  is the buyer. Change the state of the item to received. Remember to call the event associated with this function!*/
  function DepositBolsa(uint hash)
    public
    Filled(hash)
    // verifyCaller(bolsas[hash].buyer)
  {
    bolsas[hash].state = 2;
    emit LogDeposited(hash);
  }

  function TransportBolsa(uint hash)
    public
    Deposited(hash)
    // verifyCaller(bolsas[hash].buyer)
  {
    bolsas[hash].state = 3;
    emit LogTransported(hash);
  }

  function ProcessBolsa(uint hash)
    public
    Transported(hash)
    // verifyCaller(bolsas[hash].buyer)
  {
    bolsas[hash].state = 4;
    emit LogProcessed(hash);
  }

  function ValidateBolsa(uint hash)
    public
    Processed(hash)
    // verifyCaller(bolsas[hash].buyer)
  {
    // to think about later, but as of now, the validator looks at the bolsa sent and aknowledge if
    // it is recyclable or not, if yes, he sends a "yes" string and the state of the bolsa is recycled
    // Therefore, the user receives credits, otherwise the user pays"
    if (VALIDATOR_CONFIRMATION == 1) {
        bolsas[hash].state = 5;
        emit LogRecycled(hash);
      } else {
        bolsas[hash].state = 6;
        emit LogDisposed(hash);
      }

  }

  function ReceiveCredits(uint hash)
    public
    payable
    Recycled(hash)
    // verifyCaller(bolsas[hash].buyer)
    {
      bolsas[hash].seller.transfer(REWARD_PRICE);
      // need to reduce Ajutament wallet by REWARD_PRICE as well
  }

  function PayCredits(uint hash)
    public
    payable
    Disposed(hash)
    // verifyCaller(bolsas[hash].buyer)
    {
      liquidityPool.transfer(SURPLUS_PRICE);
      //need to reduce user wallet by SURPLUS_PRICE as well
  }

  /* We have these functions completed so we can run tests, just ignore it :) */


}

