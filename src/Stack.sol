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
            switch eq(mload(self), mload(add(0x20, self))) 
            case 1 {
                // optimization: check if the free memory pointer is equal to the end of the preallocated space
                // if it is, we can just natively extend the Stack because nothing has been allocated *after*
                // us. i.e.:
                // evm_memory = [00...free_mem_ptr...Stack.length...Stack.lastElement]
                // this check compares free_mem_ptr to Stack.lastElement, if they are equal, we know there is nothing after
                //
                // optimization 2: length == capacity in this case (per above) so we can avoid an add to look at capacity
                // to calculate where the last element it
                switch eq(mload(0x40), add(self, mul(add(0x02, mload(self)), 0x20))) 
                case 1 {
                    // the free memory pointer hasn't moved, i.e. free_mem_ptr == Stack.lastElement, just extend

                    // Add 1 to the Stack.capacity
                    mstore(add(0x20, self), add(0x01, mload(add(0x20, self))))

                    // the free mem ptr is where we want to place the next element
                    mstore(mload(0x40), elem)

                    // move the free_mem_ptr by a word (32 bytes. 0x20 in hex)
                    mstore(0x40, add(0x20, mload(0x40)))

                    // update the length
                    mstore(self, add(0x01, mload(self)))
                }
                default {
                    // we couldn't do the above optimization, use the `identity` precompile to perform a memory move
                    
                    // move the Stack to the free mem ptr by using the identity precompile which just returns the values
                    let Stack_size := mul(add(0x02, mload(self)), 0x20)
                    pop(
                        staticcall(
                            gas(), // pass gas
                            0x04,  // call identity precompile address 
                            self,  // arg offset == pointer to self
                            Stack_size,  // arg size: capacity + 2 * word_size (we add 2 to capacity to account for capacity and length words)
                            mload(0x40), // set return buffer to free mem ptr
                            Stack_size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                    
                    // add the element to the end of the Stack
                    mstore(add(mload(0x40), Stack_size), elem)

                    // add to the capacity
                    mstore(
                        add(0x20, mload(0x40)), // free_mem_ptr + word == new capacity word
                        add(add(0x01, overalloc), mload(add(0x20, mload(0x40)))) // add one + overalloc to capacity
                    )

                    // add to length
                    mstore(mload(0x40), add(0x01, mload(mload(0x40))))

                    // set the return ptr to the new Stack
                    ret := mload(0x40)

                    // update free memory pointer
                    // we also over allocate if requested
                    mstore(0x40, add(add(Stack_size, add(0x20, mul(overalloc, 0x20))), mload(0x40)))
                }
            }
            default {
                // we have capacity for the new element, store it
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
            let last := add(self, mul(add(0x01, mload(self)), 0x20))
            ret := mload(last)
            mstore(last, 0x00)
            mstore(self, sub(mload(self), 0x01))
        }
    }

    function _pop(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct){

        assembly ("memory-safe") {
            // we only add one to get last element
            let last := add(self, mul(add(0x01, mload(self)), 0x20))
            mstore(last, 0x00)
            mstore(self, sub(mload(self), 0x01))
        }
        s = self;
        ret = mem;
        stor = store;
        ct = ctx;
        ct = ctx;
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
    function add(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a + b);
        s = self;
    }

    function mul(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a * b);
        s = self;
    }

    function sub(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a - b);
        s = self;
    }

    function div(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a / b);
        s = self;
    }

    function sdiv(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        self.unsafe_push(uint256(a / b));
        s = self;
    }

    function mod(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a % b);
        s = self;
    }

    function smod(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        self.unsafe_push(uint256(a % b));
        s = self;
    }

    function _addmod(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        uint256 N = self.pop();
        self.unsafe_push(addmod(a, b, N));
        s = self;
    }

    function _mulmod(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        uint256 N = self.pop();
        self.unsafe_push(mulmod(a, b, N));
        s = self;
    }

    function _exp(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 exponent = self.pop();
        self.unsafe_push(a**exponent);
        s = self;
    }

    function lt(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        bool c = a < b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
        s = self;
    }

    function gt(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        bool c = a > b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
    }

    function slt(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        bool c = a < b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
        s = self;
    }

    function sgt(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        bool c = a > b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
        s = self;
    }

    function eq(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        uint256 a = self.pop();
        uint256 b = self.pop();
        bool c = a == b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
        s = self;
    }

    function iszero(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        self.unsafe_push(a == 0 ? 1 : 0);
        s = self;
    }

    function signextend(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 b = self.pop();
        uint256 x = self.pop();
        uint256 c;
        assembly ("memory-safe") {
            c := signextend(b, x)
        }
        self.unsafe_push(c);
        s = self;
    }
}

library BinOps {
    using StackLib for Stack;

    function and(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a & b);
        s = self;
    }

    function or(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a | b);
        s = self;
    }

    function xor(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a ^ b);
        s = self;
    }

    function not(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 a = self.pop();
        self.unsafe_push(~a);
        s = self;
    }

    function _byte(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 i = self.pop();
        uint256 x = self.pop();
        uint256 c;
        assembly ("memory-safe") {
            c := byte(i, x)
        }
        self.unsafe_push(c);
        s = self;
    }

    function shl(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 shift = self.pop();
        uint256 value = self.pop();
        self.unsafe_push(value << shift);
        s = self;
    }

    function shr(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 shift = self.pop();
        uint256 value = self.pop();
        self.unsafe_push(value >> shift);
        s = self;
    }

    function sar(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct){
        ret = mem;
        stor = store;
        ct = ctx;
        uint256 shift = self.pop();
        int256 value = int256(self.pop());
        self.unsafe_push(uint256(value >> shift));
        s = self;
    }
}

library Builtins {
    using StackLib for Stack;
    using MemoryLib for Memory;
    function _sha3(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        uint256 offset = self.pop();
        uint256 value = self.pop();
        uint256 hash = mem._sha3(offset, value);
        self.unsafe_push(hash);
        s = self;
        ret = mem;
        stor = store;
        ct = ctx;
    }

    function _gas(Memory mem, Stack self, Storage store, EvmContext memory ctx) internal view returns (Stack s, Memory ret, Storage stor, EvmContext memory ct) {
        s = self.push(gasleft(), 0);
        ret = mem;
        stor = store;
        ct = ctx;
    }
}

library ControlFlow {
    using StackLib for Stack;
    using MemoryLib for Memory;
    function _return(Stack self, Memory mem) internal pure returns (bytes memory ret) {
        uint256 offset = self.pop() + mem.loc();
        uint256 size = self.pop();
        assembly ("memory-safe") {
            ret := sub(offset, 0x20)
            mstore(ret, size)
        }
    }

    function _revert(Stack self, Memory mem) internal pure returns (bytes memory ret) {
        uint256 offset = self.pop() + mem.loc();
        uint256 size = self.pop();
        assembly ("memory-safe") {
            ret := sub(offset, 0x20)
            mstore(ret, size)
        }
    }
}