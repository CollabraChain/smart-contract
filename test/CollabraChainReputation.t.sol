// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CollabraChainReputation} from "../src/CollabraChainReputation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationTest is Test {
    CollabraChainReputation internal reputation;
    address internal owner;
    address internal user1;
    address internal user2;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        reputation = new CollabraChainReputation(owner);
    }

    function test_Mint_Success() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user1, 1);
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");

        assertEq(reputation.ownerOf(1), user1, "Owner should be user1");
        assertEq(reputation.balanceOf(user1), 1, "Balance should be 1");

        CollabraChainReputation.ReputationData memory data = reputation.getTokenData(1);
        assertEq(data.projectId, 123, "Project ID mismatch");
        assertEq(data.role, "Creator", "Role mismatch");
    }

    function test_Revert_If_NotOwner_Mints() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");
    }

    function test_TokenURI_Correctness() public {
        string
            memory metadataCID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
        reputation.mint(user1, 123, "Creator", metadataCID);

        string memory expectedURI = string(
            abi.encodePacked("ipfs://", metadataCID)
        );
        assertEq(reputation.tokenURI(1), expectedURI, "Token URI is incorrect");
    }

    function test_Revert_On_Transfer() public {
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");

        vm.prank(user1);
        vm.expectRevert(CollabraChainReputation.SoulBound.selector);
        reputation.transferFrom(user1, owner, 1);
    }

    function test_Revert_On_Approve() public {
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");

        vm.prank(user1);
        vm.expectRevert(CollabraChainReputation.SoulBound.selector);
        reputation.approve(owner, 1);
    }

    function test_Revert_If_TokenDoesNotExist() public {
        vm.expectRevert(CollabraChainReputation.TokenDoesNotExist.selector);
        reputation.tokenURI(999);
    }

    // ========================================
    // NEW TESTS FOR BRANCH COVERAGE
    // ========================================

    function test_Revert_On_EmptyCID() public {
        vm.expectRevert(CollabraChainReputation.EmptyCID.selector);
        reputation.mint(user1, 123, "Creator", ""); // Empty CID
    }

    function test_Revert_On_SetApprovalForAll() public {
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");

        vm.prank(user1);
        vm.expectRevert(CollabraChainReputation.SoulBound.selector);
        reputation.setApprovalForAll(user2, true);
    }

    function test_GetTokenData_NonExistentToken() public {
        vm.expectRevert(CollabraChainReputation.TokenDoesNotExist.selector);
        reputation.getTokenData(999);
    }

    function test_MultipleMints_DifferentProjects() public {
        // Test multiple mints to verify token ID incrementing
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");
        reputation.mint(user1, 456, "Freelancer", "ipfs://cid2");
        reputation.mint(user2, 789, "Creator", "ipfs://cid3");

        assertEq(reputation.balanceOf(user1), 2);
        assertEq(reputation.balanceOf(user2), 1);
        assertEq(reputation.ownerOf(1), user1);
        assertEq(reputation.ownerOf(2), user1);
        assertEq(reputation.ownerOf(3), user2);

        // Verify different project IDs
        CollabraChainReputation.ReputationData memory data1 = reputation.getTokenData(1);
        CollabraChainReputation.ReputationData memory data2 = reputation.getTokenData(2);
        CollabraChainReputation.ReputationData memory data3 = reputation.getTokenData(3);

        assertEq(data1.projectId, 123);
        assertEq(data2.projectId, 456);
        assertEq(data3.projectId, 789);
    }

    function test_SoulBound_Transfer_Branches() public {
        reputation.mint(user1, 123, "Creator", "ipfs://cid1");

        // Test the specific branch condition: from != address(0) && to != address(0)
        // This should revert for any transfer between non-zero addresses
        vm.prank(user1);
        vm.expectRevert(CollabraChainReputation.SoulBound.selector);
        reputation.safeTransferFrom(user1, user2, 1);

        vm.prank(user1);
        vm.expectRevert(CollabraChainReputation.SoulBound.selector);
        reputation.safeTransferFrom(user1, user2, 1, "");
    }
}
