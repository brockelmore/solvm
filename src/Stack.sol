// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Memory.sol";
import "./EvmContext.sol";
import "./Storage.sol";

// create a user defined type that is a pointer to memory
type Stack is bytes32;

library StackLib {
    function newStack(uint16 capacityHint) internal pure returns (Stack s) {
        assembly ("memory-safe") {
            // grab free mem ptr
            s := mload(0x40)
            
            // update free memory pointer based on Stack's layout:
            //  + 32 bytes for capacity
            //  + 32 bytes for current unset pointer/length
            //  + 32*capacity
            //  + current free memory pointer (s is equal to mload(0x40)) 
            mstore(0x40, add(s, mul(add(0x02, capacityHint), 0x20)))

            // store the capacity in the second word (see memory layout above)
            mstore(add(0x20, s), capacityHint)

            // store length as 0 because otherwise the compiler may have rugged us
            mstore(s, 0x00)
        }
    }

    // capacity of elements before a move would occur
    function capacity(Stack self) internal pure returns (uint256 cap) {
        assembly ("memory-safe") {
            cap := mload(add(0x20, self))
        }
    }

    // number of set elements in the Stack
    function length(Stack self) internal pure returns (uint256 len) {
        assembly ("memory-safe") {
            len := mload(self)
        }
    }

    // overloaded to default push function with 0 overallocation
    function push(Stack self, uint256 elem) internal view returns (Stack ret) {
        ret = push(self, elem, 0);
    }

    // push an element safely into the Stack - will perform a move if needed as well as updating the free memory pointer
    // returns the new pointer.
    //
    // WARNING: if a move occurs, the user *must* update their pointer, thus the returned updated pointer. safest
    // method is *always* updating the pointer
    function push(Stack self, uint256 elem, uint256 overalloc) internal view returns (Stack) {
        Stack ret;
        assembly ("memory-safe") {
            // set the return ptr
            ret := self
            // check if length == capacity (meaning no more preallocated space)
            let len := mload(self)
            let capPtr := add(0x20, self)
            let cap := mload(capPtr)
            let freememptr := mload(0x40)
            switch eq(len, cap) 
            case 1 {
                // optimization: check if the free memory pointer is equal to the end of the preallocated space
                // if it is, we can just natively extend the Stack because nothing has been allocated *after*
                // us. i.e.:
                // evm_memory = [00...free_mem_ptr...Stack.length...Stack.lastElement]
                // this check compares free_mem_ptr to Stack.lastElement, if they are equal, we know there is nothing after
                //
                // optimization 2: length == capacity in this case (per above) so we can avoid an add to look at capacity
                // to calculate where the last element it
                let stack_size := mul(cap, 0x20)
                let endPtr := add(capPtr, stack_size)
                switch eq(freememptr, endPtr) 
                case 1 {
                    // the free memory pointer hasn't moved, i.e. free_mem_ptr == Stack.lastElement, just extend

                    // Add 1 to the Stack.capacity
                    mstore(capPtr, add(0x01, cap))

                    // the free mem ptr is where we want to place the next element
                    mstore(freememptr, elem)

                    // move the free_mem_ptr by a word (32 bytes. 0x20 in hex)
                    mstore(0x40, add(0x20, freememptr))

                    // update the length
                    mstore(self, add(0x01, len))
                }
                default {
                    // we couldn't do the above optimization, use the `identity` precompile to perform a memory move
                    // set the return ptr to the new Stack
                    ret := freememptr
                    capPtr := add(0x20, ret)
                    // move the Stack to the free mem ptr by using the identity precompile which just returns the values
                    pop(
                        staticcall(
                            gas(), // pass gas
                            0x04,  // call identity precompile address 
                            self,  // arg offset == pointer to self
                            stack_size,  // arg size: capacity + 2 * word_size (we add 2 to capacity to account for capacity and length words)
                            ret, // set return buffer to free mem ptr
                            stack_size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                    
                    // add the element to the end of the Stack
                    mstore(add(ret, stack_size), elem)

                    // add to the capacity
                    cap := add(add(0x01, overalloc), cap) // add one + overalloc to capacity
                    mstore(
                        capPtr, // new capacity ptr
                        cap
                    )

                    // add to length
                    mstore(ret, add(0x01, mload(ret)))

                    // update free memory pointer
                    // we also over allocate if requested
                    mstore(0x40, add(0x20, add(capPtr, mul(0x20, cap))))
                }
            }
            default {
                // we have capacity for the new element, store it
                mstore(
                    // mem_loc := len_ptr + (len + 2) * 32
                    // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                    add(self, mul(add(0x02, len), 0x20)), 
                    elem
                )

                // update length
                mstore(self, add(0x01, len))
            }
        }
        return ret;
    }

    // used when you *guarantee* that the Stack has the capacity available to be pushed to.
    // no need to update return pointer in this case
    //
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_push(Stack self, uint256 elem) internal pure {
        assembly ("memory-safe") {
            mstore(
                // mem_loc := capacity_ptr + (capacity + 2) * 32
                // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                add(self, mul(add(0x02, mload(self)), 0x20)),
                elem
            )

            // update length
            mstore(self, add(0x01, mload(self)))
        }
    }

    function pop(Stack self) internal pure returns (uint256 ret) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            ret := mload(last)
            mstore(self, sub(len, 0x01))
        }
    }

    function pop2(Stack self) internal pure returns (uint256 ret1, uint256 ret2) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            ret1 := mload(last)
            ret2 := mload(sub(last, 0x20))
            mstore(self, sub(len, 0x02))
        }
    }

    function pop3(Stack self) internal pure returns (uint256 ret1, uint256 ret2, uint256 ret3) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            ret1 := mload(last)
            ret2 := mload(sub(last, 0x20))
            ret3 := mload(sub(last, 0x40))
            mstore(self, sub(len, 0x03))
        }
    }

    function _pop(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32){
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function swap(Stack self, uint256 index) internal pure {
        assembly ("memory-safe") {
            let last := add(self, mul(add(0x01, mload(self)), 0x20))
            let to_swap := sub(last, mul(index, 0x20))
            let last_val := mload(last)
            let swap_val := mload(to_swap)
            mstore(last, to_swap)
            mstore(swap_val, last)
        }
    }

    function dup(Stack self, uint256 index) internal view returns (Stack s) {
        uint256 val;
        assembly ("memory-safe") {
            let last := add(self, mul(add(0x01, mload(self)), 0x20))
            let to_dup := sub(last, mul(index, 0x20))
            val := mload(to_dup)
        }

        s = push(self, val, 0);
    }
}

library MathOps {
    using StackLib for Stack;
    function add(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, add(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function mul(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, mul(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function sub(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, sub(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function div(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, div(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function sdiv(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        (uint256 inv_a, uint256 inv_b) = self.pop2();
        int256 a = int256(inv_a);
        int256 b = int256(inv_b);
        self.unsafe_push(uint256(a / b));
        return (self, mem, store, ctx);
    }

    function mod(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, mod(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function smod(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        (uint256 inv_a, uint256 inv_b) = self.pop2();
        int256 a = int256(inv_a);
        int256 b = int256(inv_b);
        self.unsafe_push(uint256(a % b));
        return (self, mem, store, ctx);
    }

    function _addmod(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let a := add(self, mul(add(0x01, len), 0x20))
            let b := sub(a, 0x20)
            let target := sub(a, 0x40)
            mstore(target, addmod(mload(a), mload(b), mload(target)))
            mstore(self, sub(len, 0x02))
        }
        return (self, mem, store, ctx);
    }

    function _mulmod(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let a := add(self, mul(add(0x01, len), 0x20))
            let b := sub(a, 0x20)
            let target := sub(a, 0x40)
            mstore(target, mulmod(mload(a), mload(b), mload(target)))
            mstore(self, sub(len, 0x02))
        }
        return (self, mem, store, ctx);
    }

    function _exp(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, exp(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function lt(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, lt(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function gt(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, gt(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function slt(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        (uint256 inv_a, uint256 inv_b) = self.pop2();
        int256 a = int256(inv_a);
        int256 b = int256(inv_b);
        bool c = a < b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
        return (self, mem, store, ctx);
    }

    function sgt(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        (uint256 inv_a, uint256 inv_b) = self.pop2();
        int256 a = int256(inv_a);
        int256 b = int256(inv_b);
        bool c = a > b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
        return (self, mem, store, ctx);
    }

    function eq(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, eq(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function iszero(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            mstore(last, iszero(mload(last)))
        }
        return (self, mem, store, ctx);
    }

    function signextend(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        (uint256 b, uint256 x) = self.pop2();
        uint256 c;
        assembly ("memory-safe") {
            c := signextend(b, x)
        }
        self.unsafe_push(c);
        return (self, mem, store, ctx);
    }
}

library BinOps {
    using StackLib for Stack;

    function and(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, and(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function or(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, or(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function xor(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, xor(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function not(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let target := add(self, mul(add(0x01, len), 0x20))
            mstore(target, not(mload(target)))
        }
        return (self, mem, store, ctx);
    }

    function _byte(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, byte(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function shl(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, shl(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function shr(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        assembly ("memory-safe") {
            // we only add one to get last element
            let len := mload(self)
            let last := add(self, mul(add(0x01, len), 0x20))
            let target := sub(last, 0x20) 
            mstore(target, shr(mload(last), mload(target)))
            mstore(self, sub(len, 0x01))
        }
        return (self, mem, store, ctx);
    }

    function sar(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32){
        (uint256 shift, uint256 inv_value) = self.pop2();
        int256 value = int256(inv_value);
        self.unsafe_push(uint256(value >> shift));
        return (self, mem, store, ctx);
    }
}

library Builtins {
    using StackLib for Stack;
    using MemoryLib for Memory;
    function _sha3(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        (uint256 offset, uint256 value) = self.pop2();
        uint256 hash = mem._sha3(offset, value);
        self.unsafe_push(hash);
        return (self, mem, store, ctx);
    }

    function _gas(Memory mem, Stack self, Storage store, bytes32 ctx) internal view returns (Stack, Memory, Storage, bytes32) {
        self = self.push(gasleft(), 0);
        return (self, mem, store, ctx);
    }
}

library ControlFlow {
    using StackLib for Stack;
    using MemoryLib for Memory;
    function _return(Stack self, Memory mem) internal pure returns (bytes memory ret) {
        (uint256 offset, uint256 size) = self.pop2();
        offset += mem.loc();
        assembly ("memory-safe") {
            ret := sub(offset, 0x20)
            mstore(ret, size)
        }
    }

    function _revert(Stack self, Memory mem) internal pure returns (bytes memory ret) {
        (uint256 offset, uint256 size) = self.pop2();
        offset += mem.loc();
        assembly ("memory-safe") {
            ret := sub(offset, 0x20)
            mstore(ret, size)
        }
    }
}