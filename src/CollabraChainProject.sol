// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Interface.sol";

contract CollabraChainProject is ReentrancyGuard {
    // --- STATE ---
    address public immutable client;
    address public immutable freelancer;
    address public immutable agent;
    ICollabraChainReputation public immutable reputationContract;
    IERC20 public immutable paymentToken;

    enum ProjectStatus {
        Created,
        InProgress,
        InDispute,
        Completed,
        Cancelled
    }
    ProjectStatus public projectStatus;

    struct Milestone {
        string description;
        uint256 amount;
        MilestoneStatus status;
        string completionURI; // Link to proof of work
    }
    enum MilestoneStatus {
        Pending,
        Approved,
        Paid
    }

    Milestone[] public milestones;
    uint256 public totalProjectValue;
    uint256 public remainingBalance;

    // --- EVENTS ---
    event ProjectFunded(uint256 totalAmount);
    event MilestoneApproved(uint256 milestoneId, string completionURI);
    event PaymentReleased(
        address indexed to,
        uint256 amount,
        uint256 milestoneId
    );
    event DisputeRaised(address indexed raisedBy);
    event ProjectCompleted();
    event ProjectCancelled();

    // --- MODIFIERS ---
    modifier onlyClient() {
        require(msg.sender == client, "Only client");
        _;
    }
    modifier onlyAgent() {
        require(msg.sender == agent, "Only agent");
        _;
    }
    modifier inState(ProjectStatus _status) {
        require(projectStatus == _status, "Invalid state");
        _;
    }

    constructor(
        address _client,
        address _freelancer,
        address _agent,
        address _tokenAddress,
        address _reputationContractAddress,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneAmounts
    ) {
        client = _client;
        freelancer = _freelancer;
        agent = _agent;
        paymentToken = IERC20(_tokenAddress);
        reputationContract = ICollabraChainReputation(
            _reputationContractAddress
        );

        for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
            require(_milestoneAmounts[i] > 0, "Amount must be > 0");
            milestones.push(
                Milestone(
                    _milestoneDescriptions[i],
                    _milestoneAmounts[i],
                    MilestoneStatus.Pending,
                    ""
                )
            );
            totalProjectValue += _milestoneAmounts[i];
        }
    }

    function fundProject()
        external
        onlyClient
        inState(ProjectStatus.Created)
        nonReentrant
    {
        remainingBalance = totalProjectValue;
        require(
            paymentToken.allowance(msg.sender, address(this)) >=
                totalProjectValue,
            "Contract not approved"
        );
        paymentToken.transferFrom(msg.sender, address(this), totalProjectValue);
        projectStatus = ProjectStatus.InProgress;
        emit ProjectFunded(totalProjectValue);
    }

    function approveAndPayMilestone(
        uint256 _milestoneId,
        string calldata _completionURI
    ) external onlyAgent inState(ProjectStatus.InProgress) nonReentrant {
        Milestone storage milestone = milestones[_milestoneId];
        require(
            milestone.status == MilestoneStatus.Pending,
            "Milestone not pending"
        );

        milestone.status = MilestoneStatus.Approved;
        milestone.completionURI = _completionURI;
        emit MilestoneApproved(_milestoneId, _completionURI);

        uint256 amount = milestone.amount;
        remainingBalance -= amount;
        milestone.status = MilestoneStatus.Paid;
        paymentToken.transfer(freelancer, amount);
        emit PaymentReleased(freelancer, amount, _milestoneId);

        _checkCompletion();
    }

    function raiseDispute() external inState(ProjectStatus.InProgress) {
        require(
            msg.sender == client || msg.sender == freelancer,
            "Not a party to project"
        );
        projectStatus = ProjectStatus.InDispute;
        emit DisputeRaised(msg.sender);
    }

    function cancelAndWithdraw() external onlyClient {
        require(
            projectStatus == ProjectStatus.InProgress ||
                projectStatus == ProjectStatus.InDispute,
            "Cannot cancel now"
        );
        projectStatus = ProjectStatus.Cancelled;
        uint256 balance = remainingBalance;
        remainingBalance = 0;
        paymentToken.transfer(client, balance);
        emit ProjectCancelled();
    }

    function _checkCompletion() internal {
        for (uint i = 0; i < milestones.length; i++) {
            if (milestones[i].status != MilestoneStatus.Paid) return;
        }
        projectStatus = ProjectStatus.Completed;
        // Upon full completion, mint a reputation token for the freelancer
        reputationContract.mintReputation(
            freelancer,
            address(this),
            milestones[0].completionURI
        ); // Example URI
        emit ProjectCompleted();
    }
}
