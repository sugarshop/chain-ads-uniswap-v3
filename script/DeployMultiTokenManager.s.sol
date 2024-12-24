// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { MultiTokenManager } from "../src/MultiTokenManager.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { console } from "forge-std/src/console.sol";

// create a test ERC20 token
contract MEMEToken is ERC20 {
    constructor() ERC20("MEME Token", "MEME") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcast returns (MultiTokenManager multiTokenManager) {
        // 1. deploy MultiTokenManager
        multiTokenManager = new MultiTokenManager();
        console.log("MultiTokenManager deployed at:", address(multiTokenManager));

        // 2. deploy test token
        MEMEToken memeToken = new MEMEToken();
        console.log("MultiTokenManager deployed at:", address(memeToken));

        // 3. register ERC20 token
        MultiTokenManager.TokenInfo memory tokenInfo = MultiTokenManager.TokenInfo({
            erc20Address: address(memeToken),
            name: "MEME Token",
            symbol: "MEME",
            decimals: 18
        });

        uint256 tokenId = multiTokenManager.registerToken(tokenInfo);
        console.log("Token registered with ID:", tokenId);

        // 4. mint ERC1155 token
        multiTokenManager.mint(msg.sender, tokenId, 1000 * 10**18, "");
        console.log("ERC1155 minted for 1000 MEME, token ID:", tokenId, " to:", msg.sender);

        // 5. burn ERC1155 token
        // multiTokenManager.burn(msg.sender, tokenId, 1000 * 10**18);
        multiTokenManager.burn(tokenId, 1000 * 10**18);
        console.log("ERC1155 burned for 1000 MEME, token ID:", tokenId, " from:", msg.sender);

        // 6. transfer ERC1155 token
        multiTokenManager.safeTransferFrom(msg.sender, address(0x2), tokenId, 1000 * 10**18, "");
        console.log("ERC1155 transferred for 1000 MEME, token ID:", tokenId, " to:", address(0x2));

        // 7. swap ERC1155 token to ERC20 token
        uint256 amountOut = multiTokenManager.swapExactInputSingle(tokenId, address(memeToken), 500, 1000 * 10**18);
        console.log("ERC1155 swapped for", amountOut, "MEME, token ID:", tokenId);
    }
}
