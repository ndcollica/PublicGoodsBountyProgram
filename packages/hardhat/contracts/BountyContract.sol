pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract PublicGoodsBountyContract {

    //Does this need a deposit?
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmBountyRequested(address indexed owner, uint indexed txIndex);//Remove?
    event ConfirmBountyRequestAccepted(address indexed owner, uint indexed txIndex);
    event ConfirmBountyCompleted(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;
    uint public numRequestApprovedConfirmations;
    uint public numBountyCompletedConfirmations;

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isRequested;
    mapping(uint => mapping(address => bool)) public isRequestApproved;
    mapping(uint => mapping(address => bool)) public isBountyCompleted;
    mapping(uint => mapping(address => bool)) public isBountyCompletedConfirmed;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numRequestApprovedConfirmations;
        uint numBountyCompletedConfirmations;
        string name;
        string description;
    }



    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notRequestApproved(uint _txIndex) {
        require(!isRequestApproved[_txIndex][msg.sender], "bounty already approved");
        _;
    }

    modifier notBountyCompleted(uint _txIndex) {
        require(!isBountyCompleted[_txIndex][msg.sender], "bounty already completed");
        _;
    }

    modifier notBountyCompletedConfirmed(uint _txIndex) {
        require(!isBountyCompletedConfirmed[_txIndex][msg.sender], "bounty completed already confirmed");
        _;
    }

    //When deploying contract set numconfirmationsrequired to 1
    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }


    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data,
        string _name,
        string _description

    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0,
                numRequestApprovedConfirmations: 0,
                numBountyCompletedConfirmations: 0,
                name: _name,
                description: _description
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data, _name, _description);
    }

    //update to include new modifiers
    function confirmTransactionRequest(uint _txIndex)
        public
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        isRequested[_txIndex][msg.sender] = true;

        //send to approved to bounty requestor
        emit ConfirmBountyRequested(msg.sender, _txIndex);
    }

    //update to include new modifiers
    function confirmTransactionApprovalRequest(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notRequestApproved(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numRequestApprovedConfirmations += 1;
        isRequestApproved[_txIndex][msg.sender] = true;

        //send to approved to bounty requestor
        emit ConfirmBountyRequestAccepted(msg.sender, _txIndex);
    }

    //update to include new modifiers
    function confirmTransactionBountyCompleted(uint _txIndex)
        public
        txExists(_txIndex)
        notExecuted(_txIndex)
        notBountyCompleted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numRequestApprovedConfirmations += 1;
        isRequestApproved[_txIndex][msg.sender] = true;

        //send to approved to bounty requestor
        emit ConfirmBountyRequestAccepted(msg.sender, _txIndex);
    }


    //update to include new modifiers
    function confirmTransactionBountyCompletedConfirmed(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notBountyCompletedConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numBountyCompletedConfirmations += 1;
        isBountyCompletedConfirmed[_txIndex][msg.sender] = true;

        //send to approved to bounty requestor
        emit ConfirmBountyCompleted(msg.sender, _txIndex);
    }


    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    //add: modifier references
    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numRequestApprovedConfirmations = 0;
        transaction.numBountyCompletedConfirmations = 0;

        isRequested[_txIndex][msg.sender] = false;
        isRequestApproved[_txIndex][msg.sender] = false;
        isBountyCompleted[_txIndex][msg.sender] = false;

        //Does this only send to js that is listening for events
        emit RevokeConfirmation(msg.sender, _txIndex);
    }


    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    //update: include new transaction fields
    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations,
            uint numRequestApprovedConfirmations,
            uint numBountyCompletedConfirmations,
            string name,
            string description
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
            transaction.numRequestApprovedConfirmations;
            transaction.numBountyCompletedConfirmations;
            transaction.name;
            transaction.description;
        );
    }
}
