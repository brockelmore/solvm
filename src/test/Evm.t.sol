// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "memmove/Mapping.sol";

import "../Evm.sol";

contract Sizing {
    using EvmLib for Evm;

    function run(
        address origin,
        address caller,
        address execution_address,
        bytes calldata calld,
        bytes calldata executionCode
    ) external {
        uint256 fee;
        uint256 id;
        assembly("memory-safe") {
            fee := basefee()
            id := chainid()
        }
        EvmContext memory ctx = EvmContext({
            origin: origin,
            caller: caller,
            execution_address: execution_address,
            callvalue: 0,
            coinbase: block.coinbase,
            timestamp: block.timestamp,
            number: block.number,
            gaslimit: block.gaslimit,
            difficulty: block.difficulty,
            chainid: id,
            basefee: fee,
            balances: MappingLib.newMapping(1),
            calld: calld
        });
        Evm evm = EvmLib.newEvm(ctx);
        evm.evaluate(executionCode);
    }
}

contract EvmTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);

    using EvmLib for Evm;
    using MappingLib for Mapping;

    function testPush() public view {
        Evm evm;
        evm.evaluate(hex"6001", 1, 0, 0);
    }

    function testPop() public view {
        Evm evm;
        evm.evaluate(hex"600150", 1, 0, 0);
    }

    function testAdd() public view {
        Evm evm;
        evm.evaluate(hex"6001600101", 2, 0, 0);
    }

    function testAddMany() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160010160010160010160005260206000F3", 2, 0, 1);
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 4);
    }

    function testAddManyMore() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160010160005260206000F3", 2, 0, 1);
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 40);
    }

    function testMul() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160030260005260206000F3", 3, 0, 1);
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 3);
    }

    function testMSTORE() public view {
        Evm evm;
        evm.evaluate(hex"6001600352", 2, 0, 1);
    }

    function testRet() public {
        Evm evm;
        (bool succ, bytes memory ret) = evm.evaluate(hex"600160005260206000F3", 2, 0, 1);
        (uint256 r) = abi.decode(ret, (uint256));
        assertTrue(succ);
        assertEq(r, 1);
    }

    function testCtx() public {
        Mapping balances = MappingLib.newMapping(1);
        balances.insert(bytes32(uint256(0x1339)), 1e18);
        address origin = address(0x1337);
        address caller = address(0x1338);
        address execution_address = address(0x1339);
        uint256 callvalue = uint256(0x1340);
        address coinbase = address(0x1341);
        uint256 timestamp = uint256(0x1342);
        uint256 number = uint256(0x1343);
        uint256 gaslimit = uint256(0x1344);
        uint256 difficulty = uint256(0x1345);
        uint256 chainid = uint256(0x1346);
        uint256 basefee = uint256(0x1347);
        bytes memory calld = "";
        EvmContext memory ctx = EvmContext({
            origin: origin,
            caller: caller,
            execution_address: execution_address,
            callvalue: callvalue,
            coinbase: coinbase,
            timestamp: timestamp,
            number: number,
            gaslimit: gaslimit,
            difficulty: difficulty,
            chainid: chainid,
            basefee: basefee,
            balances: balances,
            calld: calld
        });

        Evm evm = EvmLib.newEvm(ctx);

        // bytes memory org   = hex"32600052";
        // bytes memory calll = hex"33602052";
        // bytes memory exec  = hex"30604052";
        // bytes memory cv    = hex"34606052";
        // bytes memory cb    = hex"41608052";
        // bytes memory ts    = hex"4260a052";
        // bytes memory nm    = hex"4360c052";
        // bytes memory gl    = hex"4560e052";
        // bytes memory df    = hex"4461010052";
        // bytes memory ci    = hex"4661012052";
        // bytes memory bf    = hex"4861014052";
        // bytes memory retur = hex"6101406000F3";

        
        bytes memory bytecode = hex"32600052336020523060405234606052416080524260a0524360c0524560e0524461010052466101205248610140526101606000F3";


        (bool succ, bytes memory ret) = evm.evaluate(bytecode, 2, 0, 10);
        (
            address or,
            address cal,
            address ex,
            uint256 calv,
            address base,
            uint256 stamp,
            uint256 num,
            uint256 lim,
            uint256 diff,
            uint256 chain,
            uint256 fee
        ) = abi.decode(ret, (address, address, address, uint256, address, uint256, uint256, uint256, uint256, uint256, uint256));
        assertEq(or, origin);
        assertEq(cal, caller);
        assertEq(ex, execution_address);
        assertEq(calv, callvalue);
        assertEq(base, coinbase);
        assertEq(stamp, timestamp);
        assertEq(num, number);
        assertEq(lim, gaslimit);
        assertEq(diff, difficulty);
        assertEq(chain, chainid);
        assertEq(fee, basefee);
    }
}