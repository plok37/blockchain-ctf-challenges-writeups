// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./SecureShell.sol";

contract Setup {
    SecureShell public secureShell;

    constructor(uint256 _password) {
        secureShell = new SecureShell(_password);
    }

    function isSolved() public view returns (bool) {
        return secureShell.owner() == msg.sender;
    }
}