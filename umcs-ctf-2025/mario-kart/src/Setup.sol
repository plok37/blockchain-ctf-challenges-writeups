// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./MarioKart.sol";

contract Setup {
    MarioKart public marioKart;
    address public deployer;
    bool public challengeSolved;

    constructor() payable {
        require(msg.value == 20 ether, "Setup needs 20 ether");
        deployer = msg.sender;
        marioKart = new MarioKart{value: 20 ether}();
        marioKart.enableSpecialItems();
    }

    function isSolved() public view returns (bool) {
        return address(marioKart).balance == 0;
    }

    function getMainContract() public view returns (address) {
        return address(marioKart);
    }
}