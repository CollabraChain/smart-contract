// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
/**
 * @title ICollabraChainReputation
 * @notice Interface for the on-chain reputation system (SBTs).
 */
interface ICollabraChainReputation is IERC721 {
    function mintReputation(
        address freelancer,
        address projectContract,
        string memory tokenURI
    ) external;
}

/**
 * @title ICollabraChainProject
 * @notice Interface for the project management contract.
 */
interface ICollabraChainProject {
    function fundProject() external;
    function approveAndPayMilestone(
        uint256 milestoneId,
        string calldata completionURI
    ) external;
}
