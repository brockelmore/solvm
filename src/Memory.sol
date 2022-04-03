// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Stack.sol";

// create a user defined type that is a pointer to memory
type Memory is bytes32;

// size, capacity, ptr
library MemoryLib {
    using StackLib for Stack;
    uint256 internal constant ptr_mask = 0x1fffffffffffffffffffff;
    function newMemory(uint32 capacityHint) internal pure returns (Memory m) {
        assembly ("memory-safe") {
            // grab free mem ptr
            m := mload(0x40)
            // update free mem ptr 
            mstore(0x40, add(m, mul(capacityHint, 0x20)))
            m := or(shl(85, mul(capacityHint, 0x20)), m)
        }
    }

    function loc(Memory self) internal pure returns (uint256 startLoc) {
        assembly ("memory-safe") {
            startLoc := and(ptr_mask, self)
        }
    }

    function end(Memory self) internal pure returns (uint256 endLoc) {
        assembly ("memory-safe") {
            endLoc := add(and(ptr_mask, self), shr(171, shl(86, self)))
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
        uint256 offset = stack.pop() + loc(self);
        uint256 word;
        assembly ("memory-safe") {
            word := mload(offset)
        }
        s = stack.push(word, 0);
        ret = self;
    }

    function mstore(Memory self, Stack stack) internal view returns (Memory ret, Stack s) {
        uint256 offset = stack.pop() + loc(self);
        uint256 elem = stack.pop();
        uint256 endLoc = end(self);
        s = stack;
        assembly ("memory-safe") {
            // set the return ptr
            ret := self
            // check if offset > capacity (meaning no more preallocated space)
            switch gt(offset, endLoc) 
            case 1 {
                // optimization: check if the free memory pointer is equal to the end of the preallocated space
                // if it is, we can just natively extend the Stack because nothing has been allocated *after*
                // us. i.e.:
                // evm_memory = [00...free_mem_ptr...Stack.length...Stack.lastElement]
                // this check compares free_mem_ptr to Stack.lastElement, if they are equal, we know there is nothing after
                //
                switch eq(mload(0x40), endLoc)
                case 1 {
                    // the free memory pointer hasn't moved, i.e. free_mem_ptr == Memory.lastElement, just extend

                    // Add a word to the Memory.capacity & Memory.length
                    let startLoc := and(self, ptr_mask)
                    endLoc   := offset
                    let cap := sub(endLoc, startLoc)
                    ret := or(or(shl(85, cap), shl(170, cap)), startLoc)

                    // the free mem ptr is where we want to place the next element
                    mstore(offset, elem)

                    // move the free_mem_ptr by a word (32 bytes. 0x20 in hex)
                    mstore(0x40, add(endLoc, 0x20))
                }
                default {
                    // we couldn't do the above optimization, use the `identity` precompile to perform a memory move
                    
                    // move the Stack to the free mem ptr by using the identity precompile which just returns the values
                    let curr_loc := and(ptr_mask, self)
                    let mem_size := sub(endLoc, curr_loc)
                    pop(
                        staticcall(
                            gas(), // pass gas
                            0x04,  // call identity precompile address 
                            curr_loc,  // arg offset == pointer to self
                            mem_size,  // arg size: capacity + 2 * word_size (we add 2 to capacity to account for capacity and length words)
                            mload(0x40), // set return buffer to free mem ptr
                            mem_size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                    
                    // add the element to the end of the Stack
                    mstore(
                        offset, 
                        elem
                    )

                    let startLoc := mload(0x40)
                    endLoc   := offset
                    let cap := sub(endLoc, startLoc)
                    ret := or(or(shl(85, cap), shl(170, cap)), startLoc)

                    // update free memory pointer
                    mstore(0x40, add(endLoc, 0x20))
                }
            }
            default {
                // we have capacity for the new element, store it
                mstore(
                    // mem_loc := capacity_ptr + (capacity + 2) * 32
                    // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                    offset, 
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