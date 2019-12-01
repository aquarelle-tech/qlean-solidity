pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

contract Market  {

    uint constant public INITIAL_SUPPLY = 10000000000;
    uint public ACHIEVE_GOAL_REWARD = 1000;
    uint public OFFICIAL_WASTE_GENERATION_QUOTA = 40;

    enum CleanInitiativeState {Started, Won, Postponed}

    // Definition of 
    struct CleanInitiative {
        string title;
        // The goal is measured in CGR
        uint quotasReductionGoal;
        // When the goal was created
        uint timestamp;
        // the current state of the initiative
        CleanInitiativeState state;
    }

    // The info for a trader of quotas
    struct WasteTrader {
        // The list of the current initiatives
        mapping (uint => CleanInitiative) initiatives;
        uint initiativesCount;
        uint currentGoal;
        // Waste Generation Quotas
        uint wasteGenerationQuotas;
    }

    // Details for each trader
    mapping (address => WasteTrader) wasteTraders;

    mapping (uint => Trade) allTrades;
    uint tradesCount;

    struct OrdersBook {
        mapping (uint => Order) orders;
        uint size;
    }

    struct Order {
        address owner;
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
    
    /***** EVENTS ******/
    event NewCleanInitiative (CleanInitiative newItem);
    event WasteQuotaReduced (uint amount);
    event WasteQuotaAssigned (uint amount);
    event InitializedTrader (address trader);

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

    // Start a new trader with default assignations
    function initializeTrader () public {
        WasteTrader memory trader = WasteTrader(0, 0, OFFICIAL_WASTE_GENERATION_QUOTA);
        // Store it
        wasteTraders[owner] = trader;
        emit InitializedTrader(owner);
    }

    /************************* Quotes management ***********************************************************/

    /**
     * Update the quantity of 
     */
    function reduceWasteQuotes (uint amount) public returns (uint) {
        WasteTrader storage trader = wasteTraders[owner];

        require(amount > 0, 'The amount need to be a valid quantity');
        require (trader.wasteGenerationQuotas > 0, 'Invalid operation. The user already have cleared all their quotes');

        trader.wasteGenerationQuotas -= amount;
        emit WasteQuotaReduced (amount);

        return trader.wasteGenerationQuotas;
    }

    function setWasteQuotes (uint amount) public returns (uint) {

        require(amount > 0, 'The amount need to be a valid quantity');

        WasteTrader storage trader = wasteTraders[owner];
        trader.wasteGenerationQuotas = amount;
        emit WasteQuotaAssigned (amount);

        return trader.wasteGenerationQuotas;
    }


    /************************* end of Quotes management ***********************************************************/


    /*************************************   Clean Initiatives ****************************************** */

    /**
     */
    function newCleanInitiative (string memory title, uint goal, uint creation) public returns (CleanInitiative memory) {

        // Create a  new initiative
        CleanInitiative memory newItem = CleanInitiative (title, goal, creation, CleanInitiativeState.Started);
        WasteTrader storage traderInfo = wasteTraders[owner];

        // Add the new item to the trader´s list of initiatives
        if (traderInfo.initiativesCount == 0) {
            traderInfo.initiatives[0] = newItem;
            traderInfo.initiativesCount++;
        } else {
            traderInfo.initiatives[traderInfo.initiativesCount] = newItem;
            traderInfo.initiativesCount++;
        }
        traderInfo.currentGoal += goal; // All the goals are added together as a single goal for the current evaluation period
        emit NewCleanInitiative (newItem);
        return newItem;
    }

    /**
     * Returns the list of initiatives currently asociated to the current user
     */
    function getCleanInitiatives ()  public view returns (CleanInitiative[] memory) {
        WasteTrader storage trader = wasteTraders[owner];

        CleanInitiative[] memory result = new CleanInitiative[](trader.initiativesCount);
        // Create a list in memory to return it back
        for (uint i = 0; i < trader.initiativesCount; i++) {
            result [i] = trader.initiatives[i];
        }

        return result;
    }

    function closeCleanInitiative (uint initiativeId) internal {
        WasteTrader storage trader = wasteTraders[owner];

        require(initiativeId < trader.initiativesCount, 'Invalid initiative id');
        trader.initiatives [initiativeId].state = CleanInitiativeState.Won;
    }

    function postponeCleanInitiative (uint initiativeId) internal {
        WasteTrader storage trader = wasteTraders[owner];

        require(initiativeId < trader.initiativesCount, 'Invalid initiative id');
        CleanInitiative storage initiative = trader.initiatives [initiativeId];
        initiative.state = CleanInitiativeState.Postponed;
    }

    // Close the current evaluation period
    function closeEvaluationPeriod () public {
        WasteTrader storage trader = wasteTraders[owner];
        // Process the initiatives
        evaluatWasteQuotesGoal (trader);
        // Re-assign the quota
        trader.wasteGenerationQuotas = OFFICIAL_WASTE_GENERATION_QUOTA;
    }

    // Process al the initiatives to close an evaluation period
    function evaluatWasteQuotesGoal (WasteTrader storage trader) internal {

        // Traverse all the traders to count their initiatives and close all the started
        CleanInitiativeState finalState;
        if (trader.wasteGenerationQuotas >= trader.currentGoal) {
            finalState = CleanInitiativeState.Won; // The goal has been achieved!
        } else {
            finalState = CleanInitiativeState.Postponed; // No, the initiatives need to be postponed
        }
        // Now change all the open initiatives to the value
        for (uint i = 0; i < trader.initiativesCount; i++ ) {
            CleanInitiative storage initiative = trader.initiatives[i];
            if (initiative.state == CleanInitiativeState.Started) {
                initiative.state = finalState;
            }
        }
        // If the goal was achieved, then reset the counters, transfer some money
        if (finalState == CleanInitiativeState.Won) {
            // Reset the current goal to start again!
            trader.currentGoal = 0;
            mint (owner, ACHIEVE_GOAL_REWARD); // Send reward
        }
    }

    /** ******************* end of Clean initiatives */


    function getOrderBook () public view returns (Order[] memory) {
        Order[] memory result = new Order[] (sellOrdersBook.size + buyOrdersBook.size);

        uint i = 0;
        uint limit = sellOrdersBook.size;
        for (i = 0; i < limit; i++) {
            result[i] = sellOrdersBook.orders[i];
        }

        limit += buyOrdersBook.size;
        for (; i<limit; i++) {
            result[i] = sellOrdersBook.orders[i];
        }

        return result;
    }
    /**
     *  Add a buy order to the order book
     */
    function addBuyOrder (uint amount, uint price) public returns (uint) {

        uint newID = uint(keccak256(abi.encodePacked(block.number)));
        Order memory order = Order (msg.sender, newID, amount, price, false);
        // A new order
        return addBuyOrder(order);
    }

    function addBuyOrder (Order memory order) internal returns (uint){
        // The buy orders should be sorted in ascending order so that the last element of the array has the highest price.
        uint i = 0;
        for (i = buyOrdersBook.size - 1; i >= 0; i--) {
            Order storage buyOrder = buyOrdersBook.orders [i];
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
        Order memory order = Order (msg.sender, newID, amount, price, true);

        return addSellOrder (order);
    }

    function addSellOrder (Order memory order) internal returns (uint) {
        uint i = 0;
        for (i = sellOrdersBook.size - 1; i >= 0; i--) {
            Order storage buyOrder = sellOrdersBook.orders [i];
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
        Trade[] memory newTrades;

        if (order.isASell) {
            newTrades = processSell(order);
        } else {
            newTrades = processBuy(order);
        }
        // Store the list of newly created trades
        uint newTradesIdx = 0;
        for (uint i = tradesCount; i < tradesCount + newTrades.length; i++) {
            allTrades[i] = newTrades[newTradesIdx];
        }
        // Update the count of trades!
        tradesCount += newTrades.length;
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

    // Get a full inventory of all my assets and balance
    function myBalance () public view returns (uint, uint, uint, uint) {
        uint balance = address(this).balance;
        WasteTrader storage trader = wasteTraders[owner];

        return (balance, trader.initiativesCount, trader.currentGoal, trader.wasteGenerationQuotas);
    }

    /**
     * Process a limit sell order
     */
    function processSell (Order memory order) internal returns (Trade[] memory) {

        Trade[] memory trades;
        // WasteTrader storage trader = wasteTraders[owner];

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

                    (buyOrder.owner, order.amount);
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