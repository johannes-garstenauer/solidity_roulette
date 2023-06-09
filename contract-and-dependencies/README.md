# rouletteApplication
Project for the CS48001 course at Sabancı University.
Blockchain Roulette Application. 
State-Of-The-Art Security Considerations.

### Current State of the Repository:
# How to deploy (Remix IDE):
1. Compile the contract
2. Deploy the contract using "Injected Provider Metamask" and as a constructor argument the id: "7743"
3. Fund the contract (bank) with some ETH (low amount of Wei is sufficient).
3. Accept the Metamask Transaction
4. Go to this site: https://vrf.chain.link/goerli/7743 and add your contract as a new consumer.
5. Now you are good to place bets (read to doc of placeBet() to understand how) and gamble away your life savings! Also, do not forget to withdraw your ETH, which you funded the contract with in the beginning after your done.
6. If you are encountering any issues after placing a bet, scan this site for more info: https://vrf.chain.link/goerli/7743 and read the error messages in the IDE.
