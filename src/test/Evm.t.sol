// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Evm.sol";
import "forge-std/Vm.sol";
import "memmove/Mapping.sol";

contract EvmTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);

    using EvmLib for Evm;
    using MappingLib for Mapping;

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

        bytes memory org = "32600052";
        bytes memory calll = "33602052";
        bytes memory exec = "30604052";
        bytes memory cv = "34606052";
        bytes memory cb = "41608052";
        bytes memory ts = "4261010052";
        bytes memory nm = "4361012052";
        bytes memory gl = "4561014052";
        bytes memory df = "4461016052";
        bytes memory ci = "4661018052";
        bytes memory bf = "4861020052";
        bytes memory retur = "6102206000F3";

        bytes memory bytecode = abi.encodePacked(org, calll, exec, cv, cb, ts, nm, gl, df, ci, bf, retur);


        (bool succ, bytes memory ret) = evm.evaluate(bytecode);
        emit log_named_bytes("ret", ret);
        // (
        //     address or,
        //     address cal,
        //     address ex,
        //     uint256 calv,
        //     address base,
        //     uint256 stamp,
        //     uint256 num,
        //     uint256 lim,
        //     uint256 diff,
        //     uint256 chain,
        //     uint256 fee
        // ) = abi.decode(ret, (address, address, address, uint256, address, uint256, uint256, uint256, uint256, uint256, uint256));
        // assertEq(or, origin);
        // assertEq(cal, caller);
        // assertEq(ex, execution_address);
        // assertEq(calv, callvalue);
        // assertEq(base, coinbase);
        // assertEq(stamp, timestamp);
        // assertEq(num, number);
        // assertEq(lim, gaslimit);
        // assertEq(diff, difficulty);
        // assertEq(chain, chainid);
        // assertEq(fee, basefee);
    }
}