// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {Script} from "forge-std/Script.sol";
import {Ticketing1155} from "../src/TicketingSystem.sol";

contract DeployTicketing is Script {
    function run() external {
        vm.startBroadcast();
        new Ticketing1155();
        vm.stopBroadcast();
    }
}
