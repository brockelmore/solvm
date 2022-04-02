// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Evm.sol";
import "forge-std/Vm.sol";

contract EvmTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);

    using EvmLib for Evm;

    function setUp() public {}

    function testPush() public view {
        Evm evm;
        evm.evaluate(hex"6001");
    }

    function testPop() public view {
        Evm evm;
        evm.evaluate(hex"600150");
    }

    function testAdd() public view {
        Evm evm;
        evm.evaluate(hex"6001600101");
    }

    function testAddMany() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160010160010160010160205260206000F3");
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 4);
    }

    function testMul() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160030260205260206000F3");
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 3);
    }

    function testMSTORE() public view {
        Evm evm;
        evm.evaluate(hex"6001600352");
    }

    function testRet() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160205260206000F3");
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 1);
        emit log_named_bytes("ret", ret);
    }
}