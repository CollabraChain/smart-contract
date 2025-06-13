// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReputation {
    /**
     * @notice Mints a new reputation token.
     * @param recipient The address that will receive the SBT.
     * @param projectId A unique identifier for the completed project.
     * @param role The role the recipient played in the project.
     * @param metadataCID The IPFS Content Identifier for the token's metadata JSON file.
     */
    function mint(
        address recipient,
        uint256 projectId,
        string calldata role,
        string calldata metadataCID
    ) external;
}
