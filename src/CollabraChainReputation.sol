// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Interface.sol";

/**
 * @title CollabraChainReputation
 * @author Gemini
 * @notice An ERC721-based contract for minting non-transferable reputation tokens (Soul-Bound Tokens).
 * These tokens represent successfully completed projects for a freelancer.
 */
contract CollabraChainReputation is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _nextTokenId;

    event ReputationMinted(address indexed freelancer, address indexed projectContract, uint256 tokenId, string tokenURI);

    constructor(
        address initialAdmin
    ) ERC721("CollabraChain Reputation", "CCR") {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /**
     * @notice Mints a new reputation token to a freelancer.
     * @dev Can only be called by a registered CollabraChainFactory.
     * @param freelancer The address receiving the SBT.
     * @param projectContract The address of the project contract.
     * @param tokenURI The URI of the token.
     */
    function mintReputation(address freelancer, address projectContract, string memory tokenURI) external {
        uint256 tokenId = _nextTokenId++;
        _safeMint(freelancer, tokenId);
        emit ReputationMinted(freelancer, projectContract, tokenId, tokenURI);
    }

    /**
     * @notice Overrides the standard ERC721 transfer functions to make tokens non-transferable (Soul-Bound).
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        if (_ownerOf(tokenId) != address(0)) {
            revert("Reputation tokens are non-transferable.");
        }
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
