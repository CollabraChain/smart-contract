// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CollabraChainProject} from "./CollabraChainProject.sol";
import {IReputation} from "./interface/IReputation.sol";

/**
 * @title CollabraChainFactoryUnprotected
 * @author Your Name
 * @notice Unprotected factory for creating projects and controller for minting reputation tokens.
 * @dev This is the unprotected version without access controls on reputation minting.
 */
contract CollabraChainFactoryUnprotected {
    // --- Events ---
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

    // --- State Variables ---
    address[] public allProjects;
    IReputation public immutable reputationContract;
    address public immutable usdcToken;
    mapping(address => bool) public isProject; // Mapping to verify valid projects
    mapping(string => address[]) public projectsByXmtpRoom; // Mapping XMTP roomId to project addresses
    mapping(address => string) public projectToXmtpRoom; // Mapping project address to XMTP roomId

    // --- Errors ---
    error ZeroAddress();
    error UnauthorizedProject();

    /**
     * @param _reputationContract The address of the deployed Reputation SBT contract.
     * @param _usdcToken The address of the USDC token contract.
     */
    constructor(address _reputationContract, address _usdcToken) {
        if (_reputationContract == address(0)) revert ZeroAddress();
        if (_usdcToken == address(0)) revert ZeroAddress();
        reputationContract = IReputation(_reputationContract);
        usdcToken = _usdcToken;
    }

    /**
     * @notice Creates a new Project, open for applications.
     * @dev Epic: Project Lifecycle Management - Project Creation
     */
    function createProject(
        string memory _title,
        string memory _description,
        string memory _category,
        string[] memory _skillsRequired,
        uint256 _totalBudget,
        uint256 _deadline,
        string memory _projectScopeCID,
        string memory _xmtpRoomId
    ) public returns (address projectAddress) {
        CollabraChainProject newProject = new CollabraChainProject(
            payable(msg.sender), // creator
            address(reputationContract), // reputationContract
            address(this), // factory
            usdcToken, // usdcToken
            _title, // title
            _description, // description
            _category, // category
            _skillsRequired, // skillsRequired
            _totalBudget, // totalBudget
            _deadline, // deadline
            _projectScopeCID, // projectScopeCID
            _xmtpRoomId // xmtpRoomId
        );

        projectAddress = address(newProject);
        allProjects.push(projectAddress);
        isProject[projectAddress] = true; // Register the new project

        // Register project with XMTP room mapping
        projectsByXmtpRoom[_xmtpRoomId].push(projectAddress);
        projectToXmtpRoom[projectAddress] = _xmtpRoomId;

        emit ProjectCreated(
            projectAddress,
            msg.sender,
            _title,
            _category,
            _totalBudget,
            _deadline,
            _projectScopeCID,
            _xmtpRoomId
        );
    }

    /**
     * @notice Called to mint reputation tokens.
     * @dev Unprotected version - anyone can call this function to mint reputation tokens.
     */
    function mintReputationForProject(
        address recipient,
        uint256 projectId,
        string calldata role,
        string calldata metadataCID
    ) external {
        reputationContract.mint(recipient, projectId, role, metadataCID);
    }

    function getProjectsCount() public view returns (uint256) {
        return allProjects.length;
    }

    /**
     * @notice Get all projects associated with a specific XMTP room
     * @param _xmtpRoomId The XMTP room ID to query
     * @return Array of project addresses in the specified room
     */
    function getProjectsByXmtpRoom(
        string memory _xmtpRoomId
    ) public view returns (address[] memory) {
        return projectsByXmtpRoom[_xmtpRoomId];
    }

    /**
     * @notice Get the XMTP room ID for a specific project
     * @param _projectAddress The project address to query
     * @return The XMTP room ID associated with the project
     */
    function getXmtpRoomForProject(
        address _projectAddress
    ) public view returns (string memory) {
        return projectToXmtpRoom[_projectAddress];
    }

    /**
     * @notice Get the count of projects in a specific XMTP room
     * @param _xmtpRoomId The XMTP room ID to query
     * @return Number of projects in the specified room
     */
    function getProjectCountByXmtpRoom(
        string memory _xmtpRoomId
    ) public view returns (uint256) {
        return projectsByXmtpRoom[_xmtpRoomId].length;
    }
}
