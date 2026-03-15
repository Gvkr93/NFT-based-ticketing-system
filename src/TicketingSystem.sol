// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Ticketing1155 is ERC1155, ERC1155Holder {
    address payable platformOwner;
    using Counters for Counters.Counter;

    //token id counter
    Counters.Counter private tokenIdCounter;    
    
    constructor () ERC1155("") {
        platformOwner=payable(msg.sender);
    }

    function setURI(string memory uri) public onlyOwner{
        _setURI(uri);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function _checkOwner() internal view {
        require(msg.sender == platformOwner, "Only owner can perform this operation");
    }

    // when organisers create an event they have to pay a small fee to the admin
    uint public eventCreationPrice=0.0002 ether;    

    function changeEventCreationPrice(uint _eventCreationPrice) public onlyOwner{
        eventCreationPrice=_eventCreationPrice;
    }

    //ticket structure
    struct Tickettoken{
        uint tokenId;
        uint price;
        uint maxSupply;
        uint currentSupply;
        address organiser;
        address owner;
        bool isActive;
        string tokenUri;
    }
    
    mapping(uint =>Tickettoken) idToTicket;

    function getCurrentTokenId() public view returns(uint256){
        return tokenIdCounter.current();
    }

    function getTicketDetails(uint _tokenId) public view returns(Tickettoken memory){
        uint currentMaxTokenId=tokenIdCounter.current();
        require(_tokenId<=currentMaxTokenId,"Token id does not exist");
        return idToTicket[_tokenId];
    }

    //we will get the IPFS uri , price and max tickets from the organiser, only organiser can mint
    function createEventToken(string memory uri,uint price,uint amount) public payable{
        //pre conditions
        require(msg.value>=eventCreationPrice,"Please pay the price for listing your event!!");
        require(price>0,"Please enter a valid price");

        //tokenid starts from 1
        tokenIdCounter.increment();
        uint currentTokenId=tokenIdCounter.current();
        
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

    //function to return all event tickets (for gallery)
    function getAllEventTokens() public view returns(Tickettoken[] memory){
        uint ticketCount=tokenIdCounter.current();
        Tickettoken[] memory tickets=new Tickettoken[](ticketCount);
        
        uint currentIndex=0;
        for(uint i=1;i<=ticketCount;i++){
            Tickettoken memory currentToken=idToTicket[i];
            tickets[currentIndex]=currentToken;
            currentIndex+=1;
        }
        return tickets;
    }

    //function to get tickets that the specific user owns
    function getUserEventTokens() public view returns(Tickettoken[] memory){
        uint totalTicketCount=tokenIdCounter.current();
        uint userTicketCount=0;
        
        for(uint i=1;i<=totalTicketCount;i++){
            Tickettoken memory currentToken=idToTicket[i];
            if(currentToken.organiser==msg.sender || currentToken.owner==msg.sender){
                userTicketCount++;
            }
        }
        
        Tickettoken[] memory tickets=new Tickettoken[](userTicketCount);
        uint index=0;

        for(uint i=1;i<=totalTicketCount;i++){
            Tickettoken memory currentToken=idToTicket[i];
            // BUG FIX: Added this if statement so it only returns the actual user's tickets, not empty ones!
            if(currentToken.organiser==msg.sender || currentToken.owner==msg.sender){
                tickets[index]=currentToken;
                index++;
            }
        }
        return tickets;
    }

    function executeSale(uint tokenId,uint amount) payable public{
        Tickettoken memory token=idToTicket[tokenId];
        uint currentSupply=token.currentSupply;
        uint price=token.price;
        address organiser=token.organiser;
        
        //check if enough tickets available
        require(currentSupply >= amount, "Not enough tickets available!!");
        
        // CRITICAL BUG FIX: You must multiply the price by the amount they are buying!
        require(msg.value >= (price * amount), "Please pay the correct price!");

        _safeTransferFrom(address(this), msg.sender, tokenId, amount, "");

        //send money to organiser
        payable(organiser).transfer(msg.value);

        //change currentsupply
        idToTicket[tokenId].currentSupply = currentSupply - amount;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Receiver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}