// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;
import "./Stack.sol";
import "./Memory.sol";
import "./Storage.sol";
import "memmove/Array.sol";
import "memmove/Mapping.sol";

struct EvmContext {
    address origin;
    address caller;
    address execution_address;
    uint256 callvalue;
    address coinbase;
    uint256 timestamp;
    uint256 number;
    uint256 gaslimit;
    uint256 difficulty;
    uint256 chainid;
    uint256 basefee;
    Mapping balances;
    bytes calld;
}

library EvmContextLib {
    using StackLib for Stack;
    using MemoryLib for Memory;
    using StorageLib for Storage;

    using ArrayLib for Array;
    using MappingLib for Mapping;

    function internalOrigin(bytes32 ct) internal pure returns (uint256 addr) {
        assembly ("memory-safe") {
            addr := mload(ct)
        }
    }

    function internalCaller(bytes32 ct) internal pure returns (uint256 addr) {
        assembly ("memory-safe") {
            addr := mload(add(ct, 0x20))
        }
    }

    function internalAddress(bytes32 ct) internal pure returns (uint256 addr) {
        assembly ("memory-safe") {
            addr := mload(add(ct, 0x40))
        }
    }

    function internalCallValue(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0x60))
        }
    }

    function internalCoinbase(bytes32 ct) internal pure returns (uint256 addr) {
        assembly ("memory-safe") {
            addr := mload(add(ct, 0x80))
        }
    }

    function internalTimestamp(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0xa0))
        }
    }

    function internalNumber(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0xc0))
        }
    }

    function internalGasLimit(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0xe0))
        }
    }

    function internalDifficulty(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0x100))
        }
    }

    function internalChainId(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0x120))
        }
    }

    function internalBaseFee(bytes32 ct) internal pure returns (uint256 val) {
        assembly ("memory-safe") {
            val := mload(add(ct, 0x140))
        }
    }

    function internalBalances(bytes32 ct) internal pure returns (Mapping map) {
        assembly ("memory-safe") {
            map := mload(add(ct, 0x160))
        }
    }

    function internalCallDataPtr(bytes32 ct) internal pure returns (bytes32 calldataPtr) {
        assembly ("memory-safe") {
            calldataPtr := add(ct, 0x180)
        }
    }

    function _address(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalAddress(ct), 0);
        return (stack, mem, store, ct);
    }

    function _balance(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        bytes32 addr = bytes32(stack.pop());
        Mapping balances = internalBalances(ct);
        (, uint256 bal) = balances.get(addr);
        stack.unsafe_push(bal);
        return (stack, mem, store, ct);
    }

    function origin(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalOrigin(ct), 0);
        return (stack, mem, store, ct);
    }

    function caller(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalCaller(ct), 0);
        return (stack, mem, store, ct);
    }

    function callvalue(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalCallValue(ct), 0);
        return (stack, mem, store, ct);
    }

    function calldataload(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        uint256 word;
        uint256 offset = stack.pop();
        assembly ("memory-safe") {
            let calldataPtr := add(ct, 0x180)
            word := mload(add(calldataPtr, offset))
        }
        stack.unsafe_push(word);
        return (stack, mem, store, ct);
    }

    function calldatasize(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        uint256 len;
        assembly ("memory-safe") {
            len := mload(add(ct, 0x180))
        }
        stack = stack.push(len, 0);
        return (stack, mem, store, ct);
    }

    function calldatacopy(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        (uint256 destOffset, uint256 offset, uint256 size) = stack.pop3();
        uint256 ptr_mask = MemoryLib.ptr_mask;

        // just use the identity precompile for simplicity
        // TODO: unsafe, fix
        assembly ("memory-safe") {
            let calldataPtr := add(ct, 0x180)
            pop(
                staticcall(
                    gas(), // pass gas
                    0x04,  // call identity precompile address 
                    add(calldataPtr, offset), // arg offset == pointer to calldata
                    size,  // arg size
                    add(and(mem, ptr_mask), destOffset), // set return buffer to memory ptr + destination offset
                    size   // identity just returns the bytes of the input so equal to argsize 
                )
            )
        }
        return (stack, mem, store, ct);
    }

    function coinbase(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalCoinbase(ct), 0);
        return (stack, mem, store, ct);
    }

    function timestamp(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalTimestamp(ct), 0);
        return (stack, mem, store, ct);
    }

    function number(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalNumber(ct), 0);
        return (stack, mem, store, ct);
    }

    function difficulty(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalDifficulty(ct), 0);
        return (stack, mem, store, ct);
    }

    function gaslimit(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalGasLimit(ct), 0);
        return (stack, mem, store, ct);
    }

    function chainid(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalChainId(ct), 0);
        return (stack, mem, store, ct);
    }

    function selfbalance(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        Mapping balances = internalBalances(ct);

        (, uint256 selfbal) = balances.get(bytes32(internalAddress(ct)));
        stack = stack.push(selfbal, 0);
        return (stack, mem, store, ct);
    }
    
    function basefee(Memory mem, Stack stack, Storage store, bytes32 ct) internal view returns(Stack, Memory, Storage, bytes32) {
        stack = stack.push(internalBaseFee(ct), 0);
        return (stack, mem, store, ct);
    }
}