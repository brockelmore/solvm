// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;
import "./Stack.sol";
import "./Memory.sol";
import "./Storage.sol";
import "./EvmContext.sol";
import "memmove/Array.sol";
import "memmove/Mapping.sol";

// create a user defined type that is a pointer to memory
type Evm is bytes32;

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

    function setupOpTable() internal view returns (Array ops) {
        ops = ArrayLib.newArray(0x5a);
        // set capacity
        assembly ("memory-safe") {
            mstore(ops, 0x5a)
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
    }

    function context(Evm self) internal pure returns (EvmContext memory ctx) {
        assembly ("memory-safe") {
            ctx := self
        }
    }

    function evaluate(Evm self, bytes memory bytecode) internal view returns (bool success, bytes memory ret) {
        (success, ret) = evaluate(self, bytecode, 32, 10, 32);
    }

    function evaluate(Evm self, bytes memory bytecode, uint16 stackSizeHint, uint16 storageSizeHint, uint32 memSizeHint) internal view returns (bool success, bytes memory ret) {
        Array ops = setupOpTable();

        EvmContext memory ctx = context(self);

        // stack capacity unlikely to surpass 32 words
        Stack stack = StackLib.newStack(stackSizeHint);
        
        // creates a storage map
        Storage store = StorageLib.newStorage(storageSizeHint);

        // mem capacity unlikely to surpass 32 words, but likely not a big deal if it does
        // (assuming no stack/storage/ctx moves)
        Memory mem = MemoryLib.newMemory(memSizeHint);

        success = true;
        ret = "";
        uint256 i = 0;

        while (i < bytecode.length) {
            uint256 op;
            assembly ("memory-safe") {
                op := shr(248, mload(add(add(0x20, bytecode), i)))
            }

            // we only use the optable for opcodes <= 0x5a, so try to short circuit
            if (op <= 0x5a) {
                if (op == 0x56) {
                    // jump
                    i = stack.pop();
                    // check for jumpdest
                    assembly ("memory-safe") {
                        op := shr(248, mload(add(add(0x20, bytecode), i)))
                    }
                    if (op != 0x5b) {
                        ret = "invalid jump";
                        success = false;
                        break;
                    }
                } else if (op == 0x57) {
                    // jumpi
                    uint256 jump_loc = stack.pop();
                    uint256 b = stack.pop();
                    if (b != 0) {
                        i = jump_loc;
                        // check for jumpdest
                        assembly ("memory-safe") {
                            op := shr(248, mload(add(add(0x20, bytecode), i)))
                        }
                        if (op != 0x5b) {
                            ret = "invalid jump";
                            success = false;
                            break;
                        }
                    }
                } else if (op == 0x38) {
                    // codesize
                    stack = stack.push(bytecode.length, 0);
                } else if (op == 0x39) {
                    // codecopy
                    codecopy(stack, mem, bytecode);
                } else if (op == 0x58) {
                    // pc
                    stack = stack.push(i, 0);
                } else {
                    // any op not specifically handled
                    (stack, mem, store, ctx) = intoOp(ops.unsafe_get(op))(mem, stack, store, ctx);
                }
            } else if (op >= 0x60 && op <= 0x7F) {
                // pushN
                (stack, i) = push(stack, bytecode, op, i);
            } else if (op >= 0x80 && op <= 0x8F) {
                // dupN
                uint256 index = op - 0x7F;
                stack = stack.dup(index);
            } else if (op >= 0x90 && op <= 0x9F) {
                // swapN
                uint256 index = op - 0x8F;
                stack.swap(index);
            } else if (op == 0) {
                // STOP
                break;
            } else if (op == 0xF3) {
                // return
                ret = stack._return(mem);
                break;
            } else if (op == 0xFD) {
                // revert
                ret = stack._revert(mem);
                success = false;
                break;
            }

            ++i;
        }
    }

    function codecopy(Stack stack, Memory mem, bytes memory bytecode) internal view {
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