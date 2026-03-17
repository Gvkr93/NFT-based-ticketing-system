// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Ticketing1155 is ERC1155, ERC1155Holder {
    using Counters for Counters.Counter;

    address payable public platformOwner;
    Counters.Counter private tokenIdCounter;
    Counters.Counter private listingIdCounter;

    // Platform settings
    uint256 public eventCreationPrice = 0.0002 ether; // when organisers create an event they have to pay a small fee to the admin
    uint256 public royaltyPercentage = 5; // 5% automated royalty to the organizer on secondary sales

    constructor() ERC1155("") {
        platformOwner = payable(msg.sender);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function setURI(string memory uri) public onlyOwner {
        _setURI(uri);
    }

    function _checkOwner() internal view {
        require(msg.sender == platformOwner, "Only owner can perform this operation");
    }

    function changeEventCreationPrice(uint256 _eventCreationPrice) public onlyOwner {
        eventCreationPrice = _eventCreationPrice;
    }

    //ticket structure
    struct Tickettoken {
        uint256 tokenId;
        uint256 price;
        uint256 maxSupply;
        uint256 currentSupply;
        address organiser;
        address owner;
        bool isActive;
        string tokenUri;
    }

    struct ResaleListing {
        uint256 listingId;
        uint256 tokenId;
        address seller;
        uint256 amount;
        uint256 pricePerTicket;
        bool isActive;
    }

    mapping(uint256 => Tickettoken) public idToTicket;
    mapping(uint256 => ResaleListing) public idToListing;

    //we will get the IPFS uri , price and max tickets from the organiser, only organiser can mint
    function createEventToken(string memory uri, uint256 price, uint256 amount) public payable {
        //pre conditions
        require(msg.value >= eventCreationPrice, "Please pay the price for listing your event!!");
        require(price > 0, "Please enter a valid price");

        //tokenid starts from 1
        tokenIdCounter.increment();
        uint256 currentTokenId = tokenIdCounter.current();

        //safemint the token to organiser with token id of ticket
        _mint(msg.sender, currentTokenId, amount, "");

        //add the ticket token to the hashmap -> amount is the maxsupply
        idToTicket[currentTokenId] = Tickettoken({
            tokenId: currentTokenId,
            price: price,
            maxSupply: amount,
            currentSupply: amount,
            organiser: msg.sender,
            owner: address(this),
            isActive: true,
            tokenUri: uri
        });

        //transfer ownership of all tokens(amount) from organiser to contract so its easy to transfer it to user later (without approval)
        _safeTransferFrom(msg.sender, address(this), currentTokenId, amount, "");

        payable(platformOwner).transfer(msg.value);
    }

    function executeSale(uint256 tokenId, uint256 amount) public payable {
        Tickettoken memory token = idToTicket[tokenId];
        uint256 currentSupply = token.currentSupply;
        uint256 price = token.price;
        address organiser = token.organiser;

        //check if enough tickets available
        require(currentSupply >= amount, "Not enough tickets available!!");

        //You must multiply the price by the amount they are buying!
        require(msg.value >= (price * amount), "Please pay the correct price!");

        _safeTransferFrom(address(this), msg.sender, tokenId, amount, "");

        //send money to organiser
        payable(organiser).transfer(msg.value);

        //change currentsupply
        idToTicket[tokenId].currentSupply = currentSupply - amount;
    }

    // The Anti-Scalping Mechanism
    function listForResale(uint256 tokenId, uint256 amount, uint256 resalePricePerTicket) public {
        require(balanceOf(msg.sender, tokenId) >= amount, "You do not own enough tickets");

        Tickettoken memory originalTicket = idToTicket[tokenId];

        // Core Feature: Enforce maximum 10% profit margin
        uint256 maxPrice = originalTicket.price + ((originalTicket.price * 10) / 100);
        require(resalePricePerTicket <= maxPrice, "Price exceeds 10% profit limit! Scalping prevented.");

        // Escrow the ticket in the smart contract
        // NOTE: The user must call setApprovalForAll() on the frontend before calling this!
        _safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        listingIdCounter.increment();
        uint256 newListingId = listingIdCounter.current();

        idToListing[newListingId] = ResaleListing({
            listingId: newListingId,
            tokenId: tokenId,
            seller: msg.sender,
            amount: amount,
            pricePerTicket: resalePricePerTicket,
            isActive: true
        });
    }

    // The Automated Royalty Mechanism
    function buyResaleTicket(uint256 listingId, uint256 amountToBuy) public payable {
        ResaleListing storage listing = idToListing[listingId];
        require(listing.isActive == true, "Listing is not active");
        require(listing.amount >= amountToBuy, "Not enough tickets in this listing");
        require(msg.value == (listing.pricePerTicket * amountToBuy), "Please pay the exact price");

        Tickettoken memory originalTicket = idToTicket[listing.tokenId];

        uint256 totalCost = msg.value;
        uint256 royaltyAmount = (totalCost * royaltyPercentage) / 100;
        uint256 sellerAmount = totalCost - royaltyAmount;

        listing.amount -= amountToBuy;
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        // Transfer from escrow to the new buyer
        _safeTransferFrom(address(this), msg.sender, listing.tokenId, amountToBuy, "");

        // Secure, automated fund routing
        payable(originalTicket.organiser).transfer(royaltyAmount); // 5% back to creator
        payable(listing.seller).transfer(sellerAmount); // Profit to fan
    }

    // --- UTILITY & VIEW FUNCTIONS ---
    function getCurrentTokenId() public view returns (uint256) {
        return tokenIdCounter.current();
    }

    function getTicketDetails(uint256 _tokenId) public view returns (Tickettoken memory) {
        uint256 currentMaxTokenId = tokenIdCounter.current();
        require(_tokenId <= currentMaxTokenId, "Token id does not exist");
        return idToTicket[_tokenId];
    }

    //function to return all event tickets (for gallery)
    function getAllEventTokens() public view returns (Tickettoken[] memory) {
        uint256 ticketCount = tokenIdCounter.current();
        Tickettoken[] memory tickets = new Tickettoken[](ticketCount);

        uint256 currentIndex = 0;
        for (uint256 i = 1; i <= ticketCount; i++) {
            Tickettoken memory currentToken = idToTicket[i];
            tickets[currentIndex] = currentToken;
            currentIndex += 1;
        }
        return tickets;
    }

    //function to get tickets that the specific user owns
    function getUserEventTokens() public view returns (Tickettoken[] memory) {
        uint256 totalTicketCount = tokenIdCounter.current();
        uint256 userTicketCount = 0;

        for (uint256 i = 1; i <= totalTicketCount; i++) {
            if (idToTicket[i].organiser == msg.sender || balanceOf(msg.sender, i) > 0) {
                userTicketCount++;
            }
        }

        Tickettoken[] memory tickets = new Tickettoken[](userTicketCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= totalTicketCount; i++) {
            Tickettoken memory currentToken = idToTicket[i];
            if (currentToken.organiser == msg.sender || currentToken.owner == msg.sender) {
                tickets[index] = currentToken;
                index++;
            }
        }
        return tickets;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
