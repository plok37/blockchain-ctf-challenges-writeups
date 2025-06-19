// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GREY} from "./lib/GREY.sol";
import {UniswapV2Factory} from "./lib/v2-core/UniswapV2Factory.sol";
import {Factory} from "./Factory.sol";
import {Token} from "./Token.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract Setup {
    bool public claimed;

    // GREY token
    GREY public grey;

    // Challenge contracts
    UniswapV2Factory public uniswapV2Factory;
    Factory public factory;
    Token public meme;

    constructor() {
        // Deploy the GREY token contract
        grey = new GREY();

        // Mint 7 GREY for setup
        grey.mint(address(this), 7 ether);

        // Deploy challenge contracts
        uniswapV2Factory = new UniswapV2Factory(address(0xdead));
        factory = new Factory(address(grey), address(uniswapV2Factory), 2 ether, 6 ether);

        // Create a meme token
        (address _meme,) = factory.createToken("Meme", "MEME", bytes32(0), 0);
        meme = Token(_meme);

        // Buy 2 GREY worth of MEME
        grey.approve(address(factory), 2 ether);
        factory.buyTokens(_meme, 2 ether, 0);
        console2.log("Meme token address:", address(meme));
        console2.log("GREY token address:", address(grey));
        console2.log("UniswapV2Factory address:", address(uniswapV2Factory));
        console2.log("Factory address:", address(factory));
        console2.log("Setup Address:", address(this));
        }

    // Note: Call this function to claim 5 GREY for the challenge
    function claim() external {
        require(!claimed, "already claimed");
        claimed = true;

        grey.transfer(msg.sender, 5 ether);
    }

    // Note: Challenge is solved when you have at least 5.965 GREY
    function isSolved() external view returns (bool) {
        return grey.balanceOf(msg.sender) >= 5.965 ether;
    }
}
