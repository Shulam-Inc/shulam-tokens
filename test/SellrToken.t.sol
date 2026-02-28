// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SellrToken.sol";

contract MockSellrOracle {
    function acceptOnToken(address token) external {
        SellrToken(token).acceptEmissionOracle();
    }

    function mintOnToken(address token, address to, uint256 amount) external {
        SellrToken(token).mint(to, amount);
    }
}

contract SellrTokenTest is Test {
    SellrToken public token;
    MockSellrOracle public oracle;
    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        vm.prank(owner);
        token = new SellrToken(owner);
        oracle = new MockSellrOracle();
    }

    // --- Construction ---

    function test_name() public view {
        assertEq(token.name(), "Shulam Seller Token");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "SELLR");
    }

    function test_decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_maxSupply() public view {
        assertEq(token.MAX_SUPPLY(), 1_000_000_000 * 10 ** 18);
    }

    function test_initialTotalSupply() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_initialEmissionOracle() public view {
        assertEq(token.emissionOracle(), address(0));
    }

    function test_initialPendingEmissionOracle() public view {
        assertEq(token.pendingEmissionOracle(), address(0));
    }

    function test_initialEmissionOracleLocked() public view {
        assertFalse(token.emissionOracleLocked());
    }

    function test_owner() public view {
        assertEq(token.owner(), owner);
    }

    // --- setEmissionOracle ---

    function test_setEmissionOracle() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        assertEq(token.pendingEmissionOracle(), address(oracle));
        assertEq(token.emissionOracle(), address(0));
        assertFalse(token.emissionOracleLocked());
    }

    function test_setEmissionOracle_emitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit SellrToken.EmissionOracleProposed(address(oracle));
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
    }

    function test_setEmissionOracle_revertNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        token.setEmissionOracle(address(oracle));
    }

    function test_setEmissionOracle_revertZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(SellrToken.ZeroAddress.selector);
        token.setEmissionOracle(address(0));
    }

    function test_setEmissionOracle_canRepropose() public {
        MockSellrOracle oracle2 = new MockSellrOracle();
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        assertEq(token.pendingEmissionOracle(), address(oracle));

        vm.prank(owner);
        token.setEmissionOracle(address(oracle2));
        assertEq(token.pendingEmissionOracle(), address(oracle2));
    }

    function test_setEmissionOracle_revertAfterLocked() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        vm.prank(owner);
        vm.expectRevert(SellrToken.EmissionOracleLocked.selector);
        token.setEmissionOracle(address(oracle));
    }

    // --- acceptEmissionOracle ---

    function test_acceptEmissionOracle() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));

        oracle.acceptOnToken(address(token));

        assertEq(token.emissionOracle(), address(oracle));
        assertEq(token.pendingEmissionOracle(), address(0));
        assertTrue(token.emissionOracleLocked());
    }

    function test_acceptEmissionOracle_emitsEvent() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));

        vm.expectEmit(true, false, false, false);
        emit SellrToken.EmissionOracleSet(address(oracle));
        oracle.acceptOnToken(address(token));
    }

    function test_acceptEmissionOracle_revertNotPending() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));

        vm.prank(user);
        vm.expectRevert(SellrToken.NotPendingOracle.selector);
        token.acceptEmissionOracle();
    }

    function test_acceptEmissionOracle_revertNoPending() public {
        vm.prank(user);
        vm.expectRevert(SellrToken.NotPendingOracle.selector);
        token.acceptEmissionOracle();
    }

    // --- mint ---

    function test_mint() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        oracle.mintOnToken(address(token), user, 1000 ether);
        assertEq(token.balanceOf(user), 1000 ether);
        assertEq(token.totalSupply(), 1000 ether);
    }

    function test_mint_revertNotOracle() public {
        vm.prank(user);
        vm.expectRevert(SellrToken.OnlyEmissionOracle.selector);
        token.mint(user, 1000 ether);
    }

    function test_mint_revertMaxSupplyExceeded() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        uint256 maxSupply = token.MAX_SUPPLY();
        vm.expectRevert(
            abi.encodeWithSelector(SellrToken.MaxSupplyExceeded.selector, maxSupply + 1, maxSupply)
        );
        oracle.mintOnToken(address(token), user, maxSupply + 1);
    }

    function test_mint_exactMaxSupply() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        uint256 maxSupply = token.MAX_SUPPLY();
        oracle.mintOnToken(address(token), user, maxSupply);
        assertEq(token.totalSupply(), maxSupply);
    }

    function test_mint_revertAfterMaxReached() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        oracle.mintOnToken(address(token), user, token.MAX_SUPPLY());

        vm.expectRevert(abi.encodeWithSelector(SellrToken.MaxSupplyExceeded.selector, 1, 0));
        oracle.mintOnToken(address(token), user, 1);
    }

    // --- burn ---

    function test_burn() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));
        oracle.mintOnToken(address(token), user, 1000 ether);

        vm.prank(user);
        token.burn(500 ether);
        assertEq(token.balanceOf(user), 500 ether);
        assertEq(token.totalSupply(), 500 ether);
    }

    // --- Different MAX_SUPPLY from BuyrToken ---

    function test_maxSupply_isDifferentFromBuyr() public view {
        // SELLR: 1B, BUYR: 10B
        assertEq(token.MAX_SUPPLY(), 1_000_000_000 * 10 ** 18);
        assertTrue(token.MAX_SUPPLY() < 10_000_000_000 * 10 ** 18);
    }

    // --- ERC20Permit ---

    function test_permit_domainSeparator() public view {
        assertTrue(token.DOMAIN_SEPARATOR() != bytes32(0));
    }

    // --- Ownable2Step ---

    function test_transferOwnership_twoStep() public {
        vm.prank(owner);
        token.transferOwnership(user);
        assertEq(token.owner(), owner);
        assertEq(token.pendingOwner(), user);

        vm.prank(user);
        token.acceptOwnership();
        assertEq(token.owner(), user);
    }
}
