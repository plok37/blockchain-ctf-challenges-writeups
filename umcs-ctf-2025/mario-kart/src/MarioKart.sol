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