// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract PositionAd is Ownable {
    // ad metadata
    struct PositionAdMetadata {
        string ipfsHash;           // IPFS hash of ad content
        string description;        // Ad description
        uint256 startTime;        // Ad start time
        uint256 endTime;          // Ad end time
        address creator;          // Creator address
        bool isActive;            // Is active
    }
    
    // Single position and metadata instead of mapping
    address public _position;
    PositionAdMetadata public _metadata;
    
    event PositionAdUpdated(
        address indexed position,
        string ipfsHash,
        uint256 startTime,
        uint256 endTime
    );
    
    // verify caller is liquidity provider of position
    modifier onlyLiquidityProvider(address position) {
        require(isLiquidityProvider(msg.sender, position), "Not a liquidity provider");
        _;
    }
    
    // Add fee tiers as constants
    uint24 public constant FEE_LOW = 100;      // 0.01% 适用于稳定币对（如 USDC-USDT）
    uint24 public constant FEE_MEDIUM = 500;   // 0.05% 适用于相关性强的代币对（如 ETH-USDC）
    uint24 public constant FEE_DEFAULT = 3000; // 0.3% 默认费率，适用于大多数标准代币对
    uint24 public constant FEE_HIGH = 10000;   // 1% 适用于流动性较低的代币对（如小众代币）
    
    // Add factory addresses for different networks
    mapping(uint256 chainId => address factory) public FACTORY_ADDRESSES;
    
    // Add mapping for position manager addresses
    mapping(uint256 chainId => address manager) public POSITION_MANAGERS;
    
    constructor() Ownable(msg.sender) {
        // Add Position Manager addresses for each network
        POSITION_MANAGERS[1] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;      // Ethereum
        POSITION_MANAGERS[137] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;    // Polygon
        POSITION_MANAGERS[10] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;     // Optimism
        POSITION_MANAGERS[42161] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;  // Arbitrum
        POSITION_MANAGERS[5] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;      // Goerli
        POSITION_MANAGERS[11155111] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // Sepolia

        // Ethereum Mainnet, Polygon, Optimism, Arbitrum, Goerli, Sepolia
        FACTORY_ADDRESSES[1] = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Ethereum
        FACTORY_ADDRESSES[137] = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Polygon
        FACTORY_ADDRESSES[10] = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Optimism
        FACTORY_ADDRESSES[42161] = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Arbitrum
        FACTORY_ADDRESSES[5] = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Goerli
        FACTORY_ADDRESSES[11155111] = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // Sepolia
    }

    // Add getter function for position manager
    function getPositionManager() public view returns (address) {
        return POSITION_MANAGERS[block.chainid];
    }
    
    // Add getter function for posotion manager
    function getFactoryAddress() public view returns (address) {
        return FACTORY_ADDRESSES[block.chainid];
    }
    
    // check if address is liquidity provider of position
    // safety: only valid Uniswap V3 position can publish ads
    // prevent abuse: avoid malicious users from publishing ads using fake positions
    // quality control: ensure ads come from real liquidity providers through verification
    // TODO: 判断 caller 是否是 position manager
    function verifyPosition(address position) external onlyOwner {
        IUniswapV3Factory factory = IUniswapV3Factory(getFactoryAddress());
        
        // get position's token0 and token1
        address token0 = IUniswapV3Pool(position).token0();
        address token1 = IUniswapV3Pool(position).token1();
        
        // check if it is a pool created by any valid fee
        require(
            factory.getPool(token0, token1, FEE_LOW) == position ||
            factory.getPool(token0, token1, FEE_MEDIUM) == position ||
            factory.getPool(token0, token1, FEE_DEFAULT) == position ||
            factory.getPool(token0, token1, FEE_HIGH) == position,
            "Not a valid Uniswap V3 pool"
        );
        
        verifiedPositions[position] = true;
    }
    
    // set position's ad content
    function setPositionAd(
        address position,
        string calldata ipfsHash,
        string calldata description,
        uint256 durationInDays
    ) external onlyLiquidityProvider(position) {
        require(bytes(ipfsHash).length > 0, "Invalid IPFS hash");
        
        _position = position;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (durationInDays * 1 days);
        
        _metadata = PositionAdMetadata({
            ipfsHash: ipfsHash,
            description: description,
            startTime: startTime,
            endTime: endTime,
            creator: msg.sender,
            isActive: true
        });
        
        emit PositionAdUpdated(position, ipfsHash, startTime, endTime);
    }
    
    // get position's ad content
    function getPositionAd() external view returns (PositionAdMetadata memory) {
        return _metadata;
    }
} 