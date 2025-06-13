// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/IProjectFactory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CollabraChainProject
 * @notice A smart contract for managing freelance projects with milestone-based payments
 * @dev Implements project lifecycle management, milestone & payment system, dispute resolution, and reputation rewards
 */
contract CollabraChainProject is ReentrancyGuard {
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
    address public immutable creator;
    address public immutable reputationContract;
    address public immutable factory;
    address payable public freelancer;
    address public arbiter;

    // Payment token (USDC)
    IERC20 public immutable usdcToken;

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
    // ERRORS
    // ========================================

    error Unauthorized();
    error InvalidState();
    error InvalidAmount(uint256 sent, uint256 expected);
    error AlreadyApplied();
    error ZeroAddress();
    error InvalidDeadline();
    error ProjectNotFound();
    error MilestoneNotFound();
    error NotAuthorizedAgent();
    error CannotDelegateSelf();

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

    // ========================================
    // MODIFIERS
    // ========================================

    modifier onlyCreator() {
        if (msg.sender != creator) revert Unauthorized();
        _;
    }

    modifier onlyFreelancer() {
        if (msg.sender != freelancer) revert Unauthorized();
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != arbiter) revert Unauthorized();
        _;
    }

    // Enhanced modifiers with AI Agent delegation support
    modifier onlyCreatorOrAgent() {
        if (msg.sender != creator && !creatorDelegates[creator][msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyFreelancerOrAgent() {
        if (freelancer == address(0)) revert Unauthorized();
        if (
            msg.sender != freelancer &&
            !freelancerDelegates[freelancer][msg.sender]
        ) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyArbiterOrAgent() {
        if (msg.sender != arbiter && !arbiterDelegates[arbiter][msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    modifier inState(ProjectState _state) {
        if (projectState != _state) revert InvalidState();
        _;
    }

    modifier milestoneInState(uint256 _milestoneId, MilestoneState _state) {
        if (milestones[_milestoneId].state != _state) revert InvalidState();
        _;
    }

    /**
     * @notice Constructor for project creation
     * @dev Epic: Project Lifecycle Management - Project Creation
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
        if (_deadline <= block.timestamp) revert InvalidDeadline();
        if (_usdcToken == address(0)) revert ZeroAddress();

        creator = _creator;
        reputationContract = _reputationContract;
        factory = _factory;
        usdcToken = IERC20(_usdcToken);
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
    // AI AGENT DELEGATION FUNCTIONS
    // ========================================

    /**
     * @notice Creator delegates authority to an AI Agent
     * @dev Epic: AI Agent Integration - Creator Delegation
     */
    function delegateCreatorToAgent(address _agent) external {
        if (msg.sender != creator) revert Unauthorized();
        if (_agent == address(0)) revert ZeroAddress();
        if (_agent == creator) revert CannotDelegateSelf();

        creatorDelegates[creator][_agent] = true;
        agentToCreator[_agent] = creator;

        emit AgentDelegated(creator, _agent, "Creator", block.timestamp);
    }

    /**
     * @notice Freelancer delegates authority to an AI Agent
     * @dev Epic: AI Agent Integration - Freelancer Delegation
     */
    function delegateFreelancerToAgent(address _agent) external {
        if (msg.sender != freelancer) revert Unauthorized();
        if (_agent == address(0)) revert ZeroAddress();
        if (_agent == freelancer) revert CannotDelegateSelf();

        freelancerDelegates[freelancer][_agent] = true;
        agentToFreelancer[_agent] = freelancer;

        emit AgentDelegated(freelancer, _agent, "Freelancer", block.timestamp);
    }

    /**
     * @notice Arbiter delegates authority to an AI Agent
     * @dev Epic: AI Agent Integration - Arbiter Delegation
     */
    function delegateArbiterToAgent(address _agent) external {
        if (msg.sender != arbiter) revert Unauthorized();
        if (_agent == address(0)) revert ZeroAddress();
        if (_agent == arbiter) revert CannotDelegateSelf();

        arbiterDelegates[arbiter][_agent] = true;
        agentToArbiter[_agent] = arbiter;

        emit AgentDelegated(arbiter, _agent, "Arbiter", block.timestamp);
    }

    /**
     * @notice Revoke agent delegation for creator
     * @dev Epic: AI Agent Integration - Revoke Delegation
     */
    function revokeCreatorAgent(address _agent) external {
        if (msg.sender != creator) revert Unauthorized();

        creatorDelegates[creator][_agent] = false;
        delete agentToCreator[_agent];

        emit AgentRevoked(creator, _agent, "Creator", block.timestamp);
    }

    /**
     * @notice Revoke agent delegation for freelancer
     * @dev Epic: AI Agent Integration - Revoke Delegation
     */
    function revokeFreelancerAgent(address _agent) external {
        if (msg.sender != freelancer) revert Unauthorized();

        freelancerDelegates[freelancer][_agent] = false;
        delete agentToFreelancer[_agent];

        emit AgentRevoked(freelancer, _agent, "Freelancer", block.timestamp);
    }

    /**
     * @notice Revoke agent delegation for arbiter
     * @dev Epic: AI Agent Integration - Revoke Delegation
     */
    function revokeArbiterAgent(address _agent) external {
        if (msg.sender != arbiter) revert Unauthorized();

        arbiterDelegates[arbiter][_agent] = false;
        delete agentToArbiter[_agent];

        emit AgentRevoked(arbiter, _agent, "Arbiter", block.timestamp);
    }

    // ========================================
    // EPIC: PROJECT LIFECYCLE MANAGEMENT
    // ========================================

    /**
     * @notice Application System - Freelancer applies to project
     * @dev Epic: Project Lifecycle Management - Application System
     */
    function applyProject() external inState(ProjectState.Open) {
        if (applicants[msg.sender]) revert AlreadyApplied();
        applicants[msg.sender] = true;
        applicantList.push(msg.sender);
        emit Applied(msg.sender, block.timestamp);
    }

    /**
     * @notice Direct Invitations - Creator invites specific freelancer
     * @dev Epic: Project Lifecycle Management - Direct Invitations
     * @dev Now supports AI Agent delegation
     */
    function inviteFreelancer(
        address _freelancer
    ) external onlyCreatorOrAgent inState(ProjectState.Open) {
        if (_freelancer == address(0)) revert ZeroAddress();
        emit ProjectInvitation(_freelancer, creator);
    }

    /**
     * @notice Application Review - Creator approves freelancer
     * @dev Epic: Project Lifecycle Management - Application Review & Direct Invitations
     * @dev Now supports AI Agent delegation
     * If the address provided hasn't applied, they are added as an applicant and approved in one step.
     */
    function approveFreelancer(
        address payable _approvedFreelancer
    ) external onlyCreatorOrAgent inState(ProjectState.Open) {
        if (_approvedFreelancer == address(0)) revert ZeroAddress();

        // Direct Invitation Logic: If not already an applicant, add them.
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
     * @notice Cancel project
     * @dev Epic: Project Lifecycle Management
     * @dev Now supports AI Agent delegation
     */
    function cancelProject() external onlyCreatorOrAgent {
        require(
            projectState == ProjectState.Open ||
                projectState == ProjectState.InProgress,
            "Cannot cancel completed project"
        );
        projectState = ProjectState.Canceled;
        emit ProjectCanceled(block.timestamp);
    }

    // ========================================
    // EPIC: MILESTONE & PAYMENT SYSTEM
    // ========================================

    /**
     * @notice Milestone Definition - Creator defines milestone with budget
     * @dev Epic: Milestone & Payment System - Milestone Definition
     * @dev Now supports AI Agent delegation
     */
    function addMilestone(
        string memory _description,
        uint256 _budget,
        uint256 _deadline
    ) external onlyCreatorOrAgent inState(ProjectState.InProgress) {
        if (_deadline <= block.timestamp) revert InvalidDeadline();

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

    function fundMilestone(
        uint256 _milestoneId
    )
        external
        onlyCreatorOrAgent
        inState(ProjectState.InProgress)
        milestoneInState(_milestoneId, MilestoneState.Defined)
    {
        Milestone storage milestone = milestones[_milestoneId];
        uint256 amount = milestone.budget;
        
        // Check if user has approved enough USDC
        uint256 allowance = usdcToken.allowance(msg.sender, address(this));
        if (allowance < amount) {
            revert InvalidAmount(allowance, amount);
        }
        
        // Transfer USDC from creator to this contract
        require(
            usdcToken.transferFrom(msg.sender, address(this), amount),
            "USDC transfer failed"
        );
        
        milestone.state = MilestoneState.Funded;
        emit MilestoneFunded(_milestoneId, amount);
    }

    /**
     * @notice Work Submission - Freelancer submits work for milestone
     * @dev Epic: Milestone & Payment System - Work Submission
     * @dev Now supports AI Agent delegation
     */
    function submitWork(
        uint256 _milestoneId,
        string memory _workCID
    )
        external
        onlyFreelancerOrAgent
        inState(ProjectState.InProgress)
        milestoneInState(_milestoneId, MilestoneState.Funded)
    {
        milestones[_milestoneId].state = MilestoneState.Submitted;
        milestones[_milestoneId].workSubmissionCID = _workCID;
        emit WorkSubmitted(_milestoneId, _workCID, freelancer, block.timestamp);
    }

    /**
     * @notice Work Approval & Automated Payments - Creator approves work and releases payment
     * @dev Epic: Milestone & Payment System - Work Approval & Automated Payments
     * @dev Epic: Reputation & Rewards - SBT Rewards upon project completion
     * @dev Now supports AI Agent delegation
     */
    function releasePayment(
        uint256 _milestoneId,
        string calldata _creatorSbtCID,
        string calldata _freelancerSbtCID
    )
        external
        onlyCreatorOrAgent
        nonReentrant
        inState(ProjectState.InProgress)
        milestoneInState(_milestoneId, MilestoneState.Submitted)
    {
        Milestone storage milestone = milestones[_milestoneId];
        uint256 payment = milestone.budget;
        milestone.state = MilestoneState.Approved;

        // Transfer USDC payment to freelancer
        require(
            usdcToken.transfer(freelancer, payment),
            "USDC payment failed"
        );

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

            // Epic: Reputation & Rewards - SBT Rewards
            IProjectFactory(factory).mintReputationForProject(
                creator,
                projectId,
                "Creator",
                _creatorSbtCID
            );
            IProjectFactory(factory).mintReputationForProject(
                freelancer,
                projectId,
                "Freelancer",
                _freelancerSbtCID
            );

            emit ReputationTokenMinted(creator, "Creator", _creatorSbtCID);
            emit ReputationTokenMinted(
                freelancer,
                "Freelancer",
                _freelancerSbtCID
            );
            emit ProjectCompleted(completedAt);
        }
    }

    // ========================================
    // EPIC: DISPUTE RESOLUTION
    // ========================================

    /**
     * @notice Dispute Creation - Creator disputes milestone work
     * @dev Epic: Dispute Resolution - Dispute Creation
     * @dev Now supports AI Agent delegation
     */
    function raiseDispute(
        uint256 _milestoneId,
        string memory _reason
    )
        external
        onlyCreatorOrAgent
        inState(ProjectState.InProgress)
        milestoneInState(_milestoneId, MilestoneState.Submitted)
    {
        milestones[_milestoneId].state = MilestoneState.Disputed;
        emit DisputeRaised(_milestoneId, creator, _reason, block.timestamp);
    }

    /**
     * @notice Dispute Resolution - Arbiter resolves dispute
     * @dev Epic: Dispute Resolution
     * @dev Now supports AI Agent delegation
     */
    function resolveDispute(
        uint256 _milestoneId,
        bool _payFreelancer
    )
        external
        onlyArbiterOrAgent
        inState(ProjectState.InProgress)
        milestoneInState(_milestoneId, MilestoneState.Disputed)
        nonReentrant
    {
        Milestone storage milestone = milestones[_milestoneId];
        uint256 payment = milestone.budget;
        milestone.state = MilestoneState.Approved;
        address recipient = _payFreelancer ? freelancer : creator;
        
        // Transfer USDC to the decided recipient
        require(
            usdcToken.transfer(recipient, payment),
            "USDC payment failed"
        );

        emit DisputeResolved(
            _milestoneId,
            _payFreelancer,
            arbiter,
            block.timestamp
        );
        emit PaymentReleased(_milestoneId, recipient, payment, block.timestamp);
    }

    // ========================================
    // VIEW FUNCTIONS & UTILITIES
    // ========================================

    /**
     * @notice Check if project is complete (all milestones approved)
     * @dev Internal utility function
     */
    function _isProjectComplete() internal view returns (bool) {
        if (milestones.length == 0) return false;
        for (uint i = 0; i < milestones.length; i++) {
            if (milestones[i].state != MilestoneState.Approved) return false;
        }
        return true;
    }

    /**
     * @notice Get all applicants for project discovery and creator dashboard
     * @dev Epic: Project Lifecycle Management - Creator Dashboard, Project Discovery
     */
    function getApplicants() external view returns (address[] memory) {
        return applicantList;
    }

    /**
     * @notice Get project metadata for project discovery
     * @dev Epic: Project Lifecycle Management - Project Discovery
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
     * @dev Epic: Milestone & Payment System
     */
    function getMilestone(
        uint256 _milestoneId
    ) external view returns (Milestone memory) {
        if (_milestoneId >= milestones.length) revert MilestoneNotFound();
        return milestones[_milestoneId];
    }

    /**
     * @notice Get all milestones
     * @dev Epic: Milestone & Payment System
     */
    function getAllMilestones() external view returns (Milestone[] memory) {
        return milestones;
    }

    /**
     * @notice Get project status for creator dashboard
     * @dev Epic: Project Lifecycle Management - Creator Dashboard
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
     * @dev Epic: Project Lifecycle Management - Application System
     */
    function hasApplied(address _applicant) external view returns (bool) {
        return applicants[_applicant];
    }

    /**
     * @notice Get project timeline information
     * @dev Epic: Project Lifecycle Management - Creator Dashboard
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
     * @notice Get the XMTP room ID associated with this project
     * @dev Epic: AI Agent Integration - XMTP Protocol Integration
     * @return The XMTP room ID for AI agent and user interactions
     */
    function getXmtpRoomId() external view returns (string memory) {
        return projectMetadata.xmtpRoomId;
    }

    // ========================================
    // AI AGENT VIEW FUNCTIONS
    // ========================================

    /**
     * @notice Check if an address is an authorized agent for creator
     * @dev Epic: AI Agent Integration - Agent Authorization Check
     */
    function isAuthorizedCreatorAgent(
        address _agent
    ) external view returns (bool) {
        return creatorDelegates[creator][_agent];
    }

    /**
     * @notice Check if an address is an authorized agent for freelancer
     * @dev Epic: AI Agent Integration - Agent Authorization Check
     */
    function isAuthorizedFreelancerAgent(
        address _agent
    ) external view returns (bool) {
        if (freelancer == address(0)) return false;
        return freelancerDelegates[freelancer][_agent];
    }

    /**
     * @notice Check if an address is an authorized agent for arbiter
     * @dev Epic: AI Agent Integration - Agent Authorization Check
     */
    function isAuthorizedArbiterAgent(
        address _agent
    ) external view returns (bool) {
        return arbiterDelegates[arbiter][_agent];
    }

    /**
     * @notice Get delegation info for an agent
     * @dev Epic: AI Agent Integration - Agent Information
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
