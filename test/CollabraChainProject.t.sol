// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {CollabraChainProject} from "../src/CollabraChainProject.sol";
import {CollabraChainFactory} from "../src/CollabraChainFactory.sol";
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

contract CollabraChainProjectTest is Test {
    CollabraChainProject internal project;
    CollabraChainFactory internal factory;
    CollabraChainReputation internal reputation;
    MockUSDC internal usdc;

    address internal creator;
    address internal freelancer1;
    address internal freelancer2;
    address internal arbiter;
    address internal randomUser;

    // Project metadata for testing
    string internal projectTitle = "Build DeFi Protocol";
    string internal projectDescription =
        "Create a lending protocol with smart contracts";
    string internal projectCategory = "DeFi Development";
    string[] internal skillsRequired;
    uint256 internal totalBudget = 10_000_000; // 10 USDC (6 decimals)
    uint256 internal deadline;
    string internal projectScopeCID = "QmProjectScope123";

    // Events to test
    event ProjectCreated(
        address indexed creator,
        string title,
        string category,
        uint256 totalBudget,
        uint256 deadline
    );
    event Applied(address indexed applicant, uint256 timestamp);
    event ProjectInvitation(address indexed invitee, address indexed creator);
    event FreelancerApproved(address indexed freelancer, uint256 timestamp);
    event ProjectStarted(address indexed freelancer, uint256 timestamp);
    event ProjectCanceled(uint256 timestamp);
    event MilestoneAdded(
        uint256 indexed milestoneId,
        string description,
        uint256 budget,
        uint256 deadline
    );
    event MilestoneFunded(uint256 indexed milestoneId, uint256 amount);
    event WorkSubmitted(
        uint256 indexed milestoneId,
        string workCID,
        address indexed freelancer,
        uint256 timestamp
    );
    event WorkApproved(uint256 indexed milestoneId, uint256 timestamp);
    event PaymentReleased(
        uint256 indexed milestoneId,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    event DisputeRaised(
        uint256 indexed milestoneId,
        address indexed creator,
        string reason,
        uint256 timestamp
    );
    event DisputeResolved(
        uint256 indexed milestoneId,
        bool payFreelancer,
        address indexed arbiter,
        uint256 timestamp
    );
    event ProjectCompleted(uint256 completedAt);
    event ReputationTokenMinted(
        address indexed recipient,
        string role,
        string sbtCID
    );

    function setUp() public {
        creator = makeAddr("creator");
        freelancer1 = makeAddr("freelancer1");
        freelancer2 = makeAddr("freelancer2");
        arbiter = makeAddr("arbiter");
        randomUser = makeAddr("randomUser");

        // Setup skills required
        skillsRequired.push("Solidity");
        skillsRequired.push("DeFi");
        skillsRequired.push("Testing");

        deadline = block.timestamp + 30 days;

        // Deploy mock USDC
        usdc = new MockUSDC();

        // Deploy reputation contract with factory as future owner
        reputation = new CollabraChainReputation(address(this));

        // Deploy factory with USDC address
        factory = new CollabraChainFactory(address(reputation), address(usdc));

        // Transfer reputation ownership to factory
        reputation.transferOwnership(address(factory));

        // Mint USDC tokens to users
        usdc.mint(creator, 100_000_000); // 100 USDC
        usdc.mint(freelancer1, 100_000_000); // 100 USDC
        usdc.mint(freelancer2, 100_000_000); // 100 USDC
        usdc.mint(randomUser, 100_000_000); // 100 USDC

        // Create project through factory
        vm.prank(creator);
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

        project = CollabraChainProject(payable(projectAddress));
    }

    // ========================================
    // EPIC: PROJECT LIFECYCLE MANAGEMENT TESTS
    // ========================================

    function test_ProjectCreation_Success() public {
        // Verify project metadata
        CollabraChainProject.ProjectMetadata memory metadata = project
            .getProjectMetadata();
        assertEq(metadata.title, projectTitle);
        assertEq(metadata.description, projectDescription);
        assertEq(metadata.category, projectCategory);
        assertEq(metadata.skillsRequired.length, 3);
        assertEq(metadata.totalBudget, totalBudget);
        assertEq(metadata.deadline, deadline);
        assertEq(metadata.projectScopeCID, projectScopeCID);

        // Verify initial state
        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.Open)
        );
        assertEq(project.creator(), creator);
        assertEq(project.freelancer(), address(0));
    }

    function test_ProjectCreation_InvalidDeadline() public {
        vm.expectRevert(CollabraChainProject.InvalidDeadline.selector);
        vm.prank(creator);
        factory.createProject(
            projectTitle,
            projectDescription,
            projectCategory,
            skillsRequired,
            totalBudget,
            block.timestamp - 1, // Past deadline
            projectScopeCID,
            "test-xmtp-room"
        );
    }

    function test_ApplicationSystem_Success() public {
        vm.expectEmit(true, false, false, true);
        emit Applied(freelancer1, block.timestamp);

        vm.prank(freelancer1);
        project.applyProject();

        assertTrue(project.hasApplied(freelancer1));
        assertFalse(project.hasApplied(freelancer2));

        address[] memory applicants = project.getApplicants();
        assertEq(applicants.length, 1);
        assertEq(applicants[0], freelancer1);
    }

    function test_ApplicationSystem_AlreadyApplied() public {
        vm.prank(freelancer1);
        project.applyProject();

        vm.expectRevert(CollabraChainProject.AlreadyApplied.selector);
        vm.prank(freelancer1);
        project.applyProject();
    }

    function test_ApplicationSystem_WrongState() public {
        // Approve a freelancer to change state
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        vm.expectRevert(CollabraChainProject.InvalidState.selector);
        vm.prank(freelancer2);
        project.applyProject();
    }

    function test_DirectInvitation_Success() public {
        vm.expectEmit(true, true, false, false);
        emit ProjectInvitation(freelancer1, creator);

        vm.prank(creator);
        project.inviteFreelancer(freelancer1);
    }

    function test_DirectInvitation_ZeroAddress() public {
        vm.expectRevert(CollabraChainProject.ZeroAddress.selector);
        vm.prank(creator);
        project.inviteFreelancer(address(0));
    }

    function test_FreelancerApproval_FromApplication() public {
        // Freelancer applies first
        vm.prank(freelancer1);
        project.applyProject();

        vm.expectEmit(true, false, false, true);
        emit FreelancerApproved(freelancer1, block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit ProjectStarted(freelancer1, block.timestamp);

        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        assertEq(project.freelancer(), freelancer1);
        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.InProgress)
        );
    }

    function test_FreelancerApproval_DirectInvitation() public {
        // Direct approval without prior application
        vm.expectEmit(true, false, false, true);
        emit Applied(freelancer1, block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit FreelancerApproved(freelancer1, block.timestamp);

        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        assertTrue(project.hasApplied(freelancer1));
        assertEq(project.freelancer(), freelancer1);
    }

    function test_ProjectCancellation_Success() public {
        vm.expectEmit(false, false, false, true);
        emit ProjectCanceled(block.timestamp);

        vm.prank(creator);
        project.cancelProject();

        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.Canceled)
        );
    }

    // ========================================
    // NEW TESTS FOR BRANCH COVERAGE
    // ========================================

    function test_ProjectCancellation_InProgress() public {
        // Setup project in progress
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.InProgress)
        );

        vm.expectEmit(false, false, false, true);
        emit ProjectCanceled(block.timestamp);

        vm.prank(creator);
        project.cancelProject();

        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.Canceled)
        );
    }

    function test_ProjectCancellation_Completed_ShouldRevert() public {
        // Complete a project first
        _setupSubmittedMilestone();

        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");

        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.Completed)
        );

        // Try to cancel completed project - should revert
        vm.expectRevert("Cannot cancel completed project");
        vm.prank(creator);
        project.cancelProject();
    }

    function test_ProjectCompletion_PartialMilestones() public {
        // Setup project with multiple milestones
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        // Add two milestones
        vm.prank(creator);
        project.addMilestone("Milestone 1", 2_000_000, block.timestamp + 7 days);

        vm.prank(creator);
        project.addMilestone("Milestone 2", 3_000_000, block.timestamp + 14 days);

        // Fund and complete only the first milestone
        vm.prank(creator);
        usdc.approve(address(project), 2_000_000);
        vm.prank(creator);
        project.fundMilestone(0);

        vm.prank(freelancer1);
        project.submitWork(0, "QmWork1");

        // Release payment for first milestone - project should NOT be complete
        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");

        // Project should still be in progress (not completed)
        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.InProgress)
        );

        // Verify only one milestone is approved
        CollabraChainProject.Milestone memory milestone1 = project.getMilestone(
            0
        );
        CollabraChainProject.Milestone memory milestone2 = project.getMilestone(
            1
        );

        assertEq(
            uint(milestone1.state),
            uint(CollabraChainProject.MilestoneState.Approved)
        );
        assertEq(
            uint(milestone2.state),
            uint(CollabraChainProject.MilestoneState.Defined)
        );
    }

    function test_IsProjectComplete_EmptyMilestones() public {
        // Project with no milestones should not be complete
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        // Try to call releasePayment without any milestones (should revert due to array bounds)
        vm.expectRevert();
        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");
    }

    function test_GetProjectStatus_WithMixedMilestones() public {
        // Setup project with multiple milestones in different states
        _setupMilestone(); // Creates one milestone

        // Add another milestone
        vm.prank(creator);
        project.addMilestone(
            "Second milestone",
            2_000_000, // 2 USDC
            block.timestamp + 14 days
        );

        // Fund and complete first milestone only
        vm.prank(creator);
        usdc.approve(address(project), 3_000_000); // 3 USDC
        vm.prank(creator);
        project.fundMilestone(0);

        vm.prank(freelancer1);
        project.submitWork(0, "QmWork1");

        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");

        // Check project status with mixed milestone states
        (
            CollabraChainProject.ProjectState state,
            address currentFreelancer,
            uint256 milestonesCount,
            uint256 completedMilestones, // totalBudgetView - unused in this test
            ,
            uint256 paidAmount
        ) = project.getProjectStatus();

        assertEq(
            uint(state),
            uint(CollabraChainProject.ProjectState.InProgress)
        );
        assertEq(currentFreelancer, freelancer1);
        assertEq(milestonesCount, 2);
        assertEq(completedMilestones, 1); // Only first milestone completed
        assertEq(paidAmount, 3_000_000); // Only first milestone paid (3 USDC)
    }

    function test_OnlyArbiter_ResolveDispute() public {
        _setupDisputedMilestone();

        // Test that only arbiter can resolve dispute
        vm.expectRevert(CollabraChainProject.Unauthorized.selector);
        vm.prank(freelancer1);
        project.resolveDispute(0, true);

        vm.expectRevert(CollabraChainProject.Unauthorized.selector);
        vm.prank(randomUser);
        project.resolveDispute(0, false);
    }

    function test_MilestoneStates_InvalidTransitions() public {
        _setupMilestone();

        // Try to submit work before funding
        vm.expectRevert(CollabraChainProject.InvalidState.selector);
        vm.prank(freelancer1);
        project.submitWork(0, "QmWork");

        // Fund milestone
        vm.prank(creator);
        usdc.approve(address(project), 3_000_000); // 3 USDC
        vm.prank(creator);
        project.fundMilestone(0);

        // Try to fund again - should fail because milestone is already funded
        vm.prank(creator);
        usdc.approve(address(project), 3_000_000); // 3 USDC
        
        vm.expectRevert(CollabraChainProject.InvalidState.selector);
        vm.prank(creator);
        project.fundMilestone(0);
    }

    function test_ProjectStates_InvalidTransitions() public {
        // Try operations in wrong project state
        vm.expectRevert(CollabraChainProject.InvalidState.selector);
        vm.prank(creator);
        project.addMilestone("Test", 1_000_000, block.timestamp + 1 days); // 1 USDC

        // Approve freelancer to change state
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        // Try to apply in wrong state
        vm.expectRevert(CollabraChainProject.InvalidState.selector);
        vm.prank(freelancer2);
        project.applyProject();
    }

    function test_DisputeRaiseAndResolve_BothPaths() public {
        _setupSubmittedMilestone();

        uint256 creatorInitialBalance = usdc.balanceOf(creator);
        uint256 freelancerInitialBalance = usdc.balanceOf(freelancer1);

        // Raise dispute
        vm.prank(creator);
        project.raiseDispute(0, "Work quality issues");

        // Test resolving dispute in favor of creator (payment to creator)
        vm.prank(creator); // Creator is arbiter by default
        project.resolveDispute(0, false); // false = pay creator

        assertEq(usdc.balanceOf(creator), creatorInitialBalance + 3_000_000); // +3 USDC
        assertEq(usdc.balanceOf(freelancer1), freelancerInitialBalance); // No payment to freelancer
    }

    function test_FreelancerApproval_ZeroAddress() public {
        vm.expectRevert(CollabraChainProject.ZeroAddress.selector);
        vm.prank(creator);
        project.approveFreelancer(payable(address(0)));
    }

    function test_InviteFreelancer_ZeroAddress() public {
        vm.expectRevert(CollabraChainProject.ZeroAddress.selector);
        vm.prank(creator);
        project.inviteFreelancer(address(0));
    }

    function test_AddMilestone_OnlyInProgress() public {
        // Try to add milestone in Open state
        vm.expectRevert(CollabraChainProject.InvalidState.selector);
        vm.prank(creator);
        project.addMilestone("Test", 1_000_000, block.timestamp + 1 days); // 1 USDC
    }

    function test_NonExistentMilestone_Operations() public {
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        // Try operations on non-existent milestone
        vm.prank(creator);
        usdc.approve(address(project), 1_000_000); // 1 USDC
        
        vm.expectRevert();
        vm.prank(creator);
        project.fundMilestone(999);

        vm.expectRevert();
        vm.prank(freelancer1);
        project.submitWork(999, "QmWork");

        vm.expectRevert();
        vm.prank(creator);
        project.releasePayment(999, "creatorSBT", "freelancerSBT");
    }

    function test_GetProjectTimeline_WithAllTimestamps() public {
        // Complete project to set all timestamps
        _setupSubmittedMilestone();
        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");

        (
            uint256 created,
            uint256 started,
            uint256 completed,
            uint256 projectDeadline
        ) = project.getProjectTimeline();

        assertTrue(created > 0);
        assertTrue(started > 0);
        assertTrue(completed > 0);
        assertEq(projectDeadline, deadline);
        assertTrue(started >= created);
        assertTrue(completed >= started);
    }

    // ========================================
    // EPIC: MILESTONE & PAYMENT SYSTEM TESTS
    // ========================================

    function test_MilestoneDefinition_Success() public {
        // Setup: Approve freelancer first
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        string memory milestoneDesc = "Smart contract development";
        uint256 milestoneBudget = 3_000_000; // 3 USDC
        uint256 milestoneDeadline = block.timestamp + 7 days;

        vm.expectEmit(true, false, false, true);
        emit MilestoneAdded(
            0,
            milestoneDesc,
            milestoneBudget,
            milestoneDeadline
        );

        vm.prank(creator);
        project.addMilestone(milestoneDesc, milestoneBudget, milestoneDeadline);

        CollabraChainProject.Milestone memory milestone = project.getMilestone(
            0
        );
        assertEq(milestone.description, milestoneDesc);
        assertEq(milestone.budget, milestoneBudget);
        assertEq(milestone.deadline, milestoneDeadline);
        assertEq(
            uint(milestone.state),
            uint(CollabraChainProject.MilestoneState.Defined)
        );
    }

    function test_MilestoneDefinition_InvalidDeadline() public {
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        vm.expectRevert(CollabraChainProject.InvalidDeadline.selector);
        vm.prank(creator);
        project.addMilestone("Test", 1_000_000, block.timestamp - 1); // 1 USDC
    }

    function test_MilestoneFunding_Success() public {
        _setupMilestone();

        vm.prank(creator);
        usdc.approve(address(project), 3_000_000); // 3 USDC
        
        vm.expectEmit(true, false, false, true);
        emit MilestoneFunded(0, 3_000_000); // 3 USDC
        
        vm.prank(creator);
        project.fundMilestone(0);

        CollabraChainProject.Milestone memory milestone = project.getMilestone(
            0
        );
        assertEq(
            uint(milestone.state),
            uint(CollabraChainProject.MilestoneState.Funded)
        );
    }

    function test_MilestoneFunding_InvalidAmount() public {
        _setupMilestone();

        // Check allowance and budget before
        CollabraChainProject.Milestone memory milestone = project.getMilestone(0);
        uint256 requiredAmount = milestone.budget; // Should be 3_000_000
        uint256 approvedAmount = 2_000_000;
        
        // Approve insufficient amount
        vm.prank(creator);
        usdc.approve(address(project), approvedAmount);
        
        // Check allowance after approve
        uint256 allowanceAfter = usdc.allowance(creator, address(project));
        assertEq(allowanceAfter, approvedAmount);
        
        // This should fail because allowance (2M) < required (3M)
        vm.expectRevert(
            abi.encodeWithSelector(
                CollabraChainProject.InvalidAmount.selector,
                approvedAmount,
                requiredAmount
            )
        );
        vm.prank(creator);
        project.fundMilestone(0);
    }

    function test_WorkSubmission_Success() public {
        _setupFundedMilestone();

        string memory workCID = "QmWorkSubmission123";

        vm.expectEmit(true, false, true, true);
        emit WorkSubmitted(0, workCID, freelancer1, block.timestamp);

        vm.prank(freelancer1);
        project.submitWork(0, workCID);

        CollabraChainProject.Milestone memory milestone = project.getMilestone(
            0
        );
        assertEq(
            uint(milestone.state),
            uint(CollabraChainProject.MilestoneState.Submitted)
        );
        assertEq(milestone.workSubmissionCID, workCID);
    }

    function test_WorkApprovalAndPayment_Success() public {
        _setupSubmittedMilestone();

        uint256 initialBalance = usdc.balanceOf(freelancer1);

        vm.expectEmit(true, false, false, true);
        emit WorkApproved(0, block.timestamp);

        vm.expectEmit(true, true, false, true);
        emit PaymentReleased(0, freelancer1, 3_000_000, block.timestamp); // 3 USDC

        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");

        assertEq(usdc.balanceOf(freelancer1), initialBalance + 3_000_000); // +3 USDC

        CollabraChainProject.Milestone memory milestone = project.getMilestone(
            0
        );
        assertEq(
            uint(milestone.state),
            uint(CollabraChainProject.MilestoneState.Approved)
        );
    }

    function test_ProjectCompletion_WithReputationMinting() public {
        _setupSubmittedMilestone();

        vm.expectEmit(true, false, false, false);
        emit ReputationTokenMinted(creator, "Creator", "creatorSBT");

        vm.expectEmit(true, false, false, false);
        emit ReputationTokenMinted(freelancer1, "Freelancer", "freelancerSBT");

        vm.expectEmit(false, false, false, true);
        emit ProjectCompleted(block.timestamp);

        vm.prank(creator);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");

        assertEq(
            uint(project.projectState()),
            uint(CollabraChainProject.ProjectState.Completed)
        );
        assertTrue(project.completedAt() > 0);
    }

    // ========================================
    // EPIC: DISPUTE RESOLUTION TESTS
    // ========================================

    function test_DisputeCreation_Success() public {
        _setupSubmittedMilestone();

        string memory reason = "Work does not meet requirements";

        vm.expectEmit(true, true, false, true);
        emit DisputeRaised(0, creator, reason, block.timestamp);

        vm.prank(creator);
        project.raiseDispute(0, reason);

        CollabraChainProject.Milestone memory milestone = project.getMilestone(
            0
        );
        assertEq(
            uint(milestone.state),
            uint(CollabraChainProject.MilestoneState.Disputed)
        );
    }

    function test_DisputeResolution_PayFreelancer() public {
        _setupDisputedMilestone();

        uint256 initialBalance = usdc.balanceOf(freelancer1);

        vm.expectEmit(true, false, false, true);
        emit DisputeResolved(0, true, creator, block.timestamp);

        vm.prank(creator); // Creator is arbiter by default
        project.resolveDispute(0, true);

        assertEq(usdc.balanceOf(freelancer1), initialBalance + 3_000_000); // +3 USDC

        CollabraChainProject.Milestone memory milestone = project.getMilestone(
            0
        );
        assertEq(
            uint(milestone.state),
            uint(CollabraChainProject.MilestoneState.Approved)
        );
    }

    function test_DisputeResolution_PayCreator() public {
        _setupDisputedMilestone();

        uint256 initialBalance = usdc.balanceOf(creator);

        vm.expectEmit(true, false, false, true);
        emit DisputeResolved(0, false, creator, block.timestamp);

        vm.prank(creator);
        project.resolveDispute(0, false);

        assertEq(usdc.balanceOf(creator), initialBalance + 3_000_000); // +3 USDC
    }

    // ========================================
    // VIEW FUNCTIONS TESTS
    // ========================================

    function test_GetProjectStatus() public {
        _setupFundedMilestone();

        (
            CollabraChainProject.ProjectState state,
            address currentFreelancer,
            uint256 milestonesCount,
            uint256 completedMilestones,
            uint256 totalBudgetView,
            uint256 paidAmount
        ) = project.getProjectStatus();

        assertEq(
            uint(state),
            uint(CollabraChainProject.ProjectState.InProgress)
        );
        assertEq(currentFreelancer, freelancer1);
        assertEq(milestonesCount, 1);
        assertEq(completedMilestones, 0);
        assertEq(totalBudgetView, totalBudget);
        assertEq(paidAmount, 0);
    }

    function test_GetProjectTimeline() public {
        (
            uint256 created,
            uint256 started,
            uint256 completed,
            uint256 projectDeadline
        ) = project.getProjectTimeline();

        assertTrue(created > 0);
        assertEq(started, 0); // Not started yet
        assertEq(completed, 0); // Not completed yet
        assertEq(projectDeadline, deadline);
    }

    function test_GetAllMilestones() public {
        _setupMilestone();

        CollabraChainProject.Milestone[] memory milestones = project
            .getAllMilestones();
        assertEq(milestones.length, 1);
        assertEq(milestones[0].description, "Smart contract development");
    }

    function test_GetMilestoneNotFound() public {
        vm.expectRevert(CollabraChainProject.MilestoneNotFound.selector);
        project.getMilestone(999);
    }

    // ========================================
    // ACCESS CONTROL TESTS
    // ========================================

    function test_OnlyCreator_AddMilestone() public {
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        vm.expectRevert(CollabraChainProject.Unauthorized.selector);
        vm.prank(freelancer1);
        project.addMilestone("Test", 1_000_000, block.timestamp + 1 days); // 1 USDC
    }

    function test_OnlyFreelancer_SubmitWork() public {
        _setupFundedMilestone();

        vm.expectRevert(CollabraChainProject.Unauthorized.selector);
        vm.prank(creator);
        project.submitWork(0, "workCID");
    }

    function test_OnlyCreator_ReleasePayment() public {
        _setupSubmittedMilestone();

        vm.expectRevert(CollabraChainProject.Unauthorized.selector);
        vm.prank(freelancer1);
        project.releasePayment(0, "creatorSBT", "freelancerSBT");
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    function _setupMilestone() internal {
        vm.prank(creator);
        project.approveFreelancer(payable(freelancer1));

        vm.prank(creator);
        project.addMilestone(
            "Smart contract development",
            3_000_000, // 3 USDC
            block.timestamp + 7 days
        );
    }

    function _setupFundedMilestone() internal {
        _setupMilestone();

        vm.prank(creator);
        usdc.approve(address(project), 3_000_000); // 3 USDC
        vm.prank(creator);
        project.fundMilestone(0);
    }

    function _setupSubmittedMilestone() internal {
        _setupFundedMilestone();

        vm.prank(freelancer1);
        project.submitWork(0, "QmWorkSubmission123");
    }

    function _setupDisputedMilestone() internal {
        _setupSubmittedMilestone();

        vm.prank(creator);
        project.raiseDispute(0, "Work does not meet requirements");
    }



    // Allow contract to receive ETH
    receive() external payable {}
}
