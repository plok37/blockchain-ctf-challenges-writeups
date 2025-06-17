# 🚩 Lot of Knowledge – Easy

- **Category:** Blockchain
- **CTF Event:** UMCS CTF 2025
- **Difficulty:** Easy

---

## Challenge Files

- [`ZKChallenge.sol`](src/ZKChallenge.sol)

This is an on-chain challenge deployed on Scroll testnet. No file was given for this challenge, but a [ScrollScan link](https://sepolia.scrollscan.com/address/0xb980702a8c8d32bf0f9381accfa271779132f1b2) was given. This `ZKChallenge.sol` was retrieved from the link.

---

## Objective

### `ZKChallenge.sol`

```solidity
function getFlag() external view returns (string memory) {
   require(proofs[msg.sender].verified, "Proof not verified");
   return flagHolder.getFlag();
}
```

The main goal is to verify your proof as required in the `getFlag()` function in the `ZKChallenge` contract.

---

## Code Analysis

### `ZKChallenge.sol`

```solidity
// SPDX-License-Identifier: MIT
//Created For UMCS CTF 2025 By MaanVader
pragma solidity ^0.8.0;

interface IFlagHolder {
    function getFlag() external view returns (string memory);
}

contract ZKChallenge {
    uint256 public constant G = 7;
    uint256 public constant P = 23;
    uint256 public constant H = 5;
    
    struct Proof {
        uint256 commitment;
        uint256 challenge;
        uint256 response;
        bool verified;
    }
    
    mapping(address => Proof) public proofs;
    bool private solved;
    IFlagHolder public immutable flagHolder;
    
    event ProofSubmitted(address indexed player, uint256 commitment);
    event ProofVerified(address indexed player);
    
    constructor(address _flagHolder) {
      flagHolder = IFlagHolder(_flagHolder);
    }
    
    function submitCommitment(uint256 _commitment) external {
        require(!proofs[msg.sender].verified, "Proof already verified"); 
        require(_commitment < P, "Invalid commitment");
        
        uint256 challenge = uint256(keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            _commitment
        ))) % P;
        
        proofs[msg.sender] = Proof({
            commitment: _commitment,
            challenge: challenge,
            response: 0,
            verified: false
        });
        
        emit ProofSubmitted(msg.sender, _commitment);
    }
    
    function verifyProof(uint256 _response) external { // can only be 1-10
        require(proofs[msg.sender].commitment != 0, "No commitment submitted");
        require(!proofs[msg.sender].verified, "Proof already verified");
        require(_response < P, "Invalid response");
        
        uint256 leftSide = modPow(G, _response, P);
        uint256 rightSide = (proofs[msg.sender].commitment * modPow(H, proofs[msg.sender].challenge, P)) % P;
        
        require(leftSide == rightSide, "Invalid proof");
        require(_response > 0 && _response <= 10, "Invalid secret range");
        
        proofs[msg.sender].verified = true;
        emit ProofVerified(msg.sender);
    }
    
    function getFlag() external view returns (string memory) {
        require(proofs[msg.sender].verified, "Proof not verified");
        return flagHolder.getFlag();
    }
    
    function modPow(
        uint256 base,
        uint256 exponent,
        uint256 modulus
    ) internal pure returns (uint256) {
        if (modulus == 0) return 0;
        
        uint256 result = 1;
        base = base % modulus;
        
        while (exponent > 0) {
            if (exponent % 2 == 1) {
                result = (result * base) % modulus;
            }
            base = (base * base) % modulus;
            exponent = exponent / 2;
        }
        
        return result;
    }
}
```

The ZKChallenge contract implements a simple zero-knowledge proof-of-knowledge protocol using small constants for demonstration. The goal is to prove knowledge of a secret value within a limited range (1–10) by submitting our proof (secret value) in the `verifyProof()` function. However, before submitting our proof, we need to submit our commitment first as defined in the `verifyProof()`. To submit our commitment, we need to call the `submitCommitment()` function with a value of `_commitment` that is smaller than `P` (23), and submitted commitment value will be used to contribute in the calculation of the value `challenge` which will be used to contribute in a calculation later on in the `verifyProof()` funciton. In the `verifyProof()`, we can observed that it use `modPow()` with the input parameter `_response` and also two constant (`G` and `P`) to calculate `leftSide`. After that, it use the submitted commitment, `challenge` value, `H`, and`P` to calculate `rightSide`. To let the proof to be verified, the calculated `leftSide` need to be equal to `rightSide`. Once the proof are being verified, we are able to call the `getFlag()` function to see the flag.

---

## Exploitation

To solve this challenge, you need to pass the zero-knowledge proof by submitting a valid commitment and response. Since the secret must be between 1 and 10, you can brute-force all possible values. For each possible secret, you submit a commitment, then check if the proof equation holds for that value. Once you find a matching response, you call `verifyProof()` to mark your proof as verified. After verification, you can call `getFlag()` to retrieve the flag. The script automates this process by iterating through all possible secrets and checking the proof equation until it succeeds. If you get a error message showing Proof not verified, you may rerun the script a few times to let the `leftSideEquation` equal to the `rightSideEquation`.

```solidity
function run() public returns (string memory) {
   // Start broadcasting transactions    
   vm.startBroadcast(YOUR_OWN_PUBLIC_ADDRESS);
   console.log("msg.sender", msg.sender);
   // Calculate the commitment: G^secret mod P
   for (uint256 i = 1; i <= 10; i++) {
      console.log("Submitting commitment...");
      uint256 commitment = 22;
      vm.prevrandao(bytes32(uint256(42)));
      zkChallenge.submitCommitment(commitment); // need to be less than 23
      uint256 leftSideEquation = modPow(G, i, P);
      console.log("LeftSide modPow(G, _response, P)", i, leftSideEquation);

      // Get the challenge generated by the contract
      (, uint256 challenge, ,bool verified ) = zkChallenge.proofs(msg.sender);
      console.log("Challenge received from contract:", challenge);
      uint256 challenge1 = uint256(keccak256(abi.encodePacked(block.prevrandao,block.timestamp,msg.sender,commitment))) % P;
      console.log("Challenge calculated by us:", challenge1);
 
      uint256 rightSideEquation = (22 * modPow(H, challenge, P)) % P;

      if (leftSideEquation == rightSideEquation) {
         console.log("Challenge matched with left side equation", rightSideEquation, leftSideEquation);
         console.log("Proof verified with response:", i);
         zkChallenge.verifyProof(i); // Verify the proof with the response
         (,  , ,bool verified2 ) = zkChallenge.proofs(msg.sender);
         console.log("verified", verified2);
         if (verified2) {
            console.log("Proof already verified");
         } else {
            console.log("Proof not verified");
         }
         break;
      } else {
         console.log("Challenge did not match with left side equation", rightSideEquation, leftSideEquation);
      }
   }
   string memory flag = zkChallenge.getFlag();
        
   vm.stopBroadcast();
   console.log("Exploit completed. \n\n");
   return flag;
}
```

After running the script, it will return a error but you will still get the flag. It is because that even if `leftSideEquation == rightSideEquation` in the script, the contract's `verifyProof()` function recomputes the challenge using the on-chain values, which may differ from our local calculation. Thus, it will cause the `require(leftSide == rightSide, "Invalid proof");` check to fail, resulting in a revert. See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Script

```bash
forge script script/Exploit.s.sol:Exploit --broadcast --rpc-url $RPC_URL --private-key $PK
```

Please kindly save the variables in the `.env` file. However, and please don't save your private key in plaint text in production!

---