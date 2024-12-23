// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {UniswapV3Swap, ISwapRouter, IERC20} from "./UniswapV3Swap.sol";

/**
 * @title MultiTokenManager
 * @dev Implementation of a multi-token management system using ERC1155
 * 
 * Architecture Overview:
 * - Base Contracts:
 *   - ERC1155: Handles multi-token functionality
 *   - Ownable: Manages contract ownership
 *   - ReentrancyGuard: Prevents reentrancy attacks
 *
 * - State Variables:
 *   - tokenIdToERC20: Maps ERC1155 tokenIds to ERC20 token addresses
 *   - _uris: Stores metadata URIs for each token
 *   - _tokenIdCounter: Tracks total number of registered tokens
 *   - uniswapV3Swap: Instance of UniswapV3Swap contract for token swaps
 *
 * - Key Features:
 *   - Token Registration: Links ERC20 tokens to ERC1155 tokenIds
 *   - Minting/Burning: Controls token supply
 *   - URI Management: Handles token metadata
 *   - Swap Integration: Enables token swaps via Uniswap V3
 */
contract MultiTokenManager is ERC1155, Ownable, ReentrancyGuard {
    error InvalidERC20Address();
    error TokenNotRegistered();

    /// @notice Mapping from tokenId to its corresponding ERC20 token address
    /// @dev Each ERC1155 token represents a wrapper for an ERC20 token
    mapping(uint256 tokenId => address erc20Address) public tokenIdToERC20;
    
    /// @notice Mapping from tokenId to its metadata URI
    /// @dev Stores the IPFS or HTTP URI containing token metadata
    mapping(uint256 tokenId => string uri) private _uris;
    
    /// @notice Counter for generating unique tokenIds
    /// @dev Increments with each new token registration
    uint256 private _tokenIdCounter;

    /// @notice Instance of UniswapV3Swap contract for token swaps
    /// @dev Deployed during contract construction
    UniswapV3Swap public uniswapV3Swap;
    
    /// @notice Events for tracking token lifecycle: registration, minting, and burning
    event TokenRegistered(uint256 indexed tokenId, address indexed erc20Address);
    event TokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event TokenBurned(uint256 indexed tokenId, address indexed from, uint256 amount);

    /// @notice Initializes the contract with empty URI and deploys UniswapV3Swap
    constructor() ERC1155("") Ownable(msg.sender) {
        uniswapV3Swap = new UniswapV3Swap();
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return _uris[tokenId];
    }
    
    // 设置 URI
    function setURI(uint256 tokenId, string memory newuri) public onlyOwner {
        _uris[tokenId] = newuri;
        emit URI(newuri, tokenId);
    }

    // 注册 ERC20 代币的结构体
    struct TokenInfo {
        address erc20Address;
        string name;
        string symbol;
        uint8 decimals;
    }

    // 注册ERC20代币，返回 tokenId ERC20 代币被注册后，可以铸造和销毁，并且 ERC20 代币被 ERC1155 代币管理
    function registerToken(TokenInfo calldata info) external onlyOwner returns (uint256) {
        if (info.erc20Address == address(0)) revert InvalidERC20Address();
        
        uint256 newTokenId = _tokenIdCounter++;
        tokenIdToERC20[newTokenId] = info.erc20Address;
        
        emit TokenRegistered(newTokenId, info.erc20Address);
        return newTokenId;
    }

    // 铸造 ERC1155 币
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        _mint(to, tokenId, amount, data);
        emit TokenMinted(tokenId, to, amount);
    }

    ISwapRouter public constant UNISWAP_ROUTER = 
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // 将 ERC1155 代币兑换为 ERC20 代币
    // todo: 需要添加一个函数来获取当前的池子fee
    // todo: 需要添加一个函数来获取当前的池子地址
    // todo: 需要添加一个函数来将 ERC1155 代币使用 ERC20 代币兑换为 ERC721 代币
    function swapExactInputSingle(
        uint256 tokenId,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        address tokenIn = tokenIdToERC20[tokenId];
        
        // 先销毁用户的ERC1155代币
        _burn(msg.sender, tokenId, amountIn);
        
        // 将对应数量的ERC20代币转给用户
        IERC20(tokenIn).transfer(msg.sender, amountIn);
        
        // 调用UniswapV3Swap的swap方法
        amountOut = uniswapV3Swap.swapExactInputSingleHop(
            tokenIn,
            tokenOut,
            poolFee,
            amountIn
        );
    }

    // 销毁 ERC1155 币
    function burn(
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant {
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        
        _burn(msg.sender, tokenId, amount);
        emit TokenBurned(tokenId, msg.sender, amount);
    }
}