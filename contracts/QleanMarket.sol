pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

contract Market  {

    uint constant public INITIAL_SUPPLY = 10000000000;

    struct OrdersBook {
        mapping (uint => Order) orders;
        uint size;
    }

    struct Order {
        uint ID;
        uint amount;
        uint price;
        bool isASell;
    }

    struct Trade {
        uint takerOrderID;
        uint makerOrderID;
        uint amount;
        uint price;
    }

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    address public owner;
    uint public municipal_credit_price;

    // All the balances (green credits)
    mapping (address => uint) public balances;
    OrdersBook public sellOrdersBook;
    OrdersBook public buyOrdersBook;

    // Events allow participants to react to specific
    // contract changes you declare
    event Sent(address from, address to, uint amount);

    constructor()
        public
    {
        owner = msg.sender;
        mint(msg.sender, INITIAL_SUPPLY);
    }

    // Sends an amount of newly created coins to an address
    // Can only be called by the contract creator
    function mint(address receiver, uint amount) public restricted {
        require(msg.sender == owner, "Invalid request for new Green Credits");
        require(amount < 1e60, "Value to low");
        balances[receiver] += amount;
    }

    // Sends an amount of existing coins
    // from any caller to an address
    function send(address receiver, uint amount) public restricted {
        require(amount <= balances[msg.sender], "Insufficient balance.");
        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit Sent(msg.sender, receiver, amount);
    }


    function getLiquidity() public view returns (uint) {
        return owner.balance;
    }

    /**
     *  Add a buy order to the order book
     */
    function addBuyOrder (uint amount, uint price) public returns (uint) {

        uint newID = uint(keccak256(abi.encodePacked(block.number)));
        Order memory order = Order (newID, amount, price, false);
        // A new order
        return addBuyOrder(order);        
    }

    function addBuyOrder (Order memory order) public returns (uint){
        // The buy orders should be sorted in ascending order so that the last element of the array has the highest price.
        uint i = 0;
        for (i = buyOrdersBook.size - 1; i >= 0; i--) {
            Order memory buyOrder = buyOrdersBook.orders [i];
            if (buyOrder.price < order.price) {
                break;
            }
        }
        buyOrdersBook.orders[i] = order;
        buyOrdersBook.size++;

        return order.ID;
    }

    /**
     *  Add a buy order to the order book
     */
    function addSellOrder (uint amount, uint price) public returns (uint){
        // Sell orders are sorted descendently so that the element with the highest index in the array has the lowest price
        uint newID = uint(keccak256(abi.encodePacked(block.number)));
        Order memory order = Order (newID, amount, price, true);

        return addSellOrder (order);
    }

    function addSellOrder (Order memory order) public returns (uint) {
        uint i = 0;
        for (i = sellOrdersBook.size - 1; i >= 0; i--) {
            Order memory buyOrder = sellOrdersBook.orders [i];
            if (buyOrder.price > order.price) {
                break;
            }
        }

        sellOrdersBook.orders[i] = order;
        sellOrdersBook.size++;

        return order.ID;
    }

    function removeBuyOrder (uint i) internal {
        delete buyOrdersBook.orders[i];
        buyOrdersBook.size--;
    }

    function removeSellOrder (uint i) internal {
        delete sellOrdersBook.orders[i];
        sellOrdersBook.size--;
    }

    function process (Order memory order) public returns (Trade[] memory){
        if (order.isASell) {
            return processSell(order);
        } else {
            return processBuy(order);
        }
    }
    

    /**
     * Process a limit buy order
     */
    function processBuy (Order memory order) public returns (Trade[] memory) {

        Trade[] memory trades;

        uint n = sellOrdersBook.size;
        // check if we have at least one matching order
        if (n != 0 || sellOrdersBook.orders[n - 1].price <= order.price) {

            for (uint i = n - 1; i >= 0; i--) {
                Order storage sellOrder = sellOrdersBook.orders[i];
                if (sellOrder.price > order.price) {
                    break;
                }
                // fill the entire order
                if (sellOrder.amount >= order.amount) {

                    Trade memory newTrade = Trade (order.ID, sellOrder.ID, order.amount, sellOrder.price);
                    trades[trades.length - 1] = newTrade;

                    sellOrder.amount -= order.amount;
                    if (sellOrder.amount == 0) {
                        removeSellOrder (i);
                    }

                    return trades;
                }
                // fill a partial order and continue
                if (sellOrder.amount < order.amount) {

                    Trade memory newTrade = Trade (order.ID, sellOrder.ID, order.amount, sellOrder.price);
                    trades[trades.length - 1] = newTrade;

                    order.amount -= sellOrder.amount;
                    removeSellOrder (i);
                    continue;
                }
            }
        }

        // finally add the remaining order to the list
        addBuyOrder (order);
        return trades;
    }


    /**
     * Process a limit sell order
     */
    function processSell (Order memory order) internal returns (Trade[] memory) {

        Trade[] memory trades;

        uint n = buyOrdersBook.size;
        // check if we have at least one matching order
        if (n != 0 || buyOrdersBook.orders[n - 1].price <= order.price) {
            // traverse all orders that match
            for (uint i = n - 1; i >= 0; i--) {
                Order storage buyOrder = buyOrdersBook.orders[i];
                if (buyOrder.price > order.price) {
                    break;
                }

                // fill the whole order
                if (buyOrder.amount >= order.amount) {

                    Trade memory newTrade = Trade (order.ID, buyOrder.ID, order.amount, buyOrder.price);
                    trades[trades.length - 1] = newTrade;

                    buyOrder.amount -= order.amount;
                    if (buyOrder.amount == 0) {
                        removeBuyOrder (i);
                    }

                    return trades;
                }

                // fill a partial order and continue
                if (buyOrder.amount < order.amount) {

                    Trade memory newTrade = Trade (order.ID, buyOrder.ID, order.amount, buyOrder.price);
                    trades[trades.length - 1] = newTrade;

                    order.amount -= buyOrder.amount;
                    removeBuyOrder (i);
                    continue;
                }
            }
        }

        // finally add the remaining order to the list
        addBuyOrder (order);
        return trades;
    }

}