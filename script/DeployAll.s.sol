// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CollabraChainReputation} from "../src/CollabraChainReputation.sol";
import {CollabraChainFactory} from "../src/CollabraChainFactory.sol";

contract DeployAll is Script {
    function setUp() public {}

    function run() public {
        // Start broadcasting transactions from the deployer
        vm.startBroadcast();

        // Use the deployer's address for admin/agent roles
        address deployer = msg.sender;

        address usdcToken = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        // Deploy CollabraChainReputation
        CollabraChainReputation reputation = new CollabraChainReputation(
            deployer
        );

        // Deploy CollabraChainFactory
        CollabraChainFactory factory = new CollabraChainFactory(
            usdcToken,
            address(reputation),
            deployer, // initialAdmin
            deployer // initialAgent
        );

        vm.stopBroadcast();

        console2.log(
            "CollabraChainReputation deployed at:",
            address(reputation)
        );
        console2.log("CollabraChainFactory deployed at:", address(factory));
    }
}
