// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CollabraChainReputation} from "../src/CollabraChainReputation.sol";
import {CollabraChainFactory} from "../src/CollabraChainFactory.sol";
import {CollabraChainProject} from "../src/CollabraChainProject.sol";

/**
 * @title VerifyContracts
 * @notice Script to verify deployed contracts on block explorers
 * @dev Provides verification commands and deployment validation
 */
contract VerifyContracts is Script {
    
    // ========================================
    // CONTRACT ADDRESSES (SET THESE AFTER DEPLOYMENT)
    // ========================================
    
    address public reputationAddress;
    address public factoryAddress;
    address public deployer;
    
    // Constructor arguments for verification
    struct VerificationArgs {
        address reputationOwner;
        address factoryReputationContract;
    }

    function setUp() public {
        // Set these addresses after deployment
        // You can get them from the deployment logs or files
        
        // Example addresses (replace with actual deployed addresses):
        // reputationAddress = 0x...;
        // factoryAddress = 0x...;
        // deployer = 0x...;
        
        console2.log("[VERIFY] Contract Verification Script");
        console2.log("================================");
    }

    /**
     * @notice Main verification function
     * @dev Validates deployment and generates verification commands
     */
    function run() public {
        _loadDeploymentAddresses();
        _validateDeployment();
        _generateVerificationCommands();
        _runPostDeploymentTests();
    }

    /**
     * @notice Load deployment addresses from environment or user input
     */
    function _loadDeploymentAddresses() internal {
        console2.log("[DEPLOY] Step 1: Loading Deployment Addresses...");
        
        // Try to load from environment variables
        try vm.envAddress("REPUTATION_ADDRESS") returns (address addr) {
            reputationAddress = addr;
        } catch {
            console2.log("[WARN]  REPUTATION_ADDRESS not set in environment");
        }
        
        try vm.envAddress("FACTORY_ADDRESS") returns (address addr) {
            factoryAddress = addr;
        } catch {
            console2.log("[WARN]  FACTORY_ADDRESS not set in environment");
        }
        
        try vm.envAddress("DEPLOYER_ADDRESS") returns (address addr) {
            deployer = addr;
        } catch {
            deployer = msg.sender;
        }
        
        console2.log("Reputation Address:", reputationAddress);
        console2.log("Factory Address:", factoryAddress);
        console2.log("Deployer Address:", deployer);
        console2.log("");
    }

    /**
     * @notice Validate the deployment
     */
    function _validateDeployment() internal {
        console2.log("[OK] Step 2: Validating Deployment...");
        
        require(reputationAddress != address(0), "Reputation address not set");
        require(factoryAddress != address(0), "Factory address not set");
        
        // Validate contract code exists
        require(reputationAddress.code.length > 0, "No code at reputation address");
        require(factoryAddress.code.length > 0, "No code at factory address");
        
        // Validate contract relationships
        CollabraChainReputation reputation = CollabraChainReputation(reputationAddress);
        CollabraChainFactory factory = CollabraChainFactory(factoryAddress);
        
        require(reputation.owner() == factoryAddress, "Reputation owner should be factory");
        require(address(factory.reputationContract()) == reputationAddress, "Factory should reference reputation");
        
        console2.log("[OK] All deployment validations passed!");
        console2.log("");
    }

    /**
     * @notice Generate verification commands for different block explorers
     */
    function _generateVerificationCommands() internal {
        console2.log("[LINK] Step 3: Generating Verification Commands...");
        
        string memory chainId = vm.toString(block.chainid);
        
        // Generate verification commands
        string memory verificationCommands = string(abi.encodePacked(
            "# Contract Verification Commands\n\n",
            "## Chain ID: ", chainId, "\n\n",
            
            "### CollabraChainReputation\n",
            "```bash\n",
            "forge verify-contract \\\n",
            "  ", vm.toString(reputationAddress), " \\\n",
            "  src/CollabraChainReputation.sol:CollabraChainReputation \\\n",
            "  --chain-id ", chainId, " \\\n",
            "  --constructor-args $(cast abi-encode \"constructor(address)\" ", vm.toString(deployer), ")\n",
            "```\n\n",
            
            "### CollabraChainFactory\n",
            "```bash\n",
            "forge verify-contract \\\n",
            "  ", vm.toString(factoryAddress), " \\\n",
            "  src/CollabraChainFactory.sol:CollabraChainFactory \\\n",
            "  --chain-id ", chainId, " \\\n",
            "  --constructor-args $(cast abi-encode \"constructor(address)\" ", vm.toString(reputationAddress), ")\n",
            "```\n\n",
            
            "## Alternative: Using Etherscan API\n",
            "If forge verification fails, you can verify manually on the block explorer:\n\n",
            "### Reputation Contract\n",
            "- Address: ", vm.toString(reputationAddress), "\n",
            "- Constructor Args: ", vm.toString(deployer), "\n\n",
            
            "### Factory Contract\n",
            "- Address: ", vm.toString(factoryAddress), "\n",
            "- Constructor Args: ", vm.toString(reputationAddress), "\n\n"
        ));
        
        string memory fileName = string(abi.encodePacked("deployment-logs/verification-commands-", chainId, ".md"));
        vm.writeFile(fileName, verificationCommands);
        
        console2.log("[OK] Verification commands saved to:", fileName);
        console2.log("");
        
        // Print commands to console for immediate use
        console2.log("[DEPLOY] Quick Verification Commands:");
        console2.log("");
        console2.log("1. Verify Reputation Contract:");
        console2.log("forge verify-contract", reputationAddress, "src/CollabraChainReputation.sol:CollabraChainReputation --chain-id", chainId);
        console2.log("");
        console2.log("2. Verify Factory Contract:");
        console2.log("forge verify-contract", factoryAddress, "src/CollabraChainFactory.sol:CollabraChainFactory --chain-id", chainId);
        console2.log("");
    }

    /**
     * @notice Run post-deployment tests
     */
    function _runPostDeploymentTests() internal {
        console2.log("[TEST] Step 4: Running Post-Deployment Tests...");
        
        CollabraChainReputation reputation = CollabraChainReputation(reputationAddress);
        CollabraChainFactory factory = CollabraChainFactory(factoryAddress);
        
        // Test 1: Contract interfaces
        require(bytes(reputation.name()).length > 0, "Reputation name should not be empty");
        require(bytes(reputation.symbol()).length > 0, "Reputation symbol should not be empty");
        require(factory.getProjectsCount() >= 0, "Factory should have projects count");
        
        // Test 2: Access controls
        require(reputation.owner() == factoryAddress, "Reputation owner should be factory");
        
        // Test 3: Contract interactions
        address testFactoryReputation = address(factory.reputationContract());
        require(testFactoryReputation == reputationAddress, "Factory should correctly reference reputation");
        
        console2.log("[OK] All post-deployment tests passed!");
        console2.log("   [PASS] Contract interfaces");
        console2.log("   [PASS] Access controls");
        console2.log("   [PASS] Contract interactions");
        console2.log("");
    }

    // ========================================
    // UTILITY FUNCTIONS
    // ========================================

    /**
     * @notice Set contract addresses manually (for testing)
     */
    function setAddresses(address _reputation, address _factory, address _deployer) external {
        reputationAddress = _reputation;
        factoryAddress = _factory;
        deployer = _deployer;
        
        console2.log("[WRITE] Addresses set manually:");
        console2.log("Reputation:", reputationAddress);
        console2.log("Factory:", factoryAddress);
        console2.log("Deployer:", deployer);
    }

    /**
     * @notice Generate constructor arguments for verification
     */
    function getConstructorArgs() external view returns (bytes memory reputationArgs, bytes memory factoryArgs) {
        reputationArgs = abi.encode(deployer);
        factoryArgs = abi.encode(reputationAddress);
        
        return (reputationArgs, factoryArgs);
    }

    /**
     * @notice Get verification status
     */
    function getVerificationStatus() external view returns (
        bool contractsExist,
        bool ownershipCorrect,
        bool referencesCorrect
    ) {
        if (reputationAddress == address(0) || factoryAddress == address(0)) {
            return (false, false, false);
        }
        
        contractsExist = reputationAddress.code.length > 0 && factoryAddress.code.length > 0;
        
        if (contractsExist) {
            CollabraChainReputation reputation = CollabraChainReputation(reputationAddress);
            CollabraChainFactory factory = CollabraChainFactory(factoryAddress);
            
            ownershipCorrect = reputation.owner() == factoryAddress;
            referencesCorrect = address(factory.reputationContract()) == reputationAddress;
        }
        
        return (contractsExist, ownershipCorrect, referencesCorrect);
    }

    /**
     * @notice Generate ABI for frontend integration
     */
    function generateABIFiles() external {
        console2.log("[WRITE] Generating ABI files for frontend integration...");
        
        // Note: In a real implementation, you would use vm.readFile to read the ABI files
        // and then format them for frontend use. For now, we'll just provide instructions.
        
        string memory abiInstructions = string(abi.encodePacked(
            "# ABI Files for Frontend Integration\n\n",
            "The contract ABIs can be found in the following files after compilation:\n\n",
            "- `out/CollabraChainReputation.sol/CollabraChainReputation.json`\n",
            "- `out/CollabraChainFactory.sol/CollabraChainFactory.json`\n",
            "- `out/CollabraChainProject.sol/CollabraChainProject.json`\n\n",
            "## Contract Addresses\n",
            "```json\n",
            "{\n",
            '  "reputation": "', vm.toString(reputationAddress), '",\n',
            '  "factory": "', vm.toString(factoryAddress), '",\n',
            '  "chainId": ', vm.toString(block.chainid), '\n',
            "}\n",
            "```\n\n",
            "## Usage in Frontend\n",
            "1. Copy the JSON files to your frontend project\n",
            "2. Import the ABIs and use with contract addresses\n",
            "3. Initialize web3/ethers contracts with these ABIs\n"
        ));
        
        string memory chainId = vm.toString(block.chainid);
        string memory fileName = string(abi.encodePacked("deployment-logs/frontend-integration-", chainId, ".md"));
        vm.writeFile(fileName, abiInstructions);
        
        console2.log("[OK] Frontend integration guide saved to:", fileName);
    }
} 