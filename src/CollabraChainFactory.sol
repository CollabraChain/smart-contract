// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./CollabraChainProject.sol";

contract CollabraChainFactory is AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    address[] public allProjects;
    mapping(address => address[]) public projectsByClient;
    mapping(address => address[]) public projectsByFreelancer;

    address public immutable usdcTokenAddress;
    address public immutable reputationContractAddress;

    event ProjectCreated(
        address indexed projectAddress,
        address indexed client,
        address indexed freelancer
    );

    constructor(
        address _usdcAddress,
        address _reputationAddress,
        address initialAdmin,
        address initialAgent
    ) {
        usdcTokenAddress = _usdcAddress;
        reputationContractAddress = _reputationAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(AGENT_ROLE, initialAgent);
    }

    function createProject(
        address _client,
        address _freelancer,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneAmounts
    ) external onlyRole(AGENT_ROLE) returns (address) {
        CollabraChainProject newProject = new CollabraChainProject(
            _client,
            _freelancer,
            msg.sender, // The agent calling this function is set as the project's agent
            usdcTokenAddress,
            reputationContractAddress,
            _milestoneDescriptions,
            _milestoneAmounts
        );

        address projectAddress = address(newProject);
        allProjects.push(projectAddress);
        projectsByClient[_client].push(projectAddress);
        projectsByFreelancer[_freelancer].push(projectAddress);

        emit ProjectCreated(projectAddress, _client, _freelancer);
        return projectAddress;
    }

    function projectCount() external view returns (uint256) {
        return allProjects.length;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
