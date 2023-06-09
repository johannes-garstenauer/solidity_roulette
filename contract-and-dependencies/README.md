# rouletteApplication
Project for the CS48001 course at Sabancı University.

### Current State of the Repository:
# How to deploy:
1. Compile the contract
2. Deploy the contract using "Injected Provider Metamask" and as a constructor argument the id: "7743"
3. Fund the contract (bank) with some ETH (low amount of Wei is sufficient).
3. Accept the Metamask Transaction
4. Go to this site: https://vrf.chain.link/goerli/7743 and add your contract as a new consumer.
5. Now you are good to place bets (read to doc of placeBet() to understand how) and gamble away your life savings! Also, do not forget to withdraw your ETH, which you funded the contract with in the beginning after your done.
6. If you are encountering any issues after placing a bet, scan this site for more info: https://vrf.chain.link/goerli/7743 and read the error messages in the IDE.

# Status
- Contract [UNDER CONSTRUCTION]
	- The contracts functionality is complete.
	- The contracts documentation and security considerations must still be regarded. 
- WEB-APP [TODO]

# 1. Contract
### Good resources:
-   [](https://docs.chain.link/vrf/v2/direct-funding/examples/get-a-random-number/#clean-up)[https://docs.chain.link/vrf/v2/direct-funding/examples/get-a-random-number/#clean-up](https://docs.chain.link/vrf/v2/direct-funding/examples/get-a-random-number/#clean-up)
-   [](https://remix.ethereum.org/#url=https://docs.chain.link/samples/VRF/VRFv2DirectFundingConsumer.sol&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.7+commit.e28d00a7.js)[https://remix.ethereum.org/#url=https://docs.chain.link/samples/VRF/VRFv2DirectFundingConsumer.sol&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.7+commit.e28d00a7.js](https://remix.ethereum.org/#url=https://docs.chain.link/samples/VRF/VRFv2DirectFundingConsumer.sol&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.7+commit.e28d00a7.js)

# 2. Web-App
- An indicator whether a bet can be placed (!gameInProgress)
- An indicator as to the max/min bet.
- A button and a menu to place a bet.
- A display of the history of games.
- A display of the current game.
- An image or animatiion of a roulette wheel and the placeable bets.
### Follow this tutorial:
-   https://www.dappuniversity.com/articles/the-ultimate-ethereum-dapp-tutorial
