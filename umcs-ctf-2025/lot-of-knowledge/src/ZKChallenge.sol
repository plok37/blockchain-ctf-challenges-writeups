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