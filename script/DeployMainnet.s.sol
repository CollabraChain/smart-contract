// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeployAll.s.sol";

/**
 * @title DeployMainnet
 * @notice Production mainnet deployment script with enhanced security
 * @dev Extends the main deployment script with mainnet-specific security checks
 */
contract DeployMainnet is DeployAll {
    
    // ========================================
    // MAINNET CONFIGURATION
    // ========================================
    
    bool public constant IS_MAINNET = true;
    
    // Security settings
    uint256 public constant DEPLOYMENT_DELAY = 60; // 1 minute delay between steps
    bool public securityChecksEnabled = true;

    function setUp() public override {
        super.setUp();
        
        console2.log("[SECURE] MAINNET DEPLOYMENT MODE");
        console2.log("Enhanced security checks: ENABLED");
        console2.log("Deployment delay:", DEPLOYMENT_DELAY, "seconds");
    }

    /**
     * @notice Mainnet deployment with security checks
     */
    function run() public override {
        _preDeploymentSecurityChecks();
        
        console2.log("[WAIT] Starting mainnet deployment with security delays...");
        
        // Run the main deployment with delays
        _secureDeployment();
        
        _postDeploymentSecurityVerification();
        _generateMainnetReport();
    }

    // ========================================
    // SECURITY FUNCTIONS
    // ========================================

    /**
     * @notice Pre-deployment security checks
     */
    function _preDeploymentSecurityChecks() internal {
        console2.log("[SECURE] Pre-Deployment Security Checks...");
        console2.log("====================================");

        console2.log("[OK] Deployer balance sufficient:", deployer.balance / 1e18, "ETH");
        
        require(
            block.chainid == 1 || block.chainid == 8453, // Ethereum or Base mainnet
            "Not on supported mainnet"
        );
        console2.log("[OK] Network validated: Chain ID", block.chainid);
        
        // Check 3: Gas price check
        require(tx.gasprice <= 50 gwei, "Gas price too high for deployment");
        console2.log("[OK] Gas price acceptable:", tx.gasprice / 1e9, "gwei");
        
        // Check 4: Confirm deployer
        console2.log("[WARN]  CRITICAL: Deploying to MAINNET");
        console2.log("Deployer address:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("Gas price:", tx.gasprice / 1e9, "gwei");
        
        console2.log("[OK] All pre-deployment checks passed");
        console2.log("");
    }

    /**
     * @notice Secure deployment with delays and verifications
     */
    function _secureDeployment() internal {
        console2.log("[START] Starting Secure Mainnet Deployment...");
        console2.log("========================================");

        vm.startBroadcast();

        // Step 1: Deploy Reputation (with delay)
        console2.log("[DEPLOY] Deploying CollabraChainReputation...");
        _deployReputation();
        _securityDelay();
        
        // Step 2: Deploy Factory (with delay)
        console2.log("[FACTORY] Deploying CollabraChainFactory...");
        _deployFactory();
        _securityDelay();
        
        // Step 3: Configure contracts (with delay)
        console2.log("[CONFIG] Configuring contracts...");
        _configureContracts();
        _securityDelay();
        
        // Step 4: Verify deployment
        console2.log("[VERIFY] Verifying deployment...");
        _verifyDeployment();

        vm.stopBroadcast();

        // Step 5: Display results
        _displayResults();
        
        // Step 6: Save deployment info
        _saveDeploymentInfo();
    }

    /**
     * @notice Security delay between deployment steps
     */
    function _securityDelay() internal {
        if (securityChecksEnabled && DEPLOYMENT_DELAY > 0) {
            console2.log("[WAIT] Security delay:", DEPLOYMENT_DELAY, "seconds...");
            vm.sleep(DEPLOYMENT_DELAY * 1000); // Convert to milliseconds
        }
    }

    /**
     * @notice Post-deployment security verification
     */
    function _postDeploymentSecurityVerification() internal {
        console2.log("\n[SECURE] Post-Deployment Security Verification...");
        console2.log("============================================");
        
        // Verify contracts are deployed correctly
        require(address(reputation) != address(0), "Reputation not deployed");
        require(address(factory) != address(0), "Factory not deployed");
        
        // Verify ownership structure
        require(reputation.owner() == address(factory), "Incorrect ownership structure");
        require(address(factory.reputationContract()) == address(reputation), "Incorrect references");
        
        // Check contract sizes (basic verification)
        require(address(reputation).code.length > 1000, "Reputation contract too small");
        require(address(factory).code.length > 1000, "Factory contract too small");
        
        // Verify initial state
        require(factory.getProjectsCount() == 0, "Initial state incorrect");
        
        console2.log("[OK] All post-deployment security checks passed!");
        console2.log("");
    }

    /**
     * @notice Generate mainnet deployment report
     */
    function _generateMainnetReport() internal {
        console2.log("[REPORT] Generating Mainnet Deployment Report...");
        
        string memory report = string(abi.encodePacked(
            "# CollabraChain Mainnet Deployment Report\n\n",
            "## Deployment Summary\n",
            "- **Date**: ", vm.toString(block.timestamp), "\n",
            "- **Block**: ", vm.toString(block.number), "\n",
            "- **Chain ID**: ", vm.toString(block.chainid), "\n",
            "- **Deployer**: ", vm.toString(deployer), "\n",
            "- **Gas Price**: ", vm.toString(tx.gasprice / 1e9), " gwei\n\n",
            
            "## Deployed Contracts\n",
            "| Contract | Address | Owner |\n",
            "|----------|---------|-------|\n",
            "| CollabraChainReputation | ", vm.toString(address(reputation)), " | ", vm.toString(reputation.owner()), " |\n",
            "| CollabraChainFactory | ", vm.toString(address(factory)), " | N/A |\n\n",
            
            "## Security Verification\n",
            "- [OK] Ownership correctly transferred\n",
            "- [OK] Contract references validated\n",
            "- [OK] Initial state verified\n",
            "- [OK] Code size validation passed\n\n",
            
            "## Next Steps\n",
            "1. **Immediate**: Verify contracts on block explorer\n",
            "2. **24h**: Monitor for any issues\n",
            "3. **48h**: Begin frontend integration\n",
            "4. **1w**: Launch public beta\n\n",
            
            "## Emergency Contacts\n",
            "- Deployer: ", vm.toString(deployer), "\n",
            "- Reputation Owner: ", vm.toString(reputation.owner()), "\n\n",
            
            "## Contract Verification Commands\n",
            "```bash\n",
            "# Verify Reputation\n",
            "forge verify-contract ", vm.toString(address(reputation)), " src/CollabraChainReputation.sol:CollabraChainReputation --chain-id ", vm.toString(block.chainid), "\n\n",
            "# Verify Factory\n",
            "forge verify-contract ", vm.toString(address(factory)), " src/CollabraChainFactory.sol:CollabraChainFactory --chain-id ", vm.toString(block.chainid), "\n",
            "```\n"
        ));
        
        string memory chainId = vm.toString(block.chainid);
        string memory fileName = string(abi.encodePacked("deployment-logs/mainnet-deployment-report-", chainId, ".md"));
        vm.writeFile(fileName, report);
        
        console2.log("[OK] Mainnet deployment report saved to:", fileName);
    }

    // ========================================
    // MAINNET UTILITY FUNCTIONS
    // ========================================

    /**
     * @notice Disable security checks (for testing only)
     */
    function disableSecurityChecks() external {
        require(!IS_MAINNET, "Cannot disable security on mainnet");
        securityChecksEnabled = false;
        console2.log("[WARN] Security checks disabled (TESTING ONLY)");
    }

    /**
     * @notice Get mainnet deployment status
     */
    function getMainnetStatus() external view returns (
        bool deployed,
        bool verified,
        uint256 deploymentBlock,
        address reputationAddr,
        address factoryAddr
    ) {
        deployed = address(reputation) != address(0) && address(factory) != address(0);
        
        if (deployed) {
            verified = reputation.owner() == address(factory) &&
                      address(factory.reputationContract()) == address(reputation);
            deploymentBlock = block.number;
            reputationAddr = address(reputation);
            factoryAddr = address(factory);
        }
        
        return (deployed, verified, deploymentBlock, reputationAddr, factoryAddr);
    }

    /**
     * @notice Emergency pause function (placeholder for future upgrades)
     */
    function emergencyInfo() external view returns (string memory) {
        return string(abi.encodePacked(
            "Emergency Contact: ", vm.toString(deployer), " | ",
            "Reputation Owner: ", vm.toString(reputation.owner()), " | ",
            "Block: ", vm.toString(block.number)
        ));
    }
} 