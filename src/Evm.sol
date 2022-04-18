// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;
import "./Stack.sol";
import "./Memory.sol";
import "./Storage.sol";
import "memmove/Array.sol";
import "memmove/Mapping.sol";

// create a user defined type that is a pointer to memory
type Evm is bytes32;


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


library EvmLib {
    using StackLib for Stack;
    using MathOps for Stack;
    using BinOps for Stack;
    using Builtins for Stack;
    using ControlFlow for Stack;
    
    using MemoryLib for Memory;

    using StorageLib for Storage;

    using ArrayLib for Array;
    using MappingLib for Mapping;

    function newEvm(
        EvmContext memory ctx
    ) internal pure returns (Evm e) {
        assembly ("memory-safe") {
            e := ctx
        }
    }

    event log_named_uint         (string key, uint val);


    error UnsupportedOp(uint256);

    function setupOpTable() internal view returns (Array ops) {
        ops = ArrayLib.newArray(256);
        // set capacity
        assembly ("memory-safe") {
            mstore(ops, 256)
        }

        // stack
        ops.unsafe_set(0x01, intoPtr(MathOps.add));
        ops.unsafe_set(0x02, intoPtr(MathOps.mul));
        ops.unsafe_set(0x03, intoPtr(MathOps.sub));
        ops.unsafe_set(0x04, intoPtr(MathOps.div));
        ops.unsafe_set(0x05, intoPtr(MathOps.sdiv));
        ops.unsafe_set(0x06, intoPtr(MathOps.mod));
        ops.unsafe_set(0x07, intoPtr(MathOps.smod));
        ops.unsafe_set(0x08, intoPtr(MathOps._addmod));
        ops.unsafe_set(0x09, intoPtr(MathOps._mulmod));
        ops.unsafe_set(0x0a, intoPtr(MathOps._exp));
        ops.unsafe_set(0x0b, intoPtr(MathOps.signextend));
        ops.unsafe_set(0x10, intoPtr(MathOps.lt));
        ops.unsafe_set(0x11, intoPtr(MathOps.gt));
        ops.unsafe_set(0x12, intoPtr(MathOps.slt));
        ops.unsafe_set(0x13, intoPtr(MathOps.sgt));
        ops.unsafe_set(0x14, intoPtr(MathOps.eq));
        ops.unsafe_set(0x15, intoPtr(MathOps.iszero));

        ops.unsafe_set(0x16, intoPtr(BinOps.and));
        ops.unsafe_set(0x17, intoPtr(BinOps.or));
        ops.unsafe_set(0x18, intoPtr(BinOps.xor));
        ops.unsafe_set(0x19, intoPtr(BinOps.not));
        ops.unsafe_set(0x1a, intoPtr(BinOps._byte));
        ops.unsafe_set(0x1b, intoPtr(BinOps.not));
        ops.unsafe_set(0x1c, intoPtr(BinOps.not));
        ops.unsafe_set(0x1d, intoPtr(BinOps.not));

        ops.unsafe_set(0x20, intoPtr(Builtins._sha3));

        // Context
        ops.unsafe_set(0x30, intoPtr(EvmContextLib._address));
        ops.unsafe_set(0x31, intoPtr(EvmContextLib._balance));
        ops.unsafe_set(0x32, intoPtr(EvmContextLib.origin));
        ops.unsafe_set(0x33, intoPtr(EvmContextLib.caller));
        ops.unsafe_set(0x34, intoPtr(EvmContextLib.callvalue));
        ops.unsafe_set(0x35, intoPtr(EvmContextLib.calldataload));
        ops.unsafe_set(0x36, intoPtr(EvmContextLib.calldatasize));
        ops.unsafe_set(0x37, intoPtr(EvmContextLib.calldatacopy));

        ops.unsafe_set(0x41, intoPtr(EvmContextLib.coinbase));
        ops.unsafe_set(0x42, intoPtr(EvmContextLib.timestamp));
        ops.unsafe_set(0x43, intoPtr(EvmContextLib.number));
        ops.unsafe_set(0x44, intoPtr(EvmContextLib.difficulty));
        ops.unsafe_set(0x45, intoPtr(EvmContextLib.gaslimit));
        ops.unsafe_set(0x46, intoPtr(EvmContextLib.chainid));
        ops.unsafe_set(0x47, intoPtr(EvmContextLib.selfbalance));
        ops.unsafe_set(0x48, intoPtr(EvmContextLib.basefee));

        ops.unsafe_set(0x50, intoPtr(StackLib._pop));

        ops.unsafe_set(0x51, intoPtr(MemoryLib.mload));
        ops.unsafe_set(0x52, intoPtr(MemoryLib.mstore));

        ops.unsafe_set(0x54, intoPtr(StorageLib.sload));
        ops.unsafe_set(0x55, intoPtr(StorageLib.sstore));

        ops.unsafe_set(0x5a, intoPtr(Builtins._gas));

        // ops.unsafe_set(0x5b, intoStackRetOpPtr(Builtins.jumpdest));
        // only 1 push op, handle different ones in the push function
        ops.unsafe_set(0x60, intoPushPtr(push));

        // only 1 dup op, handle different ones in the dup function
        ops.unsafe_set(0x80, intoDupOpPtr(StackLib.dup));

        // only 1 swap op, handle different ones in the swap function
        ops.unsafe_set(0x90, intoSwapOpPtr(StackLib.swap));
    }

    function context(Evm self) internal pure returns (EvmContext memory ctx) {
        assembly ("memory-safe") {
            ctx := self
        }
    }

    function evaluate(Evm self, bytes memory bytecode) internal returns (bool success, bytes memory ret) {
        Array ops = setupOpTable();

        EvmContext memory ctx = context(self);

        // stack capacity unlikely to surpass 32 words
        Stack stack = StackLib.newStack(32);
        
        // creates a storage map
        Storage store = StorageLib.newStorage(10);

        // mem capacity unlikely to surpass 32 words, but likely not a big deal if it does
        // (assuming no stack moves)
        Memory mem = MemoryLib.newMemory(32);

        

        success = true;
        ret = "";
        uint256 i = 0;

        bool was_jump = false;

        // semantics can be improved by moving to a `RefStack` and `RefMemory` system
        //
        // gas can be improved by making all functions have the same interface, i.e.:
        // function(Stack, Memory, Storage) internal view returns (Stack, Memory, Storage)
        //
        // this would allow for removal 90% of the if else clause below
        while (i < bytecode.length) {
            uint256 op;
            assembly ("memory-safe") {
                op := shr(248, mload(add(add(0x20, bytecode), i)))
            }

            if (was_jump) {
                if (op != 0x5b) {
                    ret = "invalid jump";
                    success = false;
                    break;
                } else {
                    was_jump = false;
                    continue;
                }
            }

            if (op == 0) {
                break;
            } else if (op == 0x38) {
                stack = stack.push(bytecode.length, 0);
            } else if (op == 0x39) {
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
                            add(bytecode, offset), // arg offset == pointer to calldata
                            size,  // arg size
                            add(and(mem, ptr_mask), destOffset), // set return buffer to memory ptr + destination offset
                            size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                }
            } else if (op == 0x56) {
                // jump
                i = stack.pop();
                was_jump = true;
                continue;
            } else if (op == 0x57) {
                // jumpi
                uint256 jump_loc = stack.pop();
                uint256 b = stack.pop();
                if (b != 0) {
                    i = jump_loc;
                    was_jump = true;
                    continue;
                }
            } else if (op == 0x58) {
                stack = stack.push(i, 0);
            } else if (op >= 0x60 && op <= 0x7F) {
                (stack, i) = intoPushOp(ops.unsafe_get(0x60))(stack, bytecode, op, i);
            } else if (op >= 0x80 && op <= 0x8F) {
                uint256 index = op - 0x7F;
                stack = intoDupOp(ops.unsafe_get(0x80))(stack, index);
            } else if (op >= 0x90 && op <= 0x9F) {
                uint256 index = op - 0x8F;
                intoSwapOp(ops.unsafe_get(0x90))(stack, index);
            } else if (op == 0xF3) {
                ret = stack._return(mem);
                break;
            } else if (op == 0xFD) {
                ret = stack._revert(mem);
                success = false;
                break;
            } else {
                (stack, mem, store, ctx) = intoOp(ops.unsafe_get(op))(mem, stack, store, ctx);
            }

            ++i;
        }
    }

    function push(Stack self, bytes memory bytecode, uint256 op, uint256 i) internal view returns (Stack s, uint256 j) {
        uint256 pushBytes;
        assembly ("memory-safe") {
            let full_word := mload(add(add(0x20, bytecode), add(i, 0x01)))
            let size := add(sub(op, 0x60), 0x01)
            j := add(size, i)
            pushBytes := shr(sub(256, mul(size, 8)), full_word)
        }
        s = self.push(pushBytes);
    }

    function intoPtr(function(Memory, Stack, Storage, EvmContext memory) internal view returns (Stack, Memory, Storage, EvmContext memory) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoOp(uint256 ptr) internal pure returns (function(Memory, Stack, Storage, EvmContext memory) internal view returns (Stack, Memory, Storage, EvmContext memory) op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoPushPtr(function(Stack, bytes memory, uint256, uint256) internal view returns (Stack, uint256) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoPushOp(uint256 ptr) internal pure returns (function(Stack, bytes memory, uint256, uint256) internal pure returns (Stack, uint256) op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoDupOpPtr(function(Stack, uint256) view returns (Stack) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoDupOp(uint256 ptr) internal pure returns (function(Stack, uint256) view returns (Stack) op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoSwapOpPtr(function(Stack, uint256) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoSwapOp(uint256 ptr) internal pure returns (function(Stack, uint256) view op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }
}