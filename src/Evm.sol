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
        ops.unsafe_set(0x1b, intoPtr(BinOps.shl));
        ops.unsafe_set(0x1c, intoPtr(BinOps.shr));
        ops.unsafe_set(0x1d, intoPtr(BinOps.sar));

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
        ops.unsafe_set(0x59, intoPtr(MemoryLib.msize));

        ops.unsafe_set(0x5a, intoPtr(Builtins._gas));
    }

    function setupCompressedOpTable() internal view returns (Array ops) {
        // only use 16 bits
        ops = ArrayLib.newArray(6);
        // set capacity
        assembly ("memory-safe") {
            mstore(ops, 6)
        }

        // The internal function dispatch table works by reference.
        // since we reference pop first, it gets referenceId 1 so it will be most optimized
        uint256 fifth = 0;
        fifth = compress(fifth, 0x50, intoPtr(StackLib._pop));

        fifth = compress(fifth, 0x51, intoPtr(MemoryLib.mload));
        fifth = compress(fifth, 0x52, intoPtr(MemoryLib.mstore));
        fifth = compress(fifth, 0x53, intoPtr(MemoryLib.mstore8));

        uint256 zeroth;
        zeroth = compress(zeroth, 0x01, intoPtr(MathOps.add));
        zeroth = compress(zeroth, 0x02, intoPtr(MathOps.mul));
        zeroth = compress(zeroth, 0x03, intoPtr(MathOps.sub));
        zeroth = compress(zeroth, 0x04, intoPtr(MathOps.div));
        zeroth = compress(zeroth, 0x05, intoPtr(MathOps.sdiv));
        zeroth = compress(zeroth, 0x06, intoPtr(MathOps.mod));
        zeroth = compress(zeroth, 0x07, intoPtr(MathOps.smod));
        zeroth = compress(zeroth, 0x08, intoPtr(MathOps._addmod));
        zeroth = compress(zeroth, 0x09, intoPtr(MathOps._mulmod));
        zeroth = compress(zeroth, 0x0a, intoPtr(MathOps._exp));
        zeroth = compress(zeroth, 0x0b, intoPtr(MathOps.signextend));
        ops.unsafe_set(0, zeroth);

        uint256 first = 0;
        first = compress(first, 0x10, intoPtr(MathOps.lt));
        first = compress(first, 0x11, intoPtr(MathOps.gt));
        first = compress(first, 0x12, intoPtr(MathOps.slt));
        first = compress(first, 0x13, intoPtr(MathOps.sgt));
        first = compress(first, 0x14, intoPtr(MathOps.eq));
        first = compress(first, 0x15, intoPtr(MathOps.iszero));
        first = compress(first, 0x16, intoPtr(BinOps.and));
        first = compress(first, 0x17, intoPtr(BinOps.or));
        first = compress(first, 0x18, intoPtr(BinOps.xor));
        first = compress(first, 0x19, intoPtr(BinOps.not));
        first = compress(first, 0x1a, intoPtr(BinOps._byte));
        first = compress(first, 0x1b, intoPtr(BinOps.shl));
        first = compress(first, 0x1c, intoPtr(BinOps.shr));
        first = compress(first, 0x1d, intoPtr(BinOps.sar));
        ops.unsafe_set(1, first);

        uint256 second = 0;
        second = compress(second, 0x20, intoPtr(Builtins._sha3));
        ops.unsafe_set(2, second);

        uint256 third = 0;
        // Context
        third = compress(third, 0x30, intoPtr(EvmContextLib._address));
        third = compress(third, 0x31, intoPtr(EvmContextLib._balance));
        third = compress(third, 0x32, intoPtr(EvmContextLib.origin));
        third = compress(third, 0x33, intoPtr(EvmContextLib.caller));
        third = compress(third, 0x34, intoPtr(EvmContextLib.callvalue));
        third = compress(third, 0x35, intoPtr(EvmContextLib.calldataload));
        third = compress(third, 0x36, intoPtr(EvmContextLib.calldatasize));
        third = compress(third, 0x37, intoPtr(EvmContextLib.calldatacopy));
        ops.unsafe_set(3, third);

        uint256 fourth = 0;
        fourth = compress(fourth, 0x41, intoPtr(EvmContextLib.coinbase));
        fourth = compress(fourth, 0x42, intoPtr(EvmContextLib.timestamp));
        fourth = compress(fourth, 0x43, intoPtr(EvmContextLib.number));
        fourth = compress(fourth, 0x44, intoPtr(EvmContextLib.difficulty));
        fourth = compress(fourth, 0x45, intoPtr(EvmContextLib.gaslimit));
        fourth = compress(fourth, 0x46, intoPtr(EvmContextLib.chainid));
        fourth = compress(fourth, 0x47, intoPtr(EvmContextLib.selfbalance));
        fourth = compress(fourth, 0x48, intoPtr(EvmContextLib.basefee));
        ops.unsafe_set(4, fourth);



        fifth = compress(fifth, 0x54, intoPtr(StorageLib.sload));
        fifth = compress(fifth, 0x55, intoPtr(StorageLib.sstore));
        fifth = compress(fifth, 0x59, intoPtr(MemoryLib.msize));

        fifth = compress(fifth, 0x5a, intoPtr(Builtins._gas));
        ops.unsafe_set(5, fifth);
    }

    function compress(uint256 ptrs, uint256 op, uint256 ptr16bit) internal pure returns (uint256 ps) {
        uint256 placement = op % 16;
        ps = ptrs | ptr16bit << (240 - 16*placement);
    }

    function uncompress(Array combinedPtrs, uint256 op) internal pure returns (uint256 ptr) {
        uint256 index = op / 16;
        uint256 placement = op % 16;
        uint256 ptrs = combinedPtrs.unsafe_get(index);
        ptr = ptrs << (16*placement) >> 240;
    }

    function context(Evm self) internal pure returns (EvmContext memory ctx) {
        assembly ("memory-safe") {
            ctx := self
        }
    }

    function evaluate(Evm self, bytes memory bytecode) internal returns (bool success, bytes memory ret) {
        (success, ret) = evaluate(self, bytecode, 32, 10, 32);
    }

    function evaluate(Evm self, bytes memory bytecode, uint16 stackSizeHint, uint16 storageSizeHint, uint32 memSizeHint) internal returns (bool success, bytes memory ret) {
        Array ops = setupCompressedOpTable();

        bytes32 ctx = Evm.unwrap(self);

        // stack capacity unlikely to surpass 32 words
        Stack stack = StackLib.newStack(stackSizeHint);

        // creates a storage map
        Storage store = StorageLib.newStorage(storageSizeHint);

        // mem capacity unlikely to surpass 32 words, but likely not a big deal if it does
        // (assuming no stack/storage/ctx moves)
        Memory mem = MemoryLib.newMemory(memSizeHint);

        success = true;
        ret = "";
        uint256 bcodeLen = bytecode.length;
        uint256 start;
        assembly ("memory-safe") {
            start := add(0x20, bytecode)
        }
        for (uint256 i; i < bcodeLen; ++i) {
            uint256 op;
            assembly ("memory-safe") {
                op := shr(248, mload(add(start, i)))
            }

            // we only use the optable for opcodes <= 0x5a, so try to short circuit
            if (op == 0) {
                // STOP
                break;
            } else if (op <= 0x5a) {
                if (op >= 0x56 && op <= 0x58) {
                    if (op == 0x56) {
                        // jump
                        i = stack.pop();
                        // check for jumpdest
                        assembly ("memory-safe") {
                            op := shr(248, mload(add(start, i)))
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
                                op := shr(248, mload(add(start, i)))
                            }
                            if (op != 0x5b) {
                                ret = "invalid jump";
                                success = false;
                                break;
                            }
                        }
                    } else {
                        // pc, 0x58
                        stack = stack.push(i, 0);
                    }
                } else if (op == 0x38) {
                    // codesize
                    stack = stack.push(bcodeLen, 0);
                } else if (op == 0x39) {
                    // codecopy
                    codecopy(stack, mem, start);
                } else {
                    // any op not specifically handled
                    (stack, mem, store, ctx) = intoOp(uncompress(ops, op))(mem, stack, store, ctx);
                }
            } else if (op <= 0x7F) {
                // pushN
                (stack, i) = push(stack, start, op, i);
            } else if (op <= 0x8F) {
                // dupN
                uint256 index = op - 0x80;
                stack = stack.dup(index);
            } else if (op <= 0x9F) {
                // swapN
                uint256 index = op - 0x8F;
                stack.swap(index);
            } else if (op == 0xF3) {
                // return
                ret = stack._return(mem);
                break;
            } else if (op == 0xFD) {
                // revert
                ret = stack._revert(mem);
                success = false;
                break;
            } else {
                ret = "invalid op";
                success = false;
                break;
            }
        }
    }

    function codecopy(Stack stack, Memory mem, uint256 start) internal {
        uint256 destOffset = stack.pop();
        uint256 offset = stack.pop();
        uint256 size = stack.pop();
        uint256 ptr_mask = MemoryLib.ptr_mask;

        // just use the identity precompile for simplicity
        // TODO: unsafe. fix
        assembly ("memory-safe") {
            pop(
                staticcall(
                    gas(), // pass gas
                    0x04,  // call identity precompile address
                    add(start, offset), // arg offset == pointer to calldata
                    size,  // arg size
                    add(and(mem, ptr_mask), destOffset), // set return buffer to memory ptr + destination offset
                    size   // identity just returns the bytes of the input so equal to argsize
                )
            )
        }
    }

    function push(Stack self, uint256 start, uint256 op, uint256 i) internal view returns (Stack s, uint256 j) {
        if (op == 0x5f) {
            s = self.push(0);
            return (s, i);
        }
        uint256 pushBytes;
        assembly ("memory-safe") {
            let full_word := mload(add(start, add(i, 0x01)))
            let size := sub(op, 0x5f)
            j := add(size, i)
            pushBytes := shr(sub(256, mul(size, 8)), full_word)
        }
        s = self.push(pushBytes);
    }

    function intoPtr(function(Memory, Stack, Storage, bytes32) internal view returns (Stack, Memory, Storage, bytes32) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoOp(uint256 ptr) internal pure returns (function(Memory, Stack, Storage, bytes32) internal view returns (Stack, Memory, Storage, bytes32) op) {
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
