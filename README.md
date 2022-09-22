# Smart Contract

## General:

The repository contains Smart Contracts developed on Ethereum and NEO (N3). For Ethereum the contracts are written in Solidity and for NEO the contracts are written in NEO Phython.

## Ethereum:

- Streaming Payments:

Users can create a payment stream to another user. The streamed asset is Ether. Based on time boundaries the streamed amount is calculated. There is a possibility for the sender and the receiver to cancel the stream. With a transaction the streamed Ether can be withdrawn from the payment stream.


- Voting Contract:

Users can create a vote on the blockchain. The creator of a voting need to registrate the voters for each vote. Within set time boundaries the registrated voters can vote either yes or no based on transactions.

- Weighted Distribution:

Artificial shares are created. The creator of such a share can transfer shares to other participants. A user can send Ether to the contract and a specific share. Those Ether are distributed following the holdings of the different users. Each users has the ability to withdraw those Ether.

On the website [newblocks](https://www.newblocks.eu) those Smart Contracts can be tested on the Ropsten Testnet. The landing page does offer an interface for each above mentioned contract.


## NEO:

- NEP_11[NFT]

The contract is based on the NEP_11 standard (NFTs) on the NEO3 blockchain. Basic functionalities are implemented. Furthermore, it was planned to implement a logic to remove the necessity for the to pay for each mint within the transaction. So called SteamStones can be purchased. The SteamStone NFT has charges, which can be used from users to mint NFTs from the contract.
The NFT contract itself was planned to be used for a blockchain game called Chain.Game. This project participated in the N3 hackathon. In this [video](https://www.youtube.com/watch?v=qTD4tD2jyJM) you can gain more information about the game. Out of strategical reasons further developments on this game are stopped.
