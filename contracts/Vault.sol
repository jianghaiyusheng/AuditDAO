// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Vault is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    address public immutable baseToken;
    uint8 public immutable baseTokenDecimals;
    uint64 public stakeNeedForTask;

    struct BaseBugBounty {
        uint64 highLevel;
        uint64 mediumLevel;
        uint64 lowLevel;
    }
    BaseBugBounty public baseBugBounty;

    mapping(address => uint) userBountyCanWithdraw;
    mapping(address => uint) userAuditCountForWithdrawStake;
    struct AuditBounty {
        uint taskIndex;
        address[] auditMembers;
        uint[] bounties;
    }
    mapping(uint => AuditBounty) auditBounties;
    mapping(address => EnumerableSet.UintSet) userAudits;

    constructor(
        address _baseToken,
        uint _stakeNeedForTask,
        uint highBounty,
        uint mediumBounty,
        uint lowBounty
    ) {
        baseToken = _baseToken;
        baseTokenDecimals = IERC20Metadata(_baseToken).decimals();
        _setStakeNeedForTask(_stakeNeedForTask);
        _setBaseBugBounty(highBounty, mediumBounty, lowBounty);
    }

    function _setStakeNeedForTask(uint _stakeNeedForTask) internal {
        require(_stakeNeedForTask > 200, "stakeNeedForTask must be larger than 200U.");
        stakeNeedForTask = uint64(_stakeNeedForTask);
    }

    function setBaseBugBounty(
        uint highBounty,
        uint mediumBounty,
        uint lowBounty
    ) external onlyOwner {
        _setBaseBugBounty(highBounty, mediumBounty, lowBounty);
    }

    function _setBaseBugBounty(
        uint highBounty,
        uint mediumBounty,
        uint lowBounty
    ) internal {
        baseBugBounty.highLevel = uint64(highBounty);
        baseBugBounty.mediumLevel = uint64(mediumBounty);
        baseBugBounty.lowLevel = uint64(lowBounty);
    }

    function _stake() internal {
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), stakeNeedForTask);
    }

    function _dispatchBounty(uint taskIndex, address[] memory auditMembers, uint[] memory bounties) internal {
        require(auditMembers.length == bounties.length, "the auditMembers and the bounties are mismatch.");
        uint sumBounty;
        for (uint256 i = 0; i < bounties.length; ) {
            sumBounty += bounties[i];
            unchecked {
                i++;
            }
        }
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), stakeNeedForTask);
        for (uint256 i = 0; i < auditMembers.length; ) {
            userBountyCanWithdraw[auditMembers[i]] += bounties[i];
            userAuditCountForWithdrawStake[auditMembers[i]]++;
            EnumerableSet.UintSet storage userAudit = userAudits[auditMembers[i]];
            userAudit.add(taskIndex);
            unchecked {
                i++;
            }
        }
        AuditBounty storage auditBounty = auditBounties[taskIndex];
        auditBounty.auditMembers = auditMembers;
        auditBounty.bounties = bounties;
    }

    function _withdrawStake(uint stakeOnOneTask) internal {
        require(userAuditCountForWithdrawStake[msg.sender]>0, "user has to audit for others before withdraw the stake");
        userAuditCountForWithdrawStake[msg.sender]--;    
        IERC20(baseToken).safeTransfer(msg.sender, stakeOnOneTask);
    }

    function withdrawBounty(uint value) external {
        require(value <= userBountyCanWithdraw[msg.sender],"user can only withdraw the value they have");
        userBountyCanWithdraw[msg.sender] -= value;
        IERC20(baseToken).safeTransfer(msg.sender, value);
    }

}