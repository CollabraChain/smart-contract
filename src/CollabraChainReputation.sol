// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CollabraChainReputation
 * @author Your Name
 * @notice A production-grade Soul-Bound Token (SBT) for on-chain reputation.
 * @dev This version enforces non-transferability by overriding the internal _update hook.
 */
contract CollabraChainReputation is ERC721, Ownable {
    // --- Structs ---
    struct ReputationData {
        uint256 projectId;
        string role;
        uint256 timestamp;
    }

    // --- State Variables ---
    uint256 private _nextTokenId = 1;
    mapping(uint256 => ReputationData) private _tokenData;
    mapping(uint256 => string) private _tokenMetadataCIDs;

    // --- Errors ---
    error SoulBound();
    error TokenDoesNotExist();
    error EmptyCID();

    // --- Constructor ---
    constructor(
        address initialOwner
    ) ERC721("CollabraChain Reputation", "CCR") Ownable(initialOwner) {}

    // --- Minting Function ---
    function mint(
        address recipient,
        uint256 projectId,
        string calldata role,
        string calldata metadataCID
    ) public onlyOwner {
        if (bytes(metadataCID).length == 0) revert EmptyCID();

        uint256 tokenId = _nextTokenId;
        _tokenData[tokenId] = ReputationData({
            projectId: projectId,
            role: role,
            timestamp: block.timestamp
        });
        _tokenMetadataCIDs[tokenId] = metadataCID;
        _safeMint(recipient, tokenId);
        _nextTokenId++;
    }

    // --- Metadata Function ---
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        string memory cid = _tokenMetadataCIDs[tokenId];
        return string(abi.encodePacked("ipfs://", cid));
    }

    // --- View Function ---
    function getTokenData(
        uint256 tokenId
    ) public view returns (ReputationData memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _tokenData[tokenId];
    }

    // --- SOUL-BOUND MECHANISM ---
    /**
     * @dev Overrides the internal _update hook to prevent any token transfers except for minting.
     * Minting is identified by the `from` address being `address(0)`.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);

        // Allow minting (from == address(0)) but block all other transfers.
        if (from != address(0) && to != address(0)) {
            revert SoulBound();
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override approve to prevent any approvals on soul-bound tokens.
     */
    function approve(
        address /* to */,
        uint256 /* tokenId */
    ) public virtual override {
        revert SoulBound();
    }

    /**
     * @dev Override setApprovalForAll to prevent any approvals on soul-bound tokens.
     */
    function setApprovalForAll(
        address /* operator */,
        bool /* approved */
    ) public virtual override {
        revert SoulBound();
    }
}
