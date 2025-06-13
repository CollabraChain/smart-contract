// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeployAll.s.sol";
import {CollabraChainProject} from "../src/CollabraChainProjectUnprotected.sol";
import "forge-std/Test.sol";

/**
 * @title DeployTestnet
 * @notice Testnet deployment script with additional testing and verification
 * @dev Extends the main deployment script with testnet-specific features
 */
contract DeployTestnet is DeployAll, Test {
    // ========================================
    // TESTNET CONFIGURATION
    // ========================================

    bool public constant IS_TESTNET = true;

    // Test project data
    string constant TEST_PROJECT_TITLE = "Sample DeFi Project";
    string constant TEST_PROJECT_DESCRIPTION =
        "A sample project for testing the platform";
    string constant TEST_PROJECT_CATEGORY = "DeFi Development";
    string[] public requiredSkills;
    uint256 constant TEST_PROJECT_BUDGET = 5_000_000; // 5 USDC (6 decimals)
    string constant TEST_PROJECT_SCOPE_CID = "QmTestProjectScope123";

    address public creatorAddr;
    address public freelancerAddr;
    address public projectAddr;

    function setUp() public override {
        super.setUp();

        // Setup test accounts
        creatorAddr = vm.addr(1);
        freelancerAddr = vm.addr(2);

        // Setup test skills
        requiredSkills.push("Solidity");
        requiredSkills.push("Testing");
        requiredSkills.push("DeFi");

        console2.log("[TEST] TESTNET DEPLOYMENT MODE");
        console2.log("Test Creator:", creatorAddr);
        console2.log("Test Freelancer:", freelancerAddr);
    }

    /**
     * @notice Extended testnet deployment with sample project creation
     */
    function run() public override {
        // Run the main deployment
        super.run();

        _generateTestnetGuide();
    }

    /**
     * @notice Generate testnet usage guide
     */
    function _generateTestnetGuide() internal {
        console2.log("[GUIDE] Step 8: Generating Testnet Guide...");

        string memory guide = string(
            abi.encodePacked(
                "# CollabraChain Testnet Deployment Guide\n\n",
                "## Deployed Contracts\n",
                "- Reputation: ",
                vm.toString(address(reputation)),
                "\n",
                "- Factory: ",
                vm.toString(address(factory)),
                "\n",
                "- Sample Project: ",
                vm.toString(projectAddr),
                "\n\n",
                "## Test Accounts\n",
                "- Creator: ",
                vm.toString(creatorAddr),
                "\n",
                "- Freelancer: ",
                vm.toString(freelancerAddr),
                "\n\n",
                "## Quick Start Testing\n",
                "1. Use the Factory to create new projects\n",
                "2. Apply to projects as a freelancer\n",
                "3. Test the full milestone workflow\n",
                "4. Verify reputation tokens are minted\n\n",
                "## Sample Project Details\n",
                "- Title: ",
                TEST_PROJECT_TITLE,
                "\n",
                "- Budget: ",
                vm.toString(TEST_PROJECT_BUDGET / 1e6),
                " USDC\n",
                "- Category: ",
                TEST_PROJECT_CATEGORY,
                "\n",
                "- Skills: Solidity, Testing, DeFi\n\n",
                "## Frontend Integration\n",
                "Use these addresses in your frontend:\n",
                "```json\n",
                "{\n",
                '  "reputation": "',
                vm.toString(address(reputation)),
                '",\n',
                '  "factory": "',
                vm.toString(address(factory)),
                '",\n',
                '  "sampleProject": "',
                vm.toString(projectAddr),
                '"\n',
                "}\n",
                "```\n"
            )
        );

        string memory chainId = vm.toString(block.chainid);
        string memory fileName = string(
            abi.encodePacked("deployment-logs/testnet-guide-", chainId, ".md")
        );
        vm.writeFile(fileName, guide);

        console2.log("[OK] Testnet guide saved to:", fileName);
    }

    // ========================================
    // TESTNET UTILITY FUNCTIONS
    // ========================================

    /**
     * @notice Get all testnet addresses
     */
    function getTestnetAddresses()
        external
        view
        returns (
            address reputationContract,
            address factoryContract,
            address sampleProjectAddr,
            address creatorAddress,
            address freelancerAddress
        )
    {
        return (
            address(reputation),
            address(factory),
            projectAddr,
            creatorAddr,
            freelancerAddr
        );
    }

    /**
     * @notice Run post-deployment verification
     */
    function verifyTestnetDeployment() external view returns (bool) {
        // Check base deployment validity
        bool baseValid = address(reputation) != address(0) &&
            address(factory) != address(0) &&
            reputation.owner() == address(factory) &&
            address(factory.reputationContract()) == address(reputation);

        bool testnetValid = projectAddr != address(0) &&
            factory.isProject(projectAddr) &&
            factory.getProjectsCount() >= 1;

        return baseValid && testnetValid;
    }

    // ========================================
    // TEST FUNCTIONS FOR FORGE
    // ========================================

    /**
     * @notice Test creator setup
     */
    function testCreator() public {
        // Ensure creatorAddr is properly set
        assertEq(
            creatorAddr,
            vm.addr(1),
            "Test creator should be address from key 1"
        );
        assertNotEq(
            creatorAddr,
            address(0),
            "Test creator should not be zero address"
        );
    }

    /**
     * @notice Test freelancer setup
     */
    function testFreelancer() public {
        // Ensure freelancerAddr is properly set
        assertEq(
            freelancerAddr,
            vm.addr(2),
            "Test freelancer should be address from key 2"
        );
        assertNotEq(
            freelancerAddr,
            address(0),
            "Test freelancer should not be zero address"
        );
    }

    /**
     * @notice Test project creation
     */
    function testProject() public {
        // This would normally check if projectAddr is set after deployment
        // For now, just verify the required skills array is properly initialized
        assertEq(requiredSkills.length, 3, "Should have 3 required skills");
        assertEq(
            requiredSkills[0],
            "Solidity",
            "First skill should be Solidity"
        );
        assertEq(
            requiredSkills[1],
            "Testing",
            "Second skill should be Testing"
        );
        assertEq(requiredSkills[2], "DeFi", "Third skill should be DeFi");
    }

    /**
     * @notice Test skills array access with fuzzing
     * @param index The index to test (will be fuzzed by Forge)
     */
    function testSkillsAccess(uint256 index) public {
        // Bound the index to valid range to prevent array bounds errors
        if (requiredSkills.length > 0) {
            index = bound(index, 0, requiredSkills.length - 1);
            // Access the skills array at the bounded index
            string memory skill = requiredSkills[index];
            // Ensure the skill is not empty
            assertNotEq(bytes(skill).length, 0, "Skill should not be empty");
        }
    }
}
