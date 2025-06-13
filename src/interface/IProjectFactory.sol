// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProjectFactory {
    function mintReputationForProject(
        address recipient,
        uint256 projectId,
        string calldata role,
        string calldata metadataCID
    ) external;
}
