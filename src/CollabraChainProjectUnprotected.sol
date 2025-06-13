// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/IProjectFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CollabraChainProject - UNPROTECTED VERSION FOR HACKATHON
 * @notice A smart contract for managing freelance projects with milestone-based payments
 * @dev UNPROTECTED - All validations and access controls removed for easy development
 */
contract CollabraChainProject {
    // ========================================
    // ENUMS & STRUCTS
    // ========================================

    enum ProjectState {
        Open, // Project is open for applications
        InProgress, // Freelancer assigned, work in progress
        Completed, // All milestones completed successfully
        Canceled // Project canceled by creator
    }

    enum MilestoneState {
        Defined, // Milestone created but not funded
        Funded, // Milestone funded, ready for work
        Submitted, // Work submitted, pending approval
        Approved, // Work approved, payment released
        Disputed // Work disputed, pending resolution
    }

    /**
     * @notice Project metadata for better project discovery and management
     */
    struct ProjectMetadata {
        string title; // Project title
        string description; // Detailed project description
        string category; // Project category (e.g., "Web Development", "Design")
        string[] skillsRequired; // Required skills
        uint256 totalBudget; // Total project budget
        uint256 deadline; // Project deadline timestamp
        string projectScopeCID; // IPFS CID for detailed project scope
        string xmtpRoomId; // XMTP protocol room ID for AI agent and user interactions
    }

    /**
     * @notice Milestone structure for work organization and payments
     */
    struct Milestone {
        string description; // Milestone description
        uint256 budget; // Milestone budget in wei
        MilestoneState state; // Current milestone state
        string workSubmissionCID; // IPFS CID for submitted work
        uint256 deadline; // Milestone deadline
    }

    // ========================================
    // STATE VARIABLES
    // ========================================

    // Core project actors
    address public creator;
    address public reputationContract;
    address public factory;
    address payable public freelancer;
    address public arbiter;

    // Payment token (USDC)
    IERC20 public usdcToken;

    // Project state
    ProjectState public projectState;
    ProjectMetadata public projectMetadata;

    // Milestones and payments
    Milestone[] public milestones;

    // Application system
    mapping(address => bool) public applicants;
    address[] public applicantList;

    // Timestamps for tracking
    uint256 public createdAt;
    uint256 public startedAt;
    uint256 public completedAt;

    // ========================================
    // AI AGENT DELEGATION SYSTEM
    // ========================================

    // Delegation mappings: user => agent => permissions
    mapping(address => mapping(address => bool)) public creatorDelegates;
    mapping(address => mapping(address => bool)) public freelancerDelegates;
    mapping(address => mapping(address => bool)) public arbiterDelegates;

    // Agent to user mapping for easy lookup
    mapping(address => address) public agentToCreator;
    mapping(address => address) public agentToFreelancer;
    mapping(address => address) public agentToArbiter;

    // ========================================
    // EVENTS - Organized by Epic
    // ========================================

    // Epic: Project Lifecycle Management
    event ProjectCreated(
        address indexed creator,
        string title,
        string category,
        uint256 totalBudget,
        uint256 deadline,
        string xmtpRoomId
    );
    event ProjectInvitation(address indexed invitee, address indexed creator);
    event Applied(address indexed applicant, uint256 timestamp);
    event FreelancerApproved(address indexed freelancer, uint256 timestamp);
    event ProjectStarted(address indexed freelancer, uint256 timestamp);
    event ProjectCanceled(uint256 timestamp);

    // Epic: Milestone & Payment System
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

    // Epic: Dispute Resolution
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

    // Epic: Reputation & Rewards
    event ProjectCompleted(uint256 completedAt);
    event ReputationTokenMinted(
        address indexed recipient,
        string role,
        string sbtCID
    );

    // Epic: AI Agent Delegation
    event AgentDelegated(
        address indexed user,
        address indexed agent,
        string role,
        uint256 timestamp
    );
    event AgentRevoked(
        address indexed user,
        address indexed agent,
        string role,
        uint256 timestamp
    );

    /**
     * @notice Constructor for project creation
     * @dev UNPROTECTED - No validations for hackathon ease
     */
    constructor(
        address payable _creator,
        address _reputationContract,
        address _factory,
        address _usdcToken,
        string memory _title,
        string memory _description,
        string memory _category,
        string[] memory _skillsRequired,
        uint256 _totalBudget,
        uint256 _deadline,
        string memory _projectScopeCID,
        string memory _xmtpRoomId
    ) {
        creator = _creator;
        reputationContract = _reputationContract;
        factory = _factory;
        if (_usdcToken != address(0)) {
            usdcToken = IERC20(_usdcToken);
        }
        projectState = ProjectState.Open;
        arbiter = _creator;
        createdAt = block.timestamp;

        // Initialize project metadata
        projectMetadata = ProjectMetadata({
            title: _title,
            description: _description,
            category: _category,
            skillsRequired: _skillsRequired,
            totalBudget: _totalBudget,
            deadline: _deadline,
            projectScopeCID: _projectScopeCID,
            xmtpRoomId: _xmtpRoomId
        });

        emit ProjectCreated(
            _creator,
            _title,
            _category,
            _totalBudget,
            _deadline,
            _xmtpRoomId
        );
    }

    // ========================================
    // AI AGENT DELEGATION FUNCTIONS - UNPROTECTED
    // ========================================

    /**
     * @notice Anyone can delegate authority to an AI Agent (UNPROTECTED)
     */
    function delegateCreatorToAgent(address _agent) external {
        creatorDelegates[msg.sender][_agent] = true;
        agentToCreator[_agent] = msg.sender;
        emit AgentDelegated(msg.sender, _agent, "Creator", block.timestamp);
    }

    /**
     * @notice Anyone can delegate freelancer authority to an AI Agent (UNPROTECTED)
     */
    function delegateFreelancerToAgent(address _agent) external {
        freelancerDelegates[msg.sender][_agent] = true;
        agentToFreelancer[_agent] = msg.sender;
        emit AgentDelegated(msg.sender, _agent, "Freelancer", block.timestamp);
    }

    /**
     * @notice Anyone can delegate arbiter authority to an AI Agent (UNPROTECTED)
     */
    function delegateArbiterToAgent(address _agent) external {
        arbiterDelegates[msg.sender][_agent] = true;
        agentToArbiter[_agent] = msg.sender;
        emit AgentDelegated(msg.sender, _agent, "Arbiter", block.timestamp);
    }

    /**
     * @notice Anyone can revoke agent delegation (UNPROTECTED)
     */
    function revokeCreatorAgent(address _agent) external {
        creatorDelegates[msg.sender][_agent] = false;
        delete agentToCreator[_agent];
        emit AgentRevoked(msg.sender, _agent, "Creator", block.timestamp);
    }

    /**
     * @notice Anyone can revoke freelancer agent delegation (UNPROTECTED)
     */
    function revokeFreelancerAgent(address _agent) external {
        freelancerDelegates[msg.sender][_agent] = false;
        delete agentToFreelancer[_agent];
        emit AgentRevoked(msg.sender, _agent, "Freelancer", block.timestamp);
    }

    /**
     * @notice Anyone can revoke arbiter agent delegation (UNPROTECTED)
     */
    function revokeArbiterAgent(address _agent) external {
        arbiterDelegates[msg.sender][_agent] = false;
        delete agentToArbiter[_agent];
        emit AgentRevoked(msg.sender, _agent, "Arbiter", block.timestamp);
    }

    // ========================================
    // PROJECT LIFECYCLE MANAGEMENT - UNPROTECTED
    // ========================================

    /**
     * @notice Anyone can apply to project (UNPROTECTED)
     */
    function applyProject() external {
        if (!applicants[msg.sender]) {
            applicants[msg.sender] = true;
            applicantList.push(msg.sender);
        }
        emit Applied(msg.sender, block.timestamp);
    }

    /**
     * @notice Anyone can invite freelancer (UNPROTECTED)
     */
    function inviteFreelancer(address _freelancer) external {
        emit ProjectInvitation(_freelancer, msg.sender);
    }

    /**
     * @notice Anyone can approve freelancer (UNPROTECTED)
     */
    function approveFreelancer(address payable _approvedFreelancer) external {
        // Auto-add as applicant if not already
        if (!applicants[_approvedFreelancer]) {
            applicants[_approvedFreelancer] = true;
            applicantList.push(_approvedFreelancer);
            emit Applied(_approvedFreelancer, block.timestamp);
        }

        freelancer = _approvedFreelancer;
        projectState = ProjectState.InProgress;
        startedAt = block.timestamp;

        emit FreelancerApproved(_approvedFreelancer, block.timestamp);
        emit ProjectStarted(_approvedFreelancer, block.timestamp);
    }

    /**
     * @notice Anyone can cancel project (UNPROTECTED)
     */
    function cancelProject() external {
        projectState = ProjectState.Canceled;
        emit ProjectCanceled(block.timestamp);
    }

    // ========================================
    // MILESTONE & PAYMENT SYSTEM - UNPROTECTED
    // ========================================

    /**
     * @notice Anyone can add milestone (UNPROTECTED)
     */
    function addMilestone(
        string memory _description,
        uint256 _budget,
        uint256 _deadline
    ) external {
        milestones.push(
            Milestone({
                description: _description,
                budget: _budget,
                state: MilestoneState.Defined,
                workSubmissionCID: "",
                deadline: _deadline
            })
        );
        emit MilestoneAdded(
            milestones.length - 1,
            _description,
            _budget,
            _deadline
        );
    }

    /**
     * @notice Anyone can fund milestone (UNPROTECTED)
     */
    function fundMilestone(uint256 _milestoneId) external {
        if (_milestoneId >= milestones.length) return;
        
        Milestone storage milestone = milestones[_milestoneId];
        uint256 amount = milestone.budget;
        
        // Try to transfer USDC if token is set, but don't fail if it doesn't work
        if (address(usdcToken) != address(0)) {
            try usdcToken.transferFrom(msg.sender, address(this), amount) {
                // Success
            } catch {
                // Ignore failure for hackathon
            }
        }
        
        milestone.state = MilestoneState.Funded;
        emit MilestoneFunded(_milestoneId, amount);
    }

    /**
     * @notice Anyone can submit work (UNPROTECTED)
     */
    function submitWork(
        uint256 _milestoneId,
        string memory _workCID
    ) external {
        if (_milestoneId >= milestones.length) return;
        
        milestones[_milestoneId].state = MilestoneState.Submitted;
        milestones[_milestoneId].workSubmissionCID = _workCID;
        emit WorkSubmitted(_milestoneId, _workCID, msg.sender, block.timestamp);
    }

    /**
     * @notice Anyone can release payment (UNPROTECTED)
     */
    function releasePayment(
        uint256 _milestoneId,
        string calldata _creatorSbtCID,
        string calldata _freelancerSbtCID
    ) external {
        if (_milestoneId >= milestones.length) return;
        
        Milestone storage milestone = milestones[_milestoneId];
        uint256 payment = milestone.budget;
        milestone.state = MilestoneState.Approved;

        // Try to transfer USDC if token and freelancer are set, but don't fail
        if (address(usdcToken) != address(0) && freelancer != address(0)) {
            try usdcToken.transfer(freelancer, payment) {
                // Success
            } catch {
                // Ignore failure for hackathon
            }
        }

        emit WorkApproved(_milestoneId, block.timestamp);
        emit PaymentReleased(
            _milestoneId,
            freelancer,
            payment,
            block.timestamp
        );

        // Check if project is complete and handle reputation rewards
        if (_isProjectComplete()) {
            projectState = ProjectState.Completed;
            completedAt = block.timestamp;
            uint256 projectId = uint256(uint160(address(this)));

            // Try to mint reputation tokens, but don't fail if it doesn't work
            if (factory != address(0)) {
                try IProjectFactory(factory).mintReputationForProject(
                    creator,
                    projectId,
                    "Creator",
                    _creatorSbtCID
                ) {
                    emit ReputationTokenMinted(creator, "Creator", _creatorSbtCID);
                } catch {
                    // Ignore failure for hackathon
                }

                if (freelancer != address(0)) {
                    try IProjectFactory(factory).mintReputationForProject(
                        freelancer,
                        projectId,
                        "Freelancer",
                        _freelancerSbtCID
                    ) {
                        emit ReputationTokenMinted(
                            freelancer,
                            "Freelancer",
                            _freelancerSbtCID
                        );
                    } catch {
                        // Ignore failure for hackathon
                    }
                }
            }

            emit ProjectCompleted(completedAt);
        }
    }

    // ========================================
    // DISPUTE RESOLUTION - UNPROTECTED
    // ========================================

    /**
     * @notice Anyone can raise dispute (UNPROTECTED)
     */
    function raiseDispute(
        uint256 _milestoneId,
        string memory _reason
    ) external {
        if (_milestoneId >= milestones.length) return;
        
        milestones[_milestoneId].state = MilestoneState.Disputed;
        emit DisputeRaised(_milestoneId, msg.sender, _reason, block.timestamp);
    }

    /**
     * @notice Anyone can resolve dispute (UNPROTECTED)
     */
    function resolveDispute(
        uint256 _milestoneId,
        bool _payFreelancer
    ) external {
        if (_milestoneId >= milestones.length) return;
        
        Milestone storage milestone = milestones[_milestoneId];
        uint256 payment = milestone.budget;
        milestone.state = MilestoneState.Approved;
        address recipient = _payFreelancer ? freelancer : creator;
        
        // Try to transfer USDC if token is set, but don't fail
        if (address(usdcToken) != address(0) && recipient != address(0)) {
            try usdcToken.transfer(recipient, payment) {
                // Success
            } catch {
                // Ignore failure for hackathon
            }
        }

        emit DisputeResolved(
            _milestoneId,
            _payFreelancer,
            msg.sender,
            block.timestamp
        );
        emit PaymentReleased(_milestoneId, recipient, payment, block.timestamp);
    }

    // ========================================
    // UTILITY FUNCTIONS FOR EASY TESTING
    // ========================================

    /**
     * @notice Set any project state (UNPROTECTED - for testing)
     */
    function setProjectState(ProjectState _state) external {
        projectState = _state;
    }

    /**
     * @notice Set any milestone state (UNPROTECTED - for testing)
     */
    function setMilestoneState(uint256 _milestoneId, MilestoneState _state) external {
        if (_milestoneId < milestones.length) {
            milestones[_milestoneId].state = _state;
        }
    }

    /**
     * @notice Set freelancer directly (UNPROTECTED - for testing)
     */
    function setFreelancer(address payable _freelancer) external {
        freelancer = _freelancer;
    }

    /**
     * @notice Set creator directly (UNPROTECTED - for testing)
     */
    function setCreator(address _creator) external {
        creator = _creator;
    }

    /**
     * @notice Set arbiter directly (UNPROTECTED - for testing)
     */
    function setArbiter(address _arbiter) external {
        arbiter = _arbiter;
    }

    // ========================================
    // VIEW FUNCTIONS & UTILITIES
    // ========================================

    /**
     * @notice Check if project is complete (all milestones approved)
     */
    function _isProjectComplete() internal view returns (bool) {
        if (milestones.length == 0) return false;
        for (uint i = 0; i < milestones.length; i++) {
            if (milestones[i].state != MilestoneState.Approved) return false;
        }
        return true;
    }

    /**
     * @notice Get all applicants
     */
    function getApplicants() external view returns (address[] memory) {
        return applicantList;
    }

    /**
     * @notice Get project metadata
     */
    function getProjectMetadata()
        external
        view
        returns (ProjectMetadata memory)
    {
        return projectMetadata;
    }

    /**
     * @notice Get milestone details
     */
    function getMilestone(
        uint256 _milestoneId
    ) external view returns (Milestone memory) {
        if (_milestoneId >= milestones.length) {
            return Milestone("", 0, MilestoneState.Defined, "", 0);
        }
        return milestones[_milestoneId];
    }

    /**
     * @notice Get all milestones
     */
    function getAllMilestones() external view returns (Milestone[] memory) {
        return milestones;
    }

    /**
     * @notice Get project status
     */
    function getProjectStatus()
        external
        view
        returns (
            ProjectState state,
            address currentFreelancer,
            uint256 milestonesCount,
            uint256 completedMilestones,
            uint256 totalBudget,
            uint256 paidAmount
        )
    {
        state = projectState;
        currentFreelancer = freelancer;
        milestonesCount = milestones.length;
        totalBudget = projectMetadata.totalBudget;

        uint256 completed = 0;
        uint256 paid = 0;

        for (uint i = 0; i < milestones.length; i++) {
            if (milestones[i].state == MilestoneState.Approved) {
                completed++;
                paid += milestones[i].budget;
            }
        }

        completedMilestones = completed;
        paidAmount = paid;
    }

    /**
     * @notice Check if address has applied to project
     */
    function hasApplied(address _applicant) external view returns (bool) {
        return applicants[_applicant];
    }

    /**
     * @notice Get project timeline information
     */
    function getProjectTimeline()
        external
        view
        returns (
            uint256 created,
            uint256 started,
            uint256 completed,
            uint256 deadline
        )
    {
        return (createdAt, startedAt, completedAt, projectMetadata.deadline);
    }

    /**
     * @notice Get the XMTP room ID
     */
    function getXmtpRoomId() external view returns (string memory) {
        return projectMetadata.xmtpRoomId;
    }

    // ========================================
    // AI AGENT VIEW FUNCTIONS
    // ========================================

    /**
     * @notice Check if an address is an authorized agent for creator
     */
    function isAuthorizedCreatorAgent(
        address _agent
    ) external view returns (bool) {
        return creatorDelegates[creator][_agent];
    }

    /**
     * @notice Check if an address is an authorized agent for freelancer
     */
    function isAuthorizedFreelancerAgent(
        address _agent
    ) external view returns (bool) {
        if (freelancer == address(0)) return false;
        return freelancerDelegates[freelancer][_agent];
    }

    /**
     * @notice Check if an address is an authorized agent for arbiter
     */
    function isAuthorizedArbiterAgent(
        address _agent
    ) external view returns (bool) {
        return arbiterDelegates[arbiter][_agent];
    }

    /**
     * @notice Get delegation info for an agent
     */
    function getAgentInfo(
        address _agent
    )
        external
        view
        returns (
            address delegatingCreator,
            address delegatingFreelancer,
            address delegatingArbiter,
            bool isCreatorAgent,
            bool isFreelancerAgent,
            bool isArbiterAgent
        )
    {
        delegatingCreator = agentToCreator[_agent];
        delegatingFreelancer = agentToFreelancer[_agent];
        delegatingArbiter = agentToArbiter[_agent];

        isCreatorAgent = creatorDelegates[creator][_agent];
        isFreelancerAgent =
            freelancer != address(0) &&
            freelancerDelegates[freelancer][_agent];
        isArbiterAgent = arbiterDelegates[arbiter][_agent];
    }
}
