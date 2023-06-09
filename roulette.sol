// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Roulette is 
  VRFConsumerBaseV2 {

  // Chainlink coordinator.
  VRFCoordinatorV2Interface COORDINATOR;

  // Your subscription ID.
  uint64 s_subscriptionId;

  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
  // This one is hardcoded for GOERLI TESTNET.
  bytes32 keyHash = 
      0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

  // Gas required to execute callback of API (fullfillRandomWords()-function).
  uint32 _callbackGasLimit = 150000;

  // The casino's address.
  address payable public house;

  // Minimum and maximum bets amount in WEI.
  uint256 public maxBet;
  uint256 public minBet;

  struct Bet {
    address payable player;   
    uint256  betAmount; // Amount of wei in the bet.
    BetTypeEnum betType; // Indicate whether single, third, red, black, odd, even bet was placed.
    uint8 betNumber; // Indicate the number of the bet, or color/parity of the bet.
    bool winner;
  }

  /*
  This represents the latest game.
  */
  uint8 public currentWinningNumber;
  Bet public currentBet;
  uint256 public currentRequestId;

  // Indicates whether a bet has been placed, and the contract is in the process of determining a winner.
  bool public gameInProgress;

  // A history of games. The key is the request ID.
  mapping(uint256 => Bet) public book;

  // The bet types; To the compiler these values are equal to uints from 0-5.
  enum BetTypeEnum {SINGLE, THIRD, RED, BLACK, ODD, EVEN}
  event LogResult(address player, string message, uint256 amount);
  event LogMinMax(uint256 max, uint256 min);
  event LogPayout(string message);
  event LogCurrentBet(Bet bet);
  event LogGameEnded(string message);
  /**
  * HARDCODED FOR GOERLI-Testnet
  * COORDINATOR: 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
  * @param subscriptionId - Set this to be the ID of your Chainlink subscription. 
  * Also, do not forget to add this contract as a consumer to that same subscription once deployed.
  */
  constructor(uint64 subscriptionId)
      VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D)
  {
    COORDINATOR = 
        VRFCoordinatorV2Interface(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D);
    s_subscriptionId = subscriptionId;
    house = payable(msg.sender);
  }

  bool private lockedPlacingBet;
  
  /*
  * Modifier to disallow re-entrancy.
  */
  modifier nonReentrant() {
    require(!lockedPlacingBet, "No re-entrancy");
    lockedPlacingBet = true;
    _;
    lockedPlacingBet = false;
  }

  /*
  * Helper-function setting the current minumum and maximum bet amounts allowed (in Wei).
  */
  function setMinMaxBets() private {
    
    uint256 _balance = address(this).balance;

    // A minimum amount should always have to be bet in order to justify the CHAINLINK API fees and to pay for the callBackGasLimit.
    uint256 _wei_threshold = 30000;
    minBet = _callbackGasLimit + _wei_threshold;

    // A maximum amount should not be exceeded when betting, 
    // so that the contract always remains able to pay out the full potential winnings. 
    require((_balance / 35) > minBet, "The funds in this contract are too low and need to be higher.");
    maxBet = (_balance / 35) - minBet;
    emit LogMinMax(maxBet, minBet);

    assert(maxBet >= minBet);
  }


  /*
  * Place a bet and start a game.
  * There are a few different types of bets available. Bet on a single value (0-36), on one of the three thirds of the field,
  * on a colour (red or black), or on odd or even. See below how you specify your bet.
  *
  *
  * @param _bet - The placed number of the bet.
  * This value is used for single and third bets. For a single value bet, choose a value between 0 and 36. 
  * For a bet on a third of the field specify which third you are betting on. Choose a value from 1 to 3.
  * For red/black/odd/even bets, _bet must always be set to 1.
  * @param _type - The type of bet placed.
  * This must be one of the following values: 'single' (0), 'third' (1), 'red' (2), 'black' (3), 'odd'(4), or 'even' (5).
  *
  *
  * Be aware that here, an external call to the CHAINLINK API is made to receive a verifiably random value. 
  * Therefor a delay may occur between placing a bet and receiving the result.
  * Check the status of the API request on https://vrf.chain.link/goerli/{subscriptionId}.
  */
  function placeBet(uint8 _bet, BetTypeEnum _type) nonReentrant() external payable {
    require(!gameInProgress, "A game is already in progress, please have a moment of patience.");
    require(msg.value >= minBet, "The amount of money in the bet must exceed the minimum bet.");
    require(msg.value <= maxBet, "The amount of money in the bet must be below the maximum bet.");

    if (_type == BetTypeEnum.SINGLE) {
      require(_bet >= 0 && _bet <= 36, "Invalid bet. Single bet must be between 0 and 36 inclusive.");
    } else if (_type == BetTypeEnum.THIRD) {
      require(_bet >= 1 && _bet <= 3, "Invalid bet. Third bet must be between 1 and 3 inclusive.");
    } else if (_type == BetTypeEnum.RED || _type == BetTypeEnum.BLACK || _type == BetTypeEnum.ODD || _type == BetTypeEnum.EVEN) {
      require(_bet == 1, "Invalid bet. Red/black/odd/even bets must be placed with a bet of 1.");
    } else {
      require(false, "Invalid bet type. Please choose 'single', 'third', 'red', 'black', 'odd', or 'even'.");
    }

    gameInProgress = true;
    currentBet = Bet(payable(msg.sender), msg.value, _type, _bet, false);

    emit LogCurrentBet(currentBet);
    spinWheel();
  }

  /*
  * Helper function to execute the external CHAINLINK API Call.
  */
  function spinWheel() private {

    // Set to default value of 3.
    uint16 _requestConfirmations = 3;

    // We require only one random word for our purposes.
    uint32 _numWords = 1;

    // Will revert, if subscription is not set and funded.
    currentRequestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      _requestConfirmations,
      _callbackGasLimit,
      _numWords
    );

    book[currentRequestId] = currentBet;
  }

  /*
  * Chainlink callback function. Chainlink will call this function with the verifiably random number.
  * Upon receiving the random number, the game is being ended and the bet is being paid out.
  */
  function fulfillRandomWords(
    uint256 _requestId,
    uint256[] memory _randomWords
 ) internal override {
    require(currentRequestId == _requestId, "The request IDs do not match");

    currentWinningNumber = uint8(_randomWords[0] % 37);

    // End the game.
    emit LogPayout("A payout has been called.");
    payoutWinner();
  }

  /*
  * Helper function to emit log of wins and losses.
  *
  * @param player - The player who finished the current game.
  * @param hasWon - Indicate whether this player has made a winning bet.
  */
  function logWinningNumber(address player, bool hasWon, uint256 amount) private {

      if (hasWon) {
        emit LogResult(player, "Player has won.", amount);
        book[currentRequestId].winner = true;
      } else {
        emit LogResult(player, "Player has lost.",amount);
      }
  }

  /*
  * Determine the winner and pay him his winning amount.
  */
  function payoutWinner() private {
    address payable player = currentBet.player;   
    uint256  betAmount = currentBet.betAmount;
    BetTypeEnum betType = currentBet.betType;
    uint8 betNumber = currentBet.betNumber;

    // Determine whether or not the current bet was succesful.
    if (betType == BetTypeEnum.SINGLE) {
      if (currentWinningNumber == betNumber) {
        player.transfer(betAmount * 35);
        logWinningNumber(player, true, betAmount * 35);
      } else{
       logWinningNumber(player, false, 0);
      }
    } else if (betType == BetTypeEnum.THIRD) {
      if (currentWinningNumber >= (betNumber - 1) * 12 && currentWinningNumber <= betNumber * 12) {
        player.transfer(betAmount * 3);
        logWinningNumber(player, true, betAmount * 3);
      } else{
        logWinningNumber(player, false, 0);
      }
    } else if (betType == BetTypeEnum.RED) {
      if (isRed(currentWinningNumber)) {
        player.transfer(betAmount * 2);
        logWinningNumber(player, true, betAmount * 2);
      } else {
        logWinningNumber(player, false, 0);
      }
    } else if (betType == BetTypeEnum.BLACK) {
      if (!isRed(currentWinningNumber)) {
        player.transfer(betAmount * 2);
        logWinningNumber(player, true, betAmount * 2);
      } else {
        logWinningNumber(player, false, 0);
      }
    } else if (betType == BetTypeEnum.ODD) {
      if (isOdd(currentWinningNumber)) {
        player.transfer(betAmount * 2);
        logWinningNumber(player, true, betAmount * 2);
      } else {
        logWinningNumber(player, false, 0);
      }
    } else if (betType == BetTypeEnum.EVEN) {
      if (!isOdd(currentWinningNumber)) {
        player.transfer(betAmount * 2);
        logWinningNumber(player, true, betAmount * 2);
      } else {
        logWinningNumber(player, false, 0);
      }
    } else {
      // If the current bet was unsuccesful, keep the winnings in the contract!
    }

    // Reset the global game variables
    setMinMaxBets();
    gameInProgress = false;
    emit LogGameEnded("The game has ended");
  }

  /*
  * @param _number - The number to be evaluated for being odd or even.
  * @return - Returns TRUE when the given number is odd, and FALSE otherwise.
  */
  function isOdd(uint8 _number) private pure returns (bool) {
    return (_number & 1) == 1;
  }

  /*
  * Determines whether a number on the roulette table would be red or black.
  * In the number ranges from 1 to 10 and 19 to 28, odd numbers are red and even numbers are black.
  * In the number ranges from 11 to 18 and 29 to 36, odd numbers are black and even numbers are red. 
  * Remember, there is a green pocket numbered 0 (zero).
  *
  * @param _number - The number to be evaluated for being red or black.
  * @return - Returns TRUE when the given number is red, and FALSE otherwise.
  */
  function isRed(uint8 _number) private pure returns (bool) {
    return (((_number >= 1 && _number <= 10) || (_number >= 19 && _number <= 28)) && isOdd(_number))
    || (((_number >= 11 && _number <= 18) || (_number >= 29 && _number <= 36)) && !isOdd(_number));
  }

  /*
  * Withdraw ETH from contract as the contract's owner (house).
  */
  function withdrawWei(uint wei_amount) nonReentrant() public {
    require(msg.sender == house, "Only the contract owner can withdraw money!");
    require(!gameInProgress, "Do not attempt to withdraw while a game is in progress.");

    uint256 _initBalance = address(this).balance;
    payable(msg.sender).transfer(wei_amount);

    uint256 curr_balance = address(this).balance;
    assert( _initBalance - wei_amount == curr_balance);

    // Recalculate the maximum and minimum allowed bets.
    setMinMaxBets();
  }

  /*
  * Fund the contract with ETH.
  */
  function addBalance() external payable {

    // Recalculate the maximum and minimum allowed bets.
    setMinMaxBets();
  }
}
