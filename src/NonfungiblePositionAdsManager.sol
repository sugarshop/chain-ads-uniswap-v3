// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "./PositionAd.sol";

/// @title Nonfungible Position Ads Manager
/// @notice Manages Uniswap V3 positions and their corresponding advertisements
/// @dev This contract provides the following main functionalities:
///
/// 1. Proxy Functions:
///    - Implements main position management functions: mint, increaseLiquidity, 
///      decreaseLiquidity, collect, and burn
///    - These methods directly proxy to Uniswap V3's NonfungiblePositionManager
///
/// 2. Advertisement Management:
///    - Uses poolToAd mapping to store relationships between pools and ad contracts
///    - Maintains allPools array to track all pools with advertisements
///    - Uses poolIndex for quick lookup of existing pool advertisements
///
/// 3. Automatic Ad Creation:
///    - Automatically checks and creates ad contracts when new positions are created
///    - Uses _ensurePoolHasAd to guarantee each pool has a corresponding ad
///
/// 4. Batch Operations:
///    - Supports batch creation of advertisements via batchCreatePoolAds
///    - Enables batch querying of advertisements via getPoolAds
///
/// 5. Query Functions:
///    - getAllPools: Retrieves all pools with advertisements
///    - getPoolAd: Queries advertisement for a single pool
///
/// 6. Event Notifications:
///    - PositionCreated: Logs new position creation
///    - LiquidityChanged: Tracks liquidity modifications
///    - PoolAdCreated: Records new advertisement creation
///    - BatchPoolAdsCached: Logs batch advertisement creation
contract NonfungiblePositionAdsManager is UUPSUpgradeable {
    /// @notice Uniswap V3 Position Manager
    INonfungiblePositionManager public immutable positionManager;
    
    /// @notice translate pool address to ad contract address
    mapping(address => address) public poolToAd;
    
    /// @notice translate pool address to ad contract address
    address[] public allPools;
    
    /// @notice translate pool address to index in allPools
    mapping(address => uint256) private poolIndex;

    /// @notice translate ad contract address to pool address
    mapping(address => address) public adToPool;
    
    event PositionCreated(uint256 indexed tokenId, address indexed pool, address indexed ad);
    event LiquidityChanged(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PoolAdCreated(address indexed pool, address indexed ad);
    event BatchPoolAdsCached(address[] pools, address[] ads);
    
    /// @notice constructor
    constructor(address _positionManager) {
        positionManager = INonfungiblePositionManager(_positionManager);
    }

    /// @notice translate pool address to ad contract address
    function mint(INonfungiblePositionManager.MintParams calldata params)
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            address ad
        )
    {
        // create position through Uniswap position manager
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(params);
        
        // compute pool address
        address pool = _computePoolAddress(params.token0, params.token1, params.fee);
        
        // ensure pool has ad contract
        ad = _ensurePoolHasAd(pool);
        
        // emit event
        emit PositionCreated(tokenId, pool, ad);
    }

    /// @notice translate pool address to ad contract address
    function _ensurePoolHasAd(address pool) internal returns (address ad) {
        ad = poolToAd[pool];
        if (ad == address(0)) {
            ad = address(new PositionAd());
            _cachePoolAd(pool, ad);
        }
    }

    /// @notice cache pool to ad mapping
    function _cachePoolAd(address pool, address ad) internal {
        if (poolIndex[pool] == 0) {
            allPools.push(pool);
            poolIndex[pool] = allPools.length;
            poolToAd[pool] = ad;
            emit PoolAdCreated(pool, ad);
        }
    }

    /// @notice batch create ads for multiple pools
    function batchCreatePoolAds(address[] calldata pools) 
        external 
        returns (address[] memory ads) 
    {
        uint256 length = pools.length;
        ads = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address pool = pools[i];
            if (poolToAd[pool] == address(0)) {
                ads[i] = address(new PositionAd());
                _cachePoolAd(pool, ads[i]);
            } else {
                ads[i] = poolToAd[pool];
            }
        }
        
        emit BatchPoolAdsCached(pools, ads);
    }

    /// @notice increase position liquidity
    function increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams calldata params)
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (liquidity, amount0, amount1) = positionManager.increaseLiquidity(params);
        emit LiquidityChanged(params.tokenId, liquidity, amount0, amount1);
    }

    /// @notice decrease position liquidity
    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = positionManager.decreaseLiquidity(params);
        emit LiquidityChanged(params.tokenId, params.liquidity, amount0, amount1);
    }

    /// @notice collect position fees
    function collect(INonfungiblePositionManager.CollectParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        return positionManager.collect(params);
    }

    /// @notice burn position
    function burn(uint256 tokenId) external {
        positionManager.burn(tokenId);
    }
    
    /// @notice get all pools with ads
    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }

    /// @notice get pool ad address
    function getPoolAd(address pool) external view returns (address) {
        return poolToAd[pool];
    }

    /// @notice batch get pool ads
    function getPoolAds(address[] calldata pools) 
        external 
        view 
        returns (address[] memory ads) 
    {
        ads = new address[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            ads[i] = poolToAd[pools[i]];
        }
    }
    
    /// @dev compute pool address
    function _computePoolAddress(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (address pool) {
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
            
        pool = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            positionManager.factory(),
            keccak256(abi.encode(token0, token1, fee)),
            positionManager.POOL_INIT_CODE_HASH()
        )))));
    }
    
    /// @dev UUPS translate upgrade authorization
    function _authorizeUpgrade(address) internal override {}
} 