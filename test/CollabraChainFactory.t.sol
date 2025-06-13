// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CollabraChainFactory} from "../src/CollabraChainFactory.sol";
import {CollabraChainProject} from "../src/CollabraChainProject.sol";
import {CollabraChainReputation} from "../src/CollabraChainReputation.sol";

// Mock USDC Token for testing
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name = "USD Coin";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

contract CollabraChainFactoryTest is Test {
    CollabraChainFactory internal factory;
    CollabraChainReputation internal reputation;
    MockUSDC internal usdc;
    
    address internal creator1;
    address internal creator2;
    address internal freelancer;
    address internal randomUser;
    
    // Test data for project creation
    string internal projectTitle = "DeFi Protocol Development";
    string internal projectDescription = "Build a comprehensive DeFi lending protocol";
    string internal projectCategory = "DeFi Development";
    string[] internal skillsRequired;
    uint256 internal totalBudget = 15_000_000; // 15 USDC (6 decimals)
    uint256 internal deadline;
    string internal projectScopeCID = "QmProjectScope456";

    // Events to test
    event ProjectCreated(
        address indexed projectAddress,
        address indexed creator,
        string title,
        string category,
        uint256 totalBudget,
        uint256 deadline,
        string projectScopeCID,
        string xmtpRoomId
    );

    function setUp() public {
        creator1 = makeAddr("creator1");
        creator2 = makeAddr("creator2");
        freelancer = makeAddr("freelancer");
        randomUser = makeAddr("randomUser");
        
        // Setup skills required
        skillsRequired.push("Solidity");
        skillsRequired.push("DeFi");
        skillsRequired.push("Smart Contracts");
        skillsRequired.push("Testing");
        
        deadline = block.timestamp + 45 days;
        
        // Deploy mock USDC
        usdc = new MockUSDC();
        
        // Deploy reputation contract
        reputation = new CollabraChainReputation(address(this));
        
        // Deploy factory with USDC address
        factory = new CollabraChainFactory(address(reputation), address(usdc));
        
        // Transfer reputation ownership to factory
        reputation.transferOwnership(address(factory));
        
        // Mint USDC tokens to test accounts
        usdc.mint(creator1, 100_000_000); // 100 USDC
        usdc.mint(creator2, 100_000_000); // 100 USDC
        usdc.mint(freelancer, 50_000_000); // 50 USDC
    }

    // ========================================
    // DEPLOYMENT & INITIALIZATION TESTS
    // ========================================

    function test_Factory_Deployment_Success() public {
        // Verify factory is properly initialized
        assertEq(address(factory.reputationContract()), address(reputation));
        assertEq(factory.usdcToken(), address(usdc));
        assertEq(factory.getProjectsCount(), 0);
    }

    function test_Factory_Deployment_ZeroAddress() public {
        vm.expectRevert(CollabraChainFactory.ZeroAddress.selector);
        new CollabraChainFactory(address(0), address(usdc));
        
        vm.expectRevert(CollabraChainFactory.ZeroAddress.selector);
        new CollabraChainFactory(address(reputation), address(0));
    }

    // ========================================
    // PROJECT CREATION TESTS
    // ========================================

    function test_CreateProject_Success() public {
        vm.expectEmit(false, true, false, true);
        emit ProjectCreated(
            address(0), // We don't know the project address yet
            creator1,
            projectTitle,
            projectCategory,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room-001"
        );
        
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room-001"
        );
        
        // Verify project was created
        assertTrue(projectAddress != address(0));
        assertTrue(factory.isProject(projectAddress));
        assertEq(factory.getProjectsCount(), 1);
        assertEq(factory.allProjects(0), projectAddress);
        
        // Verify project is properly initialized
        CollabraChainProject project = CollabraChainProject(payable(projectAddress));
        assertEq(project.creator(), creator1);
        assertEq(uint(project.projectState()), uint(CollabraChainProject.ProjectState.Open));
        
        // Verify project metadata
        CollabraChainProject.ProjectMetadata memory metadata = project.getProjectMetadata();
        assertEq(metadata.title, projectTitle);
        assertEq(metadata.description, projectDescription);
        assertEq(metadata.category, projectCategory);
        assertEq(metadata.skillsRequired.length, 4);
        assertEq(metadata.totalBudget, totalBudget);
        assertEq(metadata.deadline, deadline);
        assertEq(metadata.projectScopeCID, projectScopeCID);
    }

    function test_CreateProject_InvalidDeadline() public {
        vm.expectRevert(CollabraChainProject.InvalidDeadline.selector);
        vm.prank(creator1);
        factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            block.timestamp - 1, // Past deadline
            projectScopeCID,
            "test-xmtp-room-002"
        );
    }

    function test_CreateProject_EmptyTitle() public {
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            "", // Empty title should still work
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room-003"
        );
        
        assertTrue(projectAddress != address(0));
        assertEq(factory.getProjectsCount(), 1);
    }

    function test_CreateProject_ZeroBudget() public {
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            0, // Zero budget should work
            deadline,
            projectScopeCID,
            "test-xmtp-room-004"
        );
        
        assertTrue(projectAddress != address(0));
        CollabraChainProject project = CollabraChainProject(payable(projectAddress));
        CollabraChainProject.ProjectMetadata memory metadata = project.getProjectMetadata();
        assertEq(metadata.totalBudget, 0);
    }

    function test_CreateProject_EmptySkills() public {
        string[] memory emptySkills;
        
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            emptySkills, // Empty skills array
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room-005"
        );
        
        assertTrue(projectAddress != address(0));
        CollabraChainProject project = CollabraChainProject(payable(projectAddress));
        CollabraChainProject.ProjectMetadata memory metadata = project.getProjectMetadata();
        assertEq(metadata.skillsRequired.length, 0);
    }

    function test_CreateMultipleProjects_SameCreator() public {
        // Create first project
        vm.prank(creator1);
        address project1 = factory.createProject(
            "Project 1",
            "Description 1",
            "Category 1",
            skillsRequired,
            5_000_000, // 5 USDC
            deadline,
            "CID1",
            "test-xmtp-room-multi-1"
        );
        
        // Create second project
        vm.prank(creator1);
        address project2 = factory.createProject(
            "Project 2",
            "Description 2",
            "Category 2",
            skillsRequired,
            10_000_000, // 10 USDC
            deadline + 1 days,
            "CID2",
            "test-xmtp-room-multi-2"
        );
        
        assertEq(factory.getProjectsCount(), 2);
        assertTrue(factory.isProject(project1));
        assertTrue(factory.isProject(project2));
        assertNotEq(project1, project2);
        assertEq(factory.allProjects(0), project1);
        assertEq(factory.allProjects(1), project2);
    }

    function test_CreateMultipleProjects_DifferentCreators() public {
        // Creator1 creates project
        vm.prank(creator1);
        address project1 = factory.createProject(
            "Creator1 Project",
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room-creator1"
        );
        
        // Creator2 creates project
        vm.prank(creator2);
        address project2 = factory.createProject(
            "Creator2 Project",
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room-creator2"
        );
        
        assertEq(factory.getProjectsCount(), 2);
        
        // Verify project creators
        CollabraChainProject proj1 = CollabraChainProject(payable(project1));
        CollabraChainProject proj2 = CollabraChainProject(payable(project2));
        assertEq(proj1.creator(), creator1);
        assertEq(proj2.creator(), creator2);
    }

    // ========================================
    // REPUTATION MINTING TESTS
    // ========================================

    function test_MintReputationForProject_Success() public {
        // Create a project first
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room"
        );
        
        uint256 projectId = 123;
        string memory role = "Creator";
        string memory metadataCID = "QmReputationMetadata123";
        
        // Mint reputation token from the project contract
        vm.prank(projectAddress);
        factory.mintReputationForProject(creator1, projectId, role, metadataCID);
        
        // Verify the token was minted
        assertEq(reputation.balanceOf(creator1), 1);
        assertEq(reputation.ownerOf(1), creator1);
        
        // Verify token data
        CollabraChainReputation.ReputationData memory data = reputation.getTokenData(1);
        assertEq(data.projectId, projectId);
        assertEq(data.role, role);
        assertTrue(data.timestamp > 0);
        
        // Verify token URI
        string memory expectedURI = string(abi.encodePacked("ipfs://", metadataCID));
        assertEq(reputation.tokenURI(1), expectedURI);
    }

    function test_MintReputationForProject_UnauthorizedProject() public {
        uint256 projectId = 123;
        string memory role = "Creator";
        string memory metadataCID = "QmReputationMetadata123";
        
        // Try to mint from a non-project address
        vm.expectRevert(CollabraChainFactory.UnauthorizedProject.selector);
        vm.prank(randomUser);
        factory.mintReputationForProject(creator1, projectId, role, metadataCID);
    }

    function test_MintReputationForProject_MultipleTokens() public {
        // Create a project
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room"
        );
        
        // Mint token for creator
        vm.prank(projectAddress);
        factory.mintReputationForProject(creator1, 123, "Creator", "CreatorCID");
        
        // Mint token for freelancer
        vm.prank(projectAddress);
        factory.mintReputationForProject(freelancer, 123, "Freelancer", "FreelancerCID");
        
        // Verify both tokens were minted
        assertEq(reputation.balanceOf(creator1), 1);
        assertEq(reputation.balanceOf(freelancer), 1);
        assertEq(reputation.ownerOf(1), creator1);
        assertEq(reputation.ownerOf(2), freelancer);
        
        // Verify token data
        CollabraChainReputation.ReputationData memory creatorData = reputation.getTokenData(1);
        CollabraChainReputation.ReputationData memory freelancerData = reputation.getTokenData(2);
        
        assertEq(creatorData.role, "Creator");
        assertEq(freelancerData.role, "Freelancer");
        assertEq(creatorData.projectId, freelancerData.projectId);
    }

    // ========================================
    // INTEGRATION TESTS (End-to-End Workflow)
    // ========================================

    function test_FullWorkflow_ProjectCreationToCompletion() public {
        // 1. Create project
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room"
        );
        
        CollabraChainProject project = CollabraChainProject(payable(projectAddress));
        
        // 2. Freelancer applies
        vm.prank(freelancer);
        project.applyProject();
        
        // 3. Creator approves freelancer
        vm.prank(creator1);
        project.approveFreelancer(payable(freelancer));
        
        // 4. Creator adds milestone
        vm.prank(creator1);
        project.addMilestone("Development Phase", 5_000_000, deadline - 7 days); // 5 USDC
        
        // 5. Creator funds milestone
        vm.prank(creator1);
        usdc.approve(address(project), 5_000_000); // 5 USDC
        vm.prank(creator1);
        project.fundMilestone(0);
        
        // 6. Freelancer submits work
        vm.prank(freelancer);
        project.submitWork(0, "QmWorkSubmission");
        
        // 7. Creator approves work and releases payment (should trigger reputation minting)
        vm.prank(creator1);
        project.releasePayment(0, "CreatorSBT", "FreelancerSBT");
        
        // 8. Verify project completion and reputation minting
        assertEq(uint(project.projectState()), uint(CollabraChainProject.ProjectState.Completed));
        assertEq(reputation.balanceOf(creator1), 1);
        assertEq(reputation.balanceOf(freelancer), 1);
        
        // Verify reputation token data
        CollabraChainReputation.ReputationData memory creatorData = reputation.getTokenData(1);
        CollabraChainReputation.ReputationData memory freelancerData = reputation.getTokenData(2);
        
        assertEq(creatorData.role, "Creator");
        assertEq(freelancerData.role, "Freelancer");
        assertEq(creatorData.projectId, freelancerData.projectId);
    }

    // ========================================
    // VIEW FUNCTIONS TESTS
    // ========================================

    function test_GetProjectsCount_EmptyFactory() public {
        assertEq(factory.getProjectsCount(), 0);
    }

    function test_GetProjectsCount_WithProjects() public {
        // Create projects
        vm.prank(creator1);
        factory.createProject(
            "Project 1", projectDescription, projectCategory,
            skillsRequired, totalBudget, deadline, "CID1",
            "test-xmtp-room-1"
        );
        
        vm.prank(creator1);
        factory.createProject(
            "Project 2", projectDescription, projectCategory,
            skillsRequired, totalBudget, deadline, "CID2",
            "test-xmtp-room-2"
        );
        
        assertEq(factory.getProjectsCount(), 2);
    }

    function test_AllProjects_Array() public {
        // Create multiple projects
        vm.prank(creator1);
        address project1 = factory.createProject(
            "Project 1", projectDescription, projectCategory,
            skillsRequired, totalBudget, deadline, "CID1",
            "test-xmtp-room-array-1"
        );
        
        vm.prank(creator2);
        address project2 = factory.createProject(
            "Project 2", projectDescription, projectCategory,
            skillsRequired, totalBudget, deadline, "CID2",
            "test-xmtp-room-array-2"
        );
        
        // Verify array contains correct addresses
        assertEq(factory.allProjects(0), project1);
        assertEq(factory.allProjects(1), project2);
    }

    function test_IsProject_Validation() public {
        // Create a project
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle, projectDescription, projectCategory,
            skillsRequired, totalBudget, deadline, projectScopeCID,
            "test-xmtp-room"
        );
        
        // Test validation
        assertTrue(factory.isProject(projectAddress));
        assertFalse(factory.isProject(address(0)));
        assertFalse(factory.isProject(randomUser));
        assertFalse(factory.isProject(address(factory)));
    }

    // ========================================
    // STRESS TESTS
    // ========================================

    function test_CreateManyProjects() public {
        uint256 numProjects = 10;
        
        for (uint256 i = 0; i < numProjects; i++) {
            vm.prank(creator1);
            address projectAddress = factory.createProject(
                string(abi.encodePacked("Project ", vm.toString(i))),
                projectDescription,
                projectCategory,
                skillsRequired,
                totalBudget + i * 1_000_000, // Adding 1 USDC per project
                deadline + i * 1 days,
                string(abi.encodePacked("CID", vm.toString(i))),
                string(abi.encodePacked("test-xmtp-room-", vm.toString(i)))
            );
            
            assertTrue(factory.isProject(projectAddress));
            assertEq(factory.allProjects(i), projectAddress);
        }
        
        assertEq(factory.getProjectsCount(), numProjects);
    }

    function test_LargeSkillsArray() public {
        string[] memory largeSkillsArray = new string[](20);
        for (uint256 i = 0; i < 20; i++) {
            largeSkillsArray[i] = string(abi.encodePacked("Skill", vm.toString(i)));
        }
        
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            largeSkillsArray,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room"
        );
        
        CollabraChainProject project = CollabraChainProject(payable(projectAddress));
        CollabraChainProject.ProjectMetadata memory metadata = project.getProjectMetadata();
        assertEq(metadata.skillsRequired.length, 20);
    }

    // ========================================
    // ERROR EDGE CASES
    // ========================================

    function test_ReputationContract_Reference() public {
        assertEq(address(factory.reputationContract()), address(reputation));
        assertTrue(address(factory.reputationContract()) != address(0));
    }

    function test_Factory_Events_Emission() public {
        // Test that events are properly emitted during project creation
        vm.expectEmit(false, true, false, true);
        emit ProjectCreated(
            address(0), // We don't know the project address yet
            creator1,
            projectTitle,
            projectCategory,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room"
        );
        
        vm.prank(creator1);
        address projectAddress = factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            deadline,
            projectScopeCID,
            "test-xmtp-room"
        );
        
        // Verify project was created successfully
        assertTrue(projectAddress != address(0));
        assertTrue(factory.isProject(projectAddress));
    }

    // Allow contract to receive ETH
    receive() external payable {}
} 