// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "memmove/Mapping.sol";
import "./Stack.sol";

// create a user defined type that is a pointer to memory
type Storage is bytes32;

library StorageLib {
    using StackLib for Stack;
    using MappingLib for Mapping;
    
    function newStorage(uint16 capacityHint) internal pure returns (Storage m) {
        Mapping map = MappingLib.newMapping(capacityHint);
        m = Storage.wrap(Mapping.unwrap(map));
    }

    function sload(Storage self, Stack stack) internal pure {
        Mapping map = Mapping.wrap(Storage.unwrap(self));
        uint256 key = stack.pop();
        (, uint256 value) = map.get(bytes32(key));
        stack.unsafe_push(value);
    }

    function sstore(Storage self, Stack stack) internal pure {
        Mapping map = Mapping.wrap(Storage.unwrap(self));
        uint256 key = stack.pop();
        uint256 value = stack.pop();
        map.insert(bytes32(key), value);
    }
}