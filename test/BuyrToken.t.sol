// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BuyrToken.sol";

contract MockOracle {
    function acceptOnToken(address token) external {
        BuyrToken(token).acceptEmissionOracle();
    }

    function mintOnToken(address token, address to, uint256 amount) external {
        BuyrToken(token).mint(to, amount);
    }
}

contract BuyrTokenTest is Test {
    BuyrToken public token;
    MockOracle public oracle;
    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        vm.prank(owner);
        token = new BuyrToken(owner);
        oracle = new MockOracle();
    }

    // --- Construction ---

    function test_name() public view {
        assertEq(token.name(), "Shulam Buyer Token");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "BUYR");
    }

    function test_decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_maxSupply() public view {
        assertEq(token.MAX_SUPPLY(), 10_000_000_000 * 10 ** 18);
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
        emit BuyrToken.EmissionOracleProposed(address(oracle));
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
        vm.expectRevert(BuyrToken.ZeroAddress.selector);
        token.setEmissionOracle(address(0));
    }

    function test_setEmissionOracle_canRepropose() public {
        MockOracle oracle2 = new MockOracle();
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
        vm.expectRevert(BuyrToken.EmissionOracleLocked.selector);
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
        emit BuyrToken.EmissionOracleSet(address(oracle));
        oracle.acceptOnToken(address(token));
    }

    function test_acceptEmissionOracle_revertNotPending() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));

        vm.prank(user);
        vm.expectRevert(BuyrToken.NotPendingOracle.selector);
        token.acceptEmissionOracle();
    }

    function test_acceptEmissionOracle_revertNoPending() public {
        vm.prank(user);
        vm.expectRevert(BuyrToken.NotPendingOracle.selector);
        token.acceptEmissionOracle();
    }

    function test_acceptEmissionOracle_revertAfterLocked() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        // Even if somehow pendingEmissionOracle were set, locked check prevents
        vm.prank(address(oracle));
        vm.expectRevert(BuyrToken.NotPendingOracle.selector);
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
        vm.expectRevert(BuyrToken.OnlyEmissionOracle.selector);
        token.mint(user, 1000 ether);
    }

    function test_mint_revertOracleNotSet() public {
        // emissionOracle is address(0), so msg.sender != emissionOracle for any real caller
        vm.prank(user);
        vm.expectRevert(BuyrToken.OnlyEmissionOracle.selector);
        token.mint(user, 1000 ether);
    }

    function test_mint_revertMaxSupplyExceeded() public {
        vm.prank(owner);
        token.setEmissionOracle(address(oracle));
        oracle.acceptOnToken(address(token));

        uint256 maxSupply = token.MAX_SUPPLY();
        vm.expectRevert(
            abi.encodeWithSelector(BuyrToken.MaxSupplyExceeded.selector, maxSupply + 1, maxSupply)
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

        vm.expectRevert(abi.encodeWithSelector(BuyrToken.MaxSupplyExceeded.selector, 1, 0));
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

    // --- ERC20Permit ---

    function test_permit_domainSeparator() public view {
        // Just verify DOMAIN_SEPARATOR is non-zero (EIP-2612)
        assertTrue(token.DOMAIN_SEPARATOR() != bytes32(0));
    }

    // --- Ownable2Step ---

    function test_transferOwnership_twoStep() public {
        vm.prank(owner);
        token.transferOwnership(user);
        assertEq(token.owner(), owner); // Still owner until accepted
        assertEq(token.pendingOwner(), user);

        vm.prank(user);
        token.acceptOwnership();
        assertEq(token.owner(), user);
    }
}
