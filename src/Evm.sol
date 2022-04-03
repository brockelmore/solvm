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


    error UnsupportedOp(uint256);

    function setupOpTable() internal view returns (Array ops) {
        ops = ArrayLib.newArray(256);
        // set capacity
        assembly ("memory-safe") {
            mstore(ops, 256)
        }

        // would be nice if we could use a lookup table instead but we cant
        // cuz no constant arrays in solidity
        ops.unsafe_set(0x01, intoStackOpPtr(MathOps.add));
        ops.unsafe_set(0x02, intoStackOpPtr(MathOps.mul));
        ops.unsafe_set(0x03, intoStackOpPtr(MathOps.sub));
        ops.unsafe_set(0x04, intoStackOpPtr(MathOps.div));
        ops.unsafe_set(0x05, intoStackOpPtr(MathOps.sdiv));
        ops.unsafe_set(0x06, intoStackOpPtr(MathOps.mod));
        ops.unsafe_set(0x07, intoStackOpPtr(MathOps.smod));
        ops.unsafe_set(0x08, intoStackOpPtr(MathOps._addmod));
        ops.unsafe_set(0x09, intoStackOpPtr(MathOps._mulmod));
        ops.unsafe_set(0x0a, intoStackOpPtr(MathOps._exp));
        ops.unsafe_set(0x0b, intoStackOpPtr(MathOps.signextend));
        ops.unsafe_set(0x10, intoStackOpPtr(MathOps.lt));
        ops.unsafe_set(0x11, intoStackOpPtr(MathOps.gt));
        ops.unsafe_set(0x12, intoStackOpPtr(MathOps.slt));
        ops.unsafe_set(0x13, intoStackOpPtr(MathOps.sgt));
        ops.unsafe_set(0x14, intoStackOpPtr(MathOps.eq));
        ops.unsafe_set(0x15, intoStackOpPtr(MathOps.iszero));

        ops.unsafe_set(0x16, intoStackOpPtr(BinOps.and));
        ops.unsafe_set(0x17, intoStackOpPtr(BinOps.or));
        ops.unsafe_set(0x18, intoStackOpPtr(BinOps.xor));
        ops.unsafe_set(0x19, intoStackOpPtr(BinOps.not));
        ops.unsafe_set(0x1a, intoStackOpPtr(BinOps._byte));
        ops.unsafe_set(0x1b, intoStackOpPtr(BinOps.not));
        ops.unsafe_set(0x1c, intoStackOpPtr(BinOps.not));
        ops.unsafe_set(0x1d, intoStackOpPtr(BinOps.not));

        ops.unsafe_set(0x20, intoStackMemOpPtr(Builtins._sha3));

        // evm context & state not currently available
        // 0x30 - 0x48

        ops.unsafe_set(0x50, intoStackOpPtr(StackLib._pop));

        ops.unsafe_set(0x51, intoMemStackOpPtr(MemoryLib.mload));
        ops.unsafe_set(0x52, intoMemStackOpPtr(MemoryLib.mstore));

        ops.unsafe_set(0x54, intoStorageStackOpPtr(StorageLib.sload));
        ops.unsafe_set(0x55, intoStorageStackOpPtr(StorageLib.sstore));

        ops.unsafe_set(0x5a, intoStackRetOpPtr(Builtins._gas));
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

    function evaluate(Evm self, bytes memory bytecode) internal view returns (bool success, bytes memory ret) {
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
            } else if (op < 0x20) {
                intoStackOp(ops.unsafe_get(op))(stack);
            } else if (op == 0x20) {
                intoStackMemOp(ops.unsafe_get(op))(stack, mem);
            } else if (op == 0x30) {
                stack = stack.push(uint256(uint160(ctx.execution_address)), 0);
            } else if (op == 0x31) {
                bytes32 addr = bytes32(stack.pop());
                (, uint256 bal) = ctx.balances.get(addr);
                stack.unsafe_push(bal);
            } else if (op == 0x32) {
                stack = stack.push(uint256(uint160(ctx.origin)), 0);
            } else if (op == 0x33) {
                stack = stack.push(uint256(uint160(ctx.caller)), 0);
            } else if (op == 0x34) {
                stack = stack.push(ctx.callvalue, 0);
            } else if (op == 0x35) {
                bytes memory calld = ctx.calld;
                uint256 word;
                uint256 offset = stack.pop();
                assembly ("memory-safe") {
                    word := mload(add(calld, offset))
                }
                stack.unsafe_push(word);
            } else if (op == 0x36) {
                stack = stack.push(ctx.calld.length, 0);
            } else if (op == 0x37) {
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
            } else if (op == 0x41) {
                stack = stack.push(uint256(uint160(ctx.coinbase)), 0);
            } else if (op == 0x42) {
                stack = stack.push(ctx.timestamp, 0);
            } else if (op == 0x43) {
                stack = stack.push(ctx.number, 0);
            } else if (op == 0x44) {
                stack = stack.push(ctx.difficulty, 0);
            } else if (op == 0x45) {
                stack = stack.push(ctx.gaslimit, 0);
            } else if (op == 0x46) {
                stack = stack.push(ctx.chainid, 0);
            } else if (op == 0x47) {
                (, uint256 selfbal) = ctx.balances.get(bytes32(uint256(uint160(ctx.execution_address))));
                stack = stack.push(selfbal, 0);
            } else if (op == 0x48) {
                stack = stack.push(ctx.basefee, 0);
            } else if (op == 0x50) {
                intoStackOp(ops.unsafe_get(op))(stack);
            } else if (op == 0x51 || op == 0x52) {
                (mem, stack) = intoMemStackOp(ops.unsafe_get(op))(mem, stack);
            } else if (op == 0x54 || op == 0x55) {
                intoStorageStackOp(ops.unsafe_get(op))(store, stack);
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
                revert UnsupportedOp(op);
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

    function intoStackOpPtr(function(Stack) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
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

    function intoMemOpPtr(function(Memory) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoMemStackOpPtr(function(Memory, Stack) view returns (Memory, Stack) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoStackMemOpPtr(function(Stack, Memory) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoStorageStackOpPtr(function(Storage, Stack) view op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoStorageStackOp(uint256 ptr) internal pure returns (function(Storage, Stack) view op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoStackOp(uint256 ptr) internal pure returns (function(Stack) view op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }


    function intoStackRetOp(uint256 ptr) internal pure returns (function(Stack) view returns (Stack) op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoStackRetOpPtr(function(Stack) view returns (Stack) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoMemOp(uint256 ptr) internal pure returns (function(Memory) view op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoStackMemOp(uint256 ptr) internal pure returns (function(Stack, Memory) view op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }

    function intoMemStackOp(uint256 ptr) internal pure returns (function(Memory, Stack) view returns (Memory, Stack) op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }
}