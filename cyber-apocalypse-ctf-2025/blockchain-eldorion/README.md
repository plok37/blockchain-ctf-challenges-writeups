# 🚩 Eldorion – Very Easy

![image](../img/EldorionBanner.png)

- **Category:** Blockchain
- **CTF Event:** Cyber Apocalypse CTF 2025
- **Difficulty:** Very Easy
- **Points:** 925 Pts

---

## Challenge Description

> "Welcome to the realms of Eldoria, adventurer. You've found yourself trapped in this mysterious digital domain, and the only way to escape is by overcoming the trials laid before you. But your journey has barely begun, and already an overwhelming obstacle stands in your path. Before you can even reach the nearest city, seeking allies and information, you must face Eldorion, a colossal beast with terrifying regenerative powers. This creature, known for its ""eternal resilience"" guards the only passage forwad. It's clear: you must defeat Eldorion to continue your quest."

---

## Challenge Files

- [`Eldorion.sol`](src/Eldorion.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```solidity
pragma solidity ^0.8.28;

import { Eldorion } from "./Eldorion.sol";

contract Setup {
    Eldorion public immutable TARGET;
    
    event DeployedTarget(address at);

    constructor() payable {
        TARGET = new Eldorion();
        emit DeployedTarget(address(TARGET));
    }

    function isSolved() public view returns (bool) {
        return TARGET.isDefeated();
    }
}
```

The main goal is to defeat Elldorion in order to obtain the flag as we can observe there is a `isSolved()` function in the `Setup.sol` contract which will return `true` only when the Eldorion is defeated.

---

## Code Analysis

### `Eldorion.sol`

```solidity
pragma solidity ^0.8.28;

contract Eldorion {
    uint256 public health = 300;
    uint256 public lastAttackTimestamp;
    uint256 private constant MAX_HEALTH = 300;
    
    event EldorionDefeated(address slayer);
    
    modifier eternalResilience() {
        if (block.timestamp > lastAttackTimestamp) {
            health = MAX_HEALTH;
            lastAttackTimestamp = block.timestamp;
        }
        _;
    }
    
    function attack(uint256 damage) external eternalResilience {
        require(damage <= 100, "Mortals cannot strike harder than 100");
        require(health >= damage, "Overkill is wasteful");
        health -= damage;
        
        if (health == 0) {
            emit EldorionDefeated(msg.sender);
        }
    }

    function isDefeated() external view returns (bool) {
        return health == 0;
    }
}
```

As our main objective is to return `true` when calling the `isDefeated()` function, the condition of it is to make the variable `health` to be `0`. 

Thus, we need to call the `attack()` function as we can observe that the variable `health` can be reduced by the input parameter `damage`. There are two require statements before executing the reduction of `health`, one is the `damage` should be lesser or equal to `100`, another is the `damage` should be greater or equal to `health`. Furthermore, there is a modifier `eternalResilience()` applied on this `attack()` which will be executed everytime when calling the `attack()` function. According to the modifier, if the current block timestamp is greater than `lastAttackTimestamp`, it will reset the `health` to `MAX_HEALTH` which is `300`, the inital health of Eldorion and update `lastAttackTimestamp` to current block timestamp.

In summary, we should call the `attack()` function three times, which will deal a total damage of 300 (100 damage for each time) to Eldorion. However, if we seperately call the `attack()` as an EOA, the health of Eldorion will keep reset to 300 and cause us unable to defeat it.


```md
🔑 Key Observations

- `eternalResilience()` modifier is used to reset the health of Eldorion under a certain condition → possible exploit if we pass through the condition
- `attack()` function can deal damage to Eldorion according to the input parameter `damage` when calling the `attack` function.
- When the variable `health` is `0`, we will get a `true` when calling the `isSolved()` function in the `Setup.sol` contract.
```

---

## Exploitation

Since the `eternalResilience()` modifier compares block.timestamp with the lastAttackTimestamp, we can bypass the reset condition by calling `attack()` multiple times in a single transaction — all within the same block timestamp. This allows us to reduce health from 300 to 0 before the modifier has a chance to reset it. 

There are two methods, one is deploying a malicious contract and call the functions to do batch executions, another is just writing a script to do batch executions. The difference between them is one is the malicious contract as the msg.sender, another is the private key given in the command to run the script will act as the msg.sender.

```solidity
function run() public  {
    vm.startBroadcast();
    for(uint256 i = 0; i < 3; i++) {
        eldorion.attack(100);
    }   
}
```

However, my method is writing a script to do batch executions which is one step lesser. See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Script

```
forge script script/Exploit.s.sol:Exploit --broadcast --rpc-url $RPC_URL --private-key $PK
```

Please kindlly save the variables in the `.env` file. However, please don't save your private key in plaint text like this in production!

---