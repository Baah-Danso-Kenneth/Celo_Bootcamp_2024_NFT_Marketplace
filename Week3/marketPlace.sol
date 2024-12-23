// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CeloDaoMarketPlace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 public listingPrice = 0.0025 ether;
    address payable owner;

    mapping(uint256 => MarketItem) public idToMarketItem;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool isSold;
    }

    struct Auction {
        uint256 tokenId;
        address payable seller;
        uint256 startingPrice;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool isActive;
    }

    mapping(uint256 => Auction) public auctions;

    event MarketItemCreated(
        address indexed owner,
        address indexed seller,
        uint256 tokenId,
        uint256 price
    );

    event TokenResold(uint256 indexed tokenId, uint256 price, address indexed seller);
    event AuctionStarted(uint256 indexed tokenId, uint256 startingPrice, uint256 endTime);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 bidAmount);
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 winningBid);

    constructor() ERC721("CELOAFRICADAO", "CAD") {
        owner = payable(msg.sender);
    }

    function updateListingPrice(uint256 _newPrice) public {
        require(msg.sender == owner, "Only owner can update listing price");
        listingPrice = _newPrice;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createToken(string memory _tokenURI, uint256 _price)
        public
        payable
        returns (uint256)
    {
        uint256 tokenId = _tokenIds.current();
        require(_price > 0, "Price must be greater than zero");
        require(msg.value == listingPrice, "Must pay the listing price");

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        createMarketItem(tokenId, _price);
        _tokenIds.increment();

        return tokenId;
    }

    function createMarketItem(uint256 tokenId, uint256 price) private {
        idToMarketItem[tokenId] = MarketItem({
            tokenId: tokenId,
            seller: payable(msg.sender),
            owner: payable(address(this)),
            price: price,
            isSold: false
        });

        _transfer(msg.sender, address(this), tokenId);
        payable(owner).transfer(listingPrice);

        emit MarketItemCreated(address(this), msg.sender, tokenId, price);
    }

    function startAuction(
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration
    ) public {
        require(msg.sender == ownerOf(tokenId), "Only owner can start an auction");
        require(duration > 0, "Auction duration must be greater than zero");

        _transfer(msg.sender, address(this), tokenId);

        auctions[tokenId] = Auction({
            tokenId: tokenId,
            seller: payable(msg.sender),
            startingPrice: startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            isActive: true
        });
    }

    function placeBid(uint256 tokenId) public payable {
        Auction storage auction = auctions[tokenId];
        require(auction.isActive, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");

        if (auction.highestBid > 0) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);
    }

    function endAuction(uint256 tokenId) public {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp >= auction.endTime, "Auction is still ongoing");
        require(auction.isActive, "Auction is not active");

        auction.isActive = false;

        if (auction.highestBid > 0) {
            auction.seller.transfer(auction.highestBid);
            _transfer(address(this), auction.highestBidder, tokenId);
        } else {
            _transfer(address(this), auction.seller, tokenId);
        }
    }

    function resaleToken(uint256 tokenId, uint256 newPrice) public payable {
        MarketItem storage item = idToMarketItem[tokenId];
        require(item.owner == msg.sender, "You are not the owner");
        require(msg.value == listingPrice, "Must pay the listing price");
        require(newPrice > 0, "Price must be greater than zero");

        item.price = newPrice;
        item.seller = payable(msg.sender);
        item.owner = payable(address(this));
        item.isSold = false;

        _transfer(msg.sender, address(this), tokenId);

        _itemsSold.decrement();
        payable(owner).transfer(listingPrice);

        emit TokenResold(tokenId, newPrice, msg.sender);
    }

    function createMarketSale(uint256 tokenId) public payable {
        MarketItem storage item = idToMarketItem[tokenId];

        require(msg.value == item.price, "Submit the asking price");
        require(item.owner == address(this), "Item not available for sale");

        item.seller.transfer(msg.value);

        item.owner = payable(msg.sender);
        item.seller = payable(address(0));
        item.isSold = true;

        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
    }

    function fetchMarketPlaceItems() public view returns (MarketItem[] memory) {
        uint256 totalItems = _tokenIds.current();
        uint256 unsoldCount = totalItems - _itemsSold.current();
        MarketItem[] memory items = new MarketItem[](unsoldCount);

        uint256 index = 0;
        for (uint256 i = 0; i < totalItems; i++) {
            if (idToMarketItem[i].owner == address(this)) {
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }

    function fetchUserNFTs(address user) public view returns (MarketItem[] memory) {
        uint256 totalItems = _tokenIds.current();
        uint256 userItemCount = 0;

        for (uint256 i = 0; i < totalItems; i++) {
            if (idToMarketItem[i].owner == user) {
                userItemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](userItemCount);
        uint256 index = 0;

        for (uint256 i = 0; i < totalItems; i++) {
            if (idToMarketItem[i].owner == user) {
                items[index] = idToMarketItem[i];
                index++;
            }
        }

        return items;
    }
}
