// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Stack.sol";

// create a user defined type that is a pointer to memory
type Memory is bytes32;

library MemoryLib {
    using StackLib for Stack;
    uint256 internal constant ptr_mask = 0x1fffffffffffffffffffff;
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