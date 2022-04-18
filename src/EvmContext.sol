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

    function _address(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(uint256(uint160(ctx.execution_address)), 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function _balance(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        bytes32 addr = bytes32(stack.pop());
        (, uint256 bal) = ctx.balances.get(addr);
        stack.unsafe_push(bal);
        s = stack;
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function origin(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(uint256(uint160(ctx.origin)), 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function caller(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(uint256(uint160(ctx.caller)), 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function callvalue(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.callvalue, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function calldataload(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        bytes memory calld = ctx.calld;
        uint256 word;
        uint256 offset = stack.pop();
        assembly ("memory-safe") {
            word := mload(add(calld, offset))
        }
        stack.unsafe_push(word);
        s = stack;
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function calldatasize(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.calld.length, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function calldatacopy(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        bytes memory calld = ctx.calld;
        uint256 destOffset = stack.pop();
        uint256 offset = stack.pop();
        uint256 size = stack.pop();
        uint256 ptr_mask = MemoryLib.ptr_mask;

        // just use the identity precompile for simplicity
        assembly ("memory-safe") {
            pop(
                staticcall(
                    gas(), // pass gas
                    0x04,  // call identity precompile address 
                    add(calld, offset), // arg offset == pointer to calldata
                    size,  // arg size
                    add(and(mem, ptr_mask), destOffset), // set return buffer to memory ptr + destination offset
                    size   // identity just returns the bytes of the input so equal to argsize 
                )
            )
        }
        s = stack;
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function coinbase(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(uint256(uint160(ctx.coinbase)), 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function timestamp(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.timestamp, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function number(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.number, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function difficulty(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.difficulty, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function gaslimit(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.gaslimit, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function chainid(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.chainid, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function selfbalance(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        (, uint256 selfbal) = ctx.balances.get(bytes32(uint256(uint160(ctx.execution_address))));
        s = stack.push(selfbal, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }
    
    function basefee(Memory mem, Stack stack, Storage store, EvmContext memory ctx) internal view returns(Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = stack.push(ctx.basefee, 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }
}