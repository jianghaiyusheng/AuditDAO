// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./Vault.sol";

contract TaskManage is Vault {

    enum TaskState {
        Publish,
        Auditing,
        Finish,
        Abandon
    }
    struct TaskInfo {
        string businessDesc;
        string projectEmail;
        uint64 numCodeLine;
        address projectAddr;
        uint64 bountyMultiplier;
        uint64 stakeValue;
        // bool stakeWithdrawed;
        uint64 taskPublishTime;
        TaskState taskState;
    }
    TaskInfo[] public tasks;
    struct UserTasks {
        uint[] taskIndexs;
        uint[] canWithdrawIndexs;
        // uint64 numPublish;
        // uint64 numAuditing;
        uint64 numFinish;
        uint64 numAbandon;
    }
    mapping(address => UserTasks) public userTasks;

    constructor(
        address _baseToken,
        uint _stakeNeedForTask,
        uint highBounty,
        uint mediumBounty,
        uint lowBounty
    ) Vault(_baseToken, _stakeNeedForTask, highBounty, mediumBounty, lowBounty){

    }

    function publishTask(string calldata businessDesc, string calldata projectEmail, uint numCodeLine, uint bountyMultiplier) external {
        
        UserTasks storage _userTasks = userTasks[msg.sender];
        uint numUserTasks = _userTasks.taskIndexs.length;
        if (numUserTasks > 0) {
            TaskInfo memory curTask = tasks[_userTasks.taskIndexs[numUserTasks-1]];
            require(curTask.taskState == TaskState.Finish || curTask.taskState == TaskState.Abandon,"The user has unfineshed task yet.");
        }

        _stake();
        uint taskIndex = tasks.length;
        TaskInfo storage task = tasks[taskIndex];
        task.businessDesc = businessDesc;
        task.projectEmail = projectEmail;
        task.numCodeLine = uint64(numCodeLine);
        task.projectAddr = msg.sender;
        task.bountyMultiplier = uint64(bountyMultiplier);
        task.stakeValue = stakeNeedForTask;
        // task.stakeWithdrawed = false;
        task.taskPublishTime = uint64(block.timestamp);
        task.taskState = TaskState.Publish;

        _userTasks.taskIndexs.push(taskIndex);
        _userTasks.canWithdrawIndexs.push(taskIndex);
    }

    function startTask() external{
        UserTasks memory _userTasks = userTasks[msg.sender];
        uint numUserTasks = _userTasks.taskIndexs.length;
        require(numUserTasks > 0, "The user has not published task yet.");

        TaskInfo storage theTask = tasks[_userTasks.taskIndexs[numUserTasks-1]];
        require(theTask.taskState == TaskState.Publish,"the user's current task state is not publish");
        theTask.taskState = TaskState.Auditing;
    }

    function abandonTask() external {
        UserTasks storage _userTasks = userTasks[msg.sender];
        uint numUserTasks = _userTasks.taskIndexs.length;
        require(numUserTasks > 0, "The user has no task yet.");

        TaskInfo storage theTask = tasks[_userTasks.taskIndexs[numUserTasks-1]];
        require(theTask.taskState == TaskState.Publish || theTask.taskState == TaskState.Auditing,"the user's current task state is not publish or auditing");
        _userTasks.numAbandon++;
        theTask.taskState = TaskState.Abandon;
    }

    function finishTask(address[] calldata auditMembers, uint[] calldata bounties) external {
        UserTasks storage _userTasks = userTasks[msg.sender];
        uint numUserTasks = _userTasks.taskIndexs.length;
        require(numUserTasks > 0, "The user has no task yet.");

        uint taskIndex = _userTasks.taskIndexs[numUserTasks-1];
        TaskInfo storage theTask = tasks[taskIndex];
        require(theTask.taskState == TaskState.Publish || theTask.taskState == TaskState.Auditing,"the user's current task state is not publish or auditing");
        _dispatchBounty(taskIndex, auditMembers, bounties);
        _userTasks.numFinish++;
        theTask.taskState = TaskState.Finish;
    }

    function withdrawStake() external{
        UserTasks storage _userTasks = userTasks[msg.sender];
        uint numCanWithdrawTasks = _userTasks.canWithdrawIndexs.length;
        require(numCanWithdrawTasks > 0, "user has no task can withdraw.");
        TaskInfo memory targetTask = tasks[_userTasks.canWithdrawIndexs[numCanWithdrawTasks-1]];
        _userTasks.canWithdrawIndexs.pop();
        _withdrawStake(targetTask.stakeValue);
    }
}
