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

    event MarketItemCreated(
        address indexed owner,
        address indexed seller,
        uint256 tokenId,
        uint256 price
    );

    event TokenResold(uint256 indexed tokenId, uint256 price, address indexed seller);

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

        // Transfer funds to seller first
        item.seller.transfer(msg.value);

        // Update ownership
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
