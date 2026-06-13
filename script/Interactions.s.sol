// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Ticketing1155} from "../src/TicketingSystem.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateEvent is Script {
    function run() external {
        // 1. Get the most recently deployed contract address
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Ticketing1155", block.chainid);

        // 2. We still need HelperConfig just to get the deployerKey
        HelperConfig helperConfig = new HelperConfig();
        (, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        Ticketing1155 ticketing = Ticketing1155(mostRecentlyDeployed);
        ticketing.createEventToken{value: 0.0002 ether}("ipfs://QmYourCID", 0.05 ether, 100);
        vm.stopBroadcast();
    }
}

contract BuyTicket is Script {
    // Standard Anvil Account 1 Private Key
    uint256 public constant BUYER_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Ticketing1155", block.chainid);

        // Broadcast as the BUYER, not the deployer
        vm.startBroadcast(BUYER_KEY);
        Ticketing1155(mostRecentlyDeployed).executeSale{value: 0.05 ether}(1, 1);
        vm.stopBroadcast();
    }
}

contract ListResale is Script {
    function run() external {
        // 1. Get the most recently deployed contract
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Ticketing1155", block.chainid);

        // Since your Makefile passes the private key via CLI,
        // an empty vm.startBroadcast() will automatically use it.
        vm.startBroadcast();
        Ticketing1155 ticketing = Ticketing1155(mostRecentlyDeployed);

        // 2. APPROVE THE CONTRACT
        // The buyer must give the smart contract permission to hold their ticket in escrow
        ticketing.setApprovalForAll(address(ticketing), true);

        // 3. LIST FOR RESALE
        // TokenId: 1, Amount: 1, Resale Price: 0.055 ether
        // Remember: Your contract enforces a max 10% profit.
        // Since original price was 0.05, 0.055 is the absolute maximum allowed.
        ticketing.listForResale(1, 1, 0.055 ether);

        vm.stopBroadcast();
    }
}
