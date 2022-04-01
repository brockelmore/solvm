// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Evm.sol";
import "forge-std/Vm.sol";

contract EvmTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);

    using EvmLib for Evm;

    function setUp() public {}

    function testPush() public {
        Evm evm;
        evm.evaluate(hex"6001");
    }

    function testPop() public {
        Evm evm;
        evm.evaluate(hex"600150");
    }

    function testAdd() public {
        Evm evm;
        evm.evaluate(hex"6001600101");
    }

    function testAddMany() public {
        Evm evm;
        evm.evaluate(hex"6001600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101600101");
    }

    function testManual() public {
        uint256 j = 1;
        for (uint256 i; i < 500; i++) {
            j += 1;
        }
    }

    function testMul() public {
        Evm evm;
        evm.evaluate(hex"6001600302");
    }

    function testMSTORE() public {
        Evm evm;
        evm.evaluate(hex"6001600352");
    }

    function testRet() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160205260206000F3");
        emit log_named_bytes("ret", ret);
    }
}