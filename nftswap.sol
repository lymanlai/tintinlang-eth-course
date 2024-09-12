// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTSwap is ReentrancyGuard {
    struct Order {
        address owner;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Order)) public orders;

    event Listed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event Revoked(address indexed nftContract, uint256 indexed tokenId, address indexed seller);
    event Updated(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 newPrice);
    event Purchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);

    function list(address _nftContract, uint256 _tokenId, uint256 _price) external {
        require(_price > 0, "Price must be greater than zero");
        require(orders[_nftContract][_tokenId].owner == address(0), "NFT already listed");

        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId) == msg.sender, "Not the owner of the NFT");
        require(nft.isApprovedForAll(msg.sender, address(this)), "Contract not approved");

        orders[_nftContract][_tokenId] = Order(msg.sender, _price);
        emit Listed(_nftContract, _tokenId, msg.sender, _price);
    }

    function revoke(address _nftContract, uint256 _tokenId) external {
        Order memory order = orders[_nftContract][_tokenId];
        require(order.owner == msg.sender, "Not the owner of the order");

        delete orders[_nftContract][_tokenId];
        emit Revoked(_nftContract, _tokenId, msg.sender);
    }

    function update(address _nftContract, uint256 _tokenId, uint256 _newPrice) external {
        require(_newPrice > 0, "Price must be greater than zero");
        Order storage order = orders[_nftContract][_tokenId];
        require(order.owner == msg.sender, "Not the owner of the order");

        order.price = _newPrice;
        emit Updated(_nftContract, _tokenId, msg.sender, _newPrice);
    }

    function purchase(address _nftContract, uint256 _tokenId) external payable nonReentrant {
        Order memory order = orders[_nftContract][_tokenId];
        require(order.owner != address(0), "Order does not exist");
        require(msg.value >= order.price, "Insufficient payment");

        IERC721 nft = IERC721(_nftContract);
        address seller = order.owner;

        delete orders[_nftContract][_tokenId];

        nft.safeTransferFrom(seller, msg.sender, _tokenId);
        payable(seller).transfer(msg.value);

        emit Purchased(_nftContract, _tokenId, msg.sender, msg.value);
    }
}
