// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {Script} from "forge-std/Script.sol";
import {Ticketing1155} from "../src/TicketingSystem.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint256 public constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address ticketingContract;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        // address(0) means not deployed yet — will revert loudly if you
        // accidentally try to use it before deploying to sepolia
        return NetworkConfig({
            ticketingContract: address(0),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ticketingContract: address(0),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        // don't redeploy if already deployed
        if (activeNetworkConfig.ticketingContract != address(0)) {
            return activeNetworkConfig;
        }

        Ticketing1155 ticketing = new Ticketing1155();

        return NetworkConfig({
            ticketingContract: address(ticketing),
            deployerKey: ANVIL_KEY
        });
    }
}