// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {EPICPAW} from "../src/Epicpaw.sol";

contract EpicpawTest is Test {
    EPICPAW public epicpaw;

    function setUp() public {
        epicpaw = new EPICPAW();
    }
}
