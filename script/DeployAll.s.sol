// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CollabraChainReputation} from "../src/CollabraChainReputation.sol";
import {CollabraChainFactoryUnprotected} from "../src/CollabraChainFactoryUnprotected.sol";
import {CollabraChainProject} from "../src/CollabraChainProjectUnprotected.sol";

/**
 * @title DeployAll
 * @notice Comprehensive deployment script for the CollabraChain platform
 * @dev Deploys all contracts in the correct order with proper configuration
 */
contract DeployAll is Script {
    
    // ========================================
    // STATE VARIABLES
    // ========================================
    
    CollabraChainReputation public reputation;
    CollabraChainFactoryUnprotected public factory;
    
    address public deployer;
    address public usdcToken;
    
    // ========================================
    // USDC TOKEN ADDRESSES BY NETWORK
    // ========================================
    
    mapping(uint256 => address) public usdcAddresses;
    
    // ========================================
    // DEPLOYMENT CONFIGURATION
    // ========================================
    
    function setUp() public virtual {
        deployer = msg.sender;
        _configureUSDCAddresses();
    }

    /**
     * @notice Configure USDC addresses for different networks
     */
    function _configureUSDCAddresses() internal {
        // Mainnet USDC
        usdcAddresses[1] = 0xA0B86a33E6441f8c4F0B88e91c094ceA23Ab5da3;
        
        // Base Mainnet USDC
        usdcAddresses[8453] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        
        // Base Sepolia Testnet USDC
        usdcAddresses[84532] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        
        // Ethereum Sepolia Testnet USDC
        usdcAddresses[11155111] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        
        // Local Anvil testnet (for testing) - use a mock address
        usdcAddresses[31337] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        
        // Get USDC address for current network
        usdcToken = usdcAddresses[block.chainid];
        
        // If no USDC address configured for this network, revert
        require(usdcToken != address(0), string(abi.encodePacked(
            "USDC address not configured for chain ID: ",
            vm.toString(block.chainid)
        )));
    }

    /**
     * @notice Main deployment function
     * @dev Deploys all contracts and sets up proper ownership
     */
    function run() public virtual {
        console2.log("\n=== Starting CollabraChain Deployment ===");
        console2.log("==========================================");
        console2.log("Deployer address:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("USDC Token:", usdcToken);
        console2.log("Block number:", block.number);
        console2.log("==========================================\n");

        vm.startBroadcast();

        // Step 1: Deploy Reputation Contract
        _deployReputation();
        
        // Step 2: Deploy Factory Contract
        _deployFactory();
        
        // Step 3: Configure Ownership and Permissions
        _configureContracts();
        
        // Step 4: Verify Deployment
        _verifyDeployment();

        vm.stopBroadcast();

        // Step 5: Display Results
        _displayResults();
        
        // Step 6: Save Deployment Info
        _saveDeploymentInfo();
    }

    // ========================================
    // DEPLOYMENT STEPS
    // ========================================

    /**
     * @notice Deploy the reputation (SBT) contract
     */
    function _deployReputation() internal {
        console2.log("[1] Step 1: Deploying CollabraChainReputation...");
        
        reputation = new CollabraChainReputation(deployer);
        
        console2.log("[OK] CollabraChainReputation deployed at:", address(reputation));
        console2.log("   Initial owner:", reputation.owner());
        console2.log("");
    }

    /**
     * @notice Deploy the factory contract
     */
    function _deployFactory() internal {
        console2.log("[FACTORY] Step 2: Deploying CollabraChainFactory...");
        
        factory = new CollabraChainFactoryUnprotected(address(reputation), usdcToken);
        
        console2.log("[OK] CollabraChainFactory deployed at:", address(factory));
        console2.log("   Reputation contract reference:", address(factory.reputationContract()));
        console2.log("   USDC token reference:", factory.usdcToken());
        console2.log("");
    }

    /**
     * @notice Configure contracts with proper ownership and permissions
     */
    function _configureContracts() internal {
        console2.log("[CONFIG]  Step 3: Configuring Contract Permissions...");
        
        // Transfer reputation contract ownership to factory
        // This allows the factory to mint reputation tokens when projects complete
        console2.log("   Transferring reputation ownership to factory...");
        reputation.transferOwnership(address(factory));
        
        console2.log("[OK] Reputation ownership transferred to factory");
        console2.log("   New reputation owner:", reputation.owner());
        console2.log("");
    }

    /**
     * @notice Verify that deployment was successful
     */
    function _verifyDeployment() internal {
        console2.log("[VERIFY] Step 4: Verifying Deployment...");
        
        // Verify reputation contract
        require(address(reputation) != address(0), "Reputation deployment failed");
        require(reputation.owner() == address(factory), "Reputation ownership not transferred");
        
        // Verify factory contract
        require(address(factory) != address(0), "Factory deployment failed");
        require(address(factory.reputationContract()) == address(reputation), "Factory reputation reference incorrect");
        require(factory.usdcToken() == usdcToken, "Factory USDC reference incorrect");
        require(factory.getProjectsCount() == 0, "Factory should start with 0 projects");
        
        // Test basic functionality
        console2.log("   Testing basic contract functionality...");
        
        // The factory should be able to call reputation contract functions
        // (We can't test minting here because only project contracts can call it)
        
        console2.log("[OK] All deployment verifications passed!");
        console2.log("");
    }

    /**
     * @notice Display deployment results
     */
    function _displayResults() internal view {
        console2.log("[COMPLETE] DEPLOYMENT COMPLETE!");
        console2.log("========================");
        console2.log("");
        console2.log("[DEPLOY] DEPLOYED CONTRACTS:");
        console2.log("    CollabraChainReputation: %s", address(reputation));
        console2.log("    CollabraChainFactory:    %s", address(factory));
        console2.log("    USDC Token:              %s", usdcToken);
        console2.log("    Owner/Deployer:          %s", deployer);
        console2.log("");
        console2.log("[LINK] CONTRACT RELATIONSHIPS:");
        console2.log("    Reputation Owner:        %s", reputation.owner());
        console2.log("    Factory Reputation Ref:  %s", address(factory.reputationContract()));
        console2.log("    Factory USDC Ref:        %s", factory.usdcToken());
        console2.log("    Initial Projects Count:  %s", vm.toString(factory.getProjectsCount()));
        console2.log("");
        console2.log("[NETWORK] NETWORK INFO:");
        console2.log("    Chain ID:                %s", vm.toString(block.chainid));
        console2.log("    Block Number:            %s", vm.toString(block.number));
        console2.log("    Gas Price:               %s gwei", vm.toString(tx.gasprice / 1e9));
        console2.log("");
        console2.log("[WRITE] NEXT STEPS:");
        console2.log("    1. Verify contracts on block explorer");
        console2.log("    2. Test project creation with USDC");
        console2.log("    3. Update frontend with new addresses");
        console2.log("    4. Run integration tests with USDC");
        console2.log("========================");
    }

    /**
     * @notice Save deployment information to file
     */
    function _saveDeploymentInfo() internal {
        console2.log("\n[SAVE] Saving deployment info...");
        
        string memory chainId = vm.toString(block.chainid);
        string memory deploymentInfo = string(abi.encodePacked(
            "# CollabraChain Deployment Info\n",
            "Chain ID: ", chainId, "\n",
            "Block Number: ", vm.toString(block.number), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "CollabraChainReputation: ", vm.toString(address(reputation)), "\n",
            "CollabraChainFactory: ", vm.toString(address(factory)), "\n",
            "USDC Token: ", vm.toString(usdcToken), "\n",
            "Deployment Date: ", vm.toString(block.timestamp), "\n"
        ));
        
        string memory fileName = string(abi.encodePacked("deployment-logs/deployment-", chainId, ".txt"));
        vm.writeFile(fileName, deploymentInfo);
        
        console2.log("[OK] Deployment info saved to:", fileName);
    }

    // ========================================
    // UTILITY FUNCTIONS
    // ========================================

    /**
     * @notice Get deployment addresses for external use
     */
    function getDeployedAddresses() external view returns (
        address reputationAddress,
        address factoryAddress,
        address usdcAddress,
        address deployerAddress
    ) {
        return (address(reputation), address(factory), usdcToken, deployer);
    }

    /**
     * @notice Check if deployment is valid
     */
    function isDeploymentValid() external view returns (bool) {
        return address(reputation) != address(0) && 
               address(factory) != address(0) &&
               reputation.owner() == address(factory) &&
               address(factory.reputationContract()) == address(reputation) &&
               factory.usdcToken() == usdcToken;
    }
} 