// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;
import "./Stack.sol";
import "memmove/Array.sol";

// create a user defined type that is a pointer to memory
type Evm is bytes32;

library EvmLib {
    using StackLib for Stack;
    using MathOps for Stack;
    using BinOps for Stack;
    using ControlFlow for Stack;
    using MemoryLib for Memory;
    using ArrayLib for Array;

    function evaluate(Evm self, bytes memory bytecode) internal view returns (bool success, bytes memory ret) {
        Array ops = ArrayLib.newArray(256);
        // set capacity
        assembly ("memory-safe") {
            mstore(ops, 256)
        }

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
        // ops.unsafe_set(0x0b, intoStackOpPtr(MathOps.signextend));
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

        // only 1 push op, handle different ones in the push function
        ops.unsafe_set(0x60, intoPushPtr(push));

        // stack capacity unlikely to surpass 32 words
        Stack stack = StackLib.newStack(32);
        // mem capacity unlikely to surpass 32 words, but likely not a big deal if it does
        // (assuming no stack moves)
        Memory mem = MemoryLib.newMemory(32);
        success = true;
        ret = "";
        uint256 i = 0;

        // function(Stack) a = MathOps.add;

        while (i < bytecode.length) {
            uint256 op;
            assembly ("memory-safe") {
                op := shr(248, mload(add(add(0x20, bytecode), i)))
            }

            if (op < 0x20) {
                intoStackOp(ops.unsafe_get(op))(stack);
            } else if (op >= 0x60 && op <= 0x7F) {
                (stack, i) = intoPushOp(ops.unsafe_get(0x60))(stack, bytecode, op, i);
            }

            // would be nice if we could do a lookup table
            // if (op == 0) {
            //  break;
            // } else if (op == 1) {
            //  stack.add();
            // } else if (op == 2) {
            //  stack.mul();
            // } else if (op == 3) {
            //  stack.sub();
            // } else if (op == 4) {
            //  stack.div();
            // } else if (op == 5) {
            //  stack.sdiv();
            // } else if (op == 6) {
            //  stack.mod();
            // } else if (op == 7) {
            //  stack.smod();
            // } else if (op == 8) {
            //  stack._addmod();
            // } else if (op == 9) {
            //  stack._mulmod();
            // } else if (op == 0x0A) {
            //  stack._exp();
            // } else if (op == 0x0B) {
            //  require(false, "sign ext not supported");
            // } else if (op == 0x10) {
            //  stack.lt();
            // } else if (op == 0x11) {
            //  stack.gt();
            // } else if (op == 0x12) {
            //  stack.slt();
            // } else if (op == 0x13) {
            //  stack.sgt();
            // } else if (op == 0x14) {
            //  stack.eq();
            // } else if (op == 0x15) {
            //  stack.iszero();
            // } else if (op == 0x16) {
            //  stack.and();
            // } else if (op == 0x17) {
            //  stack.or();
            // } else if (op == 0x18) {
            //  stack.xor();
            // } else if (op == 0x19) {
            //  stack.not();
            // } else if (op == 0x51) {
            //  mem.mload(stack);
            // } else if (op == 0x52) {
            //  mem.mstore(stack);
            // } else if (op >= 0x60 && op <= 0x7F) {
            //  uint256 pushBytes;
            //  assembly ("memory-safe") {
            //      let full_word := mload(add(add(0x20, bytecode), add(i, 0x01)))
            //      let size := add(sub(op, 0x60), 0x01)
            //      i := add(size, i)
            //      pushBytes := shr(sub(256, mul(size, 8)), full_word)
            //  }
            //  stack = stack.push(pushBytes);
            // } else if (op == 80) {
            //  stack.pop();
            // } else if (op == 0xF3) {
            //  ret = stack._return(mem);
            // }else {
            //  require(false, "unsupported op");
            // }

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

    function intoMemOpPtr(function(Memory) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoMemStackOpPtr(function(Memory, Stack) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoStackMemOpPtr(function(Stack, Memory) op) internal pure returns (uint256 ptr) {
        assembly ("memory-safe") {
            ptr := op
        }
    }

    function intoStackOp(uint256 ptr) internal pure returns (function(Stack) view op) {
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

    function intoMemStackOp(uint256 ptr) internal pure returns (function(Memory, Stack) view op) {
        assembly ("memory-safe") {
            op := ptr
        }
    }
}