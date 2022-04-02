// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

// create a user defined type that is a pointer to memory
type Stack is bytes32;
type Memory is bytes32;

library MemoryLib {
    using StackLib for Stack;
    uint256 constant ptr_mask = 0x1fffffffffffffffffffff;
    function newMemory(uint32 capacityHint) internal pure returns (Memory m) {
        assembly ("memory-safe") {
            // grab free mem ptr
            m := mload(0x40)
            // update free mem ptr 
            mstore(0x40, add(m, mul(capacityHint, 0x20)))
            m := or(shl(85, capacityHint), m)
        }
    }

    function loc(Memory self) internal pure returns (uint256 startLoc) {
        assembly ("memory-safe") {
            startLoc := and(ptr_mask, self)
        }
    }

    function msize_internal(Memory self) internal pure returns (uint256 size) {
        assembly ("memory-safe") {
            size := shr(170, self)
        }
    }

    function msize(Memory self, Stack stack) internal view returns (Stack s) {
        s = stack.push(msize_internal(self), 0);
    }

    function mload(Memory self, Stack stack) internal view returns (Memory ret, Stack s) {
        uint256 offset = stack.pop();
        require(offset < msize_internal(self), "mem_load");
        uint256 word;
        assembly ("memory-safe") {
            word := mload(add(and(self, ptr_mask), offset))
        }
        s = stack.push(word, 0);
        ret = self;
    }

    function mstore(Memory self, Stack stack) internal view returns (Memory ret, Stack s) {
        uint256 offset = stack.pop();
        uint256 elem = stack.pop();
        s = stack;
        assembly ("memory-safe") {
            // set the return ptr
            ret := self
            // check if offset > capacity (meaning no more preallocated space)
            switch gt(offset, shr(171, shl(86, self))) 
            case 1 {
                // optimization: check if the free memory pointer is equal to the end of the preallocated space
                // if it is, we can just natively extend the Stack because nothing has been allocated *after*
                // us. i.e.:
                // evm_memory = [00...free_mem_ptr...Stack.length...Stack.lastElement]
                // this check compares free_mem_ptr to Stack.lastElement, if they are equal, we know there is nothing after
                //
                // optimization 2: length == capacity in this case (per above) so we can avoid an add to look at capacity
                // to calculate where the last element it
                switch eq(mload(0x40), add(and(self, ptr_mask), mul(shr(171, shl(86, self)), 0x20)))
                case 1 {
                    // the free memory pointer hasn't moved, i.e. free_mem_ptr == Memory.lastElement, just extend

                    // Add a word to the Memory.capacity & Memory.length
                    ret := add(add(self, shl(85, 0x20)), shl(170, 0x20))

                    // the free mem ptr is where we want to place the next element
                    mstore(mload(0x40), elem)

                    // move the free_mem_ptr by a word (32 bytes. 0x20 in hex)
                    mstore(0x40, add(0x20, mload(0x40)))
                }
                default {
                    // we couldn't do the above optimization, use the `identity` precompile to perform a memory move
                    
                    // move the Stack to the free mem ptr by using the identity precompile which just returns the values
                    let mem_size := shr(170, self)
                    pop(
                        staticcall(
                            gas(), // pass gas
                            0x04,  // call identity precompile address 
                            and(self, ptr_mask),  // arg offset == pointer to self
                            mem_size,  // arg size: capacity + 2 * word_size (we add 2 to capacity to account for capacity and length words)
                            mload(0x40), // set return buffer to free mem ptr
                            mem_size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                    
                    // add the element to the end of the Stack
                    mstore(add(mload(0x40), mem_size), elem)

                    // add to the capacity & length
                    ret := add(add(self, shl(85, 0x20)), shl(170, 0x20))

                    // set the return ptr to the new memory
                    ret := or(and(not(ptr_mask), ret), mload(0x40))

                    // update free memory pointer
                    mstore(0x40, add(add(mem_size, 0x20), mload(0x40)))
                }
            }
            default {
                // we have capacity for the new element, store it
                mstore(
                    // mem_loc := capacity_ptr + (capacity + 2) * 32
                    // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                    add(and(self, ptr_mask), offset), 
                    elem
                )
            }
        }
    }

    function _sha3(Memory self, uint256 offset, uint256 size) internal pure returns (uint256 ret) {
        assembly ("memory-safe") {
            let startLoc := and(ptr_mask, self)
            let off := add(startLoc, offset)
            ret := keccak256(off, size)
        }
    }
}

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

    function _pop(Stack self) internal pure {
        assembly ("memory-safe") {
            // we only add one to get last element
            let last := add(self, mul(add(0x01, mload(self)), 0x20))
            mstore(last, 0x00)
            mstore(self, sub(mload(self), 0x01))
        }
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
    function add(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a + b);
    }

    function mul(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a * b);
    }

    function sub(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a - b);
    }

    function div(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a / b);
    }

    function sdiv(Stack self) internal pure {
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        self.unsafe_push(uint256(a / b));
    }

    function mod(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a % b);
    }

    function smod(Stack self) internal pure {
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        self.unsafe_push(uint256(a % b));
    }

    function _addmod(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        uint256 N = self.pop();
        self.unsafe_push(addmod(a, b, N));
    }

    function _mulmod(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        uint256 N = self.pop();
        self.unsafe_push(mulmod(a, b, N));
    }

    function _exp(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 exponent = self.pop();
        self.unsafe_push(a**exponent);
    }

    function lt(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        bool c = a < b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
    }

    function gt(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        bool c = a > b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
    }

    function slt(Stack self) internal pure {
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        bool c = a < b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
    }

    function sgt(Stack self) internal pure {
        int256 a = int256(self.pop());
        int256 b = int256(self.pop());
        bool c = a > b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
    }

    function eq(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        bool c = a == b;
        uint256 d;
        assembly ("memory-safe") {
            d := c
        }
        self.unsafe_push(d);
    }

    function iszero(Stack self) internal pure {
        uint256 a = self.pop();
        self.unsafe_push(a == 0 ? 1 : 0);
    }

    function signextend(Stack self) internal pure {
        uint256 b = self.pop();
        uint256 x = self.pop();
        uint256 c;
        assembly ("memory-safe") {
            c := signextend(b, x)
        }
        self.unsafe_push(c);
    }
}

library BinOps {
    using StackLib for Stack;

    function and(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a & b);
    }

    function or(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a | b);
    }

    function xor(Stack self) internal pure {
        uint256 a = self.pop();
        uint256 b = self.pop();
        self.unsafe_push(a ^ b);
    }

    function not(Stack self) internal pure {
        uint256 a = self.pop();
        self.unsafe_push(~a);
    }

    function _byte(Stack self) internal pure {
        uint256 i = self.pop();
        uint256 x = self.pop();
        uint256 c;
        assembly ("memory-safe") {
            c := byte(i, x)
        }
        self.unsafe_push(c);
    }

    function shl(Stack self) internal pure {
        uint256 shift = self.pop();
        uint256 value = self.pop();
        self.unsafe_push(value << shift);
    }

    function shr(Stack self) internal pure {
        uint256 shift = self.pop();
        uint256 value = self.pop();
        self.unsafe_push(value >> shift);
    }

    function sar(Stack self) internal pure {
        uint256 shift = self.pop();
        int256 value = int256(self.pop());
        self.unsafe_push(uint256(value >> shift));
    }
}

library Builtins {
    using StackLib for Stack;
    using MemoryLib for Memory;
    function _sha3(Stack self, Memory mem) internal pure {
        uint256 offset = self.pop();
        uint256 value = self.pop();
        uint256 hash = mem._sha3(offset, value);
        self.unsafe_push(hash);
    }
}

library ControlFlow {
    using StackLib for Stack;
    using MemoryLib for Memory;
    function _return(Stack self, Memory mem) internal pure returns (bytes memory ret) {
        uint256 offset = self.pop() + mem.loc();
        uint256 size = self.pop();
        assembly ("memory-safe") {
            ret := offset
            mstore(ret, size)
        }
    }
}